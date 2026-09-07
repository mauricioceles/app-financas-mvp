import 'package:flutter_test/flutter_test.dart';

import 'package:app_financas_mvp/models/lancamento.dart';
import 'package:app_financas_mvp/models/resumo_prioridade.dart';

void main() {
  test('calcula restante, pago e total geral de uma prioridade', () {
    Lancamento criar(String id, double valor, StatusLancamento status) =>
        Lancamento(
          id: id,
          descricao: id,
          valor: valor,
          tipo: TipoLancamento.despesa,
          vencimento: DateTime(2026, 9, 10),
          status: status,
          forma: FormaLancamento.vista,
          parcelaAtual: 1,
          totalParcelas: 1,
          prioridade: PrioridadeLancamento.essencial,
        );

    final resumo = ResumoPrioridade.calcular([
      criar('paga', 400, StatusLancamento.concluido),
      criar('atrasada', 250, StatusLancamento.pendente),
      criar('a-vencer', 500, StatusLancamento.pendente),
    ]);

    expect(resumo.quantidade, 3);
    expect(resumo.restanteAPagar, 750);
    expect(resumo.totalPago, 400);
    expect(resumo.totalGeral, 1150);
  });
}
