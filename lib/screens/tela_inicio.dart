import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/lancamento.dart';
import 'tela_principal.dart';

class TelaInicio extends StatelessWidget {
  const TelaInicio({super.key});

  Future<void> _sair(BuildContext context) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sair da conta?'),
        content: const Text(
          'Você poderá entrar novamente usando a mesma conta Google.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );

    if (confirmou == true) {
      await FirebaseAuth.instance.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2FAF8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2FAF8),
        title: const Text('Meu Mês'),
        actions: [
          IconButton(
            tooltip: 'Sair da conta',
            onPressed: () => _sair(context),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const CircleAvatar(
                    radius: 34,
                    backgroundColor: Color(0xFF00897B),
                    child: Text(
                      'M',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Escolha sua área',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Mantenha sua vida pessoal e profissional organizadas '
                    'em espaços separados.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 32),
                  _BotaoArea(
                    chave: const Key('botao-pessoal'),
                    titulo: 'PESSOAL',
                    descricao: 'Despesas e receitas do seu dia a dia',
                    icone: Icons.person_outline_rounded,
                    cor: const Color(0xFF00897B),
                    onTap: () => Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const TelaPessoal(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _BotaoArea(
                    chave: const Key('botao-profissional'),
                    titulo: 'PROFISSIONAL',
                    descricao: 'Gestão das suas atividades profissionais',
                    icone: Icons.work_outline_rounded,
                    cor: const Color(0xFF315E8A),
                    onTap: () => Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const TelaProfissional(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TelaPessoal extends StatelessWidget {
  const TelaPessoal({super.key});

  void _abrirLancamentos(BuildContext context, TipoLancamento tipo) {
    Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (context) => TelaPrincipal(tipo: tipo)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pessoal')),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'O que deseja acompanhar?',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 32),
                  _BotaoArea(
                    chave: const Key('botao-despesa'),
                    titulo: 'DESPESA',
                    descricao: 'Contas pagas, pendentes e atrasadas',
                    icone: Icons.arrow_downward_rounded,
                    cor: const Color(0xFFC65454),
                    onTap: () =>
                        _abrirLancamentos(context, TipoLancamento.despesa),
                  ),
                  const SizedBox(height: 16),
                  _BotaoArea(
                    chave: const Key('botao-receita'),
                    titulo: 'RECEITA',
                    descricao: 'Valores recebidos e ainda a receber',
                    icone: Icons.arrow_upward_rounded,
                    cor: const Color(0xFF198754),
                    onTap: () =>
                        _abrirLancamentos(context, TipoLancamento.receita),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TelaProfissional extends StatelessWidget {
  const TelaProfissional({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profissional')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.construction_rounded,
                  size: 64,
                  color: Color(0xFF315E8A),
                ),
                const SizedBox(height: 20),
                Text(
                  'Área profissional em construção',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Este espaço receberá as funcionalidades profissionais '
                  'sem misturá-las com suas finanças pessoais.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BotaoArea extends StatelessWidget {
  const _BotaoArea({
    required this.chave,
    required this.titulo,
    required this.descricao,
    required this.icone,
    required this.cor,
    required this.onTap,
  });

  final Key chave;
  final String titulo;
  final String descricao;
  final IconData icone;
  final Color cor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: chave,
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: cor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icone, color: cor, size: 30),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(color: cor, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(descricao),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: cor),
            ],
          ),
        ),
      ),
    );
  }
}
