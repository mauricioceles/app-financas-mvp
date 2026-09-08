import 'package:flutter/material.dart';

import '../models/lancamento.dart';
import '../services/lancamento_service.dart';

class FormularioLancamento extends StatefulWidget {
  const FormularioLancamento({
    super.key,
    required this.servico,
    required this.tipoInicial,
  });

  final LancamentoService servico;
  final TipoLancamento tipoInicial;

  @override
  State<FormularioLancamento> createState() => _FormularioLancamentoState();
}

class _FormularioLancamentoState extends State<FormularioLancamento> {
  final _formKey = GlobalKey<FormState>();
  final _descricaoController = TextEditingController();
  final _valorController = TextEditingController();
  final _valorEntradaController = TextEditingController();
  final _valorParcelasRestantesController = TextEditingController();
  final _parcelaAtualController = TextEditingController(text: '1');
  final _parcelasController = TextEditingController(text: '2');
  final _descricaoFocus = FocusNode();

  FormaLancamento _forma = FormaLancamento.vista;
  StatusLancamento _statusAtual = StatusLancamento.pendente;
  PrioridadeLancamento _prioridade = PrioridadeLancamento.normal;
  DateTime _vencimento = DateTime.now();
  DateTime _primeiroVencimentoParcelas = DateTime.now();
  bool _salvando = false;

  @override
  void dispose() {
    _descricaoController.dispose();
    _valorController.dispose();
    _valorEntradaController.dispose();
    _valorParcelasRestantesController.dispose();
    _parcelaAtualController.dispose();
    _parcelasController.dispose();
    _descricaoFocus.dispose();
    super.dispose();
  }

  double? _converterValor(String texto) {
    var valor = texto.trim().replaceAll(RegExp(r'[R$\s]'), '');

    if (valor.contains(',')) {
      valor = valor.replaceAll('.', '').replaceAll(',', '.');
    }

    return double.tryParse(valor);
  }

  String _formatarData(DateTime data) {
    final dia = data.day.toString().padLeft(2, '0');
    final mes = data.month.toString().padLeft(2, '0');

    return '$dia/$mes/${data.year}';
  }

  bool get _ehComEntrada => _forma == FormaLancamento.entradaParcelas;

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

  String? _resumoComEntrada() {
    final entrada = _converterValor(_valorEntradaController.text);
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
    final total = (totalCentavos / 100).toStringAsFixed(2).replaceAll('.', ',');
    final entradaTexto = entrada.toStringAsFixed(2).replaceAll('.', ',');
    final parcelaTexto = parcela.toStringAsFixed(2).replaceAll('.', ',');
    return 'Entrada R\$ $entradaTexto + $quantidade × R\$ $parcelaTexto = '
        'R\$ $total';
  }

