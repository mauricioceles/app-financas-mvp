import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_financas_mvp/models/gasto_diario.dart';
import 'package:app_financas_mvp/screens/tela_inicio.dart';

void main() {
  test('converte reais e centavos sem arredondar casas extras', () {
    expect(lerCentavos('12,50'), 1250);
    expect(lerCentavos('12.50'), 1250);
    expect(lerCentavos('1.234,56'), 123456);
    expect(lerCentavos('0,01'), 1);
    expect(lerCentavos(' 10 '), 1000);
    expect(lerCentavos('10,5'), 1050);
    for (final valor in [
      '',
      '0',
      '-10',
      '1.234',
      '1,234',
      '1.2,50',
      'NaN',
      '1e3',
      '1000000000',
    ]) {
      expect(lerCentavos(valor), isNull, reason: valor);
    }
  });

  test('preserva categoria, subcategoria e valor ao serializar', () {
    final gasto = GastoDiario(
      id: 'g1',
      valorCentavos: 1299,
      data: DateTime(2026, 10, 20, 18, 45),
      categoriaId: 'alimentacao',
      subcategoriaId: 'padaria',
      observacao: ' Café ',
    );
    final salvo = GastoDiario.fromMap(gasto.id, gasto.toMap());
    expect(salvo.valorCentavos, 1299);
    expect(salvo.data, DateTime(2026, 10, 20));
    expect(salvo.categoriaId, 'alimentacao');
    expect(salvo.subcategoriaId, 'padaria');
    expect(salvo.observacao, 'Café');
  });

  test('totaliza centavos e aceita gastos sem subcategoria', () {
    GastoDiario gasto(int valor) => GastoDiario(
      id: '',
      valorCentavos: valor,
      data: DateTime(2026, 10, 20),
      categoriaId: 'transporte',
    );
    expect(totalGastos([gasto(10), gasto(20), gasto(1299)]), 1329);
    expect(totalGastos([]), 0);
    expect(GastoDiario.fromMap('g', gasto(10).toMap()).subcategoriaId, isNull);
  });

  testWidgets('menu pessoal permite alcançar gastos diários em tela pequena', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: TelaPessoal()));
    final botao = find.byKey(const Key('botao-gastos-diarios'));
    await tester.ensureVisible(botao);
    expect(botao, findsOneWidget);
    expect(find.byKey(const Key('botao-despesa')), findsOneWidget);
    expect(find.byKey(const Key('botao-receita')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
