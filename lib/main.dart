import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'firebase_options.dart';
import 'screens/tela_inicio.dart';
import 'screens/tela_login.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
      home: const _Inicializador(),
    );
  }
}

class _Inicializador extends StatefulWidget {
  const _Inicializador();

  @override
  State<_Inicializador> createState() => _InicializadorState();
}

class _InicializadorState extends State<_Inicializador> {
  late Future<void> _inicializacao;

  @override
  void initState() {
    super.initState();
    _inicializacao = _inicializar();
  }

  Future<void> _inicializar() async {
    await Future.wait<dynamic>([
      initializeDateFormatting('pt_BR'),
      Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform),
    ]);
  }

  void _tentarNovamente() {
    setState(() => _inicializacao = _inicializar());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _inicializacao,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: const Color(0xFFF2FAF8),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.cloud_off_rounded,
                      size: 52,
                      color: Colors.teal,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Nao foi possivel iniciar o aplicativo.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Verifique sua conexao e tente novamente.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _tentarNovamente,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (snapshot.connectionState != ConnectionState.done) {
          return const _TelaDeCarregamento();
        }

        return const _PortaoDeAutenticacao();
      },
    );
  }
}

class _TelaDeCarregamento extends StatelessWidget {
  const _TelaDeCarregamento();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFF2FAF8),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 38,
              backgroundColor: Color(0xFF00897B),
              child: Text(
                'M',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Meu M\u00EAs',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 24),
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
          ],
        ),
      ),
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
          return const TelaInicio();
        }

        return TelaLogin(onContinuarSemConta: _usarContaTemporaria);
      },
    );
  }
}
