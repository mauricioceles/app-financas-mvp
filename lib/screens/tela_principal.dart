import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/lancamento.dart';
import '../models/resumo_prioridade.dart';
import '../services/lancamento_service.dart';
import '../widgets/formulario_lancamento.dart';
import '../widgets/indicador_prioridade.dart';
import '../widgets/indicador_situacao.dart';
import 'tela_detalhe_lancamento.dart';

class TelaPrincipal extends StatefulWidget {
  const TelaPrincipal({super.key, required this.tipo});

  final TipoLancamento tipo;

  @override
  State<TelaPrincipal> createState() => _TelaPrincipalState();
}

class _TelaPrincipalState extends State<TelaPrincipal> {
  final LancamentoService _servico = LancamentoService();

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

  Future<void> _abrirFormulario() async {
    final salvou = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return FormularioLancamento(
          servico: _servico,
          tipoInicial: widget.tipo,
        );
      },
    );

    if (salvou == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lançamento salvo com sucesso.')),
      );
    }
  }

  Future<void> _abrirDetalhes(Lancamento lancamento) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (context) => TelaDetalheLancamento(
          servico: _servico,
          lancamentoId: lancamento.id,
        ),
      ),
    );
  }

  Widget _construirLista(List<Lancamento> todos) {
    final lancamentos = todos
        .where(
          (item) =>
              item.tipo == widget.tipo &&
              !item.excluido &&
              _pertenceAoMes(item),
        )
        .toList();
    lancamentos.sort(compararLancamentosMensais);

    if (lancamentos.isEmpty) {
      final nome = widget.tipo == TipoLancamento.receita
          ? 'conta a receber'
          : 'conta a pagar';

      return Center(
        child: Text(
          'Nenhuma $nome em ${_formatarMesSelecionado().toLowerCase()}.',
          textAlign: TextAlign.center,
        ),
      );
    }

    final itens = widget.tipo == TipoLancamento.despesa
        ? _construirItensDeDespesas(lancamentos)
        : lancamentos.map(_construirCard).toList();

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: itens.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (context, index) => itens[index],
    );
  }

  List<Widget> _construirItensDeDespesas(List<Lancamento> lancamentos) {
    final itens = <Widget>[];

    for (final prioridade in PrioridadeLancamento.values) {
      final grupo =
          lancamentos.where((item) => item.prioridade == prioridade).toList()
            ..sort((primeiro, segundo) {
              final vencimento = primeiro.vencimento.compareTo(
                segundo.vencimento,
              );
              if (vencimento != 0) {
                return vencimento;
              }
              return primeiro.descricao.toLowerCase().compareTo(
                segundo.descricao.toLowerCase(),
              );
            });

      if (grupo.isEmpty) {
        continue;
      }

      final resumo = ResumoPrioridade.calcular(grupo);
      itens.add(
        _CabecalhoGrupo(
          titulo: prioridade.rotulo.toUpperCase(),
          quantidade: resumo.quantidade,
          restanteAPagar: _moeda.format(resumo.restanteAPagar),
          totalPago: _moeda.format(resumo.totalPago),
          totalGeral: _moeda.format(resumo.totalGeral),
          cor: corDaPrioridade(prioridade),
          icone: Icons.flag_outlined,
        ),
      );
      itens.addAll(grupo.map(_construirCard));
    }

    return itens;
  }

  Widget _construirCard(Lancamento lancamento) {
    final referencia = DateTime.now();
    final receita = lancamento.tipo == TipoLancamento.receita;
    final concluido = lancamento.status == StatusLancamento.concluido;
    final atrasado = lancamento.estaAtrasadoEm(referencia);
    final corDoCard = corDeFundoDaSituacao(lancamento, referencia);
    final corSituacao = corDaSituacao(lancamento, referencia);

    final parcela = lancamento.ehEntrada
        ? 'Entrada • '
        : (lancamento.forma == FormaLancamento.parcelado &&
                  lancamento.totalParcelas > 1) ||
              lancamento.forma == FormaLancamento.entradaParcelas
        ? 'Parcela ${lancamento.parcelaAtual}/'
              '${lancamento.totalParcelas} • '
        : '';
    final recorrencia = lancamento.forma == FormaLancamento.fixo
        ? 'Conta fixa • '
        : '';
    final rotuloData = receita ? 'Recebimento' : 'Vencimento';

    return Card(
      color: corDoCard,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _abrirDetalhes(lancamento),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                lancamento.descricao,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  decoration: concluido
                      ? TextDecoration.lineThrough
                      : TextDecoration.none,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$parcela$recorrencia$rotuloData: '
                          '${_data.format(lancamento.vencimento)}',
                        ),
                        const SizedBox(height: 5),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (!receita)
                              IndicadorPrioridade(
                                prioridade: lancamento.prioridade,
                                compacto: true,
                              ),
                            IndicadorSituacao(
                              lancamento: lancamento,
                              referencia: referencia,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _moeda.format(lancamento.valor),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: receita ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Icon(
                        concluido
                            ? Icons.check_circle
                            : atrasado
                            ? Icons.warning_amber_rounded
                            : Icons.schedule,
                        color: corSituacao,
                        size: 20,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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
      (item) =>
          item.tipo == widget.tipo && !item.excluido && _pertenceAoMes(item),
    );
    final total = lancamentosDoMes.fold<double>(
      0,
      (soma, item) => soma + item.valor,
    );
    final saldoPendente = lancamentosDoMes
        .where((item) => item.status == StatusLancamento.pendente)
        .fold<double>(0, (soma, item) => soma + item.valor);
    final totalConcluido = lancamentosDoMes
        .where((item) => item.status == StatusLancamento.concluido)
        .fold<double>(0, (soma, item) => soma + item.valor);
    final receita = widget.tipo == TipoLancamento.receita;
    final tipoOposto = receita
        ? TipoLancamento.despesa
        : TipoLancamento.receita;
    final saldoOposto = todos
        .where(
          (item) =>
              item.tipo == tipoOposto &&
              !item.excluido &&
              _pertenceAoMes(item) &&
              item.status == StatusLancamento.pendente,
        )
        .fold<double>(0, (soma, item) => soma + item.valor);

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            _ItemResumo(
              titulo: receita ? 'Saldo a pagar' : 'Saldo a receber',
              valor: _moeda.format(saldoOposto),
              cor: receita ? const Color(0xFFC62828) : const Color(0xFF00897B),
              destaque: true,
            ),
            const Divider(height: 1),
            _ItemResumo(
              titulo: receita ? 'Total a receber' : 'Total a pagar',
              valor: _moeda.format(total),
              cor: const Color(0xFF1565C0),
            ),
            const Divider(height: 1),
            _ItemResumo(
              titulo: receita ? 'Total recebido' : 'Total pago',
              valor: _moeda.format(totalConcluido),
              cor: const Color(0xFF168447),
            ),
            const Divider(height: 1),
            _ItemResumo(
              titulo: receita ? 'Saldo a receber' : 'Saldo a pagar',
              valor: _moeda.format(saldoPendente),
              cor: receita ? const Color(0xFF00897B) : const Color(0xFFC62828),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final receita = widget.tipo == TipoLancamento.receita;

    return Scaffold(
      appBar: AppBar(
        title: Text(receita ? 'Receitas pessoais' : 'Despesas pessoais'),
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
              Expanded(child: _construirLista(snapshot.data!)),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirFormulario,
        icon: const Icon(Icons.add),
        label: Text(receita ? 'Adicionar receita' : 'Adicionar despesa'),
      ),
    );
  }
}

class _CabecalhoGrupo extends StatelessWidget {
  const _CabecalhoGrupo({
    required this.titulo,
    required this.quantidade,
    required this.restanteAPagar,
    required this.totalPago,
    required this.totalGeral,
    required this.cor,
    required this.icone,
  });

  final String titulo;
  final int quantidade;
  final String restanteAPagar;
  final String totalPago;
  final String totalGeral;
  final Color cor;
  final IconData icone;

  @override
  Widget build(BuildContext context) {
    final quantidadeDeContas = quantidade == 1
        ? '1 conta'
        : '$quantidade contas';

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 38,
                decoration: BoxDecoration(
                  color: cor,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 9),
              Icon(icone, color: cor, size: 21),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: cor,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$quantidadeDeContas • ordem de vencimento',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 18),
          _LinhaSubtotal(
            rotulo: 'Restante a pagar',
            valor: restanteAPagar,
            cor: const Color(0xFFC62828),
          ),
          _LinhaSubtotal(
            rotulo: 'Total pago',
            valor: totalPago,
            cor: const Color(0xFF00897B),
          ),
          _LinhaSubtotal(rotulo: 'Total geral', valor: totalGeral, cor: cor),
        ],
      ),
    );
  }
}

class _LinhaSubtotal extends StatelessWidget {
  const _LinhaSubtotal({
    required this.rotulo,
    required this.valor,
    required this.cor,
  });

  final String rotulo;
  final String valor;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(rotulo)),
          const SizedBox(width: 12),
          Text(
            valor,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: cor, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _ItemResumo extends StatelessWidget {
  const _ItemResumo({
    required this.titulo,
    required this.valor,
    required this.cor,
    this.destaque = false,
  });

  final String titulo;
  final String valor;
  final Color cor;
  final bool destaque;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: destaque
          ? BoxDecoration(
              color: cor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            )
          : null,
      child: Row(
        children: [
          Expanded(
            child: Text(
              titulo,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: cor, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              valor,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(color: cor, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
