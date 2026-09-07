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
  final _parcelasController = TextEditingController(text: '2');
  final _descricaoFocus = FocusNode();

  FormaLancamento _forma = FormaLancamento.vista;
  DateTime _vencimento = DateTime.now();
  bool _salvando = false;

  @override
  void dispose() {
    _descricaoController.dispose();
    _valorController.dispose();
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

  Future<void> _selecionarData() async {
    final data = await showDatePicker(
      context: context,
      initialDate: _vencimento,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (data != null) {
      setState(() => _vencimento = data);
    }
  }

  Future<void> _salvar({required bool fechar}) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final valor = _converterValor(_valorController.text)!;
    final totalParcelas = _forma == FormaLancamento.parcelado
        ? int.parse(_parcelasController.text)
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
          status: StatusLancamento.pendente,
          forma: _forma,
          parcelaAtual: 1,
          totalParcelas: totalParcelas,
        ),
      );

      if (mounted) {
        if (fechar) {
          Navigator.of(context).pop(true);
        } else {
          _descricaoController.clear();
          _valorController.clear();
          _descricaoFocus.requestFocus();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Lançamento salvo. Cadastre o próximo.'),
            ),
          );
        }
      }
    } catch (erro) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível salvar: $erro')),
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
    final receita = widget.tipoInicial == TipoLancamento.receita;

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
              const SizedBox(height: 16),
              DropdownButtonFormField<FormaLancamento>(
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
                    value: FormaLancamento.fixo,
                    child: Text('Fixo mensal'),
                  ),
                ],
                onChanged: (forma) {
                  if (forma != null) {
                    setState(() => _forma = forma);
                  }
                },
              ),
              if (_forma == FormaLancamento.parcelado) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _parcelasController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Quantidade de parcelas',
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
              ],
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _selecionarData,
                icon: const Icon(Icons.calendar_month),
                label: Text(
                  '${_forma == FormaLancamento.vista ? "Vencimento" : "Primeiro vencimento"}: '
                  '${_formatarData(_vencimento)}',
                ),
              ),
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
