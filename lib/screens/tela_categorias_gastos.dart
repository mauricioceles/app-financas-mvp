import 'package:flutter/material.dart';
import '../models/gasto_diario.dart';
import '../services/gasto_diario_service.dart';

class TelaCategoriasGastos extends StatefulWidget {
  const TelaCategoriasGastos({super.key, required this.service});
  final GastoDiarioService service;
  @override
  State<TelaCategoriasGastos> createState() => _TelaCategoriasGastosState();
}

class _TelaCategoriasGastosState extends State<TelaCategoriasGastos> {
  late Stream<List<CategoriaGasto>> _stream;
  @override
  void initState() {
    super.initState();
    _stream = widget.service.observarCategorias();
  }

  Future<void> _editar(List<CategoriaGasto> categorias, {CategoriaGasto? categoria, String? paiId}) async {
    await showDialog<void>(context: context, barrierDismissible: false,
      builder: (_) => _EditorCategoria(service: widget.service, categorias: categorias,
        categoria: categoria, paiId: paiId));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Categorias e subcategorias')),
    body: StreamBuilder<List<CategoriaGasto>>(stream: _stream, builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Não foi possível carregar as categorias.'),
        TextButton(onPressed: () => setState(() => _stream = widget.service.observarCategorias()),
          child: const Text('Tentar novamente')),
      ]));
      }
      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
      final categorias = snapshot.data!;
      final principais = categorias.where((c) => c.paiId == null).toList();
      return Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(padding: const EdgeInsets.all(16), children: [
          const Text('Crie suas categorias e organize os detalhes em subcategorias. '
            'Os novos nomes também serão usados no histórico.'),
          const SizedBox(height: 16),
          FilledButton.icon(onPressed: () => _editar(categorias), icon: const Icon(Icons.add),
            label: const Text('Nova categoria')),
          const SizedBox(height: 16),
          if (principais.isEmpty) const Padding(padding: EdgeInsets.all(20),
            child: Text('Comece com uma categoria, como Alimentação ou Transporte.')),
          ...principais.map((c) => Card(child: ExpansionTile(
            title: Text(c.nome),
            children: [
              ListTile(leading: const Icon(Icons.edit_outlined), title: const Text('Renomear categoria'),
                onTap: () => _editar(categorias, categoria: c)),
              ...categorias.where((sub) => sub.paiId == c.id).map((sub) => ListTile(
                leading: const Icon(Icons.subdirectory_arrow_right), title: Text(sub.nome),
                trailing: IconButton(tooltip: 'Renomear subcategoria', icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _editar(categorias, categoria: sub, paiId: c.id)))),
              ListTile(leading: const Icon(Icons.add), title: const Text('Nova subcategoria'),
                onTap: () => _editar(categorias, paiId: c.id)),
            ],
          ))),
        ])));
    }),
  );
}

class _EditorCategoria extends StatefulWidget {
  const _EditorCategoria({required this.service, required this.categorias, this.categoria, this.paiId});
  final GastoDiarioService service;
  final List<CategoriaGasto> categorias;
  final CategoriaGasto? categoria;
  final String? paiId;
  @override
  State<_EditorCategoria> createState() => _EditorCategoriaState();
}

class _EditorCategoriaState extends State<_EditorCategoria> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _nome;
  bool _salvando = false;
  String? _erro;
  @override
  void initState() {
    super.initState();
    _nome = TextEditingController(text: widget.categoria?.nome ?? '');
  }
  @override
  void dispose() { _nome.dispose(); super.dispose(); }

  Future<void> _salvar() async {
    if (_salvando || !_form.currentState!.validate()) return;
    setState(() { _salvando = true; _erro = null; });
    try {
      await widget.service.salvarCategoria(_nome.text, id: widget.categoria?.id, paiId: widget.paiId);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _salvando = false;
          _erro = 'Não foi possível salvar. Verifique sua conexão e tente novamente.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(canPop: !_salvando, child: AlertDialog(
    title: Text('${widget.categoria == null ? 'Nova' : 'Renomear'} ${widget.paiId == null ? 'categoria' : 'subcategoria'}'),
    content: SingleChildScrollView(child: Form(key: _form, child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextFormField(controller: _nome, autofocus: true, enabled: !_salvando, maxLength: 60,
        decoration: const InputDecoration(labelText: 'Nome'),
        onFieldSubmitted: (_) => _salvar(),
        validator: (texto) {
          final nome = texto?.trim().toLowerCase() ?? '';
          if (nome.isEmpty) return 'Informe um nome.';
          if (widget.categorias.any((c) => c.id != widget.categoria?.id &&
            c.paiId == widget.paiId && c.nome.trim().toLowerCase() == nome)) {
            return 'Este nome já existe neste grupo.';
          }
          return null;
        }),
      if (_erro != null) Text(_erro!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
    ]))),
    actions: [
      TextButton(onPressed: _salvando ? null : () => Navigator.pop(context), child: const Text('Cancelar')),
      FilledButton(onPressed: _salvando ? null : _salvar, child: Text(_salvando ? 'Salvando...' : 'Salvar')),
    ],
  ));
}
