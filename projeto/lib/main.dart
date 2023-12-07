import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:assets_audio_player/assets_audio_player.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(MinhaApp());
}

class EntradaConsumoAgua {
  final DateTime dataHora;
  final double quantidade;

  EntradaConsumoAgua(this.dataHora, this.quantidade);

  EntradaConsumoAgua.fromJson(Map<String, dynamic> json)
      : dataHora = DateTime.parse(json['dataHora']),
        quantidade = json['quantidade'];

  Map<String, dynamic> toJson() => {
        'dataHora': dataHora.toIso8601String(),
        'quantidade': quantidade,
      };
}

class HorarioAgendado {
  final TimeOfDay horario;
  bool estaAtivo;

  HorarioAgendado(this.horario, this.estaAtivo);

  Map<String, dynamic> toJson() => {
        'hora': horario.hour,
        'minuto': horario.minute,
        'estaAtivo': estaAtivo,
      };

  factory HorarioAgendado.fromJson(Map<String, dynamic> json) {
    return HorarioAgendado(
      TimeOfDay(hour: json['hora'], minute: json['minuto']),
      json['estaAtivo'],
    );
  }
}

class MinhaApp extends StatelessWidget {
  const MinhaApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lembrete de Água',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        hintColor: Colors.orange,
        appBarTheme: AppBarTheme(
          backgroundColor: const Color.fromRGBO(0, 150, 136, 1),
          shadowColor: Colors.black,
          elevation: 4,
        ),
      ),
      home: MinhaPaginaInicial(),
    );
  }
}

class MinhaAppBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.0),
      color: Color.fromARGB(255, 62, 172, 144), // Cor da AppBar
      child: Row(
        children: [
          Image.asset('assets/water_icon.png', width: 36, height: 36),
          SizedBox(width: 16),
          Text(
            'Lembrete de Água',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}


class MinhaPaginaInicial extends StatefulWidget {
  @override
  _MinhaPaginaInicialEstado createState() => _MinhaPaginaInicialEstado();
}

class _MinhaPaginaInicialEstado extends State<MinhaPaginaInicial> {
  late Timer _temporizador;
  IconData _iconeCalculadora = Icons.calculate;
  double _quantidadeDeAgua = 250.0;
  double calcularQuantidadeTotal() {
  double quantidadeTotal = 0.0;

  for (var entrada in historicoConsumoAgua) {
    quantidadeTotal += entrada.quantidade;
  }

  return quantidadeTotal;
}
  double _resultadoCalculadora = 0.0;
  bool _estaBebendo = false;
  late AssetsAudioPlayer _reprodutorAudio;
  String _caminhoSom = 'assets/notificacao.mp3';
  List<EntradaConsumoAgua> historicoConsumoAgua = [];
  List<HorarioAgendado> horariosAgendados = [
    HorarioAgendado(TimeOfDay(hour: 8, minute: 0), true),
    HorarioAgendado(TimeOfDay(hour: 12, minute: 0), true),
    HorarioAgendado(TimeOfDay(hour: 16, minute: 0), true),
    HorarioAgendado(TimeOfDay(hour: 20, minute: 0), true),
  ];

  @override
  void initState() {
    super.initState();
    _carregarHistoricoConsumoAgua();
    _reprodutorAudio = AssetsAudioPlayer();
  }

  Future<void> _carregarHistoricoConsumoAgua() async {
    final prefs = await SharedPreferences.getInstance();
    final historicoJson = prefs.getStringList('historicoConsumoAgua') ?? [];

    setState(() {
      historicoConsumoAgua =
          historicoJson.map((e) => EntradaConsumoAgua.fromJson(jsonDecode(e))).toList();
    });
  }
    Future<void> _exibirCalculadora() async {
    double resultado = await showDialog(
      context: context,
      builder: (BuildContext context) {
        double peso = 0.0;

        return AlertDialog(
          title: Text('Calculadora de Água'),
          content: Column(
            children: [
              Text('Informe o seu peso em quilogramas:'),
              TextField(
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  peso = double.tryParse(value) ?? 0.0;
                },
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, peso * 35);
              },
              child: Text('Calcular'),
            ),
          ],
        );
      },
    );
    if (resultado != null) {
      setState(() {
        _quantidadeDeAgua = resultado;
      });
    }
  }

@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: PreferredSize(
      preferredSize: Size.fromHeight(60.0),
      child: MinhaAppBar(),
    ),
    body: Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.teal, Colors.white],
        ),
      ),
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  'Beber Água a cada 2 horas',
                  style: TextStyle(fontSize: 18),
                ),
                SizedBox(height: 20),
                Text(
                  'Quantidade de Água: ${_quantidadeDeAgua.toStringAsFixed(0)} ml',
                  style: TextStyle(fontSize: 16),
                ),
                Container(
                  width: 300,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.5),
                        spreadRadius: 2,
                        blurRadius: 5,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Slider(
                    value: _quantidadeDeAgua,
                    min: 100.0,
                    max: 1000.0,
                    onChanged: (value) {
                      setState(() {
                        _quantidadeDeAgua = value;
                      });
                    },
                    activeColor: Colors.blue,
                    inactiveColor: Colors.grey,
                  ),
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MinhaPaginaHistorico(historicoConsumoAgua),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    primary: const Color.fromRGBO(0, 150, 136, 1),
                    onPrimary: Colors.white,
                    shadowColor: Colors.blueAccent,
                  ),
                  child: Text('Histórico'),
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    _editarCronograma(context);
                  },
                  style: ElevatedButton.styleFrom(
                    primary: Colors.teal,
                    onPrimary: Colors.white,
                    shadowColor: Colors.blueAccent,
                  ),
                  child: Text('Cronograma'),
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _alternarLembrete,
                  style: ElevatedButton.styleFrom(
                    primary: const Color.fromRGBO(0, 150, 136, 1),
                    onPrimary: Colors.white,
                    shadowColor: Colors.blueAccent,
                  ),
                  child: Text(_estaBebendo ? 'Parar lembrete' : 'Começar Lembrete'),
                ),
              ],
            ),
          ),
          Positioned(
            left: 16.0,
            bottom: 16.0,
            child: IconButton(
              onPressed: () {
                _mostrarCalculadora(context);
              },
              icon: Icon(Icons.calculate, size: 36.0), 
              color: Colors.teal,
            ),
          ),
        ],
      ),
    ),
    floatingActionButtonLocation: FloatingActionButtonLocation.startDocked,
  );
}



