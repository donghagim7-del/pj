import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MaterialApp(home: SmartMultiTap()));
}

// 콘센트 데이터를 담는 모델 클래스
class SocketData {
  bool state = false;
  String timerLabel = "없음";
  int remain = 0;
  double current = 0;
  double power = 0;
  Timer? timer;
}

class SmartMultiTap extends StatefulWidget {
  const SmartMultiTap({super.key});
  @override
  State<SmartMultiTap> createState() => _SmartMultiTapState();
}

class _SmartMultiTapState extends State<SmartMultiTap> {
  final Map<int, SocketData> sockets = {1: SocketData(), 2: SocketData()};
  double voltage = 0;

  @override
  void initState() {
    super.initState();
    _listenData();
  }

  void _listenData() {
    final db = FirebaseDatabase.instance.ref();
    // 상태 리스너 (반복문으로 처리)
    for (int i in [1, 2]) {
      db.child("socket$i").onValue.listen((e) {
        if (e.snapshot.value != null) setState(() => sockets[i]!.state = e.snapshot.value as bool);
      });
    }
    // 센서 리스너
    db.child("sensor").onValue.listen((e) {
      final data = e.snapshot.value as Map?;
      if (data == null) return;
      setState(() {
        voltage = double.tryParse(data["voltage"]?.toString() ?? "0") ?? 0;
        for (int i in [1, 2]) {
          sockets[i]!.current = double.tryParse(data["socket$i"]?["current"]?.toString() ?? "0") ?? 0;
          sockets[i]!.power = double.tryParse(data["socket$i"]?["power"]?.toString() ?? "0") ?? 0;
        }
      });
    });
  }

  void _toggleSocket(int id, bool value) {
    FirebaseDatabase.instance.ref("socket$id").set(value);
    sockets[id]!.timer?.cancel();
    setState(() {
      sockets[id]!.state = value;
      if (value) _startTimer(id);
      else sockets[id]!.remain = 0;
    });
  }

  void _startTimer(int id) {
    final s = sockets[id]!;
    s.timer?.cancel();
    s.remain = _getSeconds(s.timerLabel);
    if (s.remain > 0) {
      s.timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (s.remain <= 0) {
          t.cancel();
          _toggleSocket(id, false);
        } else {
          setState(() => s.remain--);
        }
      });
    }
  }

  int _getSeconds(String val) {
    final map = {"1분": 60, "5분": 300, "10분": 600, "30분": 1800, "1시간": 3600, "2시간": 7200};
    return map[val] ?? 0;
  }

  String _formatTime(int sec) {
    if (sec <= 0) return "";
    return sec >= 3600 ? "${sec ~/ 3600}:${(sec % 3600 ~/ 60).toString().padLeft(2, '0')}"
        : "${sec ~/ 60}:${(sec % 60).toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("스마트 멀티탭"), backgroundColor: Colors.green, centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(15),
        children: [1, 2].map((id) => _buildSocketCard(id)).toList(),
      ),
    );
  }

  Widget _buildSocketCard(int id) {
    final s = sockets[id]!;
    return Card(
      color: s.state ? Colors.green[100] : Colors.grey[200],
      elevation: 5,
      margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            SwitchListTile(
              title: Text("콘센트 $id", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              value: s.state,
              onChanged: (val) => _toggleSocket(id, val),
            ),
            const Divider(),
            Text("전압 : ${voltage.toStringAsFixed(1)}V | 전류 : ${s.current.toStringAsFixed(2)}A"),
            Text("전력 : ${s.power.toStringAsFixed(0)}W",
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue)),
            if (s.remain > 0) Text("남은시간 : ${_formatTime(s.remain)}",
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            DropdownButton<String>(
              value: s.timerLabel,
              items: ["없음", "1분", "5분", "10분", "30분", "1시간", "2시간"].map((v) =>
                  DropdownMenuItem(value: v, child: Text("타이머 $v"))).toList(),
              onChanged: (val) => setState(() => s.timerLabel = val!),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    sockets.forEach((_, s) => s.timer?.cancel());
    super.dispose();
  }
}