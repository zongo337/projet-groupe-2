import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';

class ReservationsScreen extends StatefulWidget {
  const ReservationsScreen({super.key});
  @override
  State<ReservationsScreen> createState() => _ReservationsScreenState();
}

class _ReservationsScreenState extends State<ReservationsScreen> {
  List reservations = [];
  bool loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => loading = true);
    final all = await ApiService.getReservations();
    final user = await ApiService.getUser();
    if (user != null) {
      final name = '${user['prenom'] ?? ''} ${user['nom'] ?? ''}'.trim();
      final mine = all.where((r) => r['patientNom'] == name).toList();
      reservations = mine.isNotEmpty ? mine : all;
    } else {
      reservations = all;
    }
    setState(() => loading = false);
  }

  Color _color(String s) {
    switch (s) {
      case 'EN_ATTENTE': return Colors.orange;
      case 'CONFIRMEE': return Colors.green;
      case 'PRETE': return Colors.blue;
      case 'RETIREE': return Colors.purple;
      case 'ANNULEE': return Colors.red;
      default: return Colors.grey;
    }
  }

  Future<void> _itineraire(dynamic pharmacie) async {
    final lat = pharmacie?['latitude'];
    final lng = pharmacie?['longitude'];
    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pharmacie sans coordonnées GPS')));
      return;
    }
    final uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _payer(dynamic r) async {
    String methode = 'ORANGE_MONEY';
    final telCtrl = TextEditingController();
    final montantCtrl = TextEditingController(text: '${r['prixTotal'] ?? ''}');

    final ok = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
      title: const Text('Paiement mobile'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Montant attendu : ${r['prixTotal']} FCFA', style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(value: methode, items: const [DropdownMenuItem(value: 'ORANGE_MONEY', child: Text('Orange Money')), DropdownMenuItem(value: 'MOOV_MONEY', child: Text('Moov Money'))], onChanged: (v) => setS(() => methode = v!), decoration: const InputDecoration(labelText: 'Methode de paiement')),
        TextField(controller: telCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Numero de paiement')),
        TextField(controller: montantCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Montant payé *')),
        const SizedBox(height: 8),
        const Text('Le montant saisi doit etre exactement egal au montant attendu.', style: TextStyle(fontSize: 12, color: Colors.grey)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Valider le paiement')),
      ],
    )));
    if (ok != true) return;

    final montantSaisi = double.tryParse(montantCtrl.text);
    final montantAttendu = double.tryParse('${r['prixTotal']}');
    if (montantSaisi == null || montantAttendu == null || montantSaisi != montantAttendu) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Montant incorrect. Montant attendu : ${r['prixTotal']} FCFA')));
      return;
    }

    final res = await ApiService.putReservation(r['id'], 'payer', {'methode': methode, 'telephone': telCtrl.text, 'montant': montantCtrl.text});
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.statusCode == 200 ? 'Paiement OK ! Code de retrait genere.' : 'Erreur paiement : montant incorrect ou deja paye.')));
    _load();
  }

  Future<void> _pdfRecu(dynamic r) async {
    await Printing.layoutPdf(format: PdfPageFormat.a5, onLayout: (PdfPageFormat format) async {
      final doc = pw.Document();
      doc.addPage(pw.Page(pageFormat: format, build: (context) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text('Pharma-Trouve BF', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
        pw.Text('RECU DE PAIEMENT / BON DE RETRAIT', style: pw.TextStyle(fontSize: 14)),
        pw.SizedBox(height: 12),
        pw.Text('Code retrait : ${r['codeRetrait']}', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 12),
        pw.Text('Patient : ${r['patientNom']}'),
        pw.Text('Medicament : ${r['medicament']?['nom']} x${r['quantite']}'),
        pw.Text('Pharmacie : ${r['pharmacie']?['nom']}'),
        pw.Text('Adresse : ${r['pharmacie']?['adresse']}'),
        pw.Text('Total paye : ${r['prixTotal']} FCFA'),
        pw.Text('Methode : ${r['methodePaiement']} ${r['telephonePaiement'] != null ? '(${r['telephonePaiement']})' : ''}'),
        pw.SizedBox(height: 12),
        pw.Text('Presentez ce code a la pharmacie pour retirer votre produit.'),
      ])));
      return doc.save();
    });
  }

  void _recu(dynamic r) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Recu de paiement'),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Code : ${r['codeRetrait']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFF7C3AED))),
        const SizedBox(height: 8),
        Text('Patient : ${r['patientNom']}'),
        Text('Medicament : ${r['medicament']?['nom']} x${r['quantite']}'),
        Text('Pharmacie : ${r['pharmacie']?['nom']}'),
        Text('Adresse : ${r['pharmacie']?['adresse'] ?? ''}'),
        Text('Total paye : ${r['prixTotal']} FCFA'),
        Text('Methode : ${r['methodePaiement']}'),
        const SizedBox(height: 8),
        const Text('Presentez ce code a la pharmacie.', style: TextStyle(fontSize: 12, color: Colors.grey)),
      ]),
      actions: [
        ElevatedButton(onPressed: () => _itineraire(r['pharmacie']), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), foregroundColor: Colors.white), child: const Text('Itineraire')),
        ElevatedButton(onPressed: () => _pdfRecu(r), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white), child: const Text('PDF')),
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer')),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mes reservations'), backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
      body: loading ? const Center(child: CircularProgressIndicator()) : reservations.isEmpty ? const Center(child: Text('Aucune reservation')) : RefreshIndicator(onRefresh: _load, child: ListView.builder(padding: const EdgeInsets.all(16), itemCount: reservations.length, itemBuilder: (ctx, i) {
        final r = reservations[i];
        return Card(margin: const EdgeInsets.only(bottom: 12), child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Expanded(child: Text('${r['medicament']?['nom'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF059669)))),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: _color('${r['statut']}'), borderRadius: BorderRadius.circular(12)), child: Text('${r['statut']}'.replaceAll('_', ' '), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
          ]),
          const SizedBox(height: 8),
          Text('Pharmacie : ${r['pharmacie']?['nom'] ?? ''}'),
          Text('${r['pharmacie']?['adresse'] ?? ''}'),
          Text('Quantite : ${r['quantite']}'),
          if (r['prixTotal'] != null) Text('Total : ${r['prixTotal']} FCFA', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (r['statutPaiement'] != 'PAYE')
            ElevatedButton(onPressed: () => _payer(r), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), foregroundColor: Colors.white), child: const Text('Payer (Orange / Moov Money)'))
          else ...[
            Text('Code retrait : ${r['codeRetrait']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF7C3AED))),
            const SizedBox(height: 4),
            Wrap(spacing: 8, children: [
              TextButton(onPressed: () => _recu(r), child: const Text('Voir le recu')),
              ElevatedButton.icon(onPressed: () => _itineraire(r['pharmacie']), icon: const Icon(Icons.directions, size: 16), label: const Text('Itineraire pour recuperer'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), foregroundColor: Colors.white)),
            ]),
          ],
          if (r['statut'] == 'ANNULEE')
            const Padding(padding: EdgeInsets.only(top: 8), child: Text('Reservation refusee par la pharmacie', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
          if (r['statut'] == 'CONFIRMEE')
            const Padding(padding: EdgeInsets.only(top: 8), child: Text('Reservation acceptee ! Preparez-vous a retirer.', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
          if (r['statut'] == 'RETIREE')
            const Text('Deja retiree - aucune nouvelle remise possible', style: TextStyle(color: Colors.purple, fontWeight: FontWeight.bold, fontSize: 12)),
        ])));
      })),
    );
  }
}
