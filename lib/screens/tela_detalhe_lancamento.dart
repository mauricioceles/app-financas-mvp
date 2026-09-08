import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/lancamento.dart';
import '../services/lancamento_service.dart';
import '../widgets/formulario_edicao_lancamento.dart';
import '../widgets/indicador_prioridade.dart';
import '../widgets/indicador_situacao.dart';

class TelaDetalheLancamento extends StatelessWidget {
  TelaDetalheLancamento({
    super.key,
    required this.servico,
    required this.lancamentoId,
  });

  final LancamentoService servico;
  final String lancamentoId;

  final NumberFormat _moeda = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$',
  );
  final DateFormat _data = DateFormat('dd/MM/yyyy');

  Future<void> _editar(BuildContext context, Lancamento lancamento) async {
    final editou = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => FormularioEdicaoLancamento(
          servico: servico,
          lancamento: lancamento,
        ),
      ),
    );

    if (editou == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lançamento atualizado com sucesso.')),
      );
    }
  }

  Future<void> _alternarStatus(
    BuildContext context,
    Lancamento lancamento,
  ) async {
    final novoStatus = lancamento.status == StatusLancamento.pendente
        ? StatusLancamento.concluido
        : StatusLancamento.pendente;

    try {
      await servico.alterarStatus(lancamento.id, novoStatus);
      if (context.mounted) {
        Navigator.pop(context);
      }
    } catch (erro) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível alterar: $erro')),
        );
      }
    }
  }

  Future<EscopoExclusao?> _selecionarEscopo(BuildContext context) {
    return showDialog<EscopoExclusao>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir lançamento'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Este lançamento faz parte de uma série. Quais deseja excluir?',
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () =>
                  Navigator.pop(context, EscopoExclusao.somenteEsta),
              child: const Text('Somente este'),
            ),
            OutlinedButton(
              onPressed: () =>
                  Navigator.pop(context, EscopoExclusao.estaEProximas),
              child: const Text('Este e próximos'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, EscopoExclusao.todas),
              child: const Text('Toda a série'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  Future<EscopoExclusao?> _confirmarExclusaoSimples(
    BuildContext context,
  ) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir lançamento'),
        content: const Text('Confirma a exclusão deste lançamento?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sim'),
          ),
        ],
      ),
    );

    return confirmou == true ? EscopoExclusao.somenteEsta : null;
  }

  Future<void> _excluir(BuildContext context, Lancamento lancamento) async {
    final escopo = lancamento.fazParteDeSerie
        ? await _selecionarEscopo(context)
        : await _confirmarExclusaoSimples(context);

    if (escopo == null || !context.mounted) {
      return;
    }

    try {
      await servico.excluir(lancamento, escopo: escopo);
      if (context.mounted) {
        Navigator.pop(context);
      }
    } catch (erro) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível excluir: $erro')),
        );
      }
    }
  }

  String _descricaoExibicao(Lancamento lancamento) {
    if (lancamento.ehEntrada) {
      return '${lancamento.descricao} - Entrada';
    }
    if (lancamento.forma == FormaLancamento.entradaParcelas) {
      return '${lancamento.descricao} - Parcela '
          '${lancamento.parcelaAtual} / ${lancamento.totalParcelas}';
    }
    if (lancamento.forma == FormaLancamento.parcelado &&
        lancamento.totalParcelas > 1) {
      return '${lancamento.descricao} - ${lancamento.parcelaAtual} / '
          '${lancamento.totalParcelas}';
    }
    return lancamento.descricao;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Lancamento?>(
      stream: servico.observarLancamento(lancamentoId),
      builder: (context, snapshot) {
        final lancamento = snapshot.data;
        final titulo = lancamento?.tipo == TipoLancamento.receita
            ? 'Receita'
            : 'Despesa';

        return Scaffold(
          appBar: AppBar(
            title: Text(titulo),
            actions: [
              if (lancamento != null)
                TextButton(
                  onPressed: () => _editar(context, lancamento),
                  child: const Text('Editar'),
                ),
            ],
          ),
          body: _construirConteudo(context, snapshot, lancamento),
        );
      },
    );
  }

  Widget _construirConteudo(
    BuildContext context,
    AsyncSnapshot<Lancamento?> snapshot,
    Lancamento? lancamento,
  ) {
    if (snapshot.hasError) {
      return Center(
        child: SelectableText('Erro ao carregar: ${snapshot.error}'),
      );
    }

    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }

    if (lancamento == null || lancamento.excluido) {
      return const Center(child: Text('Este lançamento não está disponível.'));
    }

    final concluido = lancamento.status == StatusLancamento.concluido;
    final receita = lancamento.tipo == TipoLancamento.receita;
    final referencia = DateTime.now();
    final status = rotuloDaSituacao(lancamento, referencia);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            _descricaoExibicao(lancamento),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 24),
          _LinhaDetalhe(
            icone: Icons.payments_outlined,
            titulo: 'Valor',
            valor: _moeda.format(lancamento.valor),
          ),
          _LinhaDetalhe(
            icone: Icons.event_outlined,
            titulo: 'Vencimento',
            valor: _data.format(lancamento.vencimento),
          ),
          _LinhaDetalhe(
            icone: concluido
                ? Icons.check_circle_outline
                : Icons.schedule_outlined,
            titulo: 'Situação',
            valor: status,
            cor: corDaSituacao(lancamento, referencia),
          ),
          if (!receita)
            _LinhaDetalhe(
              icone: Icons.flag_outlined,
              titulo: 'Prioridade',
              valor: lancamento.prioridade.rotulo,
              cor: corDaPrioridade(lancamento.prioridade),
            ),
          if (lancamento.forma == FormaLancamento.fixo)
            const _LinhaDetalhe(
              icone: Icons.autorenew,
              titulo: 'Repetição',
              valor: 'Fixa mensal',
            ),
          if (lancamento.forma == FormaLancamento.entradaParcelas)
            _LinhaDetalhe(
              icone: Icons.account_balance_wallet_outlined,
              titulo: 'Parte da série',
              valor: lancamento.ehEntrada
                  ? 'Entrada'
                  : 'Parcela ${lancamento.parcelaAtual} de '
                        '${lancamento.totalParcelas}',
            ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: () => _alternarStatus(context, lancamento),
            icon: Icon(
              concluido ? Icons.undo_rounded : Icons.thumb_up_alt_outlined,
            ),
            label: Text(
              concluido
                  ? 'Marcar como pendente'
                  : receita
                  ? 'Marcar como recebida'
                  : 'Marcar como paga',
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => _excluir(context, lancamento),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Excluir'),
          ),
        ],
      ),
    );
  }
}

class _LinhaDetalhe extends StatelessWidget {
  const _LinhaDetalhe({
    required this.icone,
    required this.titulo,
    required this.valor,
    this.cor,
  });

  final IconData icone;
  final String titulo;
  final String valor;
  final Color? cor;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icone, color: cor),
      title: Text(titulo),
      subtitle: Text(
        valor,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: cor,
          fontWeight: cor == null ? null : FontWeight.w700,
        ),
      ),
    );
  }
}
