import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:assets_audio_player/assets_audio_player.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(MyApp());
}

class WaterConsumptionEntry {
  final DateTime dateTime;
  final double amount;

  WaterConsumptionEntry(this.dateTime, this.amount);

  WaterConsumptionEntry.fromJson(Map<String, dynamic> json)
      : dateTime = DateTime.parse(json['dateTime']),
        amount = json['amount'];

  Map<String, dynamic> toJson() => {
        'dateTime': dateTime.toIso8601String(),
        'amount': amount,
      };
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lembrete de Água',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _interval = 7200; 
  double _amountOfWater = 250.0; // quant de agua (ml)
  bool _isDrinking = false;
  TimeOfDay _selectedTime = TimeOfDay.now();

  Timer? _timer;
  late AssetsAudioPlayer _audioPlayer;
  String _soundPath = 'assets/notificacao.mp3';

  List<WaterConsumptionEntry> waterConsumptionHistory = [];

  @override
  void initState() {
    super.initState();
    _loadWaterConsumptionHistory();
    _audioPlayer = AssetsAudioPlayer();
  }

  Future<void> _loadWaterConsumptionHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getStringList('waterConsumptionHistory') ?? [];

    setState(() {
      waterConsumptionHistory =
          historyJson.map((e) => WaterConsumptionEntry.fromJson(jsonDecode(e))).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(60.0),
        child: CustomAppBar(),
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
              'Quantidade de Água: ${_amountOfWater.toStringAsFixed(0)} ml',
              style: TextStyle(fontSize: 16),
            ),
            Slider(
              value: _amountOfWater,
              min: 100.0,
              max: 1000.0,
              onChanged: (value) {
                setState(() {
                  _amountOfWater = value;
                });
              },
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _toggleReminder,
              child: Text(_isDrinking ? 'Parar lembrete' : 'Começar Lembrete'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _selectTime,
              child: Text('Selecionar Horário: ${_selectedTime.format(context)}'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => HistoryPage(waterConsumptionHistory),
                  ),
                );
              },
              child: Text('Histórico'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _recordWaterConsumption(double amount) async {
    final entry = WaterConsumptionEntry(DateTime.now(), amount);
    setState(() {
      waterConsumptionHistory.add(entry);
    });

    // Salvar no shared_preferences
    final prefs = await SharedPreferences.getInstance();
    final historyJson = waterConsumptionHistory.map((e) => jsonEncode(e)).toList();
    await prefs.setStringList('waterConsumptionHistory', historyJson);
  }

  void _toggleReminder() {
    if (_isDrinking) {
      // Parar lembrete
      setState(() {
        _isDrinking = false;
      });
      _timer?.cancel(); // Verifica se _timer não é nulo antes de chamar cancel()
    } else {
      // Iniciar lembrete
      setState(() {
        _isDrinking = true;
      });
      _startReminder();
    }
  }

  void _startReminder() {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      DateTime now = DateTime.now();
      DateTime selectedDateTime =
          DateTime(now.year, now.month, now.day, _selectedTime.hour, _selectedTime.minute);

      if (now.isAfter(selectedDateTime)) {
        _showReminder();
        _playNotificationSound(); // Adiciona a reprodução do som
        _recordWaterConsumption(_amountOfWater); // Registra o consumo de água
        timer.cancel(); // Cancela o timer após exibir a mensagem
        setState(() {
          _isDrinking = false;
        });
      }
    });
  }

  void _showReminder() {
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

  void _playNotificationSound() {
    _audioPlayer.open(Audio(_soundPath));
    _audioPlayer.play();
  }

  void _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );

    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioPlayer.dispose(); // Permite que o audio de notificação funcione
    super.dispose();
  }
}

class CustomAppBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.0),
      color: Colors.blue,
      child: Row(
        children: [
          Image.asset('assets/water_icon.png', width: 36, height: 36), // Ajustar o tamanho do icone
          SizedBox(width: 16), // Para adicionar um espaço entre o titulo e o icone
          Text('Lembrete de Água', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class HistoryPage extends StatelessWidget {
  final List<WaterConsumptionEntry> waterConsumptionHistory;

  HistoryPage(this.waterConsumptionHistory);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Histórico de Consumo'),
      ),
      body: ListView.builder(
        itemCount: waterConsumptionHistory.length,
        itemBuilder: (context, index) {
          final entry = waterConsumptionHistory[index];
          return ListTile(
            title: Text('Data: ${entry.dateTime.toString()}'),
            subtitle: Text('Quantidade: ${entry.amount.toString()} ml'),
          );
        },
      ),
    );
  }
}
