import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/lancamento.dart';
import '../services/lancamento_service.dart';
import '../widgets/formulario_lancamento.dart';

class TelaPrincipal extends StatefulWidget {
  const TelaPrincipal({super.key});

  @override
  State<TelaPrincipal> createState() => _TelaPrincipalState();
}

class _TelaPrincipalState extends State<TelaPrincipal>
    with SingleTickerProviderStateMixin {
  final LancamentoService _servico = LancamentoService();

  late final TabController _tabController;

  final NumberFormat _moeda = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$',
  );

  final DateFormat _data = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _abrirFormulario() async {
    final tipo = _tabController.index == 0
        ? TipoLancamento.receita
        : TipoLancamento.despesa;

    final salvou = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return FormularioLancamento(servico: _servico, tipoInicial: tipo);
      },
    );

    if (salvou == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lançamento salvo com sucesso.')),
      );
    }
  }

  Future<void> _alternarStatus(Lancamento lancamento) async {
    final novoStatus = lancamento.status == StatusLancamento.pendente
        ? StatusLancamento.concluido
        : StatusLancamento.pendente;

    try {
      await _servico.alterarStatus(lancamento.id, novoStatus);
    } catch (erro) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível alterar: $erro')),
        );
      }
    }
  }

  Future<void> _confirmarExclusao(Lancamento lancamento) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Excluir lançamento?'),
          content: Text(
            'Deseja excluir "${lancamento.descricao}"? '
            'Esta ação não poderá ser desfeita.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Excluir'),
            ),
          ],
        );
      },
    );

    if (confirmou == true) {
      await _servico.excluir(lancamento.id);
    }
  }

  Future<void> _sair() async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Sair da conta?'),
          content: const Text(
            'Você poderá entrar novamente usando a mesma conta Google.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sair'),
            ),
          ],
        );
      },
    );

    if (confirmou == true) {
      await FirebaseAuth.instance.signOut();
    }
  }

  Widget _construirLista(List<Lancamento> todos, TipoLancamento tipo) {
    final lancamentos = todos.where((item) => item.tipo == tipo).toList();

    if (lancamentos.isEmpty) {
      final nome = tipo == TipoLancamento.receita
          ? 'conta a receber'
          : 'conta a pagar';

      return Center(child: Text('Nenhuma $nome cadastrada.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: lancamentos.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final lancamento = lancamentos[index];
        final receita = lancamento.tipo == TipoLancamento.receita;
        final concluido = lancamento.status == StatusLancamento.concluido;

        final parcela = lancamento.totalParcelas > 1
            ? 'Parcela ${lancamento.parcelaAtual}/'
                  '${lancamento.totalParcelas} • '
            : '';

        return Card(
          child: ListTile(
            onTap: () => _alternarStatus(lancamento),
            onLongPress: () => _confirmarExclusao(lancamento),
            leading: CircleAvatar(
              backgroundColor: receita ? Colors.green : Colors.red,
              child: Icon(
                receita ? Icons.arrow_upward : Icons.arrow_downward,
                color: Colors.white,
              ),
            ),
            title: Text(
              lancamento.descricao,
              style: TextStyle(
                decoration: concluido
                    ? TextDecoration.lineThrough
                    : TextDecoration.none,
              ),
            ),
            subtitle: Text(
              '$parcela'
              'Vencimento: ${_data.format(lancamento.vencimento)}\n'
              '${concluido ? "Concluído" : "Pendente"}',
            ),
            isThreeLine: true,
            trailing: SizedBox(
              width: 115,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _moeda.format(lancamento.valor),
                    style: TextStyle(
                      color: receita ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Icon(
                    concluido
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: concluido ? Colors.teal : Colors.grey,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Controle Financeiro'),
        actions: [
          IconButton(
            tooltip: 'Sair da conta',
            onPressed: _sair,
            icon: const Icon(Icons.logout),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.arrow_upward), text: 'Contas a receber'),
            Tab(icon: Icon(Icons.arrow_downward), text: 'Contas a pagar'),
          ],
        ),
      ),
      body: StreamBuilder<List<Lancamento>>(
        stream: _servico.observarLancamentos(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: SelectableText('Erro ao carregar: ${snapshot.error}'),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _construirLista(snapshot.data!, TipoLancamento.receita),
              _construirLista(snapshot.data!, TipoLancamento.despesa),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirFormulario,
        icon: const Icon(Icons.add),
        label: const Text('Adicionar'),
      ),
    );
  }
}
