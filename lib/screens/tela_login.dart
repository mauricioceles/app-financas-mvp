import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

Future<void>? _inicializacaoGoogle;

class TelaLogin extends StatefulWidget {
  const TelaLogin({super.key, required this.onContinuarSemConta});

  final Future<void> Function() onContinuarSemConta;

  @override
  State<TelaLogin> createState() => _TelaLoginState();
}

class _TelaLoginState extends State<TelaLogin> {
  bool _carregando = false;

  Future<void> _entrarComGoogle() async {
    setState(() => _carregando = true);

    try {
      if (kIsWeb) {
        await _entrarComGoogleNaWeb();
      } else {
        await _entrarComGoogleNoAndroid();
      }
    } on GoogleSignInException catch (erro) {
      if (erro.code != GoogleSignInExceptionCode.canceled) {
        _mostrarMensagem(_mensagemDoErroGoogle(erro));
      }
    } on FirebaseAuthException catch (erro) {
      if (erro.code != 'popup-closed-by-user' &&
          erro.code != 'cancelled-popup-request') {
        _mostrarMensagem(_mensagemDoErro(erro.code));
      }
    } catch (erro) {
      _mostrarMensagem('Não foi possível entrar com o Google: $erro');
    } finally {
      if (mounted) {
        setState(() => _carregando = false);
      }
    }
  }

  Future<void> _entrarComGoogleNaWeb() async {
    final autenticacao = FirebaseAuth.instance;
    final provedor = GoogleAuthProvider();

    await _autenticarPreservandoContaTemporaria(
      entrar: () => autenticacao.signInWithPopup(provedor),
      vincular: (usuario) => usuario.linkWithPopup(provedor),
    );
  }

  Future<void> _entrarComGoogleNoAndroid() async {
    _inicializacaoGoogle ??= GoogleSignIn.instance.initialize();
    await _inicializacaoGoogle;

    final contaGoogle = await GoogleSignIn.instance.authenticate();
    final autenticacaoGoogle = contaGoogle.authentication;

    if (autenticacaoGoogle.idToken == null) {
      throw StateError('O Google não forneceu o identificador de acesso.');
    }

    final credencial = GoogleAuthProvider.credential(
      idToken: autenticacaoGoogle.idToken,
    );

    await _autenticarPreservandoContaTemporaria(
      entrar: () => FirebaseAuth.instance.signInWithCredential(credencial),
      vincular: (usuario) => usuario.linkWithCredential(credencial),
    );
  }

  Future<void> _autenticarPreservandoContaTemporaria({
    required Future<UserCredential> Function() entrar,
    required Future<UserCredential> Function(User usuario) vincular,
  }) async {
    final autenticacao = FirebaseAuth.instance;
    final usuarioAtual = autenticacao.currentUser;

    if (usuarioAtual?.isAnonymous != true) {
      await entrar();
      return;
    }

    try {
      await vincular(usuarioAtual!);
    } on FirebaseAuthException catch (erro) {
      if (!_credencialJaPertenceAOutraConta(erro.code)) {
        rethrow;
      }

      await autenticacao.signOut();
      await entrar();
    }
  }

  bool _credencialJaPertenceAOutraConta(String codigo) {
    return codigo == 'credential-already-in-use' ||
        codigo == 'email-already-in-use' ||
        codigo == 'account-exists-with-different-credential';
  }

  String _mensagemDoErroGoogle(GoogleSignInException erro) {
    switch (erro.code) {
      case GoogleSignInExceptionCode.clientConfigurationError:
      case GoogleSignInExceptionCode.providerConfigurationError:
        return 'O login Google ainda não está configurado corretamente no Android.';
      case GoogleSignInExceptionCode.interrupted:
        return 'O login foi interrompido. Tente novamente.';
      default:
        return 'Não foi possível abrir o login Google.';
    }
  }

  String _mensagemDoErro(String codigo) {
    switch (codigo) {
      case 'popup-blocked':
        return 'O navegador bloqueou a janela de login. Permita pop-ups e tente novamente.';
      case 'network-request-failed':
        return 'Falha de conexão. Verifique a internet e tente novamente.';
      case 'operation-not-allowed':
        return 'O login Google ainda não está habilitado no Firebase.';
      default:
        return 'Não foi possível entrar com o Google ($codigo).';
    }
  }

  void _mostrarMensagem(String mensagem) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensagem)));
  }

  @override
  Widget build(BuildContext context) {
    final usuarioTemporario =
        FirebaseAuth.instance.currentUser?.isAnonymous == true;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.account_balance_wallet,
                        size: 64,
                        color: Colors.teal,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Meu Mês Finanças',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        usuarioTemporario
                            ? 'Conecte sua conta Google para preservar os lançamentos atuais e acessá-los em outros dispositivos.'
                            : 'Entre para acessar seus lançamentos financeiros.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _carregando ? null : _entrarComGoogle,
                          icon: _carregando
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.login),
                          label: const Text('Continuar com o Google'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _carregando
                            ? null
                            : widget.onContinuarSemConta,
                        child: const Text('Continuar temporariamente'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
