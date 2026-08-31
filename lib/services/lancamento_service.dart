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

  CollectionReference<Map<String, dynamic>> get _recorrencias {
    return _firestore
        .collection('usuarios')
        .doc(_userId)
        .collection('recorrencias');
  }

  Stream<List<Lancamento>> observarLancamentosDoMes(DateTime mes) {
    final inicio = DateTime(mes.year, mes.month);
    final proximoMes = DateTime(mes.year, mes.month + 1);

    return _colecao
        .where('vencimento', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .where('vencimento', isLessThan: Timestamp.fromDate(proximoMes))
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
    if (lancamento.forma == FormaLancamento.fixo) {
      await _adicionarFixo(lancamento);
      return;
    }

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
        grupoId: grupoId,
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

  Future<void> garantirLancamentosFixosDoMes(DateTime mes) async {
    final recorrenciasSnapshot = await _recorrencias
        .where('ativa', isEqualTo: true)
        .get();

    if (recorrenciasSnapshot.docs.isEmpty) {
      return;
    }

    final inicioMes = DateTime(mes.year, mes.month);
    final proximoMes = DateTime(mes.year, mes.month + 1);
    final lancamentosSnapshot = await _colecao
        .where(
          'vencimento',
          isGreaterThanOrEqualTo: Timestamp.fromDate(inicioMes),
        )
        .where('vencimento', isLessThan: Timestamp.fromDate(proximoMes))
        .get();

    final recorrenciasExistentes = lancamentosSnapshot.docs
        .map((documento) => documento.data()['recorrenciaId'] as String?)
        .whereType<String>()
        .toSet();

    final lote = _firestore.batch();
    var quantidadeCriada = 0;

    for (final documento in recorrenciasSnapshot.docs) {
      if (recorrenciasExistentes.contains(documento.id)) {
        continue;
      }

      final dados = documento.data();
      final inicio = (dados['inicio'] as Timestamp).toDate();

      if (_compararMeses(inicioMes, inicio) < 0) {
        continue;
      }

      final vencimento = _dataNoMes(
        inicioMes,
        (dados['diaVencimento'] as num).toInt(),
      );
      final referencia = _colecao.doc(_idOcorrencia(documento.id, inicioMes));
      final valor = (dados['valor'] as num).toDouble();

      final lancamento = Lancamento(
        id: referencia.id,
        descricao: dados['descricao'] as String,
        valor: valor,
        tipo: TipoLancamento.values.byName(dados['tipo'] as String),
        vencimento: vencimento,
        status: StatusLancamento.pendente,
        forma: FormaLancamento.fixo,
        parcelaAtual: 1,
        totalParcelas: 1,
        grupoId: documento.id,
        recorrenciaId: documento.id,
      );

      lote.set(referencia, {
        ...lancamento.toMap(),
        'valorTotal': valor,
        'criadoEm': FieldValue.serverTimestamp(),
      });
      quantidadeCriada++;
    }

    if (quantidadeCriada > 0) {
      await lote.commit();
    }
  }

  Future<void> _adicionarFixo(Lancamento lancamento) async {
    final lote = _firestore.batch();
    final recorrenciaReferencia = _recorrencias.doc();
    final vencimento = DateTime(
      lancamento.vencimento.year,
      lancamento.vencimento.month,
      lancamento.vencimento.day,
    );
    final valorCentavos = (lancamento.valor * 100).round();
    final valor = valorCentavos / 100;

    lote.set(recorrenciaReferencia, {
      'descricao': lancamento.descricao.trim(),
      'valor': valor,
      'tipo': lancamento.tipo.name,
      'diaVencimento': vencimento.day,
      'inicio': Timestamp.fromDate(vencimento),
      'ativa': true,
      'criadoEm': FieldValue.serverTimestamp(),
    });

    final ocorrenciaReferencia = _colecao.doc(
      _idOcorrencia(recorrenciaReferencia.id, vencimento),
    );
    final ocorrencia = Lancamento(
      id: ocorrenciaReferencia.id,
      descricao: lancamento.descricao,
      valor: valor,
      tipo: lancamento.tipo,
      vencimento: vencimento,
      status: StatusLancamento.pendente,
      forma: FormaLancamento.fixo,
      parcelaAtual: 1,
      totalParcelas: 1,
      grupoId: recorrenciaReferencia.id,
      recorrenciaId: recorrenciaReferencia.id,
    );

    lote.set(ocorrenciaReferencia, {
      ...ocorrencia.toMap(),
      'valorTotal': valor,
      'criadoEm': FieldValue.serverTimestamp(),
    });

    await lote.commit();
  }

  Future<void> alterarStatus(
    String lancamentoId,
    StatusLancamento status,
  ) async {
    await _colecao.doc(lancamentoId).update({'status': status.name});
  }

  Future<void> excluir(Lancamento lancamento) async {
    if (lancamento.forma == FormaLancamento.fixo &&
        lancamento.recorrenciaId != null) {
      await _colecao.doc(lancamento.id).update({'excluido': true});
      return;
    }

    await _colecao.doc(lancamento.id).delete();
  }

  int _compararMeses(DateTime primeiro, DateTime segundo) {
    final primeiroMes = primeiro.year * 12 + primeiro.month;
    final segundoMes = segundo.year * 12 + segundo.month;
    return primeiroMes.compareTo(segundoMes);
  }

  DateTime _dataNoMes(DateTime mes, int dia) {
    final ultimoDia = DateTime(mes.year, mes.month + 1, 0).day;
    return DateTime(mes.year, mes.month, dia > ultimoDia ? ultimoDia : dia);
  }

  String _idOcorrencia(String recorrenciaId, DateTime mes) {
    final numeroMes = mes.month.toString().padLeft(2, '0');
    return '${recorrenciaId}_${mes.year}$numeroMes';
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
