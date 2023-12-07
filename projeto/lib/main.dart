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

class ScheduledTime {
  final TimeOfDay time;
  bool isEnabled;

  ScheduledTime(this.time, this.isEnabled);

  Map<String, dynamic> toJson() => {
        'hour': time.hour,
        'minute': time.minute,
        'isEnabled': isEnabled,
      };

  factory ScheduledTime.fromJson(Map<String, dynamic> json) {
    return ScheduledTime(
      TimeOfDay(hour: json['hour'], minute: json['minute']),
      json['isEnabled'],
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

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
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  double _amountOfWater = 250.0;
  bool _isDrinking = false;
  late AssetsAudioPlayer _audioPlayer;
  String _soundPath = 'assets/notificacao.mp3';
  List<WaterConsumptionEntry> waterConsumptionHistory = [];
  List<ScheduledTime> scheduledTimes = [
    ScheduledTime(TimeOfDay(hour: 8, minute: 0), true),
    ScheduledTime(TimeOfDay(hour: 12, minute: 0), true),
    ScheduledTime(TimeOfDay(hour: 16, minute: 0), true),
    ScheduledTime(TimeOfDay(hour: 20, minute: 0), true),
  ];

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
            Container(
              width: 300,
              child: Slider(
                value: _amountOfWater,
                min: 100.0,
                max: 1000.0,
                onChanged: (value) {
                  setState(() {
                    _amountOfWater = value;
                  });
                },
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _toggleReminder,
              child: Text(_isDrinking ? 'Parar lembrete' : 'Começar Lembrete'),
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
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                _editSchedule(context);
              },
              child: Text('Cronograma'),
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

    final prefs = await SharedPreferences.getInstance();
    final historyJson = waterConsumptionHistory.map((e) => jsonEncode(e)).toList();
    await prefs.setStringList('waterConsumptionHistory', historyJson);
  }

  void _toggleReminder() {
    if (_isDrinking) {
      setState(() {
        _isDrinking = false;
      });
      _timer?.cancel();
    } else {
      setState(() {
        _isDrinking = true;
      });
      _startReminder();
    }
  }

  void _startReminder() {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      DateTime now = DateTime.now();

      for (var scheduledTime in scheduledTimes) {
        DateTime selectedDateTime = DateTime(
          now.year,
          now.month,
          now.day,
          scheduledTime.time.hour,
          scheduledTime.time.minute,
        );

        if (now.isAfter(selectedDateTime) && scheduledTime.isEnabled) {
          _showReminder();
          _playNotificationSound();
          _recordWaterConsumption(_amountOfWater);
          timer.cancel();
          setState(() {
            _isDrinking = false;
          });
        }
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

  @override
  void dispose() {
    _timer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Timer? _timer;

  void _editSchedule(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SchedulePage(scheduledTimes),
      ),
    );

    if (result != null && result is List<ScheduledTime>) {
      setState(() {
        scheduledTimes = result;
      });
    }
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
          Image.asset('assets/water_icon.png', width: 36, height: 36),
          SizedBox(width: 16),
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
            subtitle: Text('Quantidade: ${entry.amount.toStringAsFixed(0)} ml'),
          );
        },
      ),
    );
  }
}

class SchedulePage extends StatefulWidget {
  final List<ScheduledTime> scheduledTimes;

  SchedulePage(this.scheduledTimes);

  @override
  _SchedulePageState createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Cronograma'),
      ),
      body: ListView.builder(
        itemCount: widget.scheduledTimes.length,
        itemBuilder: (context, index) {
          final scheduledTime = widget.scheduledTimes[index];
          return ListTile(
            title: Text(
              'Horário: ${scheduledTime.time.format(context)}',
              style: TextStyle(fontSize: 16),
            ),
            trailing: Switch(
              value: scheduledTime.isEnabled,
              onChanged: (value) {
                setState(() {
                  widget.scheduledTimes[index].isEnabled = value;
                });
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddSchedulePage(),
            ),
          );

          if (result != null && result is ScheduledTime) {
            setState(() {
              widget.scheduledTimes.add(result);
            });
          }
        },
        child: Icon(Icons.add),
      ),
    );
  }
}

class AddSchedulePage extends StatefulWidget {
  @override
  _AddSchedulePageState createState() => _AddSchedulePageState();
}

class _AddSchedulePageState extends State<AddSchedulePage> {
  late TimeOfDay _selectedTime;

  @override
  void initState() {
    super.initState();
    _selectedTime = TimeOfDay.now();
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
          mainAxisAlignment: MainAxisAlignment.start, // Ajuste aqui para 'start'
          children: <Widget>[
            SizedBox(height: 20),
            Text(
              'Selecione o Horário',
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final pickedTime = await showTimePicker(
                  context: context,
                  initialTime: _selectedTime,
                );

                if (pickedTime != null) {
                  setState(() {
                    _selectedTime = pickedTime;
                  });
                }
              },
              child: Text('Horário: ${_selectedTime.format(context)}'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  ScheduledTime(_selectedTime, true),
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