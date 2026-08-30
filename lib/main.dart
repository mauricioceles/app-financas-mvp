import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/tela_login.dart';
import 'screens/tela_principal.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (FirebaseAuth.instance.currentUser == null) {
    await FirebaseAuth.instance.signInAnonymously();
  }

  runApp(const AppFinancas());
}

class AppFinancas extends StatelessWidget {
  const AppFinancas({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Meu Mês',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const _PortaoDeAutenticacao(),
    );
  }
}

class _PortaoDeAutenticacao extends StatefulWidget {
  const _PortaoDeAutenticacao();

  @override
  State<_PortaoDeAutenticacao> createState() => _PortaoDeAutenticacaoState();
}

class _PortaoDeAutenticacaoState extends State<_PortaoDeAutenticacao> {
  bool _continuarSemConta = false;

  Future<void> _usarContaTemporaria() async {
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }

    if (mounted) {
      setState(() => _continuarSemConta = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final usuario = snapshot.data;

        if (usuario != null && (!usuario.isAnonymous || _continuarSemConta)) {
          return const TelaPrincipal();
        }

        return TelaLogin(onContinuarSemConta: _usarContaTemporaria);
      },
    );
  }
}
