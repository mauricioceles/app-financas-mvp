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
  });
}
