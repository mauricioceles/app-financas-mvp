import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/gasto_diario.dart';
import '../services/gasto_diario_service.dart';

class FormularioGastoDiario extends StatefulWidget {
  const FormularioGastoDiario({super.key, required this.service,
    required this.categorias, this.gasto});
  final GastoDiarioService service;
  final List<CategoriaGasto> categorias;
  final GastoDiario? gasto;
  @override
  State<FormularioGastoDiario> createState() => _FormularioGastoDiarioState();
}

class _FormularioGastoDiarioState extends State<FormularioGastoDiario> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _valor;
  late final TextEditingController _observacao;
  late DateTime _data;
  String? _categoriaId;
  String? _subcategoriaId;
  bool _salvando = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    final gasto = widget.gasto;
    _valor = TextEditingController(text: gasto == null ? '' :
      (gasto.valorCentavos / 100).toStringAsFixed(2).replaceAll('.', ','));
    _observacao = TextEditingController(text: gasto?.observacao ?? '');
    _data = gasto?.data ?? DateTime.now();
    _categoriaId = gasto?.categoriaId;
    _subcategoriaId = gasto?.subcategoriaId;
  }

  @override
  void dispose() {
    _valor.dispose();
    _observacao.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (_salvando || !_form.currentState!.validate()) return;
    setState(() { _salvando = true; _erro = null; });
    try {
      await widget.service.salvar(GastoDiario(
        id: widget.gasto?.id ?? '', valorCentavos: lerCentavos(_valor.text)!,
        data: _data, categoriaId: _categoriaId!,
        subcategoriaId: _subcategoriaId, observacao: _observacao.text,
      ));
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() {
        _salvando = false;
        _erro = 'Não foi possível salvar. Verifique sua conexão e tente novamente.';
      });
    }
  }

  Future<void> _escolherData() async {
    final data = await showDatePicker(context: context, initialDate: _data,
      firstDate: DateTime(2000), lastDate: DateTime(2100),
      helpText: 'Data do gasto', cancelText: 'Cancelar', confirmText: 'Confirmar');
    if (data != null && mounted) setState(() => _data = data);
  }

  @override
  Widget build(BuildContext context) {
    final principais = widget.categorias.where((c) => c.paiId == null).toList();
    final subs = widget.categorias.where((c) => c.paiId == _categoriaId && c.paiId != null).toList();
    return PopScope(canPop: !_salvando, child: Scaffold(
      appBar: AppBar(title: Text(widget.gasto == null ? 'Novo gasto' : 'Editar gasto')),
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560),
        child: Form(key: _form, child: ListView(padding: const EdgeInsets.all(20), children: [
          TextFormField(controller: _valor, enabled: !_salvando, autofocus: widget.gasto == null,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Valor', prefixText: r'R$ ', hintText: '0,00', border: OutlineInputBorder()),
            validator: (valor) => lerCentavos(valor ?? '') == null
              ? 'Informe um valor positivo com até duas casas decimais.' : null),
          const SizedBox(height: 16),
          OutlinedButton.icon(onPressed: _salvando ? null : _escolherData,
            icon: const Icon(Icons.calendar_today), label: Text('Data: ${DateFormat('dd/MM/yyyy').format(_data)}')),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(initialValue: _categoriaId, isExpanded: true,
            decoration: const InputDecoration(labelText: 'Categoria', border: OutlineInputBorder()),
            items: principais.map((c) => DropdownMenuItem(value: c.id, child: Text(c.nome))).toList(),
            onChanged: _salvando ? null : (id) => setState(() { _categoriaId = id; _subcategoriaId = null; }),
            validator: (id) => id == null ? 'Selecione a categoria.' : null),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(key: ValueKey('sub-$_categoriaId'),
            initialValue: _subcategoriaId ?? '', isExpanded: true,
            decoration: const InputDecoration(labelText: 'Subcategoria (opcional)', border: OutlineInputBorder()),
            items: [const DropdownMenuItem(value: '', child: Text('Sem subcategoria')),
              ...subs.map((c) => DropdownMenuItem(value: c.id, child: Text(c.nome)))],
            onChanged: _salvando || _categoriaId == null ? null :
              (id) => setState(() => _subcategoriaId = id == '' ? null : id)),
          const SizedBox(height: 16),
          TextFormField(controller: _observacao, enabled: !_salvando, maxLength: 300, maxLines: 3,
            decoration: const InputDecoration(labelText: 'Observação (opcional)', hintText: 'Ex.: almoço perto do trabalho', border: OutlineInputBorder())),
          if (_erro != null) Padding(padding: const EdgeInsets.only(bottom: 16),
            child: Text(_erro!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
          FilledButton.icon(onPressed: _salvando ? null : _salvar,
            icon: _salvando ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check),
            label: Text(_salvando ? 'Salvando...' : 'Salvar gasto')),
        ])),
      )),
    ));
  }
}
