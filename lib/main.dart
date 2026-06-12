import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
  flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  if (androidImplementation != null) {
    await androidImplementation.requestNotificationsPermission();
  }

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'energy_alert_channel_id',
    '전력 경고 알림',
    description: '실시간 전력 모니터링 경고 및 차단 알림입니다.',
    importance: Importance.max,
    playSound: true,
  );

  if (androidImplementation != null) {
    await androidImplementation.createNotificationChannel(channel);
  }

  const AndroidNotificationChannel channel80 = AndroidNotificationChannel(
    'energy_alert_channel_id_80',
    '전력 80% 경고 알림',
    description: '전력량 80% 소모 경고 알림입니다.',
    importance: Importance.max,
    playSound: true,
  );

  if (androidImplementation != null) {
    await androidImplementation.createNotificationChannel(channel80);
  }

  const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);

  await flutterLocalNotificationsPlugin.initialize(
    settings: initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse details) {},
  );

  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: AuthWrapper(),
  ));
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasData) {
          return const SmartMultiTap();
        }
        return const LoginPage();
      },
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  void _signIn() async {
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
    } on FirebaseAuthException catch (e) {
      String message = "로그인에 실패했습니다.";
      if (e.code == 'user-not-found') {
        message = "존재하지 않는 이메일 계정입니다.";
      } else if (e.code == 'wrong-password') {
        message = "비밀번호가 잘못되었습니다.";
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _signUp() async {
    if (_passwordController.text.trim().length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("비밀번호는 최소 6자리 이상이어야 합니다."), backgroundColor: Colors.orange));
      return;
    }
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("🎉 성공적으로 회원가입되어 자동 로그인되었습니다!"), backgroundColor: Colors.green));
    } on FirebaseAuthException catch (e) {
      String message = "회원가입 실패: ${e.message}";
      if (e.code == 'email-already-in-use') {
        message = "이미 사용 중인 이메일 주소입니다.";
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("스마트 멀티탭 로그인", style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.green, centerTitle: true),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.bolt, size: 80, color: Colors.green),
              const SizedBox(height: 10),
              const Text("공유형 스마트 멀티탭 시스템", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 30),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: "이메일 주소 (ID)", border: OutlineInputBorder(), prefixIcon: Icon(Icons.email)),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: "비밀번호 (6자리 이상)", border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock)),
              ),
              const SizedBox(height: 25),
              if (_isLoading)
                const CircularProgressIndicator()
              else ...[
                ElevatedButton(
                  onPressed: _signIn,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  child: const Text("로그인", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _signUp,
                  style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 50), side: const BorderSide(color: Colors.green), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  child: const Text("이 정보로 회원가입", style: TextStyle(color: Colors.green, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }
}

class SocketData {
  bool state = false;
  String timerLabel = "없음";
  int remain = 0;
  int priority = 1;
  Timer? timer;
}

class SmartMultiTap extends StatefulWidget {
  const SmartMultiTap({super.key});

  @override
  State<SmartMultiTap> createState() => _SmartMultiTapState();
}

class _SmartMultiTapState extends State<SmartMultiTap> {
  final sockets = {for (var i in [1, 2]) i: SocketData()};

  double voltage = 220, current = 1.2, power = 264;
  double currentEnergy = 0.0;

  String selectedLimitLabel = "선택 안함";
  double limitEnergy = 0.0;
  double startEnergy = 0.0;
  double usedEnergy = 0.0;
  double remainingEnergy = 0.0;

  bool startButtonState = false;
  bool stopButtonState = false;
  double thresholdPower = 1800.0;

  bool hasNotified80 = false;
  bool hasNotified100 = false;

  bool isAdmin = false;
  bool isPasswordModeActive = false;
  String serverAdminPassword = "";

  String myApprovalStatus = "none";
  Map<String, dynamic> requestList = {};

  // 🟢 [시간 필터링 시스템을 위한 독립 히스토리 큐 인스턴스 할당]

  List<double> history1Min = [];
  List<double> history1Hour = [];
  List<double> history24Hour = [];
  String selectedTimeRange = "1분"; // 기본 선택값

  Timer? _historyCollectionTimer;
  int _tickCount = 0;

  final timerMap = {
    "없음": 0, "10초": 10, "1분": 60, "5분": 300, "10분": 600,
    "30분": 1800, "1시간": 3600, "2시간": 7200,
  };

  final List<String> energyLimits = ["선택 안함", "0.1wh", "0.2wh", "5wh", "10wh", "20wh", "50wh", "100wh", "200wh", "300wh", "500wh", "1000wh", "1300wh"];
  final Map<String, double> energyLimitValues = {
    "선택 안함": 0.0, "0.1wh": 0.1, "0.2wh": 0.2, "5wh": 5.0, "10wh": 10.0, "20wh": 20.0, "50wh": 50.0, "100wh": 100.0, "200wh": 200.0,
    "300wh": 300.0, "500wh": 500.0, "1000wh": 1000.0, "1300wh": 1300.0,
  };

  User? currentUser;

  @override
  void initState() {
    super.initState();
    final db = FirebaseDatabase.instance.ref();

    currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser != null && currentUser!.email == "admin@test.com") {
      isAdmin = true;
      isPasswordModeActive = false;
    } else {
      isAdmin = false;
    }

    if (currentUser?.email == "admin@test.com") {
      db.child("requestList").onValue.listen((e) {
        if (e.snapshot.value != null) {
          setState(() { requestList = Map<String, dynamic>.from(e.snapshot.value as Map); });
        } else {
          setState(() { requestList = {}; });
        }
      });
    }

    if (currentUser != null && currentUser!.email != "admin@test.com") {
      String safeKey = currentUser!.email!.replaceAll('.', ',');
      db.child("requestList/$safeKey").onValue.listen((e) {
        if (e.snapshot.value != null) {
          final data = e.snapshot.value as Map;
          setState(() { myApprovalStatus = data["status"] ?? "none"; });
        } else {
          setState(() { myApprovalStatus = "none"; });
        }
      });
    }

    db.child("adminPassword").onValue.listen((e) {
      String val = e.snapshot.value?.toString().trim() ?? "";
      setState(() {
        serverAdminPassword = val;

        if (currentUser != null && currentUser!.email == "admin@test.com") {
          isAdmin = true;
          isPasswordModeActive = false;
        } else {
          if (val.isEmpty) {
            isPasswordModeActive = false;
            isAdmin = false;
          } else {
            isPasswordModeActive = true;
          }
        }
      });
    });

    db.child("socket").onValue.listen((e) {
      final data = e.snapshot.value as Map?;
      if (data == null) return;
      setState(() {
        for (var i in [1, 2]) {
          final sData = data["socket$i"] as Map?;
          if (sData != null) {
            sockets[i]!.state = sData["state"] == true;
            sockets[i]!.timerLabel = sData["label"] ?? "없음";
            sockets[i]!.priority = sData["priority"] ?? i;
          }
        }
      });
      _syncTimers(fbSocketData: data);
    });

    db.child("sensor").onValue.listen((e) {
      final d = e.snapshot.value as Map?;
      if (d == null) return;
      setState(() {
        voltage = (d["voltage"] ?? 0.0).toDouble();
        current = (d["current"] ?? 0.0).toDouble();
        power = (d["power"] ?? 0.0).toDouble();
        currentEnergy = (d["energy"] ?? 0.0).toDouble();


      });
      _checkEnergyLimit();
    });

    db.child("energyState").onValue.listen((e) {
      final d = e.snapshot.value as Map?;
      if (d == null) return;
      setState(() {
        startButtonState = d["start_button"] == true;
        stopButtonState = d["stop_button"] == true;
        startEnergy = (d["start_energy"] ?? currentEnergy).toDouble();
        limitEnergy = (d["limit_energy"] ?? 0.0).toDouble();
        thresholdPower = (d["threshold"] ?? 1800.0).toDouble();

        selectedLimitLabel = "선택 안함";
        for (var entry in energyLimitValues.entries) {
          if (entry.value == limitEnergy) { selectedLimitLabel = entry.key; break; }
        }
      });
    });

    // 🟢 [시간 필터 추적용 백그라운드 스케줄러 기동 - 1초 타이머 주기]
    _historyCollectionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _tickCount++;

      setState(() {
        // 1. [1분 필터 그래프 데이터 가공]: 3초에 한 번 추출 (3초 * 20개 = 1분 통계)
        if (_tickCount % 3 == 0) {
          history1Min.add(power);
          if (history1Min.length > 20) history1Min.removeAt(0);
        }

        // 2. [1시간 필터 그래프 데이터 가공]: 3분(180초)에 한 번 추출 (180초 * 20개 = 1시간 통계)
        if (_tickCount % 180 == 0) {
          history1Hour.add(power);
          if (history1Hour.length > 20) history1Hour.removeAt(0);
        }

        // 3. [24시간 필터 그래프 데이터 가공]: 1시간(3600초)에 한 번 추출 (3600초 * 24개 = 24시간 통계)
        if (_tickCount % 3600 == 0) {
          history24Hour.add(power);
          if (history24Hour.length > 24) history24Hour.removeAt(0);
        }
      });
    });
  }

  void _sendApprovalRequest() {
    if (currentUser == null) return;
    final db = FirebaseDatabase.instance.ref();
    String safeKey = currentUser!.email!.replaceAll('.', ',');

    db.child("requestList/$safeKey").set({
      "email": currentUser!.email,
      "status": "pending",
      "timestamp": DateTime.now().millisecondsSinceEpoch
    });

    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("🔔 최고 관리자에게 승인 요청을 전송했습니다. 허가를 기다려주세요!"), backgroundColor: Colors.orange)
    );
  }

  void _handleRequestDecision(String userSafeKey, String status) {
    final db = FirebaseDatabase.instance.ref();
    if (status == "approved") {
      db.child("requestList/$userSafeKey").update({"status": "approved"});
    } else {
      db.child("requestList/$userSafeKey").remove();
    }
  }

  void _revokeUserApproval() {
    if (currentUser == null || isAdmin) return;
    final db = FirebaseDatabase.instance.ref();
    String safeKey = currentUser!.email!.replaceAll('.', ',');
    db.child("requestList/$safeKey").remove();
    setState(() {
      myApprovalStatus = "none";
    });
  }

  void _showPasswordAuthDialog() {
    final passwordController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.lock, color: Colors.orange),
              SizedBox(width: 8),
              Text("제어 권한 인증", style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("콘센트를 조작하려면 설정된 비밀번호를 입력하세요.", style: TextStyle(fontSize: 14, color: Colors.black54)),
              const SizedBox(height: 15),
              TextField(
                controller: passwordController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                decoration: const InputDecoration(border: OutlineInputBorder(), labelText: "비밀번호 4자리"),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("취소", style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              onPressed: () {
                if (passwordController.text == serverAdminPassword) {
                  setState(() { isAdmin = true; });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("🎉 인증 성공! 제어 권한이 활성화되었습니다."), backgroundColor: Colors.green));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("❌ 비밀번호가 일치하지 않습니다."), backgroundColor: Colors.red));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text("인증", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showChangePasswordDialog() {
    final currentCheckController = TextEditingController();
    final newPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.settings, color: Colors.blue),
              const SizedBox(width: 8),
              Text(isPasswordModeActive ? "비밀번호 관리 설정" : "보안 비밀번호 새 등록", style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isPasswordModeActive)
                  TextField(
                    controller: currentCheckController,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    decoration: const InputDecoration(border: OutlineInputBorder(), labelText: "현재 비밀번호 확인"),
                  ),
                const SizedBox(height: 10),
                TextField(
                  controller: newPasswordController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: "새 비밀번호 (4자리 입력)",
                    hintText: "빈칸으로 저장 시 비밀번호 해제(프리패스)",
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                    "💡 새 비밀번호 칸을 완전히 비운 채로 '설정 저장'을 누르면 비밀번호가 해제 됩니다.",
                    style: TextStyle(fontSize: 12, color: Colors.blueGrey)
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("취소", style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              onPressed: () {
                if (!isPasswordModeActive || currentCheckController.text == serverAdminPassword) {
                  String newPwd = newPasswordController.text.trim();
                  if (newPwd.isEmpty) {
                    FirebaseDatabase.instance.ref().child("adminPassword").set("");
                    setState(() {
                      if (currentUser?.email == "admin@test.com") {
                        isAdmin = true;
                      } else {
                        isAdmin = false;
                      }
                    });
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("🔓 비밀번호가 제거되었습니다."), backgroundColor: Colors.orange));
                  } else if (newPwd.length == 4) {
                    FirebaseDatabase.instance.ref().child("adminPassword").set(newPwd);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(" 새로운 비밀번호가 설정되었습니다!"), backgroundColor: Colors.blue));
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("❌ 비밀번호는 반드시 4자리이거나 완전히 비어있어야 합니다."), backgroundColor: Colors.red));
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("❌ 기존 비밀번호가 틀렸습니다."), backgroundColor: Colors.red));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              child: const Text("설정 저장", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  String getConnectionStatus() {
    if (current == 0 && power == 0) {
      if (voltage == 0) return "MCU 전원을 확인해주세요";
      else return "부하 연결 없음";
    }
    return "정상 연결됨";
  }

  Color getConnectionStatusColor() {
    String status = getConnectionStatus();
    if (status == "MCU 전원을 확인해주세요") return Colors.red;
    if (status == "부하 연결 없음") return Colors.orange;
    return Colors.green;
  }

  // 🟢 [시간 필터 전력 추이 동적 그래프 팝업 모듈 완전히 리뉴얼 수정]
  void _showGraphDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // 현재 어떤 탭(범위)이 설정되어 있느냐에 따라 매핑할 리스트 분기 결정
            List<double> activePoints;
            if (selectedTimeRange == "1분") {
              activePoints = history1Min;
            } else if (selectedTimeRange == "1시간") {
              activePoints = history1Hour;
            } else {
              activePoints = history24Hour;
            }

            // 만약 배열이 비어 있다면 현재 파워 값 하드코딩 백업 처리
            if (activePoints.isEmpty) {
              activePoints = [power];
            }

            return AlertDialog(
              title: const Text("전력 모니터링 통계", style: TextStyle(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: double.maxFinite,
                height: 340,
                child: Column(
                  children: [
                    // 🟢 [필터 컨트롤러 부착 완료]: 5초, 1분, 1시간, 24시간 분류 세그먼트 생성
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("범위 필터 선택:", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
                        DropdownButton<String>(
                          value: selectedTimeRange,
                          dropdownColor: Colors.white,
                          items: ["1분", "1시간", "24시간"].map((String val) {
                            return DropdownMenuItem<String>(
                              value: val,
                              child: Text(val, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            );
                          }).toList(),
                          onChanged: (newVal) {
                            if (newVal != null) {
                              // StatefulBuilder 내부 UI 동기화 및 부모 컴포넌트 동시 갱신
                              setDialogState(() { selectedTimeRange = newVal; });
                              setState(() { selectedTimeRange = newVal; });
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Chip(
                        label: Text("$selectedTimeRange 추이 모니터링 상태 (최대 데이터 표시)", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                        backgroundColor: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 15),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.grey[50], border: Border.all(color: Colors.grey[300]!)),
                        child: CustomPaint(
                          size: Size.infinite,
                          painter: SimpleLineChartPainter(
                              points: activePoints,
                              currentVal: power,
                              rangeLabel: selectedTimeRange // 레이블 동적 매핑 전달
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text("현재 전력 수치: ${power.toStringAsFixed(0)} W", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 15)),
                  ],
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("닫기", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))
                )
              ],
            );
          },
        );
      },
    );
  }

  void _checkEnergyLimit() {
    if (!startButtonState || limitEnergy <= 0) {
      setState(() { usedEnergy = 0.0; remainingEnergy = 0.0; });
      return;
    }
    setState(() {
      usedEnergy = currentEnergy - startEnergy;
      if (usedEnergy < 0) { usedEnergy = 0; }
      remainingEnergy = limitEnergy - usedEnergy;
    });
    final db = FirebaseDatabase.instance.ref();
    db.child("energyState/remaining_energy").set(double.parse(remainingEnergy.toStringAsFixed(2)));

    if (remainingEnergy <= 0) {
      setState(() { remainingEnergy = 0; startButtonState = false; stopButtonState = true; });
      db.child("socket/socket1").update({"state": false, "endTime": 0, "label": "없음"});
      db.child("socket/socket2").update({"state": false, "endTime": 0, "label": "없음"});
      db.child("energyState").update({ "start_button": false, "stop_button": true, "remaining_energy": 0.0 });

      if (!isAdmin) _revokeUserApproval();
    }
  }

  void _onSelectEnergyLimit(String label) {
    if (label == "선택 안함") return;
    final db = FirebaseDatabase.instance.ref();
    double limit = energyLimitValues[label]!;
    setState(() {
      selectedLimitLabel = label; limitEnergy = limit; startEnergy = currentEnergy;
      usedEnergy = 0.0; remainingEnergy = limit; startButtonState = true; stopButtonState = false;
    });
    db.child("energyState").update({ "start_button": true, "stop_button": false, "limit_energy": limit, "start_energy": currentEnergy, "remaining_energy": limit });
  }

  void _resetEnergyLimit() {
    final db = FirebaseDatabase.instance.ref();
    setState(() { selectedLimitLabel = "선택 안함"; limitEnergy = 0.0; startEnergy = 0.0; usedEnergy = 0.0; remainingEnergy = 0.0; startButtonState = false; stopButtonState = true; });
    db.child("energyState").update({ "start_button": false, "stop_button": true, "limit_energy": 0.0, "start_energy": 0.0, "remaining_energy": 0.0 });
  }

  void _syncTimers({Map? fbSocketData}) {
    final db = FirebaseDatabase.instance.ref();
    int now = DateTime.now().millisecondsSinceEpoch;
    for (var i in [1, 2]) {
      final s = sockets[i]!;
      int endTime = 0;
      if (fbSocketData != null && fbSocketData["socket$i"] is Map) { endTime = fbSocketData["socket$i"]["endTime"] ?? 0; }
      else { endTime = s.remain > 0 ? now + (s.remain * 1000) : 0; }
      s.timer?.cancel();
      if (s.state && endTime > now) {
        s.remain = ((endTime - now) / 1000).ceil();
        s.timer = Timer.periodic(const Duration(seconds: 1), (t) {
          int currentNow = DateTime.now().millisecondsSinceEpoch;
          setState(() { s.remain = ((endTime - currentNow) / 1000).ceil(); });
          if (s.remain <= 0) {
            t.cancel();
            db.child("socket/socket$i").update({"state": false, "endTime": 0, "label": "없음"});
            _checkAllTimersFinished();
          }
        });
      } else {
        s.remain = 0;
        if (s.state && endTime > 0 && endTime <= now) {
          db.child("socket/socket$i").update({"state": false, "endTime": 0, "label": "없음"});
        }
      }
    }
  }

  void _checkAllTimersFinished() {
    final db = FirebaseDatabase.instance.ref();
    db.child("socket").get().then((snapshot) {
      final data = snapshot.value as Map?;
      if (data == null) return;

      bool isAnySocketRunning = false;
      for (var i in [1, 2]) {
        final sData = data["socket$i"] as Map?;
        if (sData != null && sData["state"] == true) {
          isAnySocketRunning = true;
        }
      }
      if (!isAnySocketRunning && !isAdmin) {
        _revokeUserApproval();
      }
    });
  }

  void _toggle(int id, bool val) {
    final db = FirebaseDatabase.instance.ref();
    final s = sockets[id]!;
    int seconds = val ? timerMap[s.timerLabel]! : 0;
    int endTime = val && seconds > 0 ? DateTime.now().millisecondsSinceEpoch + (seconds * 1000) : 0;
    db.child("socket/socket$id").update({ "state": val, "endTime": endTime, "label": val ? s.timerLabel : "없음" });
  }

  void _changeTimer(int id, String label) {
    final db = FirebaseDatabase.instance.ref();
    final s = sockets[id]!;
    setState(() { s.timerLabel = label; });
    int seconds = timerMap[label]!;
    int endTime = (s.state && seconds > 0) ? DateTime.now().millisecondsSinceEpoch + (seconds * 1000) : 0;
    db.child("socket/socket$id").update({"endTime": endTime, "label": label});
  }

  void _changePriority(int id, int priority) {
    final db = FirebaseDatabase.instance.ref();
    setState(() { sockets[id]!.priority = priority; });
    db.child("socket/socket$id").update({"priority": priority});
  }

  String _time(int s) {
    if (s < 0) s = 0;
    return s >= 3600 ? "${s ~/ 3600}:${((s % 3600) ~/ 60).toString().padLeft(2, '0')}" : "${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}";
  }

  Widget info(String t, String v, {double size = 20, Color? color, bool bold = false}) {
    return Text("$t : $v", style: TextStyle(fontSize: size, color: color, fontWeight: bold ? FontWeight.bold : FontWeight.normal));
  }

  @override
  Widget build(BuildContext context) {
    bool isUserApprovedByAdmin = (myApprovalStatus == "approved");
    bool canControl = isAdmin || isUserApprovedByAdmin;

    return Scaffold(
      appBar: AppBar(
        title: const Text("스마트 멀티탭", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.logout, color: Colors.white),
          onPressed: () async {
            await FirebaseAuth.instance.signOut();
          },
          tooltip: "로그아웃",
        ),
        actions: [
          if (currentUser?.email == "admin@test.com")
            IconButton(
              icon: const Icon(Icons.settings, size: 24, color: Colors.white),
              onPressed: _showChangePasswordDialog,
            )
          else if (isPasswordModeActive)
            IconButton(
              icon: Icon(isAdmin ? Icons.lock_open : Icons.lock, size: 26, color: isAdmin ? Colors.lightGreenAccent : Colors.white),
              onPressed: () {
                if (isAdmin) {
                  setState(() { isAdmin = false; });
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("조회 전용 보호 모드로 변경되었습니다.")));
                } else {
                  _showPasswordAuthDialog();
                }
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(15),
        children: [
          if (currentUser?.email == "admin@test.com") ...[
            Container(
              margin: const EdgeInsets.only(bottom: 15),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.yellow[50],
                  border: Border.all(color: Colors.orange),
                  borderRadius: BorderRadius.circular(12)
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.notifications_active, color: Colors.orange),
                      SizedBox(width: 8),
                      Text("🔔 실시간 사용 허가 요청 목록 (마스터 전용)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.orange)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (requestList.isEmpty)
                    const Text("현재 대기 중이거나 등록된 실시간 요청이 없습니다.", style: TextStyle(color: Colors.grey, fontSize: 13))
                  else
                    ...requestList.entries.map((entry) {
                      String safeKey = entry.key;
                      var val = entry.value;
                      String userEmail = val["email"] ?? "익명 계정";
                      String status = val["status"] ?? "pending";

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: Text(userEmail, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13), overflow: TextOverflow.ellipsis)),
                            Row(
                              children: [
                                if (status == "pending") ...[
                                  ElevatedButton(
                                    onPressed: () => _handleRequestDecision(safeKey, "approved"),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2), minimumSize: Size.zero),
                                    child: const Text("승인", style: TextStyle(color: Colors.white, fontSize: 12)),
                                  ),
                                  const SizedBox(width: 4),
                                  ElevatedButton(
                                    onPressed: () => _handleRequestDecision(safeKey, "rejected"),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2), minimumSize: Size.zero),
                                    child: const Text("거절", style: TextStyle(color: Colors.white, fontSize: 12)),
                                  ),
                                ] else if (status == "approved") ...[
                                  const Text("🟢 허가됨 ", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                                  const SizedBox(width: 6),
                                  OutlinedButton(
                                    onPressed: () => _handleRequestDecision(safeKey, "revoke"),
                                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), minimumSize: Size.zero, side: const BorderSide(color: Colors.red)),
                                    child: const Text("회수", style: TextStyle(color: Colors.red, fontSize: 11)),
                                  )
                                ]
                              ],
                            )
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ],

          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: canControl ? Colors.blue[50] : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: canControl ? Colors.blue[300]! : Colors.grey[400]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(canControl ? Icons.bolt : Icons.block, color: canControl ? Colors.blue : Colors.grey),
                        const SizedBox(width: 8),
                        Text(
                          canControl
                              ? (currentUser?.email == "admin@test.com" ? "👑 마스터 총괄 관리자" : (isAdmin ? "🔑 비밀번호 인증 완료 (제어 활성)" : "🟢 관리자 사용 승인됨"))
                              : (myApprovalStatus == "pending" ? "⏳ 관리자 승인 대기 중..." : "🔴 권한 없음 (사용요청 필요)"),
                          style: TextStyle(fontWeight: FontWeight.bold, color: canControl ? Colors.blue[900] : Colors.grey[700]),
                        ),
                      ],
                    ),
                    if (!canControl && currentUser?.email != "admin@test.com" && myApprovalStatus != "pending")
                      ElevatedButton.icon(
                        onPressed: _sendApprovalRequest,
                        icon: const Icon(Icons.bolt, size: 16),
                        label: const Text("사용 요청하기"),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5)),
                      )
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  "접속 계정: ${currentUser?.email ?? '알 수 없음'}",
                  style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),

          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isPasswordModeActive ? Colors.red[50] : Colors.green[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isPasswordModeActive ? Colors.red[200]! : Colors.green[200]!),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(isPasswordModeActive ? Icons.security : Icons.lock_open, size: 16, color: isPasswordModeActive ? Colors.red : Colors.green),
                const SizedBox(width: 6),
                Text(
                  isPasswordModeActive ? "🔒 보안 비밀번호 작동 중 (인증 필요)" : "🔓 자율 모드 (비밀번호 미설정)",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isPasswordModeActive ? Colors.red[900] : Colors.green[900]),
                ),
              ],
            ),
          ),
          Card(
            color: Colors.blue[100],
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Stack(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("전체 전력 모니터링", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(color: getConnectionStatusColor(), borderRadius: BorderRadius.circular(10)),
                          child: Text(getConnectionStatus(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                        const SizedBox(height: 15),
                        Row(mainAxisAlignment: MainAxisAlignment.center, children: [info("전압", "${voltage.toStringAsFixed(1)} V", size: 18)]),
                        const SizedBox(height: 4),
                        Row(mainAxisAlignment: MainAxisAlignment.center, children: [info("전류", "${current.toStringAsFixed(2)} A", size: 18)]),
                        const SizedBox(height: 8),
                        Row(mainAxisAlignment: MainAxisAlignment.center, children: [info("오늘의 사용전력량", "${currentEnergy.toStringAsFixed(2)} Wh", color: Colors.green[800], bold: true, size: 18)]),
                        const SizedBox(height: 12),
                        Text("전력 : ${power.toStringAsFixed(0)} W", style: const TextStyle(fontSize: 32, color: Colors.blue, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text("(설정된 자동 차단 임계값: ${thresholdPower.toStringAsFixed(0)} W)", style: const TextStyle(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  Positioned(bottom: 0, right: 0, child: IconButton(icon: const Icon(Icons.trending_up, size: 30, color: Colors.blueAccent), onPressed: _showGraphDialog))
                ],
              ),
            ),
          ),
          const SizedBox(height: 15),

          IgnorePointer(
            ignoring: !canControl,
            child: Opacity(
              opacity: canControl ? 1.0 : 0.5,
              child: Card(
                color: Colors.orange[50],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: const BorderSide(color: Colors.orange, width: 1)),
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    children: [
                      const Text("🔋 전력 제한 설정 (에너지 관리)", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                      const SizedBox(height: 15),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("제한 전력량 선택 : ", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          DropdownButton<String>(
                            value: selectedLimitLabel,
                            items: energyLimits.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                            onChanged: startButtonState ? null : (v) => _onSelectEnergyLimit(v!),
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(children: [const Text("사용한 전력량", style: TextStyle(fontSize: 14, color: Colors.grey)), const SizedBox(height: 5), Text("${usedEnergy.toStringAsFixed(2)} Wh", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue))]),
                          Column(children: [const Text("남은 전력량", style: TextStyle(fontSize: 14, color: Colors.grey)), const SizedBox(height: 5), Text("${remainingEnergy.toStringAsFixed(2)} Wh", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red))]),
                        ],
                      ),
                      const SizedBox(height: 15),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(startButtonState ? "▶ 작동 중" : (stopButtonState ? "⏹ 정지됨 (리셋)" : "💤 대기 중"), style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: startButtonState ? Colors.green : Colors.red)),
                          ElevatedButton.icon(onPressed: _resetEnergyLimit, icon: const Icon(Icons.refresh, size: 18), label: const Text("RESET"), style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white)),
                        ],
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 15),
          ...[1, 2].map((id) {
            final s = sockets[id]!;

            // 💡 [핵심 추가 로직] 소켓 제어 권한 분리
            bool canControlSocket = canControl && (isAdmin || startButtonState);

            return IgnorePointer(
              ignoring: !canControlSocket,
              child: Opacity(
                opacity: canControlSocket ? 1.0 : 0.5,
                child: Card(
                  color: s.state ? Colors.green[100] : Colors.grey[200],
                  margin: const EdgeInsets.only(bottom: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        SwitchListTile(
                          title: Text("콘센트 $id", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                          subtitle: (!canControlSocket && canControl)
                              ? const Text("위에서 먼저 제한 전력량을 선택해 주세요.", style: TextStyle(color: Colors.red, fontSize: 12))
                              : null,
                          value: s.state,
                          onChanged: (v) => _toggle(id, v),
                        ),
                        if (s.state && s.remain > 0)
                          Text("남은시간 : ${_time(s.remain)}", style: const TextStyle(fontSize: 18, color: Colors.red, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 5),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            DropdownButton<String>(
                              value: s.timerLabel,
                              items: timerMap.keys.map((v) => DropdownMenuItem(value: v, child: Text("타이머 $v"))).toList(),
                              onChanged: (v) => _changeTimer(id, v!),
                            ),
                            Row(
                              children: [
                                const Text("우선순위: ", style: TextStyle(fontWeight: FontWeight.w600)),
                                DropdownButton<int>(
                                  value: s.priority,
                                  items: [1, 2].map((p) => DropdownMenuItem(value: p, child: Text("$p순위"))).toList(),
                                  onChanged: (v) => _changePriority(id, v!),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _historyCollectionTimer?.cancel();
    for (var s in sockets.values) { s.timer?.cancel(); }
    super.dispose();
  }
}

// ==========================================
// 🎨 실시간 선 그래프 커스텀 페인터 (레이블 반영 지원)
// ==========================================
// ==========================================
// 🎨 [업그레이드] 시간 단위 표기가 추가된 커스텀 페인터
// ==========================================
// ==========================================
// 🎨 [시간 단위 수정] '~전' 표기가 추가된 커스텀 페인터
// ==========================================
// ==========================================
// 🔒 [에러 완벽 차단] 데이터가 없어도 [닫기] 버튼이 무조건 뜨는 페인터
// ==========================================
// =================================================================
// 🔒 [최종 무적 버그판] 데이터 0개, 0W여도 닫기 UI가 무조건 뜨는 완벽한 페인터
// =================================================================
class SimpleLineChartPainter extends CustomPainter {
  final List<double> points;
  final double currentVal;
  final String rangeLabel;

  SimpleLineChartPainter({
    required this.points,
    required this.currentVal,
    this.rangeLabel = "5초"
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 혹시 모를 치명적 오류 방지를 위해 paint 전체를 try-catch로 감싸 안전망을 쳐둡니다.
    try {
      const double leftMargin = 40.0;
      const double bottomMargin = 25.0;
      final double graphWidth = size.width - leftMargin;
      final double graphHeight = size.height - bottomMargin;

      // [핵심 안전장치 1] 데이터가 완전히 비어있거나 1개 이하일 때 0으로 채워진 가상 배열 강제 생성
      List<double> displayPoints = List.from(points);
      if (displayPoints.length < 2) {
        double safeCurrent = (currentVal.isNaN || currentVal.isInfinite) ? 0.0 : currentVal;
        displayPoints = List.generate(20, (index) => safeCurrent);
      }

      // 최댓값 계산 (최소 300W 가이드라인 보장)
      double maxVal = 300.0;
      double calculatedMax = displayPoints.reduce(max);
      if (!calculatedMax.isNaN && !calculatedMax.isInfinite && calculatedMax > 300.0) {
        maxVal = calculatedMax;
      }

      final paintLine = Paint()..color = Colors.blue..strokeWidth = 3.0..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
      final paintGrid = Paint()..color = Colors.grey.withOpacity(0.3)..strokeWidth = 1.0;

      // 1. Y축 격자선 및 수치 렌더링
      for (int i = 0; i <= 4; i++) {
        double y = graphHeight - (i * (graphHeight / 4));
        double val = i * (maxVal / 4);

        canvas.drawLine(Offset(leftMargin, y), Offset(size.width, y), paintGrid);

        TextSpan span = TextSpan(style: const TextStyle(color: Colors.grey, fontSize: 10), text: "${val.toInt()}W");
        TextPainter tp = TextPainter(text: span, textDirection: TextDirection.ltr)..layout();
        tp.paint(canvas, Offset(0, y - tp.height / 2));
      }

      // [핵심 안전장치 2] 0으로 나누기 방지 구문 (Divide by zero crash 방지)
      double stepX = (displayPoints.length > 1) ? graphWidth / (displayPoints.length - 1) : graphWidth;
      Path linePath = Path();

      // 2. 데이터 그래프 선 및 점 그리기
      for (int i = 0; i < displayPoints.length; i++) {
        double ratioY = displayPoints[i] / maxVal;
        if (ratioY.isNaN || ratioY.isInfinite) ratioY = 0.0; // 안전벨트 추가

        double x = leftMargin + (i * stepX);
        double y = graphHeight - (ratioY * graphHeight);

        if (i == 0) {
          linePath.moveTo(x, y);
        } else {
          linePath.lineTo(x, y);
        }

        // 실제 유의미한 집계 데이터가 쌓여있을 때만 주황색 점 시각화
        if (points.isNotEmpty && points.length >= displayPoints.length) {
          canvas.drawCircle(Offset(x, y), 3, Paint()..color = Colors.orange);
        }
      }
      canvas.drawPath(linePath, paintLine);

      // 3. X축 메인 기준선
      canvas.drawLine(Offset(leftMargin, graphHeight), Offset(size.width, graphHeight), Paint()..color = Colors.black..strokeWidth = 1.5);

      // 4. X축 시간 단위 가이드라인 표기 (총 5개 지점 고정)
      int maxTicks = displayPoints.length;
      List<int> xIndices = [0, (maxTicks / 4).toInt(), (maxTicks / 2).toInt(), (maxTicks * 3 / 4).toInt(), maxTicks - 1];

      for (int index in xIndices) {
        double x = leftMargin + (index * stepX);
        int distanceFromPresent = (maxTicks - 1) - index;
        String timeText = "";

        if (distanceFromPresent == 0) {
          timeText = "현재";
        } else {
          switch (rangeLabel) {
            case "1분":
              timeText = "${distanceFromPresent * 3}초 전";
              break;
            case "1시간":
              timeText = "${distanceFromPresent * 3}분 전";
              break;
            case "24시간":
              timeText = "${distanceFromPresent}시간 전";
              break;
            default:
              timeText = "";
          }
        }

        TextSpan xUnitSpan = TextSpan(style: const TextStyle(color: Colors.black54, fontSize: 9, fontWeight: FontWeight.bold), text: timeText);
        TextPainter xUnitTp = TextPainter(text: xUnitSpan, textDirection: TextDirection.ltr)..layout();
        xUnitTp.paint(canvas, Offset(x - (xUnitTp.width / 2), graphHeight + 6));
      }
    } catch (e) {
      // 만에 하나 에러가 나더라도 침묵하여 부모 UI(닫기 버튼 등)가 무너지는 것을 완벽히 방어합니다.
      debugPrint("그래프 페인팅 에러 우회됨: $e");
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}