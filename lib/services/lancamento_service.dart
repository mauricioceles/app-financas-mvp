import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/lancamento.dart';

class LancamentoService {
  LancamentoService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String get _userId {
    final usuario = _auth.currentUser;

    if (usuario == null) {
      throw StateError('Nenhum usuário autenticado.');
    }

    return usuario.uid;
  }

  CollectionReference<Map<String, dynamic>> get _colecao {
    return _firestore
        .collection('usuarios')
        .doc(_userId)
        .collection('lancamentos');
  }

  Stream<List<Lancamento>> observarLancamentos() {
    return _colecao
        .orderBy('vencimento')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (documento) =>
                    Lancamento.fromMap(documento.id, documento.data()),
              )
              .toList(),
        );
  }

  Future<void> adicionar(Lancamento lancamento) async {
    final quantidade = lancamento.forma == FormaLancamento.parcelado
        ? lancamento.totalParcelas
        : 1;

    if (quantidade < 1 || quantidade > 120) {
      throw ArgumentError('A quantidade de parcelas deve estar entre 1 e 120.');
    }

    final lote = _firestore.batch();
    final grupoId = _colecao.doc().id;
    final valorParcelaCentavos = (lancamento.valor * 100).round();
    final valorParcela = valorParcelaCentavos / 100;
    final valorTotal = valorParcelaCentavos * quantidade / 100;

    for (var indice = 0; indice < quantidade; indice++) {
      final referencia = _colecao.doc();

      final parcela = Lancamento(
        id: referencia.id,
        descricao: lancamento.descricao,
        valor: valorParcela,
        tipo: lancamento.tipo,
        vencimento: _adicionarMeses(lancamento.vencimento, indice),
        status: StatusLancamento.pendente,
        forma: lancamento.forma,
        parcelaAtual: indice + 1,
        totalParcelas: quantidade,
      );

      lote.set(referencia, {
        ...parcela.toMap(),
        'grupoId': grupoId,
        'valorTotal': valorTotal,
        'criadoEm': FieldValue.serverTimestamp(),
      });
    }

    await lote.commit();
  }

  Future<void> alterarStatus(
    String lancamentoId,
    StatusLancamento status,
  ) async {
    await _colecao.doc(lancamentoId).update({'status': status.name});
  }

  Future<void> excluir(String lancamentoId) async {
    await _colecao.doc(lancamentoId).delete();
  }

  DateTime _adicionarMeses(DateTime data, int quantidade) {
    final totalMeses = data.year * 12 + data.month - 1 + quantidade;
    final ano = totalMeses ~/ 12;
    final mes = totalMeses % 12 + 1;
    final ultimoDia = DateTime(ano, mes + 1, 0).day;
    final dia = data.day > ultimoDia ? ultimoDia : data.day;

    return DateTime(ano, mes, dia);
  }
}
