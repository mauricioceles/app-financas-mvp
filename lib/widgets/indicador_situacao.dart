import 'package:flutter/material.dart';

import '../models/lancamento.dart';

String rotuloDaSituacao(Lancamento lancamento, DateTime referencia) {
  if (lancamento.status == StatusLancamento.concluido) {
    return lancamento.tipo == TipoLancamento.receita ? 'Recebido' : 'Pago';
  }

  return lancamento.estaAtrasadoEm(referencia) ? 'Atrasado' : 'A vencer';
}

Color corDaSituacao(Lancamento lancamento, DateTime referencia) {
  if (lancamento.status == StatusLancamento.concluido) {
    return const Color(0xFF00897B);
  }

  return lancamento.estaAtrasadoEm(referencia)
      ? const Color(0xFFC62828)
      : const Color(0xFFF57F17);
}

Color corDeFundoDaSituacao(Lancamento lancamento, DateTime referencia) {
  if (lancamento.status == StatusLancamento.concluido) {
    return const Color(0xFFE0F2E9);
  }

  return lancamento.estaAtrasadoEm(referencia)
      ? const Color(0xFFFFE2E0)
      : const Color(0xFFFFF8E1);
}

class IndicadorSituacao extends StatelessWidget {
  const IndicadorSituacao({
    super.key,
    required this.lancamento,
    required this.referencia,
  });

  final Lancamento lancamento;
  final DateTime referencia;

  @override
  Widget build(BuildContext context) {
    final cor = corDaSituacao(lancamento, referencia);
    final rotulo = rotuloDaSituacao(lancamento, referencia);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cor.withValues(alpha: 0.35)),
      ),
      child: Text(
        rotulo,
        style: TextStyle(color: cor, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}
