# Gastos diários

Em **Pessoal → Gastos diários**, registre valor, data, categoria, subcategoria opcional e observação opcional. Use o ícone de categorias para criar e renomear categorias e subcategorias. Toque em um gasto para editar; o menu de opções permite excluir após confirmação.

Hoje, Esta semana (segunda a domingo), Este mês e Outro período controlam a consulta. Os filtros de categoria e subcategoria também controlam o total, o ranking e o histórico. Expanda uma categoria no resumo para ver seus subtotais por subcategoria. Os percentuais usam o total exibido, depois dos filtros.

## Armazenamento

- `usuarios/{uid}/gastosDiarios`: valor em centavos inteiros, data local normalizada, IDs de categoria/subcategoria e observação.
- `usuarios/{uid}/categoriasGastos`: nome e `paiId` nulo para categorias principais ou ID da categoria para subcategorias.
- Não escreve em `lancamentos` ou `recorrencias` e não altera o saldo existente.
- Renomear preserva vínculos históricos. Exclusão de categorias não está disponível.
- As regras limitam o acesso ao dono da conta e validam a hierarquia. A consulta por intervalo usa somente o campo `data`, sem índice composto adicional.

## Validação e publicação

Esta alteração precisa de Flutter/Dart compatíveis com o `pubspec.yaml` do projeto. No ambiente desta implementação o SDK não estava disponível, portanto os testes e o build não foram executados.

Antes de publicar:

```sh
flutter pub get
dart format lib/models/gasto_diario.dart lib/services/gasto_diario_service.dart lib/screens/tela_gastos_diarios.dart lib/screens/tela_categorias_gastos.dart lib/widgets/formulario_gasto_diario.dart lib/screens/tela_inicio.dart test/gasto_diario_test.dart
flutter analyze
flutter test
flutter build web --release
```

Validar as regras no emulador Firestore: acesso autenticado à própria conta, rejeição para outro UID/sem autenticação, valor inválido, categoria inexistente e subcategoria de outra categoria. Confirmar no app criação, edição, exclusão, troca de período e sincronização entre dois dispositivos usando uma conta de teste.

Após validar e aprovar, publicar regras e Hosting juntos:

```sh
firebase deploy --only firestore:rules,hosting
```

A conexão com GitHub não concede acesso ao Firebase. O app publicado só terá a funcionalidade após o build e o deploy com as novas regras.
