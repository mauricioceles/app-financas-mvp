import 'package:flutter_test/flutter_test.dart';

import 'package:app_financas_mvp/models/lancamento.dart';
import 'package:app_financas_mvp/models/plano_com_entrada.dart';

void main() {
  test('gera entrada e parcelas restantes com valores diferentes', () {
    final plano = PlanoComEntrada.gerar(
      valorEntrada: 300,
      dataEntrada: DateTime(2026, 9, 7),
      statusEntrada: StatusLancamento.concluido,
      quantidadeParcelas: 5,
      valorParcela: 200,
      primeiroVencimento: DateTime(2026, 10, 15),
    );

    expect(plano, hasLength(6));
    expect(plano.first.ehEntrada, isTrue);
    expect(plano.first.numero, 0);
    expect(plano.first.valor, 300);
    expect(plano.first.status, StatusLancamento.concluido);
    expect(plano[1].ehEntrada, isFalse);
    expect(plano[1].numero, 1);
    expect(plano[1].valor, 200);
    expect(plano[1].vencimento, DateTime(2026, 10, 15));
    expect(plano.last.numero, 5);
    expect(plano.last.vencimento, DateTime(2027, 2, 15));
    expect(
      plano.every(
        (item) => item.ehEntrada || item.status == StatusLancamento.pendente,
      ),
      isTrue,
    );
  });

  test('calcula o total usando entrada e parcelas em centavos', () {
    final total = PlanoComEntrada.calcularTotal(
      valorEntrada: 199.99,
      quantidadeParcelas: 4,
      valorParcela: 150.01,
    );

    expect(total, 800.03);
  });

  test('preserva o último dia possível nos vencimentos', () {
    final plano = PlanoComEntrada.gerar(
      valorEntrada: 100,
      dataEntrada: DateTime(2026, 1, 10),
      statusEntrada: StatusLancamento.pendente,
      quantidadeParcelas: 2,
      valorParcela: 50,
      primeiroVencimento: DateTime(2026, 1, 31),
    );

    expect(plano[1].vencimento, DateTime(2026, 1, 31));
    expect(plano[2].vencimento, DateTime(2026, 2, 28));
  });

  test('recusa vencimento de parcela anterior à entrada', () {
    expect(
      () => PlanoComEntrada.gerar(
        valorEntrada: 100,
        dataEntrada: DateTime(2026, 9, 10),
        statusEntrada: StatusLancamento.pendente,
        quantidadeParcelas: 2,
        valorParcela: 50,
        primeiroVencimento: DateTime(2026, 9, 9),
      ),
      throwsArgumentError,
    );
  });
}
