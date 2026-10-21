import 'package:cloud_firestore/cloud_firestore.dart';

/// Valores em centavos evitam arredondamentos nos totais por categoria.
class GastoDiario {
  const GastoDiario({
    required this.id,
    required this.valorCentavos,
    required this.data,
    required this.categoriaId,
    this.subcategoriaId,
    this.observacao = '',
  });

  final String id;
  final int valorCentavos;
  final DateTime data;
  final String categoriaId;
  final String? subcategoriaId;
  final String observacao;

  factory GastoDiario.fromMap(String id, Map<String, dynamic> map) =>
      GastoDiario(
        id: id,
        valorCentavos: (map['valorCentavos'] as num).toInt(),
        data: (map['data'] as Timestamp).toDate(),
        categoriaId: map['categoriaId'] as String,
        subcategoriaId: map['subcategoriaId'] as String?,
        observacao: map['observacao'] as String? ?? '',
      );

  Map<String, dynamic> toMap() => {
    'valorCentavos': valorCentavos,
    'data': Timestamp.fromDate(DateTime(data.year, data.month, data.day)),
    'categoriaId': categoriaId,
    'subcategoriaId': subcategoriaId,
    'observacao': observacao.trim(),
  };
}

class CategoriaGasto {
  const CategoriaGasto({required this.id, required this.nome, this.paiId});
  final String id;
  final String nome;
  final String? paiId;

  factory CategoriaGasto.fromMap(String id, Map<String, dynamic> map) =>
      CategoriaGasto(
        id: id,
        nome: map['nome'] as String,
        paiId: map['paiId'] as String?,
      );
}

/// Aceita 12,50, 12.50 e 1.234,56. Rejeita casas extras e valores negativos.
int? lerCentavos(String texto) {
  var valor = texto.trim();
  if (valor.contains(',')) {
    if (!RegExp(r'^(\d+|\d{1,3}(\.\d{3})+)(,\d{1,2})?$').hasMatch(valor)) {
      return null;
    }
    valor = valor.replaceAll('.', '').replaceAll(',', '.');
  }
  if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(valor)) return null;
  final partes = valor.split('.');
  final reais = int.tryParse(partes[0]);
  if (reais == null || reais > 999999999) return null;
  final centavos = partes.length == 1
      ? 0
      : int.parse(partes[1].padRight(2, '0'));
  final total = reais * 100 + centavos;
  return total > 0 ? total : null;
}

int totalGastos(Iterable<GastoDiario> gastos) =>
    gastos.fold(0, (total, gasto) => total + gasto.valorCentavos);
