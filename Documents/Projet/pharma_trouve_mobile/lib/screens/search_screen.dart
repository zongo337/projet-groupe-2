import 'package:flutter/material.dart';
import '../services/api_service.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  List medicaments = [];
  List stocks = [];
  String query = '';
  bool loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final r = await Future.wait([ApiService.getMedicaments(), ApiService.getStocks()]);
    setState(() { medicaments = r[0]; stocks = r[1]; loading = false; });
  }

  List _dispo(String medId) => stocks.where((s) => s['medicament']?['id'] == medId && s['enStock'] == true).toList();

  Future<void> _reserver(dynamic stock) async {
    final user = await ApiService.getUser();
    if (user == null) return;
    final ctrl = TextEditingController(text: '1');
    final q = await showDialog<int>(context: context, builder: (ctx) => AlertDialog(
      title: Text('Reserver ${stock['medicament']['nom']}'),
      content: TextField(controller: ctrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantite')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, int.tryParse(ctrl.text) ?? 1), child: const Text('Reserver')),
      ],
    ));
    if (q == null) return;
    final nomComplet = '${user['prenom'] ?? ''} ${user['nom'] ?? ''}'.trim();
    final res = await ApiService.createReservation({
      'pharmacieId': stock['pharmacie']['id'],
      'medicamentId': stock['medicament']['id'],
      'patientNom': nomComplet,
      'patientTelephone': user['telephone'] ?? '',
      'quantite': q,
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.statusCode == 200 || res.statusCode == 201 ? 'Reservation envoyee !' : 'Erreur reservation')));
  }

  @override
  Widget build(BuildContext context) {
    final q = query.toLowerCase();
    final filtered = q.isEmpty ? medicaments : medicaments.where((m) => (m['nom'] ?? '').toString().toLowerCase().contains(q) || (m['dci'] ?? '').toString().toLowerCase().contains(q) || (m['categorie'] ?? '').toString().toLowerCase().contains(q)).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Rechercher'), backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
      body: loading ? const Center(child: CircularProgressIndicator()) : Column(children: [
        Padding(padding: const EdgeInsets.all(16), child: TextField(decoration: const InputDecoration(hintText: 'Medicament, DCI, categorie...', prefixIcon: Icon(Icons.search), border: OutlineInputBorder()), onChanged: (v) => setState(() => query = v))),
        Expanded(child: ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: filtered.length, itemBuilder: (ctx, i) {
          final m = filtered[i];
          final dispo = _dispo(m['id']);
          return Card(margin: const EdgeInsets.only(bottom: 12), child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${m['nom']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
            Text('DCI : ${m['dci']}'),
            Text('${m['categorie'] ?? ''} ${m['dosage'] ?? ''}'),
            const SizedBox(height: 8),
            if (dispo.isEmpty) const Text('Indisponible', style: TextStyle(color: Colors.red)) else ...[
              Text('Disponible dans ${dispo.length} pharmacie(s)', style: const TextStyle(fontWeight: FontWeight.bold)),
              ...dispo.map((s) => Padding(padding: const EdgeInsets.only(top: 4), child: Row(children: [
                Expanded(child: Text('${s['pharmacie']['nom']} - ${s['prix']} FCFA')),
                ElevatedButton(onPressed: () => _reserver(s), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4)), child: const Text('Reserver')),
              ]))),
            ],
          ])));
        })),
      ]),
    );
  }
}
