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
  final DateFormat _mesAno = DateFormat('MMMM yyyy', 'pt_BR');

  late DateTime _mesSelecionado;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final agora = DateTime.now();
    _mesSelecionado = DateTime(agora.year, agora.month);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _garantirLancamentosFixos();
    });
  }

  void _alterarMes(int quantidade) {
    setState(() {
      _mesSelecionado = DateTime(
        _mesSelecionado.year,
        _mesSelecionado.month + quantidade,
      );
    });
    _garantirLancamentosFixos();
  }

  void _voltarParaMesAtual() {
    final agora = DateTime.now();
    setState(() => _mesSelecionado = DateTime(agora.year, agora.month));
    _garantirLancamentosFixos();
  }

  Future<void> _garantirLancamentosFixos() async {
    try {
      await _servico.garantirLancamentosFixosDoMes(_mesSelecionado);
    } catch (erro) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Não foi possível carregar contas fixas: $erro'),
          ),
        );
      }
    }
  }

  bool _pertenceAoMes(Lancamento lancamento) {
    return lancamento.vencimento.year == _mesSelecionado.year &&
        lancamento.vencimento.month == _mesSelecionado.month;
  }

  String _formatarMesSelecionado() {
    final texto = _mesAno.format(_mesSelecionado);
    return '${texto[0].toUpperCase()}${texto.substring(1)}';
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
    final mensagem = lancamento.forma == FormaLancamento.fixo
        ? 'Deseja excluir "${lancamento.descricao}" somente de '
              '${_formatarMesSelecionado().toLowerCase()}? A conta fixa '
              'continuará nos próximos meses.'
        : 'Deseja excluir "${lancamento.descricao}"? '
              'Esta ação não poderá ser desfeita.';

    final confirmou = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Excluir lançamento?'),
          content: Text(mensagem),
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
      try {
        await _servico.excluir(lancamento);
      } catch (erro) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Não foi possível excluir: $erro')),
          );
        }
      }
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
    final lancamentos = todos
        .where(
          (item) => item.tipo == tipo && !item.excluido && _pertenceAoMes(item),
        )
        .toList();

    if (lancamentos.isEmpty) {
      final nome = tipo == TipoLancamento.receita
          ? 'conta a receber'
          : 'conta a pagar';

      return Center(
        child: Text(
          'Nenhuma $nome em ${_formatarMesSelecionado().toLowerCase()}.',
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: lancamentos.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final lancamento = lancamentos[index];
        final receita = lancamento.tipo == TipoLancamento.receita;
        final concluido = lancamento.status == StatusLancamento.concluido;

        final parcela =
            lancamento.forma == FormaLancamento.parcelado &&
                lancamento.totalParcelas > 1
            ? 'Parcela ${lancamento.parcelaAtual}/'
                  '${lancamento.totalParcelas} • '
            : '';
        final recorrencia = lancamento.forma == FormaLancamento.fixo
            ? 'Conta fixa • '
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
              '$parcela$recorrencia'
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

  Widget _construirSeletorDeMes() {
    final agora = DateTime.now();
    final estaNoMesAtual =
        _mesSelecionado.year == agora.year &&
        _mesSelecionado.month == agora.month;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Mês anterior',
            onPressed: () => _alterarMes(-1),
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Text(
              _formatarMesSelecionado(),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          TextButton(
            onPressed: estaNoMesAtual ? null : _voltarParaMesAtual,
            child: const Text('Hoje'),
          ),
          IconButton(
            tooltip: 'Próximo mês',
            onPressed: () => _alterarMes(1),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  Widget _construirResumo(List<Lancamento> todos) {
    final lancamentosDoMes = todos.where(
      (item) => !item.excluido && _pertenceAoMes(item),
    );
    final receitas = lancamentosDoMes
        .where((item) => item.tipo == TipoLancamento.receita)
        .fold<double>(0, (total, item) => total + item.valor);
    final despesas = lancamentosDoMes
        .where((item) => item.tipo == TipoLancamento.despesa)
        .fold<double>(0, (total, item) => total + item.valor);
    final saldo = receitas - despesas;

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        child: Row(
          children: [
            _ItemResumo(
              titulo: 'Receitas',
              valor: _moeda.format(receitas),
              cor: Colors.green,
            ),
            _ItemResumo(
              titulo: 'Despesas',
              valor: _moeda.format(despesas),
              cor: Colors.red,
            ),
            _ItemResumo(
              titulo: 'Saldo previsto',
              valor: _moeda.format(saldo),
              cor: saldo >= 0 ? Colors.teal : Colors.red,
            ),
          ],
        ),
      ),
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
        stream: _servico.observarLancamentosDoMes(_mesSelecionado),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: SelectableText('Erro ao carregar: ${snapshot.error}'),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            children: [
              _construirSeletorDeMes(),
              _construirResumo(snapshot.data!),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _construirLista(snapshot.data!, TipoLancamento.receita),
                    _construirLista(snapshot.data!, TipoLancamento.despesa),
                  ],
                ),
              ),
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

class _ItemResumo extends StatelessWidget {
  const _ItemResumo({
    required this.titulo,
    required this.valor,
    required this.cor,
  });

  final String titulo;
  final String valor;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                valor,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(color: cor, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
