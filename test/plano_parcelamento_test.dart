import 'package:flutter_test/flutter_test.dart';

import 'package:app_financas_mvp/models/lancamento.dart';
import 'package:app_financas_mvp/models/plano_parcelamento.dart';

void main() {
  test('reconstrói todo o histórico a partir da parcela atual', () {
    final parcelas = PlanoParcelamento.gerar(
      parcelaAtual: 8,
      totalParcelas: 16,
      vencimentoAtual: DateTime(2026, 9, 10),
      statusAtual: StatusLancamento.pendente,
    );

    expect(parcelas, hasLength(16));
    expect(parcelas.first.numero, 1);
    expect(parcelas.first.vencimento, DateTime(2026, 2, 10));
    expect(parcelas.first.status, StatusLancamento.concluido);
    expect(parcelas[6].status, StatusLancamento.concluido);
    expect(parcelas[7].numero, 8);
    expect(parcelas[7].vencimento, DateTime(2026, 9, 10));
    expect(parcelas[7].status, StatusLancamento.pendente);
    expect(parcelas[8].status, StatusLancamento.pendente);
    expect(parcelas.last.numero, 16);
    expect(parcelas.last.vencimento, DateTime(2027, 5, 10));
  });

  test('respeita o último dia ao recuar e avançar meses', () {
    final parcelas = PlanoParcelamento.gerar(
      parcelaAtual: 2,
      totalParcelas: 3,
      vencimentoAtual: DateTime(2026, 3, 31),
      statusAtual: StatusLancamento.concluido,
    );

    expect(parcelas[0].vencimento, DateTime(2026, 2, 28));
    expect(parcelas[0].status, StatusLancamento.concluido);
    expect(parcelas[1].vencimento, DateTime(2026, 3, 31));
    expect(parcelas[1].status, StatusLancamento.concluido);
    expect(parcelas[2].vencimento, DateTime(2026, 4, 30));
    expect(parcelas[2].status, StatusLancamento.pendente);
  });

  test('recusa parcela atual maior que o total', () {
    expect(
      () => PlanoParcelamento.gerar(
        parcelaAtual: 5,
        totalParcelas: 4,
        vencimentoAtual: DateTime(2026, 9, 10),
        statusAtual: StatusLancamento.pendente,
      ),
      throwsArgumentError,
    );
  });
}
