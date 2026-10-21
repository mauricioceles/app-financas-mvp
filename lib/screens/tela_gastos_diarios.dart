import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/gasto_diario.dart';
import '../services/gasto_diario_service.dart';
import '../widgets/formulario_gasto_diario.dart';
import 'tela_categorias_gastos.dart';

class TelaGastosDiarios extends StatefulWidget {
  const TelaGastosDiarios({super.key});
  @override
  State<TelaGastosDiarios> createState() => _TelaGastosDiariosState();
}

class _TelaGastosDiariosState extends State<TelaGastosDiarios> {
  final _service = GastoDiarioService();
  final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: r'R$');
  late DateTimeRange _periodo;
  late Stream<List<CategoriaGasto>> _categorias;
  late Stream<List<GastoDiario>> _gastos;
  String? _categoriaId;
  String? _subcategoriaId;

  @override
  void initState() {
    super.initState();
    final hoje = DateTime.now();
    _periodo = DateTimeRange(start: DateTime(hoje.year, hoje.month),
        end: DateTime(hoje.year, hoje.month + 1, 0));
    _categorias = _service.observarCategorias();
    _atualizarGastos();
  }

  void _atualizarGastos() {
    _gastos = _service.observarGastos(_periodo.start, _periodo.end);
  }

  void _mudarPeriodo(DateTime inicio, DateTime fim) => setState(() {
    _periodo = DateTimeRange(start: inicio, end: fim);
    _atualizarGastos();
  });

  Future<void> _escolherPeriodo() async {
    final escolha = await showDateRangePicker(
      context: context, firstDate: DateTime(2000), lastDate: DateTime(2100),
      initialDateRange: _periodo, helpText: 'Escolha o período',
      cancelText: 'Cancelar', confirmText: 'Aplicar', saveText: 'Aplicar',
      fieldStartLabelText: 'Data inicial', fieldEndLabelText: 'Data final',
    );
    if (escolha != null && mounted) {
      _mudarPeriodo(escolha.start, escolha.end);
    }
  }

  Future<void> _editar(List<CategoriaGasto> categorias, [GastoDiario? gasto]) async {
    if (!categorias.any((c) => c.paiId == null)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Crie sua primeira categoria para registrar um gasto.'),
      ));
      await Navigator.push<void>(context, MaterialPageRoute(
        builder: (_) => TelaCategoriasGastos(service: _service)));
      return;
    }
    await Navigator.push<void>(context, MaterialPageRoute(builder: (_) =>
      FormularioGastoDiario(service: _service, categorias: categorias, gasto: gasto)));
  }

  Future<void> _excluir(GastoDiario gasto) async {
    final confirmou = await showDialog<bool>(context: context, builder: (context) =>
      AlertDialog(title: const Text('Excluir gasto?'),
        content: Text('Excluir ${_moeda.format(gasto.valorCentavos / 100)} do histórico?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Excluir')),
        ]));
    if (confirmou != true || !mounted) return;
    try {
      await _service.excluir(gasto.id);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Não foi possível excluir. Verifique a conexão e tente novamente.')));
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<CategoriaGasto>>(
    stream: _categorias,
    builder: (context, categoriasSnapshot) {
      final categorias = categoriasSnapshot.data ?? [];
      final principais = categorias.where((c) => c.paiId == null).toList();
      final subcategorias = categorias.where((c) => c.paiId == _categoriaId && c.paiId != null).toList();
      final nomes = {for (final c in categorias) c.id: c.nome};
      return Scaffold(
        appBar: AppBar(title: const Text('Gastos diários'), actions: [
          IconButton(tooltip: 'Categorias e subcategorias', icon: const Icon(Icons.category_outlined),
            onPressed: () => Navigator.push<void>(context, MaterialPageRoute(
              builder: (_) => TelaCategoriasGastos(service: _service)))),
        ]),
        floatingActionButton: categoriasSnapshot.hasData && !categoriasSnapshot.hasError
          ? FloatingActionButton.extended(onPressed: () => _editar(categorias),
              icon: const Icon(Icons.add), label: const Text('Novo gasto')) : null,
        body: categoriasSnapshot.hasError
          ? _erro(() => setState(() => _categorias = _service.observarCategorias()))
          : !categoriasSnapshot.hasData
            ? const Center(child: CircularProgressIndicator())
            : StreamBuilder<List<GastoDiario>>(
                stream: _gastos,
                builder: (context, snapshot) {
                  if (snapshot.hasError) return _erro(() => setState(_atualizarGastos));
                  // Não mostrar valores do período anterior durante a nova consulta.
                  if (snapshot.connectionState == ConnectionState.waiting || !snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final todos = snapshot.data!;
                  final gastos = todos.where((g) =>
                    (_categoriaId == null || g.categoriaId == _categoriaId) &&
                    (_subcategoriaId == null || g.subcategoriaId == _subcategoriaId)).toList();
                  final total = totalGastos(gastos);
                  final hoje = DateTime.now();
                  final inicioHoje = DateTime(hoje.year, hoje.month, hoje.day);
                  final grupos = <String, List<GastoDiario>>{};
                  for (final gasto in gastos) {
                    grupos.putIfAbsent(gasto.categoriaId, () => []).add(gasto);
                  }
                  final ranking = grupos.keys.toList()..sort((a, b) =>
                    totalGastos(grupos[b]!).compareTo(totalGastos(grupos[a]!)));
                  return Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 760),
                    child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 100), children: [
                      const Text('Veja para onde seu dinheiro está indo.',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      const Text('Controle separado: estes registros não alteram o saldo de receitas e despesas.'),
                      const SizedBox(height: 16),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        OutlinedButton(onPressed: () => _mudarPeriodo(inicioHoje, inicioHoje), child: const Text('Hoje')),
                        OutlinedButton(onPressed: () => _mudarPeriodo(
                          DateTime(hoje.year, hoje.month, hoje.day - hoje.weekday + 1),
                          DateTime(hoje.year, hoje.month, hoje.day - hoje.weekday + 7)),
                          child: const Text('Esta semana')),
                        OutlinedButton(onPressed: () => _mudarPeriodo(DateTime(hoje.year, hoje.month),
                          DateTime(hoje.year, hoje.month + 1, 0)), child: const Text('Este mês')),
                        OutlinedButton.icon(onPressed: _escolherPeriodo, icon: const Icon(Icons.date_range),
                          label: const Text('Outro período')),
                      ]),
                      const SizedBox(height: 12),
                      Text('${DateFormat('dd/MM/yyyy').format(_periodo.start)} a '
                        '${DateFormat('dd/MM/yyyy').format(_periodo.end)}'),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        key: ValueKey('filtro-${_categoriaId ?? 'todas'}'),
                        initialValue: _categoriaId ?? '', isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Categoria', border: OutlineInputBorder()),
                        items: [const DropdownMenuItem(value: '', child: Text('Todas as categorias')),
                          ...principais.map((c) => DropdownMenuItem(value: c.id, child: Text(c.nome)))],
                        onChanged: (id) => setState(() { _categoriaId = id == '' ? null : id; _subcategoriaId = null; }),
                      ),
                      if (_categoriaId != null && subcategorias.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          key: ValueKey('subfiltro-$_categoriaId-${_subcategoriaId ?? 'todas'}'),
                          initialValue: _subcategoriaId ?? '', isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Subcategoria', border: OutlineInputBorder()),
                          items: [const DropdownMenuItem(value: '', child: Text('Todas as subcategorias')),
                            ...subcategorias.map((c) => DropdownMenuItem(value: c.id, child: Text(c.nome)))],
                          onChanged: (id) => setState(() => _subcategoriaId = id == '' ? null : id),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(_categoriaId == null ? 'Total no período' : 'Total filtrado no período'),
                          Text(_moeda.format(total / 100), style: Theme.of(context).textTheme.headlineMedium),
                          Text('${gastos.length} registro(s)'),
                        ]))),
                      const SizedBox(height: 16),
                      if (gastos.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(todos.isEmpty ? 'Nenhum gasto neste período. Toque em Novo gasto para começar.'
                          : 'Nenhum gasto corresponde aos filtros.')),
                      if (gastos.isNotEmpty) ...[
                        const Text('Para onde foi o dinheiro', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        ...ranking.map((id) {
                          final itens = grupos[id]!;
                          final subtotal = totalGastos(itens);
                          final subs = <String, int>{};
                          for (final g in itens) {
                            final chave = g.subcategoriaId ?? '';
                            subs[chave] = (subs[chave] ?? 0) + g.valorCentavos;
                          }
                          final subIds = subs.keys.toList()..sort((a, b) => subs[b]!.compareTo(subs[a]!));
                          return Card(child: ExpansionTile(
                            title: Text(nomes[id] ?? 'Categoria indisponível'),
                            subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('${_moeda.format(subtotal / 100)} • ${(subtotal * 100 / total).toStringAsFixed(1)}%'),
                              const SizedBox(height: 6),
                              LinearProgressIndicator(value: subtotal / total),
                            ]),
                            children: subIds.map((sub) => ListTile(
                              title: Text(sub.isEmpty ? 'Sem subcategoria' : nomes[sub] ?? 'Subcategoria indisponível'),
                              subtitle: Text('${(subs[sub]! * 100 / total).toStringAsFixed(1)}% do total exibido'),
                              trailing: Text(_moeda.format(subs[sub]! / 100)),
                            )).toList(),
                          ));
                        }),
                        const SizedBox(height: 20),
                        const Text('Histórico', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ...gastos.map((g) => Card(child: ListTile(
                          onTap: () => _editar(categorias, g),
                          title: Text(_moeda.format(g.valorCentavos / 100)),
                          subtitle: Text([
                            DateFormat('dd/MM/yyyy').format(g.data),
                            nomes[g.categoriaId] ?? 'Categoria indisponível',
                            if (g.subcategoriaId != null) nomes[g.subcategoriaId] ?? 'Subcategoria indisponível',
                            if (g.observacao.isNotEmpty) g.observacao,
                          ].join(' • ')),
                          trailing: PopupMenuButton<String>(tooltip: 'Opções do gasto',
                            onSelected: (acao) { if (acao == 'editar') { _editar(categorias, g); } else { _excluir(g); } },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'editar', child: Text('Editar')),
                              PopupMenuItem(value: 'excluir', child: Text('Excluir')),
                            ]),
                        ))),
                      ],
                    ])));
                }),
      );
    });

  Widget _erro(VoidCallback tentar) => Center(child: Padding(
    padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('Não foi possível carregar os dados. Verifique sua conexão e tente novamente.', textAlign: TextAlign.center),
      const SizedBox(height: 12),
      FilledButton(onPressed: tentar, child: const Text('Tentar novamente')),
    ])));
}