void _mostrarCalculadora(BuildContext context) {
  double peso = 0.0;

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('Calculadora de Água'),
            content: Container(
              width: 300.0, 
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Informe o seu peso em quilogramas:'),
                  TextField(
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (value) {
                      setState(() {
                        peso = double.tryParse(value) ?? 0.0;
                      });
                    },
                  ),
                ],
              ),
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  double resultado = peso * 35;
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: Text('Resultado'),
                        content: Text('Você deve beber ${resultado.toStringAsFixed(0)} ml de água por dia.'),
                        actions: <Widget>[
                          ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            child: Text('Fechar'),
                          ),
                        ],
                      );
                    },
                  );
                },
                child: Text('Calcular'),
              ),
              SizedBox(width: 8.0), 
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(); 
                },
                child: Text('Fechar'),
              ),
            ],
          );
        },
      );
    },
  );
}



  Future<void> _gravarConsumoAgua(double quantidade) async {
    final entrada = EntradaConsumoAgua(DateTime.now(), quantidade);
    setState(() {
      historicoConsumoAgua.add(entrada);
    });

    final prefs = await SharedPreferences.getInstance();
    final historicoJson = historicoConsumoAgua.map((e) => jsonEncode(e)).toList();
    await prefs.setStringList('historicoConsumoAgua', historicoJson);
  }

  void _alternarLembrete() {
    if (_estaBebendo) {
      setState(() {
        _estaBebendo = false;
      });
      _temporizador?.cancel();
    } else {
      setState(() {
        _estaBebendo = true;
      });
      _iniciarLembrete();
    }
  }

  void _iniciarLembrete() {
    _temporizador = Timer.periodic(Duration(seconds: 1), (temporizador) {
      DateTime agora = DateTime.now();

      for (var horarioAgendado in horariosAgendados) {
        DateTime horarioSelecionado = DateTime(
          agora.year,
          agora.month,
          agora.day,
          horarioAgendado.horario.hour,
          horarioAgendado.horario.minute,
        );

        if (agora.isAfter(horarioSelecionado) && horarioAgendado.estaAtivo) {
          _mostrarLembrete();
          _reproduzirSomNotificacao();
          _gravarConsumoAgua(_quantidadeDeAgua);
          temporizador.cancel();
          setState(() {
            _estaBebendo = false;
          });
        }
      }
    });
  }

  void _reproduzirSomNotificacao() {
    _reprodutorAudio.open(Audio(_caminhoSom));
    _reprodutorAudio.play();
  }

  void _mostrarLembrete() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Hora de Beber Água!'),
          content: Text('Não se esqueça de se manter hidratado.'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _reproduzirSom() {
    _reprodutorAudio.open(
      Audio('$_caminhoSom'),
      autoStart: true,
      showNotification: true,
    );
  }

  Future<void> _editarCronograma(BuildContext context) async {
    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MinhaPaginaCronograma(horariosAgendados),
      ),
    );

    if (resultado != null && resultado is List<HorarioAgendado>) {
      setState(() {
        horariosAgendados = resultado;
      });
    }
  }
}

