import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/lancamento.dart';
import '../models/plano_com_entrada.dart';
import '../models/plano_parcelamento.dart';

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

  Stream<Lancamento?> observarLancamento(String lancamentoId) {
    return _colecao.doc(lancamentoId).snapshots().map((documento) {
      final dados = documento.data();
      if (!documento.exists || dados == null) {
        return null;
      }

      return Lancamento.fromMap(documento.id, dados);
    });
  }

  Future<void> adicionar(Lancamento lancamento) async {
    if (lancamento.forma == FormaLancamento.fixo) {
      await _adicionarFixo(lancamento);
      return;
    }

    if (lancamento.forma == FormaLancamento.entradaParcelas) {
      throw ArgumentError(
        'Use adicionarComEntrada para lançamentos com entrada.',
      );
    }

    final lote = _firestore.batch();
    final grupoId = _colecao.doc().id;
    final valorParcelaCentavos = (lancamento.valor * 100).round();
    final valorParcela = valorParcelaCentavos / 100;
    final plano = lancamento.forma == FormaLancamento.parcelado
        ? PlanoParcelamento.gerar(
            parcelaAtual: lancamento.parcelaAtual,
            totalParcelas: lancamento.totalParcelas,
            vencimentoAtual: lancamento.vencimento,
            statusAtual: lancamento.status,
          )
        : <ParcelaPlanejada>[
            ParcelaPlanejada(
              numero: 1,
              vencimento: lancamento.vencimento,
              status: lancamento.status,
            ),
          ];
    final valorTotal = valorParcelaCentavos * plano.length / 100;

    for (final item in plano) {
      final referencia = _colecao.doc();

      final parcela = Lancamento(
        id: referencia.id,
        descricao: lancamento.descricao,
        valor: valorParcela,
        tipo: lancamento.tipo,
        vencimento: item.vencimento,
        status: item.status,
        forma: lancamento.forma,
        parcelaAtual: item.numero,
        totalParcelas: plano.length,
        prioridade: lancamento.prioridade,
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

  Future<void> adicionarComEntrada({
    required String descricao,
    required TipoLancamento tipo,
    required double valorEntrada,
    required DateTime dataEntrada,
    required StatusLancamento statusEntrada,
    required int quantidadeParcelas,
    required double valorParcela,
    required DateTime primeiroVencimento,
    required PrioridadeLancamento prioridade,
  }) async {
    final plano = PlanoComEntrada.gerar(
      valorEntrada: valorEntrada,
      dataEntrada: dataEntrada,
      statusEntrada: statusEntrada,
      quantidadeParcelas: quantidadeParcelas,
      valorParcela: valorParcela,
      primeiroVencimento: primeiroVencimento,
    );
    final grupoId = _colecao.doc().id;
    final valorTotalCentavos = plano.fold<int>(
      0,
      (soma, item) => soma + (item.valor * 100).round(),
    );
    final lote = _firestore.batch();

    for (final item in plano) {
      final referencia = _colecao.doc();
      final lancamento = Lancamento(
        id: referencia.id,
        descricao: descricao,
        valor: item.valor,
        tipo: tipo,
        vencimento: item.vencimento,
        status: item.status,
        forma: FormaLancamento.entradaParcelas,
        parcelaAtual: item.numero,
        totalParcelas: quantidadeParcelas,
        prioridade: prioridade,
        grupoId: grupoId,
      );

      lote.set(referencia, {
        ...lancamento.toMap(),
        'grupoId': grupoId,
        'valorTotal': valorTotalCentavos / 100,
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

      final referencia = _colecao.doc(_idOcorrencia(documento.id, inicioMes));
      final ocorrenciaJaExiste = await referencia.get();
      if (ocorrenciaJaExiste.exists) {
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
        prioridade: prioridadeLancamentoDeNome(dados['prioridade']),
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
      'prioridade': lancamento.prioridade.name,
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
      prioridade: lancamento.prioridade,
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

  Future<void> atualizarOcorrencia({
    required Lancamento lancamento,
    required String descricao,
    required double valor,
    required DateTime vencimento,
    required PrioridadeLancamento prioridade,
  }) async {
    final valorCentavos = (valor * 100).round();

    await _colecao.doc(lancamento.id).update({
      'descricao': descricao.trim(),
      'valor': valorCentavos / 100,
      'prioridade': prioridade.name,
      'vencimento': Timestamp.fromDate(
        DateTime(vencimento.year, vencimento.month, vencimento.day),
      ),
    });

    if (lancamento.tipo == TipoLancamento.despesa &&
        lancamento.fazParteDeSerie &&
        lancamento.grupoId != null &&
        prioridade != lancamento.prioridade) {
      await _atualizarPrioridadeDaSerie(lancamento, prioridade);
    }
  }

  Future<void> _atualizarPrioridadeDaSerie(
    Lancamento lancamento,
    PrioridadeLancamento prioridade,
  ) async {
    final grupoId = lancamento.grupoId!;
    final snapshot = await _colecao.where('grupoId', isEqualTo: grupoId).get();
    const limiteSeguro = 450;

    for (
      var inicio = 0;
      inicio < snapshot.docs.length;
      inicio += limiteSeguro
    ) {
      final fim = (inicio + limiteSeguro < snapshot.docs.length)
          ? inicio + limiteSeguro
          : snapshot.docs.length;
      final lote = _firestore.batch();

      for (final documento in snapshot.docs.sublist(inicio, fim)) {
        lote.update(documento.reference, {'prioridade': prioridade.name});
      }

      await lote.commit();
    }

    if (lancamento.forma == FormaLancamento.fixo &&
        lancamento.recorrenciaId != null) {
      await _recorrencias.doc(lancamento.recorrenciaId).update({
        'prioridade': prioridade.name,
      });
    }
  }

  Future<void> excluir(
    Lancamento lancamento, {
    EscopoExclusao escopo = EscopoExclusao.somenteEsta,
  }) async {
    if (!lancamento.fazParteDeSerie || escopo == EscopoExclusao.somenteEsta) {
      if (lancamento.forma == FormaLancamento.fixo) {
        await _colecao.doc(lancamento.id).update({'excluido': true});
      } else {
        await _colecao.doc(lancamento.id).delete();
      }
      return;
    }

    if (lancamento.forma == FormaLancamento.parcelado ||
        lancamento.forma == FormaLancamento.entradaParcelas) {
      await _excluirParcelas(lancamento, escopo);
      return;
    }

    await _excluirContaFixa(lancamento, escopo);
  }

  Future<void> _excluirParcelas(
    Lancamento lancamento,
    EscopoExclusao escopo,
  ) async {
    final grupoId = lancamento.grupoId;
    if (grupoId == null) {
      await _colecao.doc(lancamento.id).delete();
      return;
    }

    final snapshot = await _colecao.where('grupoId', isEqualTo: grupoId).get();
    final documentos = snapshot.docs.where((documento) {
      if (escopo == EscopoExclusao.todas) {
        return true;
      }

      final parcelaAtual =
          (documento.data()['parcelaAtual'] as num?)?.toInt() ?? 1;
      return parcelaAtual >= lancamento.parcelaAtual;
    });

    await _excluirDocumentos(documentos.map((item) => item.reference).toList());
  }

  Future<void> _excluirContaFixa(
    Lancamento lancamento,
    EscopoExclusao escopo,
  ) async {
    final recorrenciaId = lancamento.recorrenciaId;
    if (recorrenciaId == null) {
      await _colecao.doc(lancamento.id).update({'excluido': true});
      return;
    }

    final snapshot = await _colecao
        .where('recorrenciaId', isEqualTo: recorrenciaId)
        .get();
    final documentos = snapshot.docs.where((documento) {
      if (escopo == EscopoExclusao.todas) {
        return true;
      }

      final vencimento = (documento.data()['vencimento'] as Timestamp).toDate();
      return !vencimento.isBefore(lancamento.vencimento);
    }).toList();

    final lote = _firestore.batch();
    for (final documento in documentos) {
      lote.delete(documento.reference);
    }

    final recorrencia = _recorrencias.doc(recorrenciaId);
    if (escopo == EscopoExclusao.todas) {
      lote.delete(recorrencia);
    } else {
      lote.update(recorrencia, {
        'ativa': false,
        'encerradaEm': Timestamp.fromDate(lancamento.vencimento),
      });
    }

    await lote.commit();
  }

  Future<void> _excluirDocumentos(
    List<DocumentReference<Map<String, dynamic>>> documentos,
  ) async {
    const limiteSeguro = 450;

    for (var inicio = 0; inicio < documentos.length; inicio += limiteSeguro) {
      final fim = (inicio + limiteSeguro < documentos.length)
          ? inicio + limiteSeguro
          : documentos.length;
      final lote = _firestore.batch();

      for (final documento in documentos.sublist(inicio, fim)) {
        lote.delete(documento);
      }

      await lote.commit();
    }
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
}
