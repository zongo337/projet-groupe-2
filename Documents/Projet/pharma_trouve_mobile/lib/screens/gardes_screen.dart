import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/api_service.dart';

class GardesScreen extends StatefulWidget {
  const GardesScreen({super.key});
  @override
  State<GardesScreen> createState() => _GardesScreenState();
}

class _GardesScreenState extends State<GardesScreen> {
  List gardes = [];
  List stocks = [];
  bool loading = true;
  dynamic userPos;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => loading = true);
    final r = await Future.wait([ApiService.getAllGardes(), ApiService.getStocks()]);
    gardes = r[0];
    stocks = r[1];
    setState(() => loading = false);
  }

  bool _estDuJour(dynamic g) {
    final now = DateTime.now();
    final d = DateTime(now.year, now.month, now.day);
    final deb = DateTime.parse(g['dateDebut'].toString());
    final fin = DateTime.parse(g['dateFin'].toString());
    return !deb.isAfter(d) && !fin.isBefore(d);
  }

  List _meds(String phaId) => stocks.where((s) => s['pharmacie']?['id'] == phaId && s['enStock'] == true).toList();

  Future<void> _locate() async {
    final p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) await Geolocator.requestPermission();
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

  @override
  Widget build(BuildContext context) {
    final list = [...gardes];
    list.sort((a, b) {
      final ta = _estDuJour(a) ? 0 : 1;
      final tb = _estDuJour(b) ? 0 : 1;
      if (ta != tb) return ta.compareTo(tb);
      return a['dateDebut'].toString().compareTo(b['dateDebut'].toString());
    });
    return Scaffold(
      appBar: AppBar(title: const Text('Pharmacies de garde'), backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
      body: loading ? const Center(child: CircularProgressIndicator()) : Column(children: [
        Padding(padding: const EdgeInsets.all(16), child: ElevatedButton.icon(onPressed: _locate, icon: const Icon(Icons.my_location), label: const Text('Gardes pres de moi'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), foregroundColor: Colors.white, padding: const EdgeInsets.all(16)))),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Align(alignment: Alignment.centerLeft, child: Text('Toutes les pharmacies en garde (${list.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)))),
        if (list.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Text('Aucune garde planifiee.', style: TextStyle(color: Colors.grey))),
        Expanded(child: ListView.builder(padding: const EdgeInsets.all(16), itemCount: list.length, itemBuilder: (ctx, i) {
          final g = list[i];
          final p = g['pharmacie'];
          final meds = _meds(p['id']);
          final d = userPos != null && p['latitude'] != null ? _dist(userPos.latitude, userPos.longitude, p['latitude'].toDouble(), p['longitude'].toDouble()) : null;
          return Card(margin: const EdgeInsets.only(bottom: 12), color: _estDuJour(g) ? const Color(0xFFE8F5E9) : Colors.white, child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text('${p['nom']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)))),
              if (_estDuJour(g)) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: const Color(0xFF059669), borderRadius: BorderRadius.circular(10)), child: const Text("AUJOURD'HUI", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
            ]),
            if (d != null) Text('a ${d.toStringAsFixed(1)} km', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF059669))),
            const SizedBox(height: 6),
            Text('${p['adresse']}'),
            Text('${p['ville'] ?? ''}'),
            Text('Tel : ${p['telephone'] ?? ''}'),
            Text('Du ${g['dateDebut']} au ${g['dateFin']}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 8),
            Text('Medicaments disponibles (${meds.length}) :', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            if (meds.isEmpty)
              const Text('Aucun medicament en stock.', style: TextStyle(fontSize: 12, color: Colors.grey))
            else
              ...meds.map((s) => Padding(padding: const EdgeInsets.only(top: 2), child: Text('${s['medicament']?['nom']} - ${s['prix']} FCFA', style: const TextStyle(fontSize: 12, color: Color(0xFF059669))))),
          ])));
        })),
      ]),
    );
  }
}
