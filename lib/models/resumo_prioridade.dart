import 'lancamento.dart';

class ResumoPrioridade {
  const ResumoPrioridade({
    required this.quantidade,
    required this.totalGeral,
    required this.totalPago,
    required this.restanteAPagar,
  });

  final int quantidade;
  final double totalGeral;
  final double totalPago;
  final double restanteAPagar;

  factory ResumoPrioridade.calcular(Iterable<Lancamento> lancamentos) {
    var quantidade = 0;
    var totalGeralCentavos = 0;
    var totalPagoCentavos = 0;

    for (final lancamento in lancamentos) {
      final valorCentavos = (lancamento.valor * 100).round();
      quantidade++;
      totalGeralCentavos += valorCentavos;

      if (lancamento.status == StatusLancamento.concluido) {
        totalPagoCentavos += valorCentavos;
      }
    }

    return ResumoPrioridade(
      quantidade: quantidade,
      totalGeral: totalGeralCentavos / 100,
      totalPago: totalPagoCentavos / 100,
      restanteAPagar: (totalGeralCentavos - totalPagoCentavos) / 100,
    );
  }
}
