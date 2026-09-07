import 'lancamento.dart';

class ParcelaPlanejada {
  const ParcelaPlanejada({
    required this.numero,
    required this.vencimento,
    required this.status,
  });

  final int numero;
  final DateTime vencimento;
  final StatusLancamento status;
}

class PlanoParcelamento {
  const PlanoParcelamento._();

  static List<ParcelaPlanejada> gerar({
    required int parcelaAtual,
    required int totalParcelas,
    required DateTime vencimentoAtual,
    required StatusLancamento statusAtual,
  }) {
    if (totalParcelas < 2 || totalParcelas > 120) {
      throw ArgumentError('O total de parcelas deve estar entre 2 e 120.');
    }

    if (parcelaAtual < 1 || parcelaAtual > totalParcelas) {
      throw ArgumentError(
        'A parcela atual deve estar entre 1 e o total de parcelas.',
      );
    }

    return List<ParcelaPlanejada>.generate(totalParcelas, (indice) {
      final numero = indice + 1;
      final status = numero < parcelaAtual
          ? StatusLancamento.concluido
          : numero == parcelaAtual
          ? statusAtual
          : StatusLancamento.pendente;

      return ParcelaPlanejada(
        numero: numero,
        vencimento: _adicionarMeses(vencimentoAtual, numero - parcelaAtual),
        status: status,
      );
    });
  }

  static DateTime _adicionarMeses(DateTime data, int quantidade) {
    final totalMeses = data.year * 12 + data.month - 1 + quantidade;
    final ano = totalMeses ~/ 12;
    final mes = totalMeses % 12 + 1;
    final ultimoDia = DateTime(ano, mes + 1, 0).day;
    final dia = data.day > ultimoDia ? ultimoDia : data.day;

    return DateTime(ano, mes, dia);
  }
}
