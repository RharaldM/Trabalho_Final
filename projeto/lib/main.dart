import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:assets_audio_player/assets_audio_player.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
        primarySwatch: Colors.blue,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.blue,
        ),
      ),
      home: MinhaPaginaInicial(),
    );
  }
}

class MinhaPaginaInicial extends StatefulWidget {
  @override
  _MinhaPaginaInicialEstado createState() => _MinhaPaginaInicialEstado();
}

class _MinhaPaginaInicialEstado extends State<MinhaPaginaInicial> {
  double _quantidadeDeAgua = 250.0;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(60.0),
        child: MinhaAppBar(),
      ),
      body: Center(
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
              child: Slider(
                value: _quantidadeDeAgua,
                min: 100.0,
                max: 1000.0,
                onChanged: (value) {
                  setState(() {
                    _quantidadeDeAgua = value;
                  });
                },
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _alternarLembrete,
              child: Text(_estaBebendo ? 'Parar lembrete' : 'Começar Lembrete'),
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
              child: Text('Histórico'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                _editarCronograma(context);
              },
              child: Text('Cronograma'),
            ),
          ],
        ),
      ),
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

  void _reproduzirSomNotificacao() {
    _reprodutorAudio.open(Audio(_caminhoSom));
    _reprodutorAudio.play();
  }

  @override
  void dispose() {
    _temporizador?.cancel();
    _reprodutorAudio.dispose();
    super.dispose();
  }

  Timer? _temporizador;

  void _editarCronograma(BuildContext context) async {
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

class MinhaAppBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.0),
      color: Colors.blue,
      child: Row(
        children: [
          Image.asset('assets/water_icon.png', width: 36, height: 36),
          SizedBox(width: 16),
          Text('Lembrete de Água', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class MinhaPaginaHistorico extends StatelessWidget {
  final List<EntradaConsumoAgua> historicoConsumoAgua;

  MinhaPaginaHistorico(this.historicoConsumoAgua);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Histórico de Consumo'),
      ),
      body: ListView.builder(
        itemCount: historicoConsumoAgua.length,
        itemBuilder: (context, index) {
          final entrada = historicoConsumoAgua[index];
          return ListTile(
            title: Text('Data: ${entrada.dataHora.toString()}'),
            subtitle: Text('Quantidade: ${entrada.quantidade.toStringAsFixed(0)} ml'),
          );
        },
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
      body: ListView.builder(
        itemCount: widget.horariosAgendados.length,
        itemBuilder: (context, index) {
          final horarioAgendado = widget.horariosAgendados[index];
          return ListTile(
            title: Text(
              'Horário: ${horarioAgendado.horario.format(context)}',
              style: TextStyle(fontSize: 16),
            ),
            trailing: Switch(
              value: horarioAgendado.estaAtivo,
              onChanged: (value) {
                setState(() {
                  widget.horariosAgendados[index].estaAtivo = value;
                });
              },
            ),
          );
        },
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
