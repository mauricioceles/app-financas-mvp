import 'lancamento.dart';

class PartePlanejada {
  const PartePlanejada({
    required this.numero,
    required this.vencimento,
    required this.valor,
    required this.status,
    required this.ehEntrada,
  });

  final int numero;
  final DateTime vencimento;
  final double valor;
  final StatusLancamento status;
  final bool ehEntrada;
}

class PlanoComEntrada {
  const PlanoComEntrada._();

  static List<PartePlanejada> gerar({
    required double valorEntrada,
    required DateTime dataEntrada,
    required StatusLancamento statusEntrada,
    required int quantidadeParcelas,
    required double valorParcela,
    required DateTime primeiroVencimento,
  }) {
    if (quantidadeParcelas < 1 || quantidadeParcelas > 120) {
      throw ArgumentError('A quantidade deve estar entre 1 e 120 parcelas.');
    }

    final entradaCentavos = (valorEntrada * 100).round();
    final parcelaCentavos = (valorParcela * 100).round();
    if (entradaCentavos <= 0 || parcelaCentavos <= 0) {
      throw ArgumentError('A entrada e a parcela devem ser maiores que zero.');
    }

    final entradaNormalizada = _somenteData(dataEntrada);
    final primeiroVencimentoNormalizado = _somenteData(primeiroVencimento);
    if (primeiroVencimentoNormalizado.isBefore(entradaNormalizada)) {
      throw ArgumentError(
        'O primeiro vencimento não pode ser anterior à entrada.',
      );
    }

    return <PartePlanejada>[
      PartePlanejada(
        numero: 0,
        vencimento: entradaNormalizada,
        valor: entradaCentavos / 100,
        status: statusEntrada,
        ehEntrada: true,
      ),
      ...List<PartePlanejada>.generate(quantidadeParcelas, (indice) {
        return PartePlanejada(
          numero: indice + 1,
          vencimento: _adicionarMeses(primeiroVencimentoNormalizado, indice),
          valor: parcelaCentavos / 100,
          status: StatusLancamento.pendente,
          ehEntrada: false,
        );
      }),
    ];
  }

  static double calcularTotal({
    required double valorEntrada,
    required int quantidadeParcelas,
    required double valorParcela,
  }) {
    final entradaCentavos = (valorEntrada * 100).round();
    final parcelaCentavos = (valorParcela * 100).round();
    return (entradaCentavos + quantidadeParcelas * parcelaCentavos) / 100;
  }

  static DateTime _adicionarMeses(DateTime data, int quantidade) {
    final totalMeses = data.year * 12 + data.month - 1 + quantidade;
    final ano = totalMeses ~/ 12;
    final mes = totalMeses % 12 + 1;
    final ultimoDia = DateTime(ano, mes + 1, 0).day;
    final dia = data.day > ultimoDia ? ultimoDia : data.day;

    return DateTime(ano, mes, dia);
  }

  static DateTime _somenteData(DateTime data) {
    return DateTime(data.year, data.month, data.day);
  }
}
