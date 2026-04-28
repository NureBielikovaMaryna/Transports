import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// --- НАСТРОЙКИ МАСШТАБИРОВАНИЯ (Обнови ссылки из PowerShell) ---
const String authBaseUri = "https://05l8n6bz-5152.euw.devtunnels.ms";   // Порт 5152
const String trainsBaseUri = "https://5v6hx7v5-5153.euw.devtunnels.ms"; // Порт 5153


// Заголовки для обхода анти-фишинга Dev Tunnels
const Map<String, String> tunnelHeaders = {
  "X-Tunnel-Skip-AntiPhishing-Page": "true",
  "Content-Type": "application/json",
};

void main() => runApp(const TransportApp());

class TransportApp extends StatelessWidget {
  const TransportApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
      home: const LoginScreen(),
    );
  }
}

int? currentUserId;
String? currentUserName;

// --- 1. РЕГИСТРАЦИЯ (Auth Service - 5152) ---
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final nameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();

  Future<void> register() async {
    final url = Uri.parse("$authBaseUri/api/Auth/register").replace(queryParameters: {
      "name": nameCtrl.text,
      "email": emailCtrl.text,
      "password": passCtrl.text,
    });

    final res = await http.post(url, headers: tunnelHeaders);
    
    if (res.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Реєстрація успішна!")));
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Помилка: ${res.body}")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Реєстрація")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(children: [
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Ім'я")),
          TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: "Email")),
          TextField(controller: passCtrl, decoration: const InputDecoration(labelText: "Пароль"), obscureText: true),
          const SizedBox(height: 20),
          ElevatedButton(onPressed: register, child: const Text("Створити акаунт")),
        ]),
      ),
    );
  }
}

// --- 2. ВХОД (Auth Service - 5152) ---
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();

  Future<void> login() async {
    final url = Uri.parse("$authBaseUri/api/Auth/login").replace(queryParameters: {
      "email": emailCtrl.text,
      "password": passCtrl.text,
    });

    final res = await http.post(url, headers: tunnelHeaders);

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      setState(() {
        currentUserId = data['userId'];
        currentUserName = data['message'];
      });
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => const MainNavigation()));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Неправильна пошта або пароль")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Вхід")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(children: [
          TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: "Email")),
          TextField(controller: passCtrl, decoration: const InputDecoration(labelText: "Пароль"), obscureText: true),
          const SizedBox(height: 20),
          ElevatedButton(onPressed: login, child: const Text("Увійти")),
          TextButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const RegisterScreen())),
            child: const Text("Зареєструватися"),
          )
        ]),
      ),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});
  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _idx = 0;
  final _tabs = [const ScheduleScreen(), const HistoryScreen()];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Вітаю, ${currentUserName?.split(',')[1] ?? 'Користувач'}"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: () {
              // Обнуляємо дані
              currentUserId = null;
              currentUserName = null;
              // Повертаємось на екран логіну та очищуємо історію переходів
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (c) => const LoginScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: _tabs[_idx],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _idx,
        onTap: (i) => setState(() => _idx = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.train), label: "Поїзди"),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: "Історія"),
        ],
      ),
    );
  }
}

// --- 3. РАСПИСАНИЕ (Trains Service - 5153) ---
class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});
  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  Future<List<dynamic>> getTrains() async {
    // ТЕПЕРЬ ТЯНЕМ С 5153! (Trains Service)
    final res = await http.get(
      Uri.parse("$trainsBaseUri/api/Trains"), 
      headers: tunnelHeaders,
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    } else {
      throw Exception("Ошибка загрузки расписания");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Розклад (Scaled)"),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => setState(() {})),
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: getTrains(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) return Center(child: Text("Помилка сервісу поїздів: ${snap.error}"));
          
          final trains = snap.data ?? [];
          return ListView.builder(
            itemCount: trains.length,
            itemBuilder: (c, i) {
              final train = trains[i];
              return ListTile(
                leading: const Icon(Icons.train, color: Colors.blue),
                title: Text("Поїзд №${train['number']}"),
                subtitle: Text("Зупинок: ${train['route']?.length ?? 0}"),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Text(
        (train['delayMinutes'] ?? 0) > 0 
            ? "+${train['delayMinutes']} хв" 
            : "Вчасно",
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
          color: (train['delayMinutes'] ?? 0) > 0 ? Colors.red : Colors.green,
        ),
      ),
      if ((train['delayMinutes'] ?? 0) > 0)
        const Text(
          "запізнення",
          style: TextStyle(fontSize: 10, color: Colors.grey),
        ),
    ],
  ),
                onTap: () {
                  // ЗАПИСЬ В ИСТОРИЮ (Auth Service - 5152)
                  final viewUrl = Uri.parse("$authBaseUri/api/Auth/view").replace(queryParameters: {
                    "userId": currentUserId.toString(),
                    "trainId": train['id'].toString(),
                  });
                  http.post(viewUrl, headers: tunnelHeaders);

                  showModalBottomSheet(
                    context: context,
                    builder: (c) => ListView(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text("Зупинки №${train['number']}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                        ...(train['route'] as List).map((r) => ListTile(
                          title: Text(r['station']['name']),
                          subtitle: Text("Прибуття: ${r['scheduledArrival']}"),
                        )).toList(),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

// --- 4. ИСТОРИЯ (Auth Service - 5152) ---
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  Future<List<dynamic>> getHistory() async {
    final res = await http.get(
      Uri.parse("$authBaseUri/api/Auth/history/$currentUserId"),
      headers: tunnelHeaders,
    );
    return jsonDecode(res.body);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Ваша історія")),
      body: FutureBuilder<List<dynamic>>(
        future: getHistory(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          return ListView.builder(
            itemCount: snap.data!.length,
            itemBuilder: (c, i) {
              final h = snap.data![i];
              return Card(
                child: ListTile(
                  title: Text("Поїзд №${h['trainNumber']}"),
                  subtitle: Text("Переглянуто: ${h['viewedAt']}"),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
