import 'package:flutter/material.dart';
import 'features/auth/login_page.dart';
import 'features/auth/register_page.dart';
import 'features/home/home_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  int? _userId;

  void _setUser(int userId) => setState(() => _userId = userId);
  void _logout() => setState(() => _userId = null);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'POS Offline',
      theme: ThemeData(useMaterial3: true),
      routes: {'/register': (_) => const RegisterPage()},
      home: _userId == null
          ? LoginPage(onLoggedIn: _setUser)
          : HomePage(userId: _userId!, onLogout: _logout),
    );
  }
}
