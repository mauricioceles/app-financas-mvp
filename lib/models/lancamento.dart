import 'package:cloud_firestore/cloud_firestore.dart';

enum TipoLancamento { receita, despesa }

enum StatusLancamento { pendente, concluido }

enum FormaLancamento { vista, parcelado }

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

  Map<String, dynamic> toMap() {
    return {
      'descricao': descricao.trim(),
      'valor': valor,
      'tipo': tipo.name,
      'vencimento': Timestamp.fromDate(vencimento),
      'status': status.name,
      'forma': forma.name,
      'parcelaAtual': parcelaAtual,
      'totalParcelas': totalParcelas,
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
      parcelaAtual: dados['parcelaAtual'] as int,
      totalParcelas: dados['totalParcelas'] as int,
    );
  }
}
