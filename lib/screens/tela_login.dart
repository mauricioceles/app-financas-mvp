import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class TelaLogin extends StatefulWidget {
  const TelaLogin({super.key, required this.onContinuarSemConta});

  final Future<void> Function() onContinuarSemConta;

  @override
  State<TelaLogin> createState() => _TelaLoginState();
}

class _TelaLoginState extends State<TelaLogin> {
  bool _carregando = false;

  Future<void> _entrarComGoogle() async {
    if (!kIsWeb) {
      _mostrarMensagem(
        'O login Google no Android será configurado na próxima etapa.',
      );
      return;
    }

    setState(() => _carregando = true);

    final autenticacao = FirebaseAuth.instance;
    final provedor = GoogleAuthProvider();

    try {
      final usuarioAtual = autenticacao.currentUser;

      if (usuarioAtual?.isAnonymous == true) {
        try {
          await usuarioAtual!.linkWithPopup(provedor);
        } on FirebaseAuthException catch (erro) {
          if (erro.code == 'credential-already-in-use' ||
              erro.code == 'email-already-in-use') {
            await autenticacao.signOut();
            await autenticacao.signInWithPopup(provedor);
          } else {
            rethrow;
          }
        }
      } else {
        await autenticacao.signInWithPopup(provedor);
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
