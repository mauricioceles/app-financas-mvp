import 'package:cloud_firestore/cloud_firestore.dart';

enum TipoLancamento { receita, despesa }

enum StatusLancamento { pendente, concluido }

enum FormaLancamento { vista, parcelado, entradaParcelas, fixo }

enum PrioridadeLancamento { essencial, alta, normal, baixa }

enum EscopoExclusao { somenteEsta, estaEProximas, todas }

extension PrioridadeLancamentoExtensao on PrioridadeLancamento {
  String get rotulo => switch (this) {
    PrioridadeLancamento.essencial => 'Essencial',
    PrioridadeLancamento.alta => 'Alta',
    PrioridadeLancamento.normal => 'Normal',
    PrioridadeLancamento.baixa => 'Baixa',
  };
}

PrioridadeLancamento prioridadeLancamentoDeNome(Object? nome) {
  if (nome is String) {
    for (final prioridade in PrioridadeLancamento.values) {
      if (prioridade.name == nome) {
        return prioridade;
      }
    }
  }

  return PrioridadeLancamento.normal;
}

class Lancamento {
  const Lancamento({
    required this.id,
    required this.descricao,
    required this.valor,
    required this.tipo,
    required this.vencimento,
    required this.status,
    required this.forma,
    required this.parcelaAtual,
    required this.totalParcelas,
    this.prioridade = PrioridadeLancamento.normal,
    this.grupoId,
    this.recorrenciaId,
    this.excluido = false,
  });

  final String id;
  final String descricao;
  final double valor;
  final TipoLancamento tipo;
  final DateTime vencimento;
  final StatusLancamento status;
  final FormaLancamento forma;
  final int parcelaAtual;
  final int totalParcelas;
  final PrioridadeLancamento prioridade;
  final String? grupoId;
  final String? recorrenciaId;
  final bool excluido;

  bool get fazParteDeSerie =>
      forma == FormaLancamento.parcelado ||
      forma == FormaLancamento.entradaParcelas ||
      forma == FormaLancamento.fixo;

  bool get ehEntrada =>
      forma == FormaLancamento.entradaParcelas && parcelaAtual == 0;

  bool estaAtrasadoEm(DateTime referencia) {
    if (status == StatusLancamento.concluido) {
      return false;
    }

    final diaDoVencimento = DateTime(
      vencimento.year,
      vencimento.month,
      vencimento.day,
    );
    final diaDeReferencia = DateTime(
      referencia.year,
      referencia.month,
      referencia.day,
    );

    return diaDoVencimento.isBefore(diaDeReferencia);
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'descricao': descricao.trim(),
      'valor': valor,
      'tipo': tipo.name,
      'vencimento': Timestamp.fromDate(vencimento),
      'status': status.name,
      'forma': forma.name,
      'parcelaAtual': parcelaAtual,
      'totalParcelas': totalParcelas,
      'prioridade': prioridade.name,
      'excluido': excluido,
      if (grupoId != null) 'grupoId': grupoId,
      if (recorrenciaId != null) 'recorrenciaId': recorrenciaId,
    };
  }

  factory Lancamento.fromMap(String id, Map<String, dynamic> dados) {
    return Lancamento(
      id: id,
      descricao: dados['descricao'] as String,
      valor: (dados['valor'] as num).toDouble(),
      tipo: TipoLancamento.values.byName(dados['tipo'] as String),
      vencimento: (dados['vencimento'] as Timestamp).toDate(),
      status: StatusLancamento.values.byName(dados['status'] as String),
      forma: FormaLancamento.values.byName(dados['forma'] as String),
      parcelaAtual: (dados['parcelaAtual'] as num?)?.toInt() ?? 1,
      totalParcelas: (dados['totalParcelas'] as num?)?.toInt() ?? 1,
      prioridade: prioridadeLancamentoDeNome(dados['prioridade']),
      grupoId: dados['grupoId'] as String?,
      recorrenciaId: dados['recorrenciaId'] as String?,
      excluido: dados['excluido'] == true,
    );
  }
}

int compararLancamentosMensais(Lancamento primeiro, Lancamento segundo) {
  if (primeiro.tipo == TipoLancamento.despesa &&
      segundo.tipo == TipoLancamento.despesa) {
    final status = primeiro.status.index.compareTo(segundo.status.index);
    if (status != 0) {
      return status;
    }

    if (primeiro.status == StatusLancamento.pendente) {
      final prioridade = primeiro.prioridade.index.compareTo(
        segundo.prioridade.index,
      );
      if (prioridade != 0) {
        return prioridade;
      }
    }
  }

  final vencimento = primeiro.vencimento.compareTo(segundo.vencimento);
  if (vencimento != 0) {
    return vencimento;
  }

  return primeiro.descricao.toLowerCase().compareTo(
    segundo.descricao.toLowerCase(),
  );
}
