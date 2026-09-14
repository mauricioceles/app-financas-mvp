import 'lancamento.dart';

List<FormaLancamento> formasDisponiveisNaEdicao(Lancamento lancamento) {
  if (lancamento.status == StatusLancamento.concluido) {
    return <FormaLancamento>[lancamento.forma];
  }

  return switch (lancamento.forma) {
    FormaLancamento.fixo => <FormaLancamento>[
      FormaLancamento.fixo,
      FormaLancamento.parcelado,
      FormaLancamento.entradaParcelas,
    ],
    FormaLancamento.vista => <FormaLancamento>[
      FormaLancamento.vista,
      FormaLancamento.parcelado,
    ],
    FormaLancamento.parcelado ||
    FormaLancamento.entradaParcelas => <FormaLancamento>[lancamento.forma],
  };
}

bool mudancaDeFormaPermitida(Lancamento lancamento, FormaLancamento novaForma) {
  return formasDisponiveisNaEdicao(lancamento).contains(novaForma);
}

bool deveSubstituirOcorrenciaFixa({
  required DateTime vencimentoOcorrencia,
  required DateTime vencimentoSelecionado,
}) {
  final ocorrencia = DateTime(
    vencimentoOcorrencia.year,
    vencimentoOcorrencia.month,
    vencimentoOcorrencia.day,
  );
  final selecionado = DateTime(
    vencimentoSelecionado.year,
    vencimentoSelecionado.month,
    vencimentoSelecionado.day,
  );
  return !ocorrencia.isBefore(selecionado);
}

String rotuloFormaLancamento(FormaLancamento forma) {
  return switch (forma) {
    FormaLancamento.vista => 'À vista',
    FormaLancamento.parcelado => 'Parcelado',
    FormaLancamento.entradaParcelas => 'Entrada + parcelas',
    FormaLancamento.fixo => 'Fixo mensal',
  };
}
