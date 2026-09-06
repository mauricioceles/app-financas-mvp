import 'package:flutter/material.dart';

import '../models/lancamento.dart';
import '../services/lancamento_service.dart';

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
  late DateTime _vencimento;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _descricaoController = TextEditingController(
      text: widget.lancamento.descricao,
    );
    _valorController = TextEditingController(
      text: widget.lancamento.valor.toStringAsFixed(2).replaceAll('.', ','),
    );
    _vencimento = widget.lancamento.vencimento;
  }

  @override
  void dispose() {
    _descricaoController.dispose();
    _valorController.dispose();
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

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final confirmou = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar parcela'),
        content: const Text('Confirma a edição desta parcela?'),
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
      await widget.servico.atualizarOcorrencia(
        lancamento: widget.lancamento,
        descricao: _descricaoController.text,
        valor: _converterValor(_valorController.text)!,
        vencimento: _vencimento,
      );

      if (mounted) {
        Navigator.pop(context, true);
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
    return Scaffold(
      appBar: AppBar(title: const Text('Editar parcela')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
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
                TextFormField(
                  controller: _valorController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Valor desta parcela',
                    prefixText: 'R\$ ',
                    border: OutlineInputBorder(),
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
                OutlinedButton.icon(
                  onPressed: _salvando ? null : _selecionarData,
                  icon: const Icon(Icons.calendar_month),
                  label: Text('Vencimento: ${_formatarData(_vencimento)}'),
                ),
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
