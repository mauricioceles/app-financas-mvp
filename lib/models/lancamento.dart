import 'package:cloud_firestore/cloud_firestore.dart';

enum TipoLancamento { receita, despesa }

enum StatusLancamento { pendente, concluido }

enum FormaLancamento { vista, parcelado, fixo }

enum EscopoExclusao { somenteEsta, estaEProximas, todas }

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
  final String? grupoId;
  final String? recorrenciaId;
  final bool excluido;

  bool get fazParteDeSerie =>
      forma == FormaLancamento.parcelado || forma == FormaLancamento.fixo;

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
      grupoId: dados['grupoId'] as String?,
      recorrenciaId: dados['recorrenciaId'] as String?,
      excluido: dados['excluido'] == true,
    );
  }
}
