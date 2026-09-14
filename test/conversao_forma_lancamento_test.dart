import 'package:flutter_test/flutter_test.dart';

import 'package:app_financas_mvp/models/conversao_forma_lancamento.dart';
import 'package:app_financas_mvp/models/lancamento.dart';

void main() {
  Lancamento criar({
    required FormaLancamento forma,
    StatusLancamento status = StatusLancamento.pendente,
  }) {
    return Lancamento(
      id: 'lancamento-1',
      descricao: 'Dívida negociada',
      valor: 100,
      tipo: TipoLancamento.despesa,
      vencimento: DateTime(2026, 9, 10),
      status: status,
      forma: forma,
      parcelaAtual: 1,
      totalParcelas: 1,
      recorrenciaId: forma == FormaLancamento.fixo ? 'recorrencia-1' : null,
    );
  }

  test('permite transformar conta fixa pendente em parcelamento', () {
    final formas = formasDisponiveisNaEdicao(
      criar(forma: FormaLancamento.fixo),
    );

    expect(formas, [
      FormaLancamento.fixo,
      FormaLancamento.parcelado,
      FormaLancamento.entradaParcelas,
    ]);
  });

  test('permite transformar conta à vista pendente em parcelamento', () {
    final formas = formasDisponiveisNaEdicao(
      criar(forma: FormaLancamento.vista),
    );

    expect(formas, [FormaLancamento.vista, FormaLancamento.parcelado]);
  });

  test('mantém bloqueada a forma de uma série parcelada existente', () {
    final formas = formasDisponiveisNaEdicao(
      criar(forma: FormaLancamento.parcelado),
    );

    expect(formas, [FormaLancamento.parcelado]);
  });

  test('mantém bloqueada a forma de um lançamento concluído', () {
    final formas = formasDisponiveisNaEdicao(
      criar(forma: FormaLancamento.fixo, status: StatusLancamento.concluido),
    );

    expect(formas, [FormaLancamento.fixo]);
  });

  test('preserva o histórico e substitui a ocorrência atual e as futuras', () {
    final selecionado = DateTime(2026, 9, 10);

    expect(
      deveSubstituirOcorrenciaFixa(
        vencimentoOcorrencia: DateTime(2026, 8, 10),
        vencimentoSelecionado: selecionado,
      ),
      isFalse,
    );
    expect(
      deveSubstituirOcorrenciaFixa(
        vencimentoOcorrencia: DateTime(2026, 9, 10, 23, 59),
        vencimentoSelecionado: selecionado,
      ),
      isTrue,
    );
    expect(
      deveSubstituirOcorrenciaFixa(
        vencimentoOcorrencia: DateTime(2026, 10, 10),
        vencimentoSelecionado: selecionado,
      ),
      isTrue,
    );
  });
}
