import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// ТВОЯ АКТУАЛЬНА ССЫЛКА (обнови если сменится)
const String baseUri = "https://44stgk2r-5152.euw.devtunnels.ms";

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

// Глобальные данные текущего пользователя
int? currentUserId;
String? currentUserName;

// --- 1. РЕГИСТРАЦИЯ (Query Params) ---
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
    // Формируем URL с параметрами, как того требует твой C# метод Register
    final url = Uri.parse("$baseUri/api/Auth/register").replace(queryParameters: {
      "name": nameCtrl.text,
      "email": emailCtrl.text,
      "password": passCtrl.text,
    });

    final res = await http.post(url);
    
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

// --- 2. ВХОД (Query Params) ---
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();

  Future<void> login() async {
    // Твой метод Login ждет email и password в строке запроса
    final url = Uri.parse("$baseUri/api/Auth/login").replace(queryParameters: {
      "email": emailCtrl.text,
      "password": passCtrl.text,
    });

    final res = await http.post(url);

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      setState(() {
        currentUserId = data['userId'];
        currentUserName = data['message']; // Там фраза "Вітаю, Марина!"
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

// --- 3. НАВИГАЦИЯ ---
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

// --- 4. РАСПИСАНИЕ С ОСТАНОВКАМИ ---
class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  // Метод для получения данных
  Future<List<dynamic>> getTrains() async {
    final res = await http.get(
      Uri.parse("$baseUri/api/Auth/trains"),
      headers: {"X-Tunnel-Skip-AntiPhishing-Page": "true"},
    );
    return jsonDecode(res.body);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Доступні поїзди"),
        actions: [
          // Кнопка обновления в верхней панели
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {}); // Перерисовывает экран и вызывает FutureBuilder заново
            },
          ),
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        // Каждый раз, когда вызывается setState, future запускается заново
        future: getTrains(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text("Помилка: ${snap.error}"));
          }
          if (!snap.hasData || snap.data!.isEmpty) {
            return const Center(child: Text("Поїздів не знайдено"));
          }

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {});
            },
            child: ListView.builder(
              itemCount: snap.data!.length,
              itemBuilder: (c, i) {
                final train = snap.data![i];
                final int delay = train['delayMinutes'] ?? 0;

                return ListTile(
                  leading: const Icon(Icons.train),
                  title: Text("Поїзд №${train['number']}"),
                  subtitle: Text("Маршрут: ${train['route'].length} зупинок"),
                  // --- ОТОБРАЖЕНИЕ ЗАДЕРЖКИ СБОКУ ---
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        delay > 0 ? "+$delay хв" : "Вчасно",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: delay > 0 ? Colors.red : Colors.green,
                        ),
                      ),
                      if (delay > 0)
                        const Text(
                          "затримка",
                          style: TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                    ],
                  ),
                  onTap: () {
                    // Запись просмотра (RecordView)
                    final viewUrl = Uri.parse("$baseUri/api/Auth/view").replace(queryParameters: {
                      "userId": currentUserId.toString(),
                      "trainId": train['id'].toString(),
                    });
                    http.post(viewUrl);

                    // Открытие остановок
                    showModalBottomSheet(
                      context: context,
                      builder: (c) => ListView(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              "Зупинки поїзда №${train['number']}",
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                          ...(train['route'] as List).map((r) => ListTile(
                            leading: const Icon(Icons.location_on_outlined),
                            title: Text(r['station']['name']),
                            subtitle: Text("Прибуття: ${r['scheduledArrival']}"),
                          )).toList(),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}

// --- 5. ИСТОРИЯ (под твой Select в C#) ---
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  Future<List<dynamic>> getHistory() async {
    final res = await http.get(Uri.parse("$baseUri/api/Auth/history/$currentUserId"), 
      headers: {"X-Tunnel-Skip-AntiPhishing-Page": "true"});
    return jsonDecode(res.body);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Ваші перегляди")),
      body: FutureBuilder<List<dynamic>>(
        future: getHistory(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          return ListView.builder(
            itemCount: snap.data!.length,
            itemBuilder: (c, i) {
              final h = snap.data![i];
              return Card(
                margin: const EdgeInsets.all(8),
                child: ExpansionTile(
                  title: Text("Поїзд №${h['trainNumber']}"),
                  subtitle: Text("Переглянуто: ${h['viewedAt']}"),
                  children: (h['stops'] as List).map((s) => ListTile(
                    dense: true,
                    title: Text(s['stationName']),
                    subtitle: Text("Час: ${s['arrival']} - ${s['departure']}"),
                  )).toList(),
                ),
              );
            },
          );
        },
      ),
    );
  }
}