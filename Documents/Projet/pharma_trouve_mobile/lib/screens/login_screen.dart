import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class LoginScreen extends StatefulWidget {
  final Function(Map<String, dynamic>) onLogin;
  const LoginScreen({super.key, required this.onLogin});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  final nomCtrl = TextEditingController();
  final prenomCtrl = TextEditingController();
  final telCtrl = TextEditingController();
  bool isLogin = true;
  String role = 'PATIENT';
  String message = '';
  bool loading = false;

  Future<void> _submit() async {
    setState(() { loading = true; message = ''; });
    try {
      if (isLogin) {
        final res = await ApiService.login(emailCtrl.text.trim(), passwordCtrl.text);
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final token = data['token'] ?? '';
          final user = (data['user'] is Map) ? Map<String, dynamic>.from(data['user']) : Map<String, dynamic>.from(data);
          await ApiService.saveToken(token);
          await ApiService.saveUser(user);
          widget.onLogin(user);
        } else { setState(() => message = 'Connexion impossible (code ${res.statusCode})'); }
      } else {
        final res = await ApiService.register({'nom': nomCtrl.text.trim(), 'prenom': prenomCtrl.text.trim(), 'email': emailCtrl.text.trim(), 'telephone': telCtrl.text.trim(), 'password': passwordCtrl.text, 'role': role});
        if (res.statusCode == 200 || res.statusCode == 201) { setState(() { isLogin = true; message = 'Compte cree ! Connectez-vous.'; }); }
        else { setState(() => message = 'Erreur inscription (code ${res.statusCode})'); }
      }
    } catch (e) { setState(() => message = 'Erreur reseau : $e'); }
    finally { setState(() => loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 40),
      const Icon(Icons.local_pharmacy, size: 80, color: Color(0xFF2563EB)),
      const SizedBox(height: 16),
      const Text('Pharma-Trouve BF', textAlign: TextAlign.center, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
      const SizedBox(height: 32),
      if (!isLogin) ...[
        TextField(controller: nomCtrl, decoration: const InputDecoration(labelText: 'Nom *', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: prenomCtrl, decoration: const InputDecoration(labelText: 'Prenom *', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: telCtrl, decoration: const InputDecoration(labelText: 'Telephone', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(value: role, items: const [DropdownMenuItem(value: 'PATIENT', child: Text('Patient')), DropdownMenuItem(value: 'PHARMACIEN', child: Text('Pharmacien'))], onChanged: (v) => setState(() => role = v!), decoration: const InputDecoration(labelText: 'Role', border: OutlineInputBorder())),
        const SizedBox(height: 12),
      ],
      TextField(controller: emailCtrl, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email *', border: OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: passwordCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Mot de passe *', border: OutlineInputBorder())),
      const SizedBox(height: 24),
      if (message.isNotEmpty) Container(padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)), child: Text(message, style: const TextStyle(color: Colors.red))),
      ElevatedButton(onPressed: loading ? null : _submit, style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16), backgroundColor: const Color(0xFF2563EB)), child: Text(loading ? 'Chargement...' : (isLogin ? 'Se connecter' : 'S\'inscrire'), style: const TextStyle(color: Colors.white, fontSize: 16))),
      const SizedBox(height: 16),
      TextButton(onPressed: () => setState(() { isLogin = !isLogin; message = ''; }), child: Text(isLogin ? 'Pas de compte ? S\'inscrire' : 'Deja un compte ? Se connecter')),
    ]))));
  }
}
