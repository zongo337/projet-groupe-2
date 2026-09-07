import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'http://localhost:8080';

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }

  static Future<void> saveUser(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user', jsonEncode(user));
  }

  static Future<Map<String, dynamic>?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString('user');
    return s == null ? null : jsonDecode(s);
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('user');
  }

  static Future<Map<String, String>> getHeaders() async {
    final token = await getToken();
    return {'Content-Type': 'application/json', if (token != null) 'Authorization': 'Bearer $token'};
  }

  static Future<http.Response> postFirst(List<String> paths, String body) async {
    http.Response last = http.Response('', 404);
    for (final p in paths) {
      final r = await http.post(Uri.parse('$baseUrl$p'), headers: {'Content-Type': 'application/json'}, body: body);
      last = r;
      if (r.statusCode != 404) return r;
    }
    return last;
  }

  static Future<http.Response> login(String email, String password) =>
      postFirst(['/auth/authenticate', '/api/auth/authenticate', '/auth/login', '/api/auth/login'], jsonEncode({'email': email, 'password': password}));

  static Future<http.Response> register(Map<String, dynamic> data) =>
      postFirst(['/auth/register', '/api/auth/register'], jsonEncode(data));

  static Future<List<dynamic>> getPharmacies() async { final r = await http.get(Uri.parse('$baseUrl/pharmacies'), headers: await getHeaders()); return r.statusCode == 200 ? jsonDecode(r.body) : []; }
  static Future<List<dynamic>> getMedicaments() async { final r = await http.get(Uri.parse('$baseUrl/medicaments'), headers: await getHeaders()); return r.statusCode == 200 ? jsonDecode(r.body) : []; }
  static Future<List<dynamic>> getStocks() async { final r = await http.get(Uri.parse('$baseUrl/stocks'), headers: await getHeaders()); return r.statusCode == 200 ? jsonDecode(r.body) : []; }
  static Future<List<dynamic>> getGardes() async { final r = await http.get(Uri.parse('$baseUrl/gardes/aujourd-hui'), headers: await getHeaders()); return r.statusCode == 200 ? jsonDecode(r.body) : []; }
  static Future<List<dynamic>> getAllGardes() async { final r = await http.get(Uri.parse('$baseUrl/gardes'), headers: await getHeaders()); return r.statusCode == 200 ? jsonDecode(r.body) : []; }
  static Future<List<dynamic>> getReservations() async { final r = await http.get(Uri.parse('$baseUrl/reservations'), headers: await getHeaders()); return r.statusCode == 200 ? jsonDecode(r.body) : []; }

  static Future<http.Response> createReservation(Map<String, dynamic> data) async =>
      http.post(Uri.parse('$baseUrl/reservations'), headers: await getHeaders(), body: jsonEncode(data));

  static Future<http.Response> putReservation(String id, String action, Map<String, dynamic> body) async =>
      http.put(Uri.parse('$baseUrl/reservations/$id/$action'), headers: await getHeaders(), body: jsonEncode(body));
}