class MinhaPaginaHistorico extends StatelessWidget {
  final List<EntradaConsumoAgua> historicoConsumoAgua;

  MinhaPaginaHistorico(this.historicoConsumoAgua);

  @override
  Widget build(BuildContext context) {
    final quantidadeTotal = calcularQuantidadeTotal();

    return Scaffold(
      appBar: AppBar(
        title: Text('Histórico de Consumo'),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.teal, Colors.white],
          ),
        ),
        child: Column(
          children: [
            _QuantidadeTotalWidget(quantidadeTotal), 
            Expanded(
              child: ListView.builder(
                itemCount: historicoConsumoAgua.length,
                itemBuilder: (context, index) {
                  final entrada = historicoConsumoAgua[index];
                  return ListTile(
                    title: Text('Data: ${entrada.dataHora.toString()}'),
                    subtitle: Text('Quantidade: ${entrada.quantidade.toStringAsFixed(0)} ml'),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  double calcularQuantidadeTotal() {
    double quantidadeTotal = 0.0;

    for (var entrada in historicoConsumoAgua) {
      quantidadeTotal += entrada.quantidade;
    }

    return quantidadeTotal;
  }
}

class _QuantidadeTotalWidget extends StatelessWidget {
  final double quantidadeTotal;

  _QuantidadeTotalWidget(this.quantidadeTotal);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Text(
        'Quantidade Total: ${quantidadeTotal.toStringAsFixed(0)} ml',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class MinhaPaginaCronograma extends StatefulWidget {
  final List<HorarioAgendado> horariosAgendados;

  MinhaPaginaCronograma(this.horariosAgendados);

  @override
  _MinhaPaginaCronogramaEstado createState() => _MinhaPaginaCronogramaEstado();
}

class _MinhaPaginaCronogramaEstado extends State<MinhaPaginaCronograma> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Cronograma'),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.teal, Colors.white],
          ),
        ),
        child: ListView.builder(
          itemCount: widget.horariosAgendados.length,
          itemBuilder: (context, index) {
                    final horarioAgendado = widget.horariosAgendados[index];
            return Container(
              margin: EdgeInsets.all(8.0),
              padding: EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                border: Border.all(
                  color: const Color.fromRGBO(0, 150, 136, 1),
                  width: 2.0,
                ),
                borderRadius: BorderRadius.circular(8.0),
                color: Colors.white,
              ),
              child: ListTile(
                title: Text(
                  'Horário: ${horarioAgendado.horario.format(context)}',
                  style: TextStyle(fontSize: 16, color: Colors.black),
                ),
                trailing: Switch(
                  value: horarioAgendado.estaAtivo,
                  onChanged: (value) {
                    setState(() {
                      widget.horariosAgendados[index].estaAtivo = value;
                    });
                  },
                  activeTrackColor: const Color.fromRGBO(0, 150, 136, 1),
                  activeColor: Colors.white,
                ),
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final resultado = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MinhaPaginaAdicionarCronograma(),
            ),
          );

          if (resultado != null && resultado is HorarioAgendado) {
            setState(() {
              widget.horariosAgendados.add(resultado);
            });
          }
        },
        child: Icon(Icons.add),
        backgroundColor: const Color.fromRGBO(0, 150, 136, 1),
      ),
    );
  }
}

class MinhaPaginaAdicionarCronograma extends StatefulWidget {
  @override
  _MinhaPaginaAdicionarCronogramaEstado createState() => _MinhaPaginaAdicionarCronogramaEstado();
}

class _MinhaPaginaAdicionarCronogramaEstado extends State<MinhaPaginaAdicionarCronograma> {
  late TimeOfDay _horarioSelecionado;

  @override
  void initState() {
    super.initState();
    _horarioSelecionado = TimeOfDay.now();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Adicionar Horário'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            SizedBox(height: 20),
            Text(
              'Selecione o Horário',
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final horarioEscolhido = await showTimePicker(
                  context: context,
                  initialTime: _horarioSelecionado,
                );

                if (horarioEscolhido != null) {
                  setState(() {
                    _horarioSelecionado = horarioEscolhido;
                  });
                }
              },
              child: Text('Horário: ${_horarioSelecionado.format(context)}'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  HorarioAgendado(_horarioSelecionado, true),
                );
              },
              child: Text('Adicionar'),
            ),
          ],
        ),
      ),
    );
  }
} 
