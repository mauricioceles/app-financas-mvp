import 'package:flutter/material.dart';

import '../models/conversao_forma_lancamento.dart';
import '../models/lancamento.dart';
import '../services/lancamento_service.dart';

enum ResultadoEdicaoLancamento { atualizado, convertido }

class FormularioEdicaoLancamento extends StatefulWidget {
  const FormularioEdicaoLancamento({
    super.key,
    required this.servico,
    required this.lancamento,
  });

  final LancamentoService servico;
  final Lancamento lancamento;

  @override
  State<FormularioEdicaoLancamento> createState() =>
      _FormularioEdicaoLancamentoState();
}

class _FormularioEdicaoLancamentoState
    extends State<FormularioEdicaoLancamento> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _descricaoController;
  late final TextEditingController _valorController;
  late final TextEditingController _parcelasController;
  late final TextEditingController _valorParcelasRestantesController;
  late FormaLancamento _forma;
  late DateTime _vencimento;
  late DateTime _primeiroVencimentoParcelas;
  late PrioridadeLancamento _prioridade;
  StatusLancamento _statusEntrada = StatusLancamento.concluido;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _descricaoController = TextEditingController(
      text: widget.lancamento.descricao,
    );
    final valorInicial = widget.lancamento.valor
        .toStringAsFixed(2)
        .replaceAll('.', ',');
    _valorController = TextEditingController(text: valorInicial);
    _parcelasController = TextEditingController(text: '2');
    _valorParcelasRestantesController = TextEditingController(
      text: valorInicial,
    );
    _forma = widget.lancamento.forma;
    _vencimento = widget.lancamento.vencimento;
    _primeiroVencimentoParcelas = _adicionarMeses(_vencimento, 1);
    _prioridade = widget.lancamento.prioridade;
  }

  @override
  void dispose() {
    _descricaoController.dispose();
    _valorController.dispose();
    _parcelasController.dispose();
    _valorParcelasRestantesController.dispose();
    super.dispose();
  }

  bool get _mudandoForma => _forma != widget.lancamento.forma;

  bool get _convertendoParaParcelado =>
      _mudandoForma && _forma == FormaLancamento.parcelado;

  bool get _convertendoParaEntrada =>
      _mudandoForma && _forma == FormaLancamento.entradaParcelas;

  List<FormaLancamento> get _formasDisponiveis =>
      formasDisponiveisNaEdicao(widget.lancamento);

  double? _converterValor(String texto) {
    var valor = texto.trim().replaceAll(RegExp(r'[R$\s]'), '');

    if (valor.contains(',')) {
      valor = valor.replaceAll('.', '').replaceAll(',', '.');
    }

    return double.tryParse(valor);
  }

  String _formatarValor(double valor) {
    return valor.toStringAsFixed(2).replaceAll('.', ',');
  }

  String _formatarData(DateTime data) {
    final dia = data.day.toString().padLeft(2, '0');
    final mes = data.month.toString().padLeft(2, '0');
    return '$dia/$mes/${data.year}';
  }

  DateTime _adicionarMeses(DateTime data, int quantidade) {
    final totalMeses = data.year * 12 + data.month - 1 + quantidade;
    final ano = totalMeses ~/ 12;
    final mes = totalMeses % 12 + 1;
    final ultimoDia = DateTime(ano, mes + 1, 0).day;
    return DateTime(ano, mes, data.day > ultimoDia ? ultimoDia : data.day);
  }

  Future<void> _selecionarData({bool primeiroVencimento = false}) async {
    final data = await showDatePicker(
      context: context,
      initialDate: primeiroVencimento
          ? _primeiroVencimentoParcelas
          : _vencimento,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (data != null) {
      setState(() {
        if (primeiroVencimento) {
          _primeiroVencimentoParcelas = data;
        } else {
          _vencimento = data;
        }
      });
    }
  }

  String? _resumoConversao() {
    if (_convertendoParaParcelado) {
      final valor = _converterValor(_valorController.text);
      final quantidade = int.tryParse(_parcelasController.text);
      if (valor == null || valor <= 0 || quantidade == null || quantidade < 2) {
        return null;
      }

      final totalCentavos = (valor * 100).round() * quantidade;
      return '$quantidade parcelas de R\$ ${_formatarValor(valor)} = '
          'R\$ ${_formatarValor(totalCentavos / 100)}';
    }

    if (_convertendoParaEntrada) {
      final entrada = _converterValor(_valorController.text);
      final parcela = _converterValor(_valorParcelasRestantesController.text);
      final quantidade = int.tryParse(_parcelasController.text);
      if (entrada == null ||
          entrada <= 0 ||
          parcela == null ||
          parcela <= 0 ||
          quantidade == null ||
          quantidade < 1) {
        return null;
      }

      final totalCentavos =
          (entrada * 100).round() + quantidade * (parcela * 100).round();
      return 'Entrada de R\$ ${_formatarValor(entrada)} + $quantidade parcelas '
          'de R\$ ${_formatarValor(parcela)} = '
          'R\$ ${_formatarValor(totalCentavos / 100)}';
    }

    return null;
  }

  String? _avisoForma() {
    if (_formasDisponiveis.length == 1) {
      if (widget.lancamento.status == StatusLancamento.concluido) {
        return widget.lancamento.tipo == TipoLancamento.receita
            ? 'A forma de uma receita já recebida não pode ser alterada.'
            : 'A forma de uma despesa já paga não pode ser alterada.';
      }
      return 'Para proteger o histórico, a forma desta série não pode ser '
          'alterada por esta tela.';
    }

    if (!_mudandoForma) {
      return null;
    }

    if (widget.lancamento.forma == FormaLancamento.fixo) {
      return 'O histórico anterior será mantido. Esta conta fixa e as '
          'ocorrências futuras serão substituídas pelo novo parcelamento.';
    }

    return 'O lançamento atual será substituído pelo novo parcelamento.';
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_convertendoParaEntrada &&
        _primeiroVencimentoParcelas.isBefore(_vencimento)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'O primeiro vencimento não pode ser anterior à entrada.',
          ),
        ),
      );
      return;
    }

    final resumo = _resumoConversao();
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          _mudandoForma ? 'Confirmar parcelamento' : 'Editar lançamento',
        ),
        content: Text(
          _mudandoForma
              ? '${_avisoForma()}\n\n${resumo ?? ''}'
              : widget.lancamento.ehEntrada
              ? 'Confirma a edição desta entrada?'
              : 'Confirma a edição deste lançamento?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirmou != true || !mounted) {
      return;
    }

    setState(() => _salvando = true);

    try {
      if (_mudandoForma) {
        await widget.servico.converterForma(
          lancamento: widget.lancamento,
          novaForma: _forma,
          descricao: _descricaoController.text,
          valor: _converterValor(_valorController.text)!,
          vencimento: _vencimento,
          prioridade: _prioridade,
          quantidadeParcelas: int.parse(_parcelasController.text),
          valorParcelaRestante: _convertendoParaEntrada
              ? _converterValor(_valorParcelasRestantesController.text)
              : null,
          primeiroVencimento: _convertendoParaEntrada
              ? _primeiroVencimentoParcelas
              : null,
          statusEntrada: _statusEntrada,
        );
      } else {
        await widget.servico.atualizarOcorrencia(
          lancamento: widget.lancamento,
          descricao: _descricaoController.text,
          valor: _converterValor(_valorController.text)!,
          vencimento: _vencimento,
          prioridade: _prioridade,
        );
      }

      if (mounted) {
        Navigator.pop(
          context,
          _mudandoForma
              ? ResultadoEdicaoLancamento.convertido
              : ResultadoEdicaoLancamento.atualizado,
        );
      }
    } catch (erro) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível editar: $erro')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _salvando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final receita = widget.lancamento.tipo == TipoLancamento.receita;
    final resumo = _resumoConversao();
    final aviso = _avisoForma();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.lancamento.ehEntrada ? 'Editar entrada' : 'Editar lançamento',
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            24 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _descricaoController,
                  decoration: const InputDecoration(
                    labelText: 'Descrição',
                    border: OutlineInputBorder(),
                  ),
                  validator: (texto) {
                    if (texto == null || texto.trim().isEmpty) {
                      return 'Informe uma descrição.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<FormaLancamento>(
                  key: ValueKey(_forma),
                  initialValue: _forma,
                  decoration: InputDecoration(
                    labelText: 'Forma',
                    helperText: aviso,
                    helperMaxLines: 4,
                    border: const OutlineInputBorder(),
                  ),
                  items: _formasDisponiveis
                      .map(
                        (forma) => DropdownMenuItem(
                          value: forma,
                          child: Text(rotuloFormaLancamento(forma)),
                        ),
                      )
                      .toList(),
                  onChanged: _salvando || _formasDisponiveis.length == 1
                      ? null
                      : (forma) {
                          if (forma != null) {
                            setState(() {
                              _forma = forma;
                              if (_convertendoParaEntrada) {
                                _statusEntrada = StatusLancamento.concluido;
                              }
                            });
                          }
                        },
                ),
                if (!receita) ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<PrioridadeLancamento>(
                    key: ValueKey(_prioridade),
                    initialValue: _prioridade,
                    decoration: InputDecoration(
                      labelText: 'Prioridade',
                      helperText:
                          !_mudandoForma && widget.lancamento.fazParteDeSerie
                          ? 'A nova prioridade será aplicada a toda a série.'
                          : 'Define a ordem de pagamento desta despesa.',
                      border: const OutlineInputBorder(),
                    ),
                    items: PrioridadeLancamento.values
                        .map(
                          (prioridade) => DropdownMenuItem(
                            value: prioridade,
                            child: Text(prioridade.rotulo),
                          ),
                        )
                        .toList(),
                    onChanged: (prioridade) {
                      if (prioridade != null) {
                        setState(() => _prioridade = prioridade);
                      }
                    },
                  ),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  controller: _valorController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: _convertendoParaEntrada
                        ? 'Valor da entrada'
                        : _convertendoParaParcelado
                        ? 'Valor de cada parcela'
                        : widget.lancamento.ehEntrada
                        ? 'Valor da entrada'
                        : 'Valor deste lançamento',
                    prefixText: 'R\$ ',
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (texto) {
                    final valor = _converterValor(texto ?? '');
                    if (valor == null || valor <= 0) {
                      return 'Informe um valor válido.';
                    }
                    return null;
                  },
                ),
                if (_convertendoParaParcelado || _convertendoParaEntrada) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _parcelasController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: _convertendoParaEntrada
                          ? 'Parcelas restantes'
                          : 'Total de parcelas',
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                    validator: (texto) {
                      if (!_convertendoParaParcelado &&
                          !_convertendoParaEntrada) {
                        return null;
                      }
                      final parcelas = int.tryParse(texto ?? '');
                      final minimo = _convertendoParaEntrada ? 1 : 2;
                      if (parcelas == null ||
                          parcelas < minimo ||
                          parcelas > 120) {
                        return _convertendoParaEntrada
                            ? 'Informe entre 1 e 120 parcelas restantes.'
                            : 'Informe entre 2 e 120 parcelas.';
                      }
                      return null;
                    },
                  ),
                ],
                if (_convertendoParaEntrada) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _valorParcelasRestantesController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Valor de cada parcela restante',
                      prefixText: 'R\$ ',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                    validator: (texto) {
                      if (!_convertendoParaEntrada) {
                        return null;
                      }
                      final valor = _converterValor(texto ?? '');
                      if (valor == null || valor <= 0) {
                        return 'Informe um valor de parcela válido.';
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _salvando ? null : _selecionarData,
                  icon: const Icon(Icons.calendar_month),
                  label: Text(
                    '${_convertendoParaEntrada
                        ? "Data da entrada"
                        : _convertendoParaParcelado
                        ? "Primeiro vencimento"
                        : widget.lancamento.ehEntrada
                        ? "Data da entrada"
                        : "Vencimento"}: '
                    '${_formatarData(_vencimento)}',
                  ),
                ),
                if (_convertendoParaEntrada) ...[
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: _statusEntrada == StatusLancamento.concluido,
                    title: Text(
                      receita ? 'Entrada já recebida' : 'Entrada já paga',
                    ),
                    onChanged: _salvando
                        ? null
                        : (concluida) {
                            setState(() {
                              _statusEntrada = concluida
                                  ? StatusLancamento.concluido
                                  : StatusLancamento.pendente;
                            });
                          },
                  ),
                  OutlinedButton.icon(
                    onPressed: _salvando
                        ? null
                        : () => _selecionarData(primeiroVencimento: true),
                    icon: const Icon(Icons.event_repeat),
                    label: Text(
                      'Primeiro vencimento: '
                      '${_formatarData(_primeiroVencimentoParcelas)}',
                    ),
                  ),
                ],
                if (resumo != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer
                          .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Resumo do novo acordo',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(resumo),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _salvando ? null : _salvar,
                  icon: _salvando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(_salvando ? 'Salvando...' : 'Salvar alterações'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
