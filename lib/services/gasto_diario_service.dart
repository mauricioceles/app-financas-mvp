import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/gasto_diario.dart';

class GastoDiarioService {
  GastoDiarioService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  DocumentReference<Map<String, dynamic>> get _usuario {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('Entre na sua conta para continuar.');
    return _firestore.collection('usuarios').doc(uid);
  }

  CollectionReference<Map<String, dynamic>> get _gastos =>
      _usuario.collection('gastosDiarios');
  CollectionReference<Map<String, dynamic>> get _categorias =>
      _usuario.collection('categoriasGastos');

  Stream<List<CategoriaGasto>> observarCategorias() =>
      _categorias.snapshots().map((snapshot) {
        final categorias = snapshot.docs.map((doc) =>
            CategoriaGasto.fromMap(doc.id, doc.data())).toList();
        categorias.sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
        return categorias;
      });

  /// O fim é inclusivo na interface; a consulta usa o próximo dia exclusivo.
  Stream<List<GastoDiario>> observarGastos(DateTime inicio, DateTime fim) =>
      _gastos
        .where('data', isGreaterThanOrEqualTo: Timestamp.fromDate(
            DateTime(inicio.year, inicio.month, inicio.day)))
        .where('data', isLessThan: Timestamp.fromDate(
            DateTime(fim.year, fim.month, fim.day + 1)))
        .orderBy('data', descending: true)
        .snapshots().map((snapshot) => snapshot.docs.map((doc) =>
            GastoDiario.fromMap(doc.id, doc.data())).toList());

  Future<String> salvarCategoria(String nome, {String? id, String? paiId}) async {
    final limpo = nome.trim();
    if (limpo.isEmpty || limpo.length > 60) {
      throw ArgumentError('Use um nome de 1 a 60 caracteres.');
    }
    final ref = id == null ? _categorias.doc() : _categorias.doc(id);
    await _firestore.runTransaction((tx) async {
      if (paiId != null) {
        final pai = await tx.get(_categorias.doc(paiId));
        if (!pai.exists || pai.data()?['paiId'] != null) {
          throw StateError('Escolha uma categoria principal válida.');
        }
      }
      if (id != null) {
        final atual = await tx.get(ref);
        if (!atual.exists || atual.data()?['paiId'] != paiId) {
          throw StateError('A categoria mudou. Atualize a tela.');
        }
      }
      tx.set(ref, {'nome': limpo, 'paiId': paiId});
    });
    return ref.id;
  }

  Future<void> salvar(GastoDiario gasto) async {
    if (gasto.valorCentavos <= 0 || gasto.valorCentavos > 99999999999 ||
        gasto.observacao.trim().length > 300) {
      throw ArgumentError('Confira o valor e a observação.');
    }
    final ref = gasto.id.isEmpty ? _gastos.doc() : _gastos.doc(gasto.id);
    await _firestore.runTransaction((tx) async {
      final categoria = await tx.get(_categorias.doc(gasto.categoriaId));
      if (!categoria.exists || categoria.data()?['paiId'] != null) {
        throw StateError('Escolha uma categoria principal válida.');
      }
      if (gasto.subcategoriaId != null) {
        final sub = await tx.get(_categorias.doc(gasto.subcategoriaId!));
        if (!sub.exists || sub.data()?['paiId'] != gasto.categoriaId) {
          throw StateError('A subcategoria não pertence à categoria escolhida.');
        }
      }
      if (gasto.id.isNotEmpty && !(await tx.get(ref)).exists) {
        throw StateError('Este gasto já foi excluído. Atualize a tela.');
      }
      tx.set(ref, gasto.toMap());
    });
  }

  Future<void> excluir(String id) => _gastos.doc(id).delete();
}
