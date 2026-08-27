import 'package:flutter/material.dart';

void main() {
  runApp(const AppFinancas());
}

class AppFinancas extends StatelessWidget {
  const AppFinancas({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Meu Mês',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const TelaPrincipal(),
    );
  }
}

// Transformamos em StatefulWidget para o app ter "memória"
class TelaPrincipal extends StatefulWidget {
  const TelaPrincipal({super.key});

  @override
  State<TelaPrincipal> createState() => _TelaPrincipalState();
}

class _TelaPrincipalState extends State<TelaPrincipal> {
  // Nossa memória temporária: uma lista que guarda as contas recebidas
  List<String> receitas = [];

  // Variável para guardar o texto que o usuário digitar
  final TextEditingController _descricaoController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: const Text('Controle Financeiro'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.arrow_upward), text: 'Contas a Receber'),
              Tab(icon: Icon(Icons.arrow_downward), text: 'Contas a Pagar'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Agora a lista mostra os itens reais da memória
            ListView.builder(
              itemCount: receitas.length,
              itemBuilder: (context, index) {
                return ListTile(
                  leading: const Icon(Icons.attach_money, color: Colors.green),
                  title: Text(receitas[index]), // Mostra o texto salvo
                  trailing: const Text('R\$ 0,00', style: TextStyle(color: Colors.green)),
                );
              },
            ),
            // A lista de gastos continua como estava para referência visual
            ListView(
              children: const [
                ListTile(
                  leading: Icon(Icons.money_off, color: Colors.red),
                  title: Text('Aluguel'),
                  trailing: Text('R\$ 1.500,00', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            showModalBottomSheet(
              context: context,
              builder: (BuildContext context) {
                return Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Cadastrar Receita',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _descricaoController, // Conecta o campo à memória
                        decoration: const InputDecoration(
                          labelText: 'Descrição da Receita',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          // O "setState" avisa ao Flutter que a memória mudou
                          // e manda a tela se redesenhar com o novo item
                          setState(() {
                            receitas.add(_descricaoController.text);
                          });
                          _descricaoController.clear(); // Limpa o campo
                          Navigator.pop(context); // Fecha a aba
                        },
                        child: const Text('Salvar'),
                      ),
                    ],
                  ),
                );
              },
            );
          },
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}