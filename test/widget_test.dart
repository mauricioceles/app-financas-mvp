import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_financas_mvp/models/lancamento.dart';
import 'package:app_financas_mvp/screens/tela_inicio.dart';

void main() {
  test('converte os dados do Firestore em lançamento', () {
    final vencimento = DateTime(2026, 8, 30);
    final lancamento = Lancamento.fromMap('lancamento-1', {
      'descricao': 'Internet',
      'valor': 129.90,
      'tipo': 'despesa',
      'vencimento': Timestamp.fromDate(vencimento),
      'status': 'pendente',
      'forma': 'parcelado',
      'parcelaAtual': 2,
      'totalParcelas': 12,
      'grupoId': 'grupo-1',
    });

    expect(lancamento.id, 'lancamento-1');
    expect(lancamento.descricao, 'Internet');
    expect(lancamento.valor, 129.90);
    expect(lancamento.tipo, TipoLancamento.despesa);
    expect(
      lancamento.vencimento.millisecondsSinceEpoch,
      vencimento.millisecondsSinceEpoch,
    );
    expect(lancamento.status, StatusLancamento.pendente);
    expect(lancamento.forma, FormaLancamento.parcelado);
    expect(lancamento.parcelaAtual, 2);
    expect(lancamento.totalParcelas, 12);
    expect(lancamento.grupoId, 'grupo-1');
    expect(lancamento.recorrenciaId, isNull);
    expect(lancamento.excluido, isFalse);
  });

  test('converte uma ocorrência de conta fixa', () {
    final lancamento = Lancamento.fromMap('fixo-202609', {
      'descricao': 'Internet',
      'valor': 120.0,
      'tipo': 'despesa',
      'vencimento': Timestamp.fromDate(DateTime(2026, 9, 10)),
      'status': 'concluido',
      'forma': 'fixo',
      'parcelaAtual': 1,
      'totalParcelas': 1,
      'grupoId': 'fixo-1',
      'recorrenciaId': 'fixo-1',
      'excluido': true,
    });

    expect(lancamento.forma, FormaLancamento.fixo);
    expect(lancamento.status, StatusLancamento.concluido);
    expect(lancamento.recorrenciaId, 'fixo-1');
    expect(lancamento.excluido, isTrue);
  });

  test('identifica lançamentos que fazem parte de uma série', () {
    Lancamento criar(FormaLancamento forma) => Lancamento(
      id: '1',
      descricao: 'Teste',
      valor: 10,
      tipo: TipoLancamento.despesa,
      vencimento: DateTime(2026, 9, 10),
      status: StatusLancamento.pendente,
      forma: forma,
      parcelaAtual: 1,
      totalParcelas: 1,
    );

    expect(criar(FormaLancamento.vista).fazParteDeSerie, isFalse);
    expect(criar(FormaLancamento.parcelado).fazParteDeSerie, isTrue);
    expect(criar(FormaLancamento.fixo).fazParteDeSerie, isTrue);
  });

  test('considera atraso somente antes da data de referência', () {
    final pendente = Lancamento(
      id: '1',
      descricao: 'Teste',
      valor: 10,
      tipo: TipoLancamento.despesa,
      vencimento: DateTime(2026, 9, 5, 23, 59),
      status: StatusLancamento.pendente,
      forma: FormaLancamento.vista,
      parcelaAtual: 1,
      totalParcelas: 1,
    );
    final concluido = Lancamento(
      id: '2',
      descricao: 'Teste pago',
      valor: 10,
      tipo: TipoLancamento.despesa,
      vencimento: DateTime(2026, 9, 5),
      status: StatusLancamento.concluido,
      forma: FormaLancamento.vista,
      parcelaAtual: 1,
      totalParcelas: 1,
    );

    expect(pendente.estaAtrasadoEm(DateTime(2026, 9, 5)), isFalse);
    expect(pendente.estaAtrasadoEm(DateTime(2026, 9, 6)), isTrue);
    expect(concluido.estaAtrasadoEm(DateTime(2026, 9, 6)), isFalse);
  });

  testWidgets('abre as opções de despesa e receita da área pessoal', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: TelaInicio()));

    expect(find.text('PESSOAL'), findsOneWidget);
    expect(find.text('PROFISSIONAL'), findsOneWidget);

    await tester.tap(find.byKey(const Key('botao-pessoal')));
    await tester.pumpAndSettle();

    expect(find.text('DESPESA'), findsOneWidget);
    expect(find.text('RECEITA'), findsOneWidget);
  });

  testWidgets('abre a área profissional provisória', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: TelaInicio()));

    await tester.tap(find.byKey(const Key('botao-profissional')));
    await tester.pumpAndSettle();

    expect(find.text('Área profissional em construção'), findsOneWidget);
  });
}
