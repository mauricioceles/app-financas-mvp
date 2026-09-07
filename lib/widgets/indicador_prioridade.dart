import 'package:flutter/material.dart';

import '../models/lancamento.dart';

Color corDaPrioridade(PrioridadeLancamento prioridade) => switch (prioridade) {
  PrioridadeLancamento.essencial => const Color(0xFFB71C1C),
  PrioridadeLancamento.alta => const Color(0xFFEF6C00),
  PrioridadeLancamento.normal => const Color(0xFF1565C0),
  PrioridadeLancamento.baixa => const Color(0xFF616161),
};

class IndicadorPrioridade extends StatelessWidget {
  const IndicadorPrioridade({
    super.key,
    required this.prioridade,
    this.compacto = false,
  });

  final PrioridadeLancamento prioridade;
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    final cor = corDaPrioridade(prioridade);

    return Semantics(
      label: 'Prioridade ${prioridade.rotulo}',
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compacto ? 7 : 10,
          vertical: compacto ? 3 : 5,
        ),
        decoration: BoxDecoration(
          color: cor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: cor.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: compacto ? 7 : 8,
              height: compacto ? 7 : 8,
              decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              prioridade.rotulo,
              style: TextStyle(
                color: cor,
                fontSize: compacto ? 11 : null,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