  Future<void> _salvar({required bool fechar}) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_ehComEntrada) {
      setState(() => _salvando = true);

      try {
        await widget.servico.adicionarComEntrada(
          descricao: _descricaoController.text,
          tipo: widget.tipoInicial,
          valorEntrada: _converterValor(_valorEntradaController.text)!,
          dataEntrada: _vencimento,
          statusEntrada: _statusAtual,
          quantidadeParcelas: int.parse(_parcelasController.text),
          valorParcela: _converterValor(
            _valorParcelasRestantesController.text,
          )!,
          primeiroVencimento: _primeiroVencimentoParcelas,
          prioridade: widget.tipoInicial == TipoLancamento.despesa
              ? _prioridade
              : PrioridadeLancamento.normal,
        );
        _finalizarSalvamento(fechar: fechar);
      } catch (erro) {
        _mostrarErro(erro);
      } finally {
        if (mounted) {
          setState(() => _salvando = false);
        }
      }
      return;
    }

    final valor = _converterValor(_valorController.text)!;
    final totalParcelas = _forma == FormaLancamento.parcelado
        ? int.parse(_parcelasController.text)
        : 1;
    final parcelaAtual = _forma == FormaLancamento.parcelado
        ? int.parse(_parcelaAtualController.text)
        : 1;

    setState(() => _salvando = true);

    try {
      await widget.servico.adicionar(
        Lancamento(
          id: '',
          descricao: _descricaoController.text,
          valor: valor,
          tipo: widget.tipoInicial,
          vencimento: _vencimento,
          status: _forma == FormaLancamento.parcelado
              ? _statusAtual
              : StatusLancamento.pendente,
          forma: _forma,
          parcelaAtual: parcelaAtual,
          totalParcelas: totalParcelas,
          prioridade: widget.tipoInicial == TipoLancamento.despesa
              ? _prioridade
              : PrioridadeLancamento.normal,
        ),
      );

      _finalizarSalvamento(fechar: fechar);
    } catch (erro) {
      _mostrarErro(erro);
    } finally {
      if (mounted) {
        setState(() => _salvando = false);
      }
    }
  }

  void _finalizarSalvamento({required bool fechar}) {
    if (!mounted) {
      return;
    }

    if (fechar) {
      Navigator.of(context).pop(true);
      return;
    }

    _descricaoController.clear();
    _valorController.clear();
    _valorEntradaController.clear();
    _valorParcelasRestantesController.clear();
    _parcelaAtualController.text = '1';
    _parcelasController.text = '2';
    setState(() {
      _statusAtual = _ehComEntrada
          ? StatusLancamento.concluido
          : StatusLancamento.pendente;
      _prioridade = PrioridadeLancamento.normal;
    });
    _descricaoFocus.requestFocus();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Lançamento salvo. Cadastre o próximo.')),
    );
  }

  void _mostrarErro(Object erro) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Não foi possível salvar: $erro')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final receita = widget.tipoInicial == TipoLancamento.receita;
    final parcelaAtualInformada =
        int.tryParse(_parcelaAtualController.text) ?? 1;
    final resumoComEntrada = _resumoComEntrada();

    return SafeArea(
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
              Text(
                receita ? 'Nova receita' : 'Nova despesa',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Área pessoal',
                  border: OutlineInputBorder(),
                ),
                child: Row(
                  children: [
                    Icon(
                      receita
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded,
                      color: receita ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 12),
                    Text(receita ? 'Receita' : 'Despesa'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descricaoController,
                focusNode: _descricaoFocus,
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
                decoration: const InputDecoration(
                  labelText: 'Forma',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: FormaLancamento.vista,
                    child: Text('À vista'),
                  ),
                  DropdownMenuItem(
                    value: FormaLancamento.parcelado,
                    child: Text('Parcelado'),
                  ),
                  DropdownMenuItem(
                    value: FormaLancamento.entradaParcelas,
                    child: Text('Entrada + parcelas'),
                  ),
                  DropdownMenuItem(
                    value: FormaLancamento.fixo,
                    child: Text('Fixo mensal'),
                  ),
                ],
                onChanged: (forma) {
                  if (forma != null) {
                    setState(() {
                      final entrandoNaFormaComEntrada =
                          forma == FormaLancamento.entradaParcelas &&
                          _forma != FormaLancamento.entradaParcelas;
                      final saindoDaFormaComEntrada =
                          forma != FormaLancamento.entradaParcelas &&
                          _forma == FormaLancamento.entradaParcelas;
                      _forma = forma;
                      if (entrandoNaFormaComEntrada) {
                        _statusAtual = StatusLancamento.concluido;
                      } else if (saindoDaFormaComEntrada) {
                        _statusAtual = StatusLancamento.pendente;
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
                  decoration: const InputDecoration(
                    labelText: 'Prioridade',
                    helperText: 'Define a ordem de pagamento desta despesa.',
                    border: OutlineInputBorder(),
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
              if (_ehComEntrada) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _valorEntradaController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Valor da entrada',
                    prefixText: 'R\$ ',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (texto) {
                    if (!_ehComEntrada) {
                      return null;
                    }
                    final valor = _converterValor(texto ?? '');
                    if (valor == null || valor <= 0) {
                      return 'Informe um valor de entrada válido.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _salvando ? null : _selecionarData,
                  icon: const Icon(Icons.calendar_month),
                  label: Text('Data da entrada: ${_formatarData(_vencimento)}'),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _statusAtual == StatusLancamento.concluido,
                  title: Text(
                    receita ? 'Entrada já recebida' : 'Entrada já paga',
                  ),
                  onChanged: _salvando
                      ? null
                      : (concluida) {
                          setState(() {
                            _statusAtual = concluida
                                ? StatusLancamento.concluido
                                : StatusLancamento.pendente;
                          });
                        },
                ),
                TextFormField(
                  controller: _parcelasController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Parcelas restantes',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (texto) {
                    if (!_ehComEntrada) {
                      return null;
                    }
                    final parcelas = int.tryParse(texto ?? '');
                    if (parcelas == null || parcelas < 1 || parcelas > 120) {
                      return 'Informe entre 1 e 120 parcelas restantes.';
                    }
                    return null;
                  },
                ),
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
                    if (!_ehComEntrada) {
                      return null;
                    }
                    final valor = _converterValor(texto ?? '');
                    if (valor == null || valor <= 0) {
                      return 'Informe um valor de parcela válido.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
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
                if (resumoComEntrada != null) ...[
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
                        Text(
                          receita ? 'Resumo da receita' : 'Resumo da despesa',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(resumoComEntrada),
                      ],
                    ),
                  ),
                ],
              ] else ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _valorController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: _forma == FormaLancamento.parcelado
                        ? 'Valor de cada parcela'
                        : _forma == FormaLancamento.fixo
                        ? 'Valor mensal'
                        : 'Valor',
                    helperText: switch (_forma) {
                      FormaLancamento.parcelado =>
                        'O valor será repetido em todas as parcelas.',
                      FormaLancamento.fixo =>
                        'A conta será repetida mensalmente.',
                      FormaLancamento.vista => null,
                      FormaLancamento.entradaParcelas => null,
                    },
                    prefixText: 'R\$ ',
                    border: const OutlineInputBorder(),
                  ),
                  validator: (texto) {
                    final valor = _converterValor(texto ?? '');
                    if (valor == null || valor <= 0) {
                      return 'Informe um valor válido.';
                    }
                    return null;
                  },
                ),
                if (_forma == FormaLancamento.parcelado) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _parcelaAtualController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Parcela atual',
                      helperText: 'Use 1 quando o parcelamento for novo.',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                    validator: (texto) {
                      if (_forma != FormaLancamento.parcelado) {
                        return null;
                      }
                      final parcelaAtual = int.tryParse(texto ?? '');
                      final totalParcelas = int.tryParse(
                        _parcelasController.text,
                      );
                      if (parcelaAtual == null || parcelaAtual < 1) {
                        return 'Informe uma parcela atual válida.';
                      }
                      if (totalParcelas != null &&
                          parcelaAtual > totalParcelas) {
                        return 'A parcela atual não pode superar o total.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _parcelasController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Total de parcelas',
                      border: OutlineInputBorder(),
                    ),
                    validator: (texto) {
                      if (_forma != FormaLancamento.parcelado) {
                        return null;
                      }
                      final parcelas = int.tryParse(texto ?? '');
                      if (parcelas == null || parcelas < 2 || parcelas > 120) {
                        return 'Informe entre 2 e 120 parcelas.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<StatusLancamento>(
                    key: ValueKey(_statusAtual),
                    initialValue: _statusAtual,
                    decoration: InputDecoration(
                      labelText: 'Situação da parcela atual',
                      border: const OutlineInputBorder(),
                      helperText: parcelaAtualInformada > 1
                          ? receita
                                ? 'As anteriores serão marcadas como recebidas.'
                                : 'As anteriores serão marcadas como pagas.'
                          : 'As parcelas futuras serão criadas como pendentes.',
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: StatusLancamento.pendente,
                        child: Text('Pendente'),
                      ),
                      DropdownMenuItem(
                        value: StatusLancamento.concluido,
                        child: Text(receita ? 'Recebida' : 'Paga'),
                      ),
                    ],
                    onChanged: (status) {
                      if (status != null) {
                        setState(() => _statusAtual = status);
                      }
                    },
                  ),
                ],
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _salvando ? null : _selecionarData,
                  icon: const Icon(Icons.calendar_month),
                  label: Text(
                    '${switch (_forma) {
                      FormaLancamento.vista => "Vencimento",
                      FormaLancamento.parcelado => "Vencimento da parcela atual",
                      FormaLancamento.fixo => "Primeiro vencimento",
                      FormaLancamento.entradaParcelas => "Data da entrada",
                    }}: '
                    '${_formatarData(_vencimento)}',
                  ),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _salvando ? null : () => _salvar(fechar: false),
                child: _salvando
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Salvar e cadastrar outra'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: _salvando ? null : () => _salvar(fechar: true),
                child: const Text('Salvar e fechar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
