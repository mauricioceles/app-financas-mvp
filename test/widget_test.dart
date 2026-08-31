import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_financas_mvp/models/lancamento.dart';

void main() {
  test('converte os dados do Firestore em lançamento', () {
    final vencimento = DateTime(2026, 8, 30);
    final lancamento = Lancamento.fromMap('lancamento-1', {
      'descricao': 'Internet',
      'valor': 129.90,
      'tipo': 'despesa',
      'vencimento': Timestamp.fromDate(vencimento),
      'status': 'pendente',
      'forma': 'parcelado',
      'parcelaAtual': 2,
      'totalParcelas': 12,
      'grupoId': 'grupo-1',
    });

    expect(lancamento.id, 'lancamento-1');
    expect(lancamento.descricao, 'Internet');
    expect(lancamento.valor, 129.90);
    expect(lancamento.tipo, TipoLancamento.despesa);
    expect(
      lancamento.vencimento.millisecondsSinceEpoch,
      vencimento.millisecondsSinceEpoch,
    );
    expect(lancamento.status, StatusLancamento.pendente);
    expect(lancamento.forma, FormaLancamento.parcelado);
    expect(lancamento.parcelaAtual, 2);
    expect(lancamento.totalParcelas, 12);
    expect(lancamento.grupoId, 'grupo-1');
    expect(lancamento.recorrenciaId, isNull);
    expect(lancamento.excluido, isFalse);
  });

  test('converte uma ocorrência de conta fixa', () {
    final lancamento = Lancamento.fromMap('fixo-202609', {
      'descricao': 'Internet',
      'valor': 120.0,
      'tipo': 'despesa',
      'vencimento': Timestamp.fromDate(DateTime(2026, 9, 10)),
      'status': 'concluido',
      'forma': 'fixo',
      'parcelaAtual': 1,
      'totalParcelas': 1,
      'grupoId': 'fixo-1',
      'recorrenciaId': 'fixo-1',
      'excluido': true,
    });

    expect(lancamento.forma, FormaLancamento.fixo);
    expect(lancamento.status, StatusLancamento.concluido);
    expect(lancamento.recorrenciaId, 'fixo-1');
    expect(lancamento.excluido, isTrue);
  });
}
