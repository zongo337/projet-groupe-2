import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/api_service.dart';
import 'search_screen.dart';
import 'gardes_screen.dart';
import 'reservations_screen.dart';

class HomeScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback onLogout;
  const HomeScreen({super.key, required this.user, required this.onLogout});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List pharmacies = [];
  List stocks = [];
  bool loading = true;
  dynamic userPos;

  @override
  void initState() { super.initState(); _load(); }

  String _nomAff() {
    final p = (widget.user['prenom'] ?? '').toString();
    final n = (widget.user['nom'] ?? '').toString();
    final full = '$p $n'.replaceAll('  ', ' ').trim();
    return full.isEmpty ? (widget.user['email'] ?? '').toString() : full;
  }

  Future<void> _load() async {
    setState(() => loading = true);
    final results = await Future.wait([ApiService.getPharmacies(), ApiService.getStocks()]);
    setState(() { pharmacies = results[0]; stocks = results[1]; loading = false; });
  }

  Future<void> _locate() async {
    bool enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Activez la localisation'))); return; }
    LocationPermission p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
    if (p == LocationPermission.denied || p == LocationPermission.deniedForever) return;
    final pos = await Geolocator.getCurrentPosition();
    setState(() => userPos = pos);
  }

  double _dist(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) + cos(lat1 * pi / 180) * cos(lat2 * pi / 180) * sin(dLon / 2) * sin(dLon / 2);
    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  double _distOf(dynamic p) {
    if (userPos == null || p['latitude'] == null) return 99999;
    return _dist(userPos.latitude, userPos.longitude, p['latitude'].toDouble(), p['longitude'].toDouble());
  }

  int _stockCount(String id) => stocks.where((s) => s['pharmacie']?['id'] == id && s['enStock'] == true).length;

  List<Widget> _sections() {
    final regions = <String>[];
    for (final p in pharmacies) {
      final r = (p['region'] ?? 'Autre').toString();
      if (!regions.contains(r)) regions.add(r);
    }
    regions.sort();
    final widgets = <Widget>[];
    for (final region in regions) {
      final list = pharmacies.where((p) => (p['region'] ?? 'Autre').toString() == region).toList();
      if (userPos != null) list.sort((a, b) => _distOf(a).compareTo(_distOf(b)));
      widgets.add(Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text('Region $region (${list.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)))));
      for (final p in list) {
        final d = userPos != null && p['latitude'] != null ? _distOf(p) : null;
        widgets.add(Card(margin: const EdgeInsets.only(bottom: 12), child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${p['nom']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
          if (d != null) Text('a ${d.toStringAsFixed(1)} km de vous', style: const TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text('${p['adresse']}'),
          Text('${p['ville']} ${p['quartier'] ?? ''}'),
          Text('Tel : ${p['telephone'] ?? ''}'),
          const SizedBox(height: 6),
          Text('${_stockCount(p['id'])} medicament(s) en stock', style: const TextStyle(color: Color(0xFF059669))),
          if (p['livraisonDisponible'] == true) Text('Livraison : ${p['fraisLivraison'] ?? 'Gratuit'} FCFA ${p['zoneLivraison'] ?? ''}', style: const TextStyle(color: Color(0xFF7C3AED))),
        ]))));
      }
    }
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pharma-Trouve BF'), backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white, actions: [IconButton(icon: const Icon(Icons.logout), onPressed: widget.onLogout)]),
      drawer: Drawer(child: ListView(children: [
        DrawerHeader(decoration: const BoxDecoration(color: Color(0xFF2563EB)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
          const CircleAvatar(radius: 28, backgroundColor: Colors.white, child: Icon(Icons.person, size: 34, color: Color(0xFF2563EB))),
          const SizedBox(height: 8),
          Text(_nomAff(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          Text('${widget.user['email']}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ])),
        ListTile(leading: const Icon(Icons.home), title: const Text('Accueil'), onTap: () => Navigator.pop(context)),
        ListTile(leading: const Icon(Icons.search), title: const Text('Rechercher'), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen())); }),
        ListTile(leading: const Icon(Icons.nights_stay), title: const Text('Pharmacies de garde'), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const GardesScreen())); }),
        ListTile(leading: const Icon(Icons.shopping_cart), title: const Text('Mes reservations'), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const ReservationsScreen())); }),
      ])),
      body: loading ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(onRefresh: _load, child: ListView(padding: const EdgeInsets.all(16), children: [
        Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF7C3AED)]), borderRadius: BorderRadius.circular(12)), child: Column(children: [
          const Text('Bienvenue', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          Text('${_nomAff()}, trouvez vos medicaments facilement', style: const TextStyle(color: Colors.white70)),
        ])),
        const SizedBox(height: 16),
        ElevatedButton.icon(onPressed: _locate, icon: const Icon(Icons.my_location), label: Text(userPos == null ? 'Pharmacies pres de moi' : 'Position detectee - tri par distance'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), foregroundColor: Colors.white, padding: const EdgeInsets.all(16))),
        const SizedBox(height: 8),
        ..._sections(),
      ])),
    );
  }
}
