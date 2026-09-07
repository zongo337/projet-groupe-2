import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() => runApp(const PharmaTrouveApp());

class PharmaTrouveApp extends StatelessWidget {
  const PharmaTrouveApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pharma-Trouve BF',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});
  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  Map<String, dynamic>? user;
  bool loading = true;

  @override
  void initState() { super.initState(); _check(); }

  Future<void> _check() async {
    final u = await ApiService.getUser();
    setState(() { user = u; loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (user == null) return LoginScreen(onLogin: (u) => setState(() => user = u));
    return HomeScreen(user: user!, onLogout: () => setState(() => user = null));
  }
}
