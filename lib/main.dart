import 'dart:ui';
import 'dart:async';
import 'package:permission_handler/permission_handler.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'dart:convert';
import 'firebase_options.dart';
import 'dart:io';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Safe Firebase Initialization
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint("Firebase init note: $e");
  }

  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CocoTrade ERP',
      home: MainLayoutScreen(),
    ),
  );
}
class SmsQueueItem {
  String id;
  String phone;
  String message;
  String status; // 'PENDING', 'SENT', 'FAILED'
  String createdAt;

  SmsQueueItem({
    required this.id,
    required this.phone,
    required this.message,
    this.status = 'PENDING',
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'phone': phone,
    'message': message,
    'status': status,
    'createdAt': createdAt,
  };

  factory SmsQueueItem.fromJson(Map<String, dynamic> json) => SmsQueueItem(
    id: json['id'] ?? '',
    phone: json['phone'] ?? '',
    message: json['message'] ?? '',
    status: json['status'] ?? 'PENDING',
    createdAt: json['createdAt'] ?? '',
  );
}
// ---------------- DATA MODELS ----------------
class CompanyProfile {
  String name; String statementName; String tagline; String address; String phone; String invocation;
  CompanyProfile({
    this.name = 'SRI SAI COCONUTS', 
    this.statementName = 'SRI SAI COCONUTS',
    this.tagline = 'COCONUT EXPORTERS', 
    this.address = 'Kakinada, Kakinada Dist.,\nAP-533001', 
    this.phone = '09885551000', 
    this.invocation = 'Om Sri Ganesaya Namaha'
  });
  
  Map<String, dynamic> toJson() => {'name': name, 'statementName': statementName, 'tagline': tagline, 'address': address, 'phone': phone, 'invocation': invocation};
  
  factory CompanyProfile.fromJson(Map<String, dynamic> json) => CompanyProfile(
    name: json['name'] ?? 'SRI SAI COCONUTS', 
    statementName: json['statementName'] ?? json['name'] ?? 'SRI SAI COCONUTS',
    tagline: json['tagline'] ?? 'COCONUT EXPORTERS', 
    address: json['address'] ?? 'Kakinada, Kakinada Dist.,\nAP-533001', 
    phone: json['phone'] ?? '09885551000', 
    invocation: json['invocation'] ?? 'Om Sri Ganesaya Namaha'
  );
}

class TradeConfirmation {
  String id, date, seller, buyer, coconutType, status; double rate;
  TradeConfirmation({required this.id, required this.date, required this.seller, required this.buyer, required this.coconutType, required this.rate, this.status = 'PENDING'});
  Map<String, dynamic> toJson() => {'id': id, 'date': date, 'seller': seller, 'buyer': buyer, 'coconutType': coconutType, 'rate': rate, 'status': status};
  factory TradeConfirmation.fromJson(Map<String, dynamic> json) => TradeConfirmation(id: json['id'] ?? '', date: json['date'] ?? '', seller: json['seller'] ?? '', buyer: json['buyer'] ?? '', coconutType: json['coconutType'] ?? 'TENDER', rate: (json['rate'] as num?)?.toDouble() ?? 0, status: json['status'] ?? 'PENDING');
}

class Party {
  String name, type, phone, address;
  Party({required this.name, required this.type, required this.phone, required this.address});
  Map<String, dynamic> toJson() => {'name': name, 'type': type, 'phone': phone, 'address': address};
  factory Party.fromJson(Map<String, dynamic> json) => Party(name: json['name'] ?? '', type: json['type'] ?? 'BUYER', phone: json['phone'] ?? '', address: json['address'] ?? '');
}

class TruckEntry {
  String id, state, date, truck, supplier, buyer, transporter, type, remarks, invoiceNo;
  String sourceSeller;
  double qty, supplierBill, buyerBill, commission, transportExp, freight, advance, rate, bags, bagRate, loadRate, insurance, amc, loadManualAmt;
  bool isInvoice, isLoadManual;
  String updatedAt; // <-- ADD THIS

  DateTime? _cachedDt;
  DateTime get parsedDate => _cachedDt ??= _MainLayoutScreenState.parseFlexibleDate(date);

  TruckEntry({
    required this.id, required this.state, required this.date, required this.truck, required this.supplier, required this.buyer, required this.transporter, required this.type, required this.qty, required this.supplierBill, required this.buyerBill, required this.commission, required this.transportExp, required this.freight, required this.advance,
    this.sourceSeller = '',
    this.isInvoice = false, this.invoiceNo = '', this.rate = 0, this.bags = 0, this.bagRate = 0, this.loadRate = 0, this.insurance = 0, this.amc = 0, this.isLoadManual = false, this.loadManualAmt = 0, this.remarks = '',
    String? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now().toUtc().toIso8601String();

  double get balance => freight - advance;
  Map<String, dynamic> toJson() => {
    'id': id, 'state': state, 'date': date, 'truck': truck, 'supplier': supplier, 'buyer': buyer, 'transporter': transporter, 'type': type, 'qty': qty, 'supplierBill': supplierBill, 'buyerBill': buyerBill, 'commission': commission, 'transportExp': transportExp, 'freight': freight, 'advance': advance,
    'sourceSeller': sourceSeller,
    'isInvoice': isInvoice, 'invoiceNo': invoiceNo, 'rate': rate, 'bags': bags, 'bagRate': bagRate, 'loadRate': loadRate, 'insurance': insurance, 'amc': amc, 'isLoadManual': isLoadManual, 'loadManualAmt': loadManualAmt, 'remarks': remarks,
    'updatedAt': updatedAt, // <-- SERIALIZE
  };
  factory TruckEntry.fromJson(Map<String, dynamic> json) => TruckEntry(
    id: json['id'] ?? '', state: json['state'] ?? 'Andhra Pradesh', date: json['date'] ?? '', truck: json['truck'] ?? '', supplier: json['supplier'] ?? '', buyer: json['buyer'] ?? '', transporter: json['transporter'] ?? '', type: json['type'] ?? 'TENDER', qty: (json['qty'] as num?)?.toDouble() ?? 0, supplierBill: (json['supplierBill'] as num?)?.toDouble() ?? 0, buyerBill: (json['buyerBill'] as num?)?.toDouble() ?? 0, commission: (json['commission'] as num?)?.toDouble() ?? 0, transportExp: (json['transportExp'] as num?)?.toDouble() ?? 0, freight: (json['freight'] as num?)?.toDouble() ?? 0, advance: (json['advance'] as num?)?.toDouble() ?? 0,
    sourceSeller: json['sourceSeller'] ?? '',
    isInvoice: json['isInvoice'] ?? false, invoiceNo: json['invoiceNo'] ?? '', rate: (json['rate'] as num?)?.toDouble() ?? 0, bags: (json['bags'] as num?)?.toDouble() ?? 0, bagRate: (json['bagRate'] as num?)?.toDouble() ?? 0, loadRate: (json['loadRate'] as num?)?.toDouble() ?? 0, insurance: (json['insurance'] as num?)?.toDouble() ?? 0, amc: (json['amc'] as num?)?.toDouble() ?? 0, isLoadManual: json['isLoadManual'] ?? false, loadManualAmt: (json['loadManualAmt'] as num?)?.toDouble() ?? 0, remarks: json['remarks'] ?? '',
    updatedAt: json['updatedAt'] ?? DateTime.now().toUtc().toIso8601String(),
  );
}
class BankAccount {
  String id, name, account, ifsc, branch, note;
  BankAccount({required this.id, required this.name, required this.account, required this.ifsc, required this.branch, this.note = "Please Credit to our Account only"});
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'account': account, 'ifsc': ifsc, 'branch': branch, 'note': note};
  factory BankAccount.fromJson(Map<String, dynamic> json) => BankAccount(id: json['id'] ?? '', name: json['name'] ?? '', account: json['account'] ?? '', ifsc: json['ifsc'] ?? '', branch: json['branch'] ?? '', note: json['note'] ?? "Please Credit to our Account only");
}

class PaymentEntry {
  String id, state, type, seller, buyer, mode, date, truckId;
  double amount, transportReceived, settlement, commissionAdjusted;
  String updatedAt; // <-- ADD THIS
  DateTime? _cachedDt;
  DateTime get parsedDate => _cachedDt ??= _MainLayoutScreenState.parseFlexibleDate(date);

  PaymentEntry({
    required this.id,
    required this.state,
    required this.type,
    required this.seller,
    required this.buyer,
    required this.amount,
    required this.transportReceived,
    required this.settlement,
    this.commissionAdjusted = 0.0,
    required this.mode,
    required this.date,
    this.truckId = '',
    String? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now().toUtc().toIso8601String();

  String get party => type.contains("SELLER") ? seller : buyer;

  Map<String, dynamic> toJson() => {
    'id': id,
    'state': state,
    'type': type,
    'seller': seller,
    'buyer': buyer,
    'amount': amount,
    'transportReceived': transportReceived,
    'settlement': settlement,
    'commissionAdjusted': commissionAdjusted,
    'mode': mode,
    'date': date,
    'truckId': truckId,
    'updatedAt': updatedAt, // <-- SERIALIZE
  };

  factory PaymentEntry.fromJson(Map<String, dynamic> json) => PaymentEntry(
    id: json['id'] ?? '',
    state: json['state'] ?? 'Andhra Pradesh',
    type: json['type'] ?? 'PAYMENT TO SELLER',
    seller: json['seller'] ?? '',
    buyer: json['buyer'] ?? '',
    amount: (json['amount'] as num?)?.toDouble() ?? 0,
    transportReceived: (json['transportReceived'] as num?)?.toDouble() ?? 0,
    settlement: (json['settlement'] as num?)?.toDouble() ?? 0,
    commissionAdjusted: (json['commissionAdjusted'] as num?)?.toDouble() ?? 0,
    mode: json['mode'] ?? 'DIRECT',
    date: json['date'] ?? '',
    truckId: json['truckId'] ?? '',
    updatedAt: json['updatedAt'] ?? DateTime.now().toUtc().toIso8601String(),
  );
}

class TransportPayment {
  String id, state, transporter, bank, date, billMonth;
  double amount;

  TransportPayment({
    required this.id,
    required this.state,
    required this.transporter,
    required this.bank,
    required this.amount,
    required this.date,
    this.billMonth = '',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'state': state,
    'transporter': transporter,
    'bank': bank,
    'amount': amount,
    'date': date,
    'billMonth': billMonth,
  };

  factory TransportPayment.fromJson(Map<String, dynamic> json) => TransportPayment(
    id: json['id'] ?? '',
    state: json['state'] ?? 'Andhra Pradesh',
    transporter: json['transporter'] ?? '',
    bank: json['bank'] ?? '',
    amount: (json['amount'] as num?)?.toDouble() ?? 0,
    date: json['date'] ?? '',
    billMonth: json['billMonth'] ?? '',
  );
}

class GoodsItemController {
  final TextEditingController descCtrl, qtyCtrl, rateCtrl;
  GoodsItemController({String desc = 'COCONUT', String qty = '', String rate = ''})
      : descCtrl = TextEditingController(text: desc), qtyCtrl = TextEditingController(text: qty), rateCtrl = TextEditingController(text: rate);

  String get description => descCtrl.text.isEmpty ? 'COCONUT' : descCtrl.text.toUpperCase();
  double get qty => double.tryParse(qtyCtrl.text) ?? 0;
  double get rate => double.tryParse(rateCtrl.text) ?? 0;
  double calculateAmount(double divisor) {
    if (qty == 0 || rate == 0 || divisor == 0) return 0;
    return ((qty * rate) / divisor).ceilToDouble();
  }
  void dispose() { descCtrl.dispose(); qtyCtrl.dispose(); rateCtrl.dispose(); }
}

// ---------------- SECURITY & ENCRYPTION ----------------
class SecurityHelper {
  static final _key = enc.Key.fromUtf8('CocoTradeERP_SecureKey_2026_0907');
  
  static String encrypt(String rawData) {
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(_key));
    final encrypted = encrypter.encrypt(rawData, iv: iv);
    // Prepend IV base64 for decryption
    return '${iv.base64}:${encrypted.base64}';
  }

  static String decrypt(String encryptedBase64) {
    final parts = encryptedBase64.split(':');
    if (parts.length != 2) throw Exception("Invalid encrypted format");
    final iv = enc.IV.fromBase64(parts[0]);
    final encrypted = enc.Encrypted.fromBase64(parts[1]);
    final encrypter = enc.Encrypter(enc.AES(_key));
    return encrypter.decrypt(encrypted, iv: iv);
  }
}

// ---------------- LOCAL STORAGE MANAGER ----------------
class LocalDriveManager {
  static const String _prefCustomDirKey = 'cocotrade_custom_dir_path';
  static const String _folderName = 'CocoTradeData';
  static const String _fileName = 'cocotrade_master_db.json';

  static Future<File> getLocalDatabaseFile() async {
    final prefs = await SharedPreferences.getInstance();
    final customDir = prefs.getString(_prefCustomDirKey);
    if (customDir != null && customDir.isNotEmpty) {
      final customDirObj = Directory(customDir);
      if (!await customDirObj.exists()) await customDirObj.create(recursive: true);
      return File('${customDirObj.path}/$_fileName');
    }
    final docsDir = await getApplicationDocumentsDirectory();
    final dataDir = Directory('${docsDir.path}/$_folderName');
    if (!await dataDir.exists()) await dataDir.create(recursive: true);
    return File('${dataDir.path}/$_fileName');
  }

  static Future<void> writeToDrive(Map<String, dynamic> data) async {
    try {
      final file = await getLocalDatabaseFile();
      final jsonString = jsonEncode(data);
      // Write raw JSON directly to phone storage to guarantee cross-boot persistence
      await file.writeAsString(jsonString, flush: true);
    } catch (e) {
      debugPrint("Local database write failed: $e");
    }
  }

  static Future<Map<String, dynamic>?> readFromDrive() async {
    try {
      final file = await getLocalDatabaseFile();
      if (await file.exists()) {
        final content = (await file.readAsString()).trim();
        if (content.isEmpty) return null;

        if (content.startsWith('{')) {
          return jsonDecode(content) as Map<String, dynamic>;
        }
        // Fallback for older encrypted test files
        try {
          final decrypted = SecurityHelper.decrypt(content);
          return jsonDecode(decrypted) as Map<String, dynamic>;
        } catch (_) {
          return jsonDecode(content) as Map<String, dynamic>;
        }
      }
    } catch (e) {
      debugPrint("Error reading from local drive: $e");
    }
    return null;
  }
}

// ---------------- MAIN SCREEN WITH NEO-SAAS ARCHITECTURE ----------------
class MainLayoutScreen extends StatefulWidget {
  const MainLayoutScreen({super.key});
  @override
  State<MainLayoutScreen> createState() => _MainLayoutScreenState();
}
class PaymentSplitItem {
  final TextEditingController amtCtrl;
  String mode;

  PaymentSplitItem({String amount = '', this.mode = 'ICICI BANK'})
      : amtCtrl = TextEditingController(text: amount);

  double get parsedAmount {
    // Evaluates math expressions like 95000+25000+6000 directly inside the input
    final text = amtCtrl.text.replaceAll('₹', '').replaceAll(',', '').trim();
    if (text.isEmpty) return 0.0;
    if (text.contains('+')) {
      return text.split('+').fold<double>(0.0, (sum, part) => sum + (double.tryParse(part.trim()) ?? 0.0));
    }
    return double.tryParse(text) ?? 0.0;
  }

  void dispose() => amtCtrl.dispose();
}

class _MainLayoutScreenState extends State<MainLayoutScreen> {

  static const String _prefFirstLoginKey = 'auth_first_login_completed_v2';
  static const String _prefEmailKey = 'auth_user_email';
  static const String _prefPassKey = 'auth_user_password';
  static const String _prefPinKey = 'auth_user_pin';
  static const String _prefIsLicensedKey = 'auth_is_licensed_v1';
  static const String _prefLicenseKeyString = 'auth_license_key_string';
  StreamSubscription<QuerySnapshot>? _trucksSub;
  StreamSubscription<QuerySnapshot>? _paymentsSub;
  StreamSubscription<DocumentSnapshot>? _metadataSub;
  String _syncHealthStatus = 'CONNECTED'; // 'CONNECTED', 'QUEUED', 'ERROR'
  String _syncHealthLabel = 'Live Synced';
  Widget _buildSyncHealthBadge() {
    Color dotColor;
    String label;
    Color bgColor;

    switch (_syncHealthStatus) {
      case 'QUEUED':
        dotColor = const Color(0xFFF59E0B); // Amber
        label = 'Offline / Queued';
        bgColor = const Color(0xFFFEF3C7);
        break;
      case 'ERROR':
        dotColor = const Color(0xFFEF4444); // Red
        label = 'Sync Error';
        bgColor = const Color(0xFFFEE2E2);
        break;
      case 'SYNCED':
      default:
        dotColor = const Color(0xFF10B981); // Emerald Green
        label = 'Cloud Live';
        bgColor = const Color(0xFFECFDF5);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: dotColor.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: dotColor),
          ),
        ],
      ),
    );
  }
  void _showBulkPaymentAllocationDialog() {
    final bool isSeller = _payType.contains("SELLER");
    final sName = _paySeller.trim().toUpperCase();
    final bName = _payBuyer.trim().toUpperCase();

    final bool hasParty = isSeller ? (sName.isNotEmpty && sName != 'SELECT SELLER') : (bName.isNotEmpty && bName != 'SELECT BUYER');
    if (!hasParty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.red, content: Text('Please select a ${isSeller ? "Seller" : "Buyer"} first!')),
      );
      return;
    }

    final String partyName = isSeller ? sName : bName;
    final totalDepositCtrl = TextEditingController();
    final dateCtrl = TextEditingController(text: formatDisplayDate(DateTime.now().toIso8601String()));
    String mode = _payMode;

    // Retrieve open trucks for this party
    final openTrucks = _trucks.where((t) {
      final matchState = t.state == _selectedState;
      final matchParty = isSeller
          ? (t.supplier.toString().trim().toUpperCase() == partyName)
          : (t.buyer.toString().trim().toUpperCase() == partyName);
      final double bill = isSeller ? (t.supplierBill as num).toDouble() : (t.buyerBill > 0 ? t.buyerBill : t.supplierBill).toDouble();
      return matchState && matchParty && bill > 0;
    }).toList();

    // Map each truck to its remaining due
    List<Map<String, dynamic>> candidateAllocations = [];
    for (var t in openTrucks) {
      final double bill = isSeller ? (t.supplierBill as num).toDouble() : (t.buyerBill > 0 ? t.buyerBill : t.supplierBill).toDouble();
      final double alreadyPaid = _payments.where((p) => p.state == _selectedState && p.truckId.trim() == t.id.trim()).fold<double>(
        0.0,
        (sum, p) => sum + p.amount + p.settlement + p.commissionAdjusted,
      );
      final double remainingDue = (bill - alreadyPaid).clamp(0.0, double.infinity);
      if (remainingDue > 0.05) {
        candidateAllocations.add({
          'truck': t,
          'bill': bill,
          'due': remainingDue,
          'allocated': 0.0,
          'ctrl': TextEditingController(text: '0'),
          'selected': true,
        });
      }
    }

    candidateAllocations.sort((a, b) => _MainLayoutScreenState.parseFlexibleDate(a['truck'].date).compareTo(_MainLayoutScreenState.parseFlexibleDate(b['truck'].date)));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          void recalculateBulkDistribution() {
            double depositPool = parseMathExpression(totalDepositCtrl.text);
            for (var item in candidateAllocations) {
              if (item['selected'] == true && depositPool > 0) {
                double due = item['due'] as double;
                double alloc = depositPool >= due ? due : depositPool;
                item['allocated'] = alloc;
                item['ctrl'].text = alloc.toStringAsFixed(0);
                depositPool -= alloc;
              } else {
                item['allocated'] = 0.0;
                item['ctrl'].text = '0';
              }
            }
          }

          final double totalAssigned = candidateAllocations.fold<double>(0.0, (sum, i) => sum + (double.tryParse(i['ctrl'].text) ?? 0.0));
          final double depositTotal = parseMathExpression(totalDepositCtrl.text);
          final double unallocatedRemainder = (depositTotal - totalAssigned).clamp(0.0, double.infinity);

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.call_split_rounded, color: Color(0xFF047857)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Bulk Payment Allocation — $partyName', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                ),
              ],
            ),
            content: SizedBox(
              width: 580,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: _customField('Lump-Sum Deposit (₹)', totalDepositCtrl, isNum: true, onChanged: (_) {
                            setDlgState(() => recalculateBulkDistribution());
                          }),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: _customField('Date', dateCtrl, hint: 'DD-MM-YY'),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Mode', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                              const SizedBox(height: 5),
                              Container(
                                height: 40,
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFCBD5E1)),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _paymentModes.contains(mode) ? mode : _paymentModes.first,
                                    isExpanded: true,
                                    items: _paymentModes.map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 12)))).toList(),
                                    onChanged: (val) => setDlgState(() => mode = val!),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('Distribute Across Open Consignments:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 280),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: candidateAllocations.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                        itemBuilder: (c, idx) {
                          final item = candidateAllocations[idx];
                          final t = item['truck'];
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: item['selected'] as bool,
                                  activeColor: const Color(0xFF047857),
                                  onChanged: (v) {
                                    setDlgState(() {
                                      item['selected'] = v ?? false;
                                      recalculateBulkDistribution();
                                    });
                                  },
                                ),
                                Expanded(
                                    flex: 5,
                                    child: Builder(
                                      builder: (context) {
                                        final double currentAllocated = double.tryParse((item['ctrl'] as TextEditingController).text.trim()) ?? 0.0;
                                        final double baseDue = (item['due'] as num).toDouble();
                                        final double liveRemainingDue = (baseDue - currentAllocated).clamp(0.0, double.infinity);
                                        final bool isSettled = currentAllocated > 0 && liveRemainingDue <= 0.05;

                                        return Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            // Line 1: Date & Respective Party Name
                                            Text(
                                              isSeller
                                                  ? '${formatDisplayDate(t.date)} • Buyer: ${t.buyer.isNotEmpty ? t.buyer : "—"}'
                                                  : '${formatDisplayDate(t.date)} • Seller: ${t.supplier.isNotEmpty ? t.supplier : "—"}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w900,
                                                fontSize: 12.5,
                                                color: Color(0xFF0F172A),
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 3),
                                            // Line 2: Only Live Due & Bill Amount
                                            Row(
                                              children: [
                                                Text(
                                                  isSettled ? 'Due: ₹0 (SETTLED)' : 'Due: ${money(liveRemainingDue)}',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: isSettled
                                                        ? const Color(0xFF047857)
                                                        : (currentAllocated > 0 ? const Color(0xFFD97706) : const Color(0xFFDC2626)),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  '•  Bill: ${money(item['bill'])}',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFF64748B),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 120,
                                  height: 36,
                                  child: TextField(
                                    controller: item['ctrl'] as TextEditingController,
                                    keyboardType: TextInputType.number,
                                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                                    decoration: InputDecoration(
                                      prefixText: '₹ ',
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                    ),
                                    onChanged: (_) => setDlgState(() {}),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Allocated: ${money(totalAssigned)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          Text(
                            unallocatedRemainder > 0 ? 'On-Account Advance: ${money(unallocatedRemainder)}' : 'Fully Cleared',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: unallocatedRemainder > 0 ? const Color(0xFF047857) : const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF047857)),
                onPressed: () {
                  final nowMs = DateTime.now().millisecondsSinceEpoch;
                  final pDate = dateCtrl.text.trim();
                  int entriesCreated = 0;

                  setState(() {
                    _saveStateToHistory();

                    for (var item in candidateAllocations) {
                      double alloc = double.tryParse(item['ctrl'].text) ?? 0.0;
                      if (alloc > 0) {
                        _payments.add(PaymentEntry(
                          id: '${nowMs}_bulk_${entriesCreated++}',
                          state: _selectedState,
                          type: _payType,
                          seller: isSeller ? partyName : '',
                          buyer: isSeller ? '' : partyName,
                          amount: alloc,
                          transportReceived: 0,
                          settlement: 0,
                          mode: mode,
                          date: pDate,
                          truckId: item['truck'].id,
                        ));
                      }
                    }

                    // Remaining balance saved as unallocated deposit on-account
                    if (unallocatedRemainder > 0) {
                      _payments.add(PaymentEntry(
                        id: '${nowMs}_bulk_on_account',
                        state: _selectedState,
                        type: _payType,
                        seller: isSeller ? partyName : '',
                        buyer: isSeller ? '' : partyName,
                        amount: unallocatedRemainder,
                        transportReceived: 0,
                        settlement: 0,
                        mode: mode,
                        date: pDate,
                        truckId: '',
                      ));
                    }

                    _calculateOverdueBills(_trucks);
                  });

                  _commitToLocalDrive();
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(backgroundColor: const Color(0xFF047857), content: Text('Created $entriesCreated truck payments (${money(depositTotal)} allocated)!')),
                  );
                },
                child: const Text('Confirm & Save Bulk Allocation'),
              ),
            ],
          );
        },
      ),
    );
  }
  void _listenToCloudFirestore() {
    if (Firebase.apps.isEmpty) {
      debugPrint("Firebase not ready; skipping live Firestore listener.");
      setState(() {
        _syncHealthStatus = 'QUEUED';
        _syncHealthLabel = 'Offline Mode';
      });
      return;
    }
    final db = FirebaseFirestore.instance;

    _metadataSub = db.collection('app_metadata').doc('master_config').snapshots().listen((doc) {
      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _syncHealthStatus = 'CONNECTED';
          _syncHealthLabel = 'Live Synced';
          if (data['companyProfile'] != null) {
            _myCompany = CompanyProfile.fromJson(data['companyProfile']);
            _companyName = _myCompany.name;
          }
          if (data['parties'] != null) {
            _parties = (data['parties'] as List).map((i) => Party.fromJson(i)).toList();
          }
          if (data['bankAccounts'] != null) {
            _bankAccounts = (data['bankAccounts'] as List).map((i) => BankAccount.fromJson(i)).toList();
            if (_bankAccounts.isNotEmpty && !_bankAccounts.any((b) => b.id == _selectedBank.id)) {
              _selectedBank = _bankAccounts.first;
            }
          }
          if (data['transportPayments'] != null) {
            _transportPayments = (data['transportPayments'] as List).map((i) => TransportPayment.fromJson(i)).toList();
          }
          if (data['confirmations'] != null) {
            _confirmations = (data['confirmations'] as List).map((i) => TradeConfirmation.fromJson(i)).toList();
          }
          if (data['coconutTypes'] != null) {
            _coconutTypes = List<String>.from(data['coconutTypes']);
          }
          if (data['paymentModes'] != null) {
            _paymentModes = List<String>.from(data['paymentModes']);
          }
        });
      }
    }, onError: (e) {
      debugPrint("Firestore metadata stream error: $e");
      setState(() {
        _syncHealthStatus = 'ERROR';
        _syncHealthLabel = 'Sync Error';
      });
    });

    // Trucks stream with conflict resolution
    _trucksSub = db.collection('trucks').snapshots().listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        final Map<String, TruckEntry> currentTrucksMap = {
          for (var t in _trucks) (t as TruckEntry).id: t
        };

        for (var doc in snapshot.docs) {
          final remoteData = doc.data() as Map<String, dynamic>;
          final remoteEntry = TruckEntry.fromJson(remoteData);

          if (!currentTrucksMap.containsKey(remoteEntry.id)) {
            currentTrucksMap[remoteEntry.id] = remoteEntry;
          } else {
            // Conflict resolution: Last-Write-Wins via UTC ISO comparison
            final localEntry = currentTrucksMap[remoteEntry.id]!;
            final localTime = DateTime.tryParse(localEntry.updatedAt) ?? DateTime(1970);
            final remoteTime = DateTime.tryParse(remoteEntry.updatedAt) ?? DateTime(1970);

            if (remoteTime.isAfter(localTime) || remoteTime.isAtSameMomentAs(localTime)) {
              currentTrucksMap[remoteEntry.id] = remoteEntry;
            }
          }
        }

        setState(() {
          _syncHealthStatus = 'CONNECTED';
          _syncHealthLabel = 'Live Synced';
          _trucks = currentTrucksMap.values.toList();
          _calculateOverdueBills(_trucks);
        });
      }
    }, onError: (e) {
      debugPrint("Firestore trucks stream error: $e");
      setState(() {
        _syncHealthStatus = 'QUEUED';
        _syncHealthLabel = 'Offline Queued';
      });
    });

    // Payments stream with conflict resolution
    _paymentsSub = db.collection('payments').snapshots().listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        final Map<String, PaymentEntry> currentPaymentsMap = {
          for (var p in _payments) (p as PaymentEntry).id: p
        };

        for (var doc in snapshot.docs) {
          final remoteData = doc.data() as Map<String, dynamic>;
          final remoteEntry = PaymentEntry.fromJson(remoteData);

          if (!currentPaymentsMap.containsKey(remoteEntry.id)) {
            currentPaymentsMap[remoteEntry.id] = remoteEntry;
          } else {
            final localEntry = currentPaymentsMap[remoteEntry.id]!;
            final localTime = DateTime.tryParse(localEntry.updatedAt) ?? DateTime(1970);
            final remoteTime = DateTime.tryParse(remoteEntry.updatedAt) ?? DateTime(1970);

            if (remoteTime.isAfter(localTime) || remoteTime.isAtSameMomentAs(localTime)) {
              currentPaymentsMap[remoteEntry.id] = remoteEntry;
            }
          }
        }

        setState(() {
          _syncHealthStatus = 'CONNECTED';
          _syncHealthLabel = 'Live Synced';
          _payments = currentPaymentsMap.values.toList();
          _calculateOverdueBills(_trucks);
        });
      }
    }, onError: (e) {
      debugPrint("Firestore payments stream error: $e");
      setState(() {
        _syncHealthStatus = 'QUEUED';
        _syncHealthLabel = 'Offline Queued';
      });
    });
  }
  Future<void> _deleteDocumentFromFirestore(String collection, String id) async {
    try {
      await FirebaseFirestore.instance.collection(collection).doc(id).delete();
      debugPrint("Deleted $collection document $id from Firestore");
    } catch (e) {
      debugPrint("Error deleting $collection from Firestore: $e");
    }
  }
  @override
  void dispose() {
    _trucksSub?.cancel();
    _paymentsSub?.cancel();
    _saveDebounceTimer?.cancel();
    _metadataSub?.cancel();
    _cInvocationCtrl.dispose();
    _cStatementNameCtrl.dispose();
    _partySearchCtrl.dispose();
    _paySearchCtrl.dispose();
    super.dispose();
  }
  bool _dashShowQuickTrade = false;
  bool _dashShowOverdue = false;
  bool _isSidebarExpanded = true;
  bool _hideSettledEntries = false;
  bool _isLoading = true;
  bool _isFirstLoginDone = false;
  bool _isLicensed = false;
  bool _isLocked = true;
  bool _forceEmailLogin = false;
  bool _isProfileSetupDone = false;
  int _trialDaysLeft = 2;
  bool _isTrialExpired = false;
  bool _hasCustomBuyerBill = false;
  bool _invLoadingIsManual = false;
  String _invLoadingRegion = 'AP'; // 'AP' or 'TN' (₹650)
  final TextEditingController _invLoadingCtrl = TextEditingController(text: '650');

  String _companyName = "CocoTrade ERP";
  String _companyPhone = "";
  String _companyAddress = "";
  String _savedEmail = "admin@cocotrade.com";
  String _savedPassword = "admin123";
  String _savedPin = "1234";
  String _savedLicenseKey = "";
  String _selectedFinancialYear = "2026-2027";
  String? _customPdfSaveDir;
  final List<String> _financialYears = ["2024-2025", "2025-2026", "2026-2027", "2027-2028", "2028-2029"];
  String _selectedTransportMonth = "ALL MONTHS";
// SMS/WhatsApp Templates
  String _sellerMsgTemplate = "Trade Confirmed!\nDate: {date}\nBuyer: {buyer}\nCommodity: {type}\nRate: Rs. {rate}\n- {company}";
  String _buyerMsgTemplate = "Trade Confirmed!\nDate: {date}\nSeller: {seller}\nCommodity: {type}\nRate: Rs. {rate}\n- {company}";
  String _partyTypeFilter = 'ALL';
  String _lastSyncTime = 'Never';
  String _tSupplier = "", _tSourceSeller = "", _tBuyer = "", _tTransporter = "", _tCoconutType = "TENDER";
  final TextEditingController _cInvocationCtrl = TextEditingController();
  final TextEditingController _cStatementNameCtrl = TextEditingController();
  final _partySearchCtrl = TextEditingController();
  final TextEditingController _sellerMsgCtrl = TextEditingController();
  final TextEditingController _buyerMsgCtrl = TextEditingController();
  final TextEditingController _loginEmailCtrl = TextEditingController();
  final TextEditingController _loginPassCtrl = TextEditingController();
  final TextEditingController _licenseKeyCtrl = TextEditingController();
  final TextEditingController _pinCtrl = TextEditingController();
  final TextEditingController _settingsEmailCtrl = TextEditingController();
  final TextEditingController _settingsPassCtrl = TextEditingController();
  final TextEditingController _settingsPinCtrl = TextEditingController();
  final TextEditingController _cNameCtrl = TextEditingController();
  final TextEditingController _cTaglineCtrl = TextEditingController();
  final TextEditingController _cPhoneCtrl = TextEditingController();
  final TextEditingController _cAddressCtrl = TextEditingController();
  final _paySearchCtrl = TextEditingController();
  // Focus nodes for keyboard chaining
  final FocusNode _tSupplierFocus = FocusNode();
  final FocusNode _tBuyerFocus = FocusNode();
  final FocusNode _tTransporterFocus = FocusNode();
  final FocusNode _tQtyFocus = FocusNode();

  String _selectedTab = 'dashboard';
  String _selectedState = "Andhra Pradesh";
  String _reportsSelectedTab = 'buyer'; // 'buyer' or 'seller'
  CompanyProfile _myCompany = CompanyProfile();
  
  List<dynamic> _parties = [];
  List<dynamic> _trucks = [];
  List<dynamic> _confirmations = [];
  List<dynamic> _transportPayments = [];
  List<dynamic> _payments = [];
  List<dynamic> _overdueBills = [];
  List<String> _paymentModes = [
    "ICICI BANK",
    "DIRECT",
    "CASH",
    "KOTAK BANK",
    "STATE BANK OF INDIA",
    "SBI",
  ];
  List<String> _coconutTypes = ["TENDER", "WATER & DRY", "HUSKED", "UNHUSKED", "MATURE", "GOTTA", "BOMBAY CHEEL"];
  List<BankAccount> _bankAccounts = [
    BankAccount(id: '1', name: "STATE BANK OF INDIA", account: "30554488991", ifsc: "SBIN0000054", branch: "MAIN BRANCH"),
    BankAccount(id: '2', name: "ICICI BANK", account: "0280005500946", ifsc: "ICIC0000280", branch: "KAKINADA"),
  ];
  List<SmsQueueItem> _smsQueue = [];
  BankAccount _selectedBank = BankAccount(id: '1', name: "STATE BANK OF INDIA", account: "30554488991", ifsc: "SBIN0000054", branch: "MAIN BRANCH");

  final _confDateCtrl = TextEditingController();
  final _confRateCtrl = TextEditingController();
  String _confBuyer = "", _confSeller = "", _confCocotype = "TENDER";
  String get _confType => _confCocotype;
  set _confType(String v) => _confCocotype = v;

  final _tTruckCtrl = TextEditingController();
  final _tDateCtrl = TextEditingController();
  final _tRemarksCtrl = TextEditingController();
  final _tCommCtrl = TextEditingController(text: "500");
  final _tFreightCtrl = TextEditingController(text: "0");
  final _tQtyCtrl = TextEditingController(text: "0");
  final _tSBillCtrl = TextEditingController(text: "0");
  final _tBBillCtrl = TextEditingController(text: "0");
  final _tExpCtrl = TextEditingController(text: "0");
  final _tAdvCtrl = TextEditingController(text: "0");
 
  final _invNCtrl = TextEditingController(text: "INV-00001");
  TextEditingController get _iNoCtrl => _invNCtrl;
  final _iDateCtrl = TextEditingController();
  final _iPhoneCtrl = TextEditingController();
  final _iAddressCtrl = TextEditingController();
  final _iLorryCtrl = TextEditingController();
  final _iDriverCtrl = TextEditingController();
  String _iBuyer = "", _iSeller = "", _iTransporter = "", _iTerms = "CASH";
  double _iDivisor = 1000;
  bool _iLoadingManual = false;
  final List<GoodsItemController> _invoiceGoods = [];
  final _iLoadManualAmountCtrl = TextEditingController(text: "0");
  final _iLoadRateCtrl = TextEditingController(text: "0");
  final _iAmcCtrl = TextEditingController(text: "0");
  final _iInsCtrl = TextEditingController(text: "0");
  final _iCommCtrl = TextEditingController(text: "0");
  final _iAdvCtrl = TextEditingController(text: "0");
  final _iFreightCtrl = TextEditingController(text: "0");
  final _iBagRateCtrl = TextEditingController(text: "0");
  final _iBagsCtrl = TextEditingController(text: "0");
  final _iSellerAmountCtrl = TextEditingController(text: "0");
  final _iTransportExpCtrl = TextEditingController(text: "0");

  double get _invTotalGoodsQty => _invoiceGoods.fold(0, (s, it) => s + it.qty);
  double get _invTotalGoodsAmount => _invoiceGoods.fold(0, (s, it) => s + it.calculateAmount(_iDivisor));
  double get _invGunniesAmount => (double.tryParse(_iBagsCtrl.text) ?? 0) * (double.tryParse(_iBagRateCtrl.text) ?? 0);
  double get _invLoadingAmount => _iLoadingManual ? (double.tryParse(_iLoadManualAmountCtrl.text) ?? 0) : (_invTotalGoodsQty * (double.tryParse(_iLoadRateCtrl.text) ?? 0)) / 1000;
  double get _invAmc => double.tryParse(_iAmcCtrl.text) ?? 0;
  double get _invInsurance => double.tryParse(_iInsCtrl.text) ?? 0;
  double get _invCommission => double.tryParse(_iCommCtrl.text) ?? 0;
  double get _invAdvance => double.tryParse(_iAdvCtrl.text) ?? 0;
  double get _invFreight => double.tryParse(_iFreightCtrl.text) ?? 0;
  double get _invTotalCharges => _invGunniesAmount + _invLoadingAmount + _invAmc + _invInsurance + _invCommission + _invAdvance;
  double get _invGrandTotal => _invTotalGoodsAmount + _invTotalCharges;
  double get _invTruckBalance => _invFreight - _invAdvance;
  
  String _payType = "PAYMENT TO SELLER", _paySeller = "", _payBuyer = "", _payMode = "DIRECT";
  String _paySelectedTruckId = "";
  final _payTransportReceivedCtrl = TextEditingController(text: "0");
  final _payDateCtrl = TextEditingController();
  final _payAmountCtrl = TextEditingController(text: "0");
  final _paySettlementCtrl = TextEditingController(text: "0");
  final _payCommAdjustedCtrl = TextEditingController(text: "0");

  String _tpTransporter = "";
  final _tpBankCtrl = TextEditingController(text: "STATE BANK OF INDIA");
  final _tpDateCtrl = TextEditingController();

  String _analysisTransporter = "", _repSeller = "", _repSellerBuyerFilter = "", _repBuyer = "", _repBuyerSellerFilter = "";  
  final _repSellerFromCtrl = TextEditingController(), _repSellerToCtrl = TextEditingController(), _repSellerCommRateCtrl = TextEditingController(text: "70");
  final _repBuyerFromCtrl = TextEditingController(), _repBuyerToCtrl = TextEditingController();  
  double _repSellerCommDivisor = 1000;

  final _b1BagsCtrl = TextEditingController(text: "55"), _b1NutsCtrl = TextEditingController(text: "4400"), _b1WeightCtrl = TextEditingController(text: "25000"), _b1RateCtrl = TextEditingController(text: "40"), _b1LoadingRateCtrl = TextEditingController(text: "650"), _b1AmcCtrl = TextEditingController(text: "500"),_b1InsCtrl = TextEditingController(text: "300"), _b1CommCtrl = TextEditingController(text: "500"), _b1FreightCtrl = TextEditingController(text: "35000");
  String _b1LoadingType = "AP";

  final _b2QtyCtrl = TextEditingController(text: "30500"), _b2RateCtrl = TextEditingController(text: "2500"), _b2LoadRateCtrl = TextEditingController(text: "650"), _b2AmcCtrl = TextEditingController(text: "500"), _b2CommCtrl = TextEditingController(text: "1000"), _b2HamaliCtrl = TextEditingController(text: "300"), _b2BagRateCtrl = TextEditingController(text: "30"), _b2BagsCtrl = TextEditingController(text: "30"), _b2DivisorCtrl = TextEditingController(text: "1000"), _b2FreightCtrl = TextEditingController(text: "30000");
  bool _b2LoadingManual = false;
  final _b2LoadManualAmountCtrl = TextEditingController(text: "0");

  String? _editingTruckId;
  String? _editingInvoiceId;
  String? _editingPaymentId;
  bool get isMobile => MediaQuery.of(context).size.width < 600; // Android Phones
bool get isTablet => MediaQuery.of(context).size.width >= 600 && MediaQuery.of(context).size.width < 1100; // iPads
bool get isDesktop => MediaQuery.of(context).size.width >= 1100; // Windows PCs
  // Undo / Redo History Stacks (Storing JSON snapshots)
  final List<String> _undoStack = [];
  final List<String> _redoStack = [];
  static const int _maxHistorySize = 25;
// Helper to evaluate single numbers or math strings like "95000+25000+6000"
  static double parseMathExpression(String input) {
    final clean = input.replaceAll('₹', '').replaceAll(',', '').trim();
    if (clean.isEmpty) return 0.0;
    if (clean.contains('+')) {
      return clean.split('+').fold<double>(
        0.0,
        (sum, part) => sum + (double.tryParse(part.trim()) ?? 0.0),
      );
    }
    return double.tryParse(clean) ?? 0.0;
  }

  // Popup Dialog to add multiple payments / split modes (like "+ Add New Party")
  void _showAddMultiplePaymentsDialog() {
    final bool isSeller = _payType.contains("SELLER");
    final sName = _paySeller.trim().toUpperCase();
    final bName = _payBuyer.trim().toUpperCase();

    final bool hasSeller = sName.isNotEmpty && sName != 'SELECT SELLER';
    final bool hasBuyer = bName.isNotEmpty && bName != 'SELECT BUYER';

    // Either Seller or Buyer is enough
    if (!hasSeller && !hasBuyer) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text('Please select either Seller or Buyer before adding payments!'),
        ),
      );
      return;
    }

    final cleanSeller = hasSeller ? sName : "";
    final cleanBuyer = hasBuyer ? bName : "";
    final dateCtrl = TextEditingController(text: _payDateCtrl.text.trim());
    List<PaymentSplitItem> dialogLegs = [
      PaymentSplitItem(amount: '', mode: 'ICICI BANK'),
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          final double totalDialogAmount = dialogLegs.fold<double>(
            0.0,
            (sum, leg) => sum + leg.parsedAmount,
          );

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(
                  isSeller ? Icons.arrow_circle_up_rounded : Icons.arrow_circle_down_rounded,
                  color: const Color(0xFF047857),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isSeller ? 'Add Amount Paid (To Seller)' : 'Add Amount Received (From Buyer)',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 580,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Party Summary Banner
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Seller: $sName\nBuyer: $bName',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Color(0xFF1E293B)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Manual Date Input (No Calendar)
                    _customField('Payment Date (DD-MM-YY) *', dateCtrl, hint: 'DD-MM-YY'),
                    const SizedBox(height: 14),

                    // Payment Legs List
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Payment Amounts & Modes',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF64748B)),
                        ),
                        InkWell(
                          onTap: () {
                            setDlgState(() {
                              dialogLegs.add(PaymentSplitItem(amount: '', mode: 'DIRECT'));
                            });
                          },
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            child: Text(
                              '+ Add Another Payment / Mode',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    ...dialogLegs.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final leg = entry.value;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '#${idx + 1}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF475569)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Amount (Supports 95000 or 95000+25000 math typing)
                            Expanded(
                              flex: 5,
                              child: SizedBox(
                                height: 38,
                                child: TextField(
                                  controller: leg.amtCtrl,
                                  keyboardType: TextInputType.text,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                  decoration: InputDecoration(
                                    hintText: 'e.g. 95000 or 95000+6000',
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF047857), width: 1.5)),
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                  onChanged: (_) => setDlgState(() {}),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Mode Dropdown
                            Expanded(
                              flex: 5,
                              child: Container(
                                height: 38,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFCBD5E1)),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _paymentModes.contains(leg.mode)
                                        ? leg.mode
                                        : (_paymentModes.isNotEmpty ? _paymentModes.first : "DIRECT"),
                                    isExpanded: true,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                    items: _paymentModes
                                        .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                                        .toList(),
                                    onChanged: (val) {
                                      if (val != null) setDlgState(() => leg.mode = val);
                                    },
                                  ),
                                ),
                              ),
                            ),
                            if (dialogLegs.length > 1) ...[
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                tooltip: 'Remove',
                                onPressed: () {
                                  setDlgState(() {
                                    leg.dispose();
                                    dialogLegs.removeAt(idx);
                                  });
                                },
                              ),
                            ],
                          ],
                        ),
                      );
                    }),

                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total to Record:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF047857))),
                          Text(
                            money(totalDialogAmount),
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF047857)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  for (var l in dialogLegs) { l.dispose(); }
                  Navigator.pop(ctx);
                },
                child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF047857),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  final activeLegs = dialogLegs.where((l) => l.parsedAmount > 0).toList();
                  if (activeLegs.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(backgroundColor: Colors.red, content: Text('Please enter an amount!')),
                    );
                    return;
                  }

                  final baseId = DateTime.now().millisecondsSinceEpoch;
                  final pDate = dateCtrl.text.trim();

                  setState(() {
                    _saveStateToHistory();
                    for (int i = 0; i < activeLegs.length; i++) {
                      final leg = activeLegs[i];
                      _payments.add(PaymentEntry(
                        id: '${baseId}_$i',
                        state: _selectedState,
                        type: _payType,
                        seller: cleanSeller,
                        buyer: cleanBuyer,
                        amount: leg.parsedAmount,
                        transportReceived: 0,
                        settlement: 0,
                        commissionAdjusted: 0,
                        mode: leg.mode,
                        date: pDate,
                        truckId: _paySelectedTruckId,
                      ));
                    }
                    _clearPaymentForm();
                    _calculateOverdueBills(_trucks);
                  });

                  _commitToLocalDrive();
                  for (var l in dialogLegs) { l.dispose(); }
                  Navigator.pop(ctx);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: const Color(0xFF047857),
                      content: Text('Recorded ${activeLegs.length} payments totalling ${money(totalDialogAmount)}!'),
                    ),
                  );
                },
                child: const Text('Save & Record Payments'),
              ),
            ],
          );
        },
      ),
    );
  }
  // Single source of truth for Buyer Statement calculations across all screens & PDFs
  List<Map<String, dynamic>> _computeBuyerStatementRows({
    required String stateName,
    required String buyerName,
    String sellerFilter = '',
    String fromDate = '',
    String toDate = '',
  }) {
    final bool hasSpecificBuyer = buyerName.trim().isNotEmpty;
    final bClean = buyerName.trim().toUpperCase();
    final sClean = sellerFilter.trim().toUpperCase();

    final filteredTrucks = _trucks.where((t) {
      final matchesState = t.state == stateName;
      final matchesBuyer = !hasSpecificBuyer || t.buyer.toUpperCase() == bClean;
      final matchesSeller = sClean.isEmpty || t.supplier.toUpperCase() == sClean;
      final matchesFY = _isDateInFY(t.date, _selectedFinancialYear);
      final matchesRange = isDateInRange(t.date, fromDate, toDate);
      return matchesState && matchesBuyer && matchesSeller && matchesFY && matchesRange;
    }).toList();

    final Set<String> visibleTruckIds = filteredTrucks.map((t) => (t.id as String).trim()).toSet();

    final buyerPayments = _payments.where((p) {
      final matchesState = p.state == stateName;
      final matchesBuyer = !hasSpecificBuyer || p.buyer.toUpperCase() == bClean;
      final matchesSeller = sClean.isEmpty || p.seller.isEmpty || p.seller.toUpperCase() == sClean;
      final matchesFY = _isDateInFY(p.date, _selectedFinancialYear);
      final bool isLinkedToVisibleTruck = p.truckId.trim().isNotEmpty && visibleTruckIds.contains(p.truckId.trim());
      final matchesRange = isLinkedToVisibleTruck || isDateInRange(p.date, fromDate, toDate);
      final bool belongsToBuyer = p.buyer.trim().isNotEmpty && matchesBuyer;
      return matchesState && belongsToBuyer && matchesSeller && matchesFY && matchesRange;
    }).toList();

    final List<PaymentEntry> directPayments = [];
    final List<PaymentEntry> buyerAdvanceEntries = [];

    for (final p in buyerPayments) {
      final bool isPaymentToSeller = p.type.toUpperCase().contains("SELLER");

      // FIX: Only count payment to seller if buyer settled it directly (DIRECT mode)
      if (isPaymentToSeller) {
        if (p.mode == "DIRECT") {
          directPayments.add(p);
        }
      } else {
        if (p.mode == "DIRECT" || p.truckId.trim().isNotEmpty) {
          directPayments.add(p);
        } else {
          buyerAdvanceEntries.add(p);
        }
      }
    }

    // Chronological FIFO advance drawdown
    buyerAdvanceEntries.sort((a, b) => parseFlexibleDate(a.date).compareTo(parseFlexibleDate(b.date)));
    List<Map<String, dynamic>> advanceBuckets = [];
    for (var adv in buyerAdvanceEntries) {
      final double totalDeposit = adv.amount + adv.settlement;
      advanceBuckets.add({
        'entry': adv,
        'original': totalDeposit,
        'available': totalDeposit,
      });
    }

    final sortedTrucks = List<dynamic>.from(filteredTrucks)
      ..sort((a, b) => parseFlexibleDate(a.date).compareTo(parseFlexibleDate(b.date)));

    final List<Map<String, dynamic>> statementRows = [];
    for (final t in sortedTrucks) {
      final double billAmount = (t.buyerBill > 0 ? t.buyerBill : t.supplierBill).toDouble();
      final double qty = (t.qty as num?)?.toDouble() ?? 0.0;

      final matchedDirectList = directPayments.where((p) => p.truckId.trim() == t.id.trim()).toList();
      final double directPaid = matchedDirectList.fold<double>(0.0, (sum, p) => sum + p.amount + p.settlement);

      double remainingDue = (billAmount - directPaid).clamp(0.0, double.infinity);
      double advanceAdjusted = 0.0;
      List<String> advanceAuditTrails = [];

      if (hasSpecificBuyer && remainingDue > 0) {
        for (var b in advanceBuckets) {
          double avail = b['available'] as double;
          if (avail <= 0.05) continue;

          final advEntry = b['entry'] as PaymentEntry;
          final double origDeposit = b['original'] as double;
          final String dt = formatDisplayDate(advEntry.date);

          if (avail >= remainingDue) {
            b['available'] = avail - remainingDue;
            advanceAdjusted += remainingDue;
            advanceAuditTrails.add('Adv dt. $dt of ${money(origDeposit)} adj. ${money(remainingDue)}');
            remainingDue = 0.0;
            break;
          } else {
            advanceAdjusted += avail;
            remainingDue -= avail;
            b['available'] = 0.0;
            advanceAuditTrails.add('Adv dt. $dt of ${money(origDeposit)} adj. ${money(avail)}');
          }
        }
      }

      final double totalRowPaid = directPaid + advanceAdjusted;
      final double rowBalance = (billAmount - totalRowPaid).clamp(0.0, double.infinity);

      statementRows.add({
        'truck': t,
        'date': formatDisplayDate(t.date),
        'seller': t.supplier,
        'qty': numFmt(qty),
        'rawQty': qty,
        'bill': money(billAmount),
        'billAmount': billAmount,
        'directPaid': directPaid,
        'advanceAdjusted': advanceAdjusted,
        'advanceAuditTrails': advanceAuditTrails,
        'totalPaid': totalRowPaid,
        'balance': money(rowBalance),
        'rawBalance': rowBalance,
        'payments': matchedDirectList,
      });
    }

    return statementRows;
  }
 List<String> get _filteredPaymentBuyers {
    final seller = _paySeller.trim().toUpperCase();
    if (seller.isEmpty) {
      return _buyerNames; // Shows all buyers when no seller is selected
    }

    final linkedBuyers = <String>{};

    // Scan trucks for matching supplier/seller
    for (final t in _trucks) {
      final tSupplier = t.supplier.toString().trim().toUpperCase();
      final tBuyer = t.buyer.toString().trim().toUpperCase();
      if (tSupplier == seller && tBuyer.isNotEmpty && tBuyer != '—') {
        linkedBuyers.add(tBuyer);
      }
    }

    // Fall back to all registered buyers if no trade entries exist yet
    if (linkedBuyers.isEmpty) {
      return _buyerNames;
    }

    final result = linkedBuyers.toList()..sort();
    return result;
  }
  List<PaymentSplitItem> _paySplitLegs = [PaymentSplitItem(mode: 'ICICI BANK')];

  double get _totalPayingAmount =>
      _paySplitLegs.fold<double>(0.0, (sum, leg) => sum + leg.parsedAmount);

  void _addPaymentSplitLeg({String amount = '', String mode = 'DIRECT'}) {
    setState(() {
      final leg = PaymentSplitItem(amount: amount, mode: mode);
      leg.amtCtrl.addListener(() => setState(() {}));
      _paySplitLegs.add(leg);
    });
  }

  void _removePaymentSplitLeg(int index) {
    if (_paySplitLegs.length > 1) {
      setState(() {
        _paySplitLegs[index].dispose();
        _paySplitLegs.removeAt(index);
      });
    }
  }
  // 1. Edit grouped payments (supports math editing like 50000+25000+6000)
  void _editDayPaymentsGroup(List<PaymentEntry> dayPayments) {
    if (dayPayments.isEmpty) return;
    if (dayPayments.length == 1) {
      _editPaymentEntryDialog(dayPayments.first);
      return;
    }

    final String joinedAmounts = dayPayments.map((p) => p.amount.toStringAsFixed(0)).join('+');
    final amtCtrl = TextEditingController(text: joinedAmounts);
    final dateCtrl = TextEditingController(text: dayPayments.first.date);
    String mode = dayPayments.first.mode.trim().toUpperCase();
    if (mode.isEmpty) mode = "DIRECT";

    final List<String> availableModes = {
      ..._paymentModes.map((m) => m.trim().toUpperCase()),
      mode,
      "DIRECT",
      "CASH",
      "SBI",
      "STATE BANK OF INDIA",
      "ICICI BANK",
      "KOTAK BANK",
    }.where((m) => m.isNotEmpty).toList()..sort();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Edit Payment Group', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _customField('Amounts (Math: e.g. 50000+25000+6000)', amtCtrl),
                const SizedBox(height: 12),
                _customField('Date (DD-MM-YY)', dateCtrl, hint: 'DD-MM-YY'),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: availableModes.contains(mode) ? mode : availableModes.first,
                  items: availableModes
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setDlgState(() => mode = val);
                  },
                  decoration: InputDecoration(
                    labelText: 'Payment Mode',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF047857)),
              onPressed: () {
                final raw = amtCtrl.text.replaceAll('₹', '').replaceAll(',', '').trim();
                List<double> newAmts = [];
                if (raw.contains('+')) {
                  newAmts = raw.split('+').map((s) => double.tryParse(s.trim()) ?? 0.0).where((a) => a > 0).toList();
                } else {
                  final a = double.tryParse(raw) ?? 0.0;
                  if (a > 0) newAmts.add(a);
                }

                if (newAmts.isEmpty) return;

                final seller = dayPayments.first.seller;
                final buyer = dayPayments.first.buyer;
                final truckId = dayPayments.first.truckId;
                final type = dayPayments.first.type;
                final pDate = dateCtrl.text.trim();
                final baseId = DateTime.now().millisecondsSinceEpoch;

                setState(() {
                  _saveStateToHistory();
                  final oldIds = dayPayments.map((p) => p.id).toSet();
                  _payments.removeWhere((p) => oldIds.contains(p.id));

                  for (int i = 0; i < newAmts.length; i++) {
                    _payments.add(PaymentEntry(
                      id: '${baseId}_$i',
                      state: _selectedState,
                      type: type,
                      seller: seller,
                      buyer: buyer,
                      amount: newAmts[i],
                      transportReceived: 0,
                      settlement: 0,
                      commissionAdjusted: 0,
                      mode: mode,
                      date: pDate,
                      truckId: truckId,
                    ));
                  }
                  _calculateOverdueBills(_trucks);
                });

                _commitToLocalDrive();
                Navigator.pop(ctx);
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }
  Future<Uint8List> _generateConsolidatedBuyerPdfReport(
    PdfPageFormat format,
    String buyer,
    String sellerFilter,
  ) async {
    final pdf = pw.Document();
    const greenBorder = PdfColor.fromInt(0xFF4D8B61);
    const titleGreen = PdfColor.fromInt(0xFF126B35);
    const redAccent = PdfColor.fromInt(0xFFBD2020);

    // Use unified calculator for both states (Guarantees exact match with statements)
    final apRows = _computeBuyerStatementRows(
      stateName: "Andhra Pradesh",
      buyerName: buyer,
      sellerFilter: sellerFilter,
    );
    final tnRows = _computeBuyerStatementRows(
      stateName: "Tamil Nadu",
      buyerName: buyer,
      sellerFilter: sellerFilter,
    );

    final double apBill = apRows.fold(0.0, (s, r) => s + (r['billAmount'] as double));
    final double apPaid = apRows.fold(0.0, (s, r) => s + (r['totalPaid'] as double));
    final double apBal = (apBill - apPaid).clamp(0.0, double.infinity);

    final double tnBill = tnRows.fold(0.0, (s, r) => s + (r['billAmount'] as double));
    final double tnPaid = tnRows.fold(0.0, (s, r) => s + (r['totalPaid'] as double));
    final double tnBal = (tnBill - tnPaid).clamp(0.0, double.infinity);

    final double grandBilled = apBill + tnBill;
    final double grandPaid = apPaid + tnPaid;
    final double grandBalance = (grandBilled - grandPaid).clamp(0.0, double.infinity);

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      build: (ctx) => [
        pw.Center(
          child: pw.Text(
            _myCompany.statementName.isNotEmpty ? _myCompany.statementName.toUpperCase() : _myCompany.name.toUpperCase(),
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: titleGreen),
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Center(child: pw.Text('CONSOLIDATED STATEMENT OF ACCOUNT (AP & TN)', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
        pw.SizedBox(height: 4),
        pw.Center(child: pw.Text('BUYER: ${buyer.toUpperCase()}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: titleGreen))),
        pw.SizedBox(height: 8),

        // Section A: Andhra Pradesh
        if (apRows.isNotEmpty) ...[
          pw.Container(
            padding: const pw.EdgeInsets.all(4),
            color: const PdfColor.fromInt(0xFFEBF5EE),
            child: pw.Text('ANDHRA PRADESH CONSIGNMENTS', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: titleGreen)),
          ),
          pw.Table(
            border: pw.TableBorder.all(color: greenBorder, width: 0.8),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF2F7F3)),
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('DATE', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                  pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('SELLER', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                  pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('QTY', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                  pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('BILL (Rs)', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                  pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('PAID (Rs)', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                  pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('BAL (Rs)', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                ],
              ),
              ...apRows.map((r) => pw.TableRow(children: [
                pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(r['date'], style: const pw.TextStyle(fontSize: 8))),
                pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(r['seller'], style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(r['qty'], textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8))),
                pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(pdfMoney(r['billAmount']), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8))),
                pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(pdfMoney(r['totalPaid']), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8))),
                pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(pdfMoney(r['rawBalance']), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
              ])),
            ],
          ),
          pw.SizedBox(height: 10),
        ],

        // Section B: Tamil Nadu
        if (tnRows.isNotEmpty) ...[
          pw.Container(
            padding: const pw.EdgeInsets.all(4),
            color: const PdfColor.fromInt(0xFFEFF6FF),
            child: pw.Text('TAMIL NADU CONSIGNMENTS', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF1D4ED8))),
          ),
          pw.Table(
            border: pw.TableBorder.all(color: greenBorder, width: 0.8),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF2F7F3)),
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('DATE', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                  pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('SELLER', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                  pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('QTY', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                  pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('BILL (Rs)', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                  pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('PAID (Rs)', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                  pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('BAL (Rs)', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                ],
              ),
              ...tnRows.map((r) => pw.TableRow(children: [
                pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(r['date'], style: const pw.TextStyle(fontSize: 8))),
                pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(r['seller'], style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(r['qty'], textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8))),
                pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(pdfMoney(r['billAmount']), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8))),
                pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(pdfMoney(r['totalPaid']), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8))),
                pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(pdfMoney(r['rawBalance']), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
              ])),
            ],
          ),
          pw.SizedBox(height: 12),
        ],

        // Consolidated Summary Box
        pw.Container(
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            color: const PdfColor.fromInt(0xFFF8FAFC),
            border: pw.Border.all(color: greenBorder, width: 1.2),
          ),
          child: pw.Column(
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('AP Total Due: Rs. ${pdfMoney(apBal)}', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                  pw.Text('TN Total Due: Rs. ${pdfMoney(tnBal)}', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.Divider(color: greenBorder, height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('COMBINED TOTAL BILLED : Rs. ${pdfMoney(grandBilled)}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  pw.Text('OVERALL NET OUTSTANDING: Rs. ${pdfMoney(grandBalance)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: titleGreen)),
                ],
              ),
            ],
          ),
        ),
      ],
    ));
    return pdf.save();
  }
// FEATURE 6: Save PDF directly to user-selected Windows directory or share via Android
  Future<void> _exportPdfToCustomDirOrShare({
    required BuildContext context,
    required String fileName,
    required Uint8List pdfBytes,
  }) async {
    if (!kIsWeb && Platform.isWindows) {
      String targetDir = _customPdfSaveDir ?? '';
      if (targetDir.isEmpty || !await Directory(targetDir).exists()) {
        final docs = await getApplicationDocumentsDirectory();
        final defaultFolder = Directory('${docs.path}\\CocoTrade_PDFs');
        if (!await defaultFolder.exists()) await defaultFolder.create(recursive: true);
        targetDir = defaultFolder.path;
      }

      final String fullPath = '$targetDir\\$fileName';
      final file = File(fullPath);
      await file.writeAsBytes(pdfBytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF047857),
            duration: const Duration(seconds: 5),
            content: Text('Saved to: $fullPath'),
            action: SnackBarAction(
              label: 'Open Folder',
              textColor: Colors.white,
              onPressed: () => Process.run('explorer.exe', [targetDir]),
            ),
          ),
        );
      }
    } else {
      // Android: Native Share / WhatsApp Drawer
      await Printing.sharePdf(bytes: pdfBytes, filename: fileName);
    }
  }
  // 2. Delete all payment legs belonging to the group in one click
  Future<void> _deleteDayPaymentsGroup(List<PaymentEntry> dayPayments, double total, String dateStr) async {
    if (dayPayments.isEmpty) return;
    if (await _confirmDelete(context, "Payment of ${money(total)} on $dateStr")) {
      setState(() {
  _saveStateToHistory();
  final idsToDelete = dayPayments.map((p) => p.id).toSet();
  _payments.removeWhere((p) => idsToDelete.contains(p.id));
  _calculateOverdueBills(_trucks);
});
for (var p in dayPayments) {
  _deleteDocumentFromFirestore('payments', p.id);
}
_commitToLocalDrive();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF047857),
            content: Text('Deleted payment of ${money(total)}.'),
          ),
        );
      }
    }
  } 
  // Breakdown dialog showing itemized installments and advance drawdowns
  void _showPaymentBreakdownDialog(
    List<PaymentEntry> dayPayments,
    String dateStr,
    double total, {
    double advanceAdjusted = 0.0,
    List<String>? advanceAuditTrails,
  }) {
    if (dayPayments.isEmpty && advanceAdjusted <= 0) return;

    final firstP = dayPayments.isNotEmpty ? dayPayments.first : null;
    final String sellerDisplay = firstP?.seller ?? _repBuyerSellerFilter;
    final String buyerDisplay = firstP?.buyer ?? _repBuyer;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        title: Row(
          children: [
            const Icon(Icons.receipt_long_rounded, color: Color(0xFF047857), size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                dateStr.isNotEmpty && dateStr != '—'
                    ? 'Payment Breakdown ($dateStr)'
                    : 'Payment Breakdown',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF0F172A)),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: isMobile ? MediaQuery.of(context).size.width : 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Party Info Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (sellerDisplay.isNotEmpty)
                      Text(
                        'Seller: $sellerDisplay',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (sellerDisplay.isNotEmpty && buyerDisplay.isNotEmpty)
                      const SizedBox(height: 3),
                    if (buyerDisplay.isNotEmpty)
                      Text(
                        'Buyer: $buyerDisplay',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Itemized Installments:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 8),

              // Installment List (Direct Payments + Advance Drawdown)
              Container(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.38),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    // A. Direct Payments
                    ...dayPayments.asMap().entries.map((entry) {
                      final i = entry.key;
                      final p = entry.value;
                      final pDate = formatDisplayDate(p.date);

                      // FEATURE 7: Clean formatting for zero-amount discount
                      String displayAmt;
                      String subtitleText;
                      if (p.amount <= 0 && p.settlement > 0) {
                        displayAmt = 'Disc ${money(p.settlement)}';
                        subtitleText = '$pDate • SETTLEMENT / DISCOUNT';
                      } else if (p.amount > 0 && p.settlement > 0) {
                        displayAmt = money(p.amount);
                        subtitleText = '$pDate • ${p.mode} + Disc ${money(p.settlement)}';
                      } else {
                        displayAmt = money(p.amount);
                        subtitleText = '$pDate • ${p.mode}';
                      }

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: const BoxDecoration(
                          border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: const Color(0xFFECFDF5),
                              child: Text(
                                '${i + 1}',
                                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: Color(0xFF047857)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    displayAmt,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13.5,
                                      color: Color(0xFF047857),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    subtitleText,
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            InkWell(
                              borderRadius: BorderRadius.circular(6),
                              onTap: () {
                                Navigator.pop(ctx);
                                _editPaymentEntryDialog(p);
                              },
                              child: const Padding(
                                padding: EdgeInsets.all(5),
                                child: Icon(Icons.edit_outlined, size: 17, color: Color(0xFF047857)),
                              ),
                            ),
                            const SizedBox(width: 4),
                            InkWell(
                              borderRadius: BorderRadius.circular(6),
                              onTap: () async {
                                if (await _confirmDelete(context, "Payment leg of ${money(p.amount)}")) {
                                  setState(() {
  _saveStateToHistory();
  _payments.removeWhere((item) => item.id == p.id);
  _calculateOverdueBills(_trucks);
});
_deleteDocumentFromFirestore('payments', p.id);
_commitToLocalDrive();
Navigator.pop(ctx);
                                }
                              },
                              child: const Padding(
                                padding: EdgeInsets.all(5),
                                child: Icon(Icons.delete_outline, size: 17, color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),

                    // B. FEATURE 4: Advance Drawdown Row
                    if (advanceAdjusted > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        color: const Color(0xFFEFF6FF),
                        child: Row(
                          children: [
                            const CircleAvatar(
                              radius: 12,
                              backgroundColor: Color(0xFFDBEAFE),
                              child: Icon(Icons.account_balance_wallet_rounded, size: 13, color: Color(0xFF1D4ED8)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Adv Adj: ${money(advanceAdjusted)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13.5,
                                      color: Color(0xFF1D4ED8),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    advanceAuditTrails != null && advanceAuditTrails.isNotEmpty
                                        ? advanceAuditTrails.join(' • ')
                                        : 'Settled from Unallocated Advance Deposit',
                                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Total Settled Summary
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Settled:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF047857))),
                    Text(
                      money(total),
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF047857)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
          ),
          if (dayPayments.isNotEmpty)
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF047857),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.edit, size: 14),
              label: const Text('Edit All'),
              onPressed: () {
                Navigator.pop(ctx);
                _editDayPaymentsGroup(dayPayments);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSingleLinePaidDetailsCell(
    List<dynamic> pList, {
    double advanceAdjusted = 0.0,
    List<String>? advanceAuditTrails,
  }) {
    final double totalDirect = pList.fold<double>(
      0.0,
      (s, p) => s + (p.amount as num).toDouble() + (p.settlement as num).toDouble() + (p.commissionAdjusted as num).toDouble(),
    );
    final double totalRowPaid = totalDirect + advanceAdjusted;

    if (totalRowPaid <= 0 && pList.isEmpty) {
      return const Text('—', style: TextStyle(color: Colors.grey, fontSize: 12));
    }

    final sortedPayments = List<PaymentEntry>.from(pList.cast<PaymentEntry>())
      ..sort((a, b) => parseFlexibleDate(a.date).compareTo(parseFlexibleDate(b.date)));

    final int paymentCount = sortedPayments.length + (advanceAdjusted > 0 ? 1 : 0);
    final bool isMultiSplit = paymentCount > 1;

    // Single payment summary text with zero-amount discount support (Feature 7)
    String mainText;
    if (!isMultiSplit && sortedPayments.isNotEmpty) {
      final p = sortedPayments.first;
      if (p.amount <= 0 && p.settlement > 0) {
        mainText = 'Disc ${money(p.settlement)} on ${formatDisplayDate(p.date)}';
      } else {
        mainText = '${money(p.amount)} (${p.mode}) on ${formatDisplayDate(p.date)}';
      }
    } else if (!isMultiSplit && advanceAdjusted > 0) {
      mainText = 'Adv Adj: ${money(advanceAdjusted)}';
    } else {
      mainText = '${money(totalRowPaid)} ($paymentCount Payments)';
    }

    // Build Excel Yellow Note Lines
    final List<InlineSpan> noteLines = [
      TextSpan(
        text: 'NOTE: Payment Breakdown (Total: ${money(totalRowPaid)})\n',
        style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF78350F), fontSize: 11),
      ),
      const TextSpan(text: '──────────────────────────────────\n', style: TextStyle(color: Color(0xFFD97706), fontSize: 9)),
    ];

    for (int i = 0; i < sortedPayments.length; i++) {
      final p = sortedPayments[i];
      final dt = formatDisplayDate(p.date);

      // FEATURE 7: Output Disc directly if principal amount is 0
      String pDesc;
      if (p.amount <= 0 && p.settlement > 0) {
        pDesc = 'Disc ${money(p.settlement)}';
      } else if (p.amount > 0 && p.settlement > 0) {
        pDesc = '${money(p.amount)} (${p.mode}) + Disc ${money(p.settlement)}';
      } else {
        pDesc = '${money(p.amount)} (${p.mode})';
      }

      noteLines.add(
        TextSpan(
          text: '${i + 1}. $dt: $pDesc\n',
          style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF451A03), fontSize: 11),
        ),
      );
    }

    // FEATURE 4: Advance Drawdown entry in yellow note
    if (advanceAdjusted > 0) {
      noteLines.add(
        TextSpan(
          text: '• Advance Drawdown: ${money(advanceAdjusted)}\n',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8), fontSize: 11),
        ),
      );
      if (advanceAuditTrails != null && advanceAuditTrails.isNotEmpty) {
        for (var trail in advanceAuditTrails) {
          noteLines.add(
            TextSpan(
              text: '   ↳ $trail\n',
              style: const TextStyle(fontSize: 9.5, fontStyle: FontStyle.italic, color: Color(0xFF2563EB)),
            ),
          );
        }
      }
    }

    noteLines.addAll([
      const TextSpan(text: '──────────────────────────────────\n', style: TextStyle(color: Color(0xFFD97706), fontSize: 9)),
      TextSpan(
        text: 'TOTAL CLEARED: ${money(totalRowPaid)}',
        style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF92400E), fontSize: 11.5),
      ),
    ]);

    Widget noteWidget = Tooltip(
      triggerMode: TooltipTriggerMode.tap,
      waitDuration: const Duration(milliseconds: 50),
      showDuration: const Duration(seconds: 15),
      preferBelow: false,
      verticalOffset: 12,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF9C3),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFF59E0B), width: 1.2),
        boxShadow: const [
          BoxShadow(color: Color(0x26000000), blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      richMessage: TextSpan(children: noteLines),
      child: MouseRegion(
        cursor: isMultiSplit ? SystemMouseCursors.help : SystemMouseCursors.basic,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: isMultiSplit
              ? () => _showPaymentBreakdownDialog(
                    sortedPayments,
                    sortedPayments.isNotEmpty ? formatDisplayDate(sortedPayments.last.date) : 'History',
                    totalRowPaid,
                    advanceAdjusted: advanceAdjusted,
                    advanceAuditTrails: advanceAuditTrails,
                  )
              : null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isMultiSplit)
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: const BoxDecoration(
                    color: Color(0xFFDC2626),
                    shape: BoxShape.circle,
                  ),
                ),
              Flexible(
                child: Text(
                  mainText,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                    color: advanceAdjusted > 0 && sortedPayments.isEmpty
                        ? const Color(0xFF1D4ED8)
                        : const Color(0xFF047857),
                    decoration: isMultiSplit ? TextDecoration.underline : TextDecoration.none,
                    decorationStyle: TextDecorationStyle.dotted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          noteWidget,
          if (sortedPayments.isNotEmpty) ...[
            const SizedBox(width: 6),
            InkWell(
              onTap: () {
                if (paymentCount > 1) {
                  _showPaymentBreakdownDialog(
                    sortedPayments,
                    sortedPayments.isNotEmpty ? formatDisplayDate(sortedPayments.last.date) : 'History',
                    totalRowPaid,
                    advanceAdjusted: advanceAdjusted,
                    advanceAuditTrails: advanceAuditTrails,
                  );
                } else if (sortedPayments.isNotEmpty) {
                  _editPaymentEntryDialog(sortedPayments.first);
                }
              },
              child: const Padding(
                padding: EdgeInsets.all(2.5),
                child: Icon(Icons.edit_outlined, size: 14, color: Color(0xFF047857)),
              ),
            ),
            const SizedBox(width: 3),
            InkWell(
              onTap: () => _deleteDayPaymentsGroup(
                sortedPayments,
                totalDirect,
                formatDisplayDate(sortedPayments.first.date),
              ),
              child: const Padding(
                padding: EdgeInsets.all(2.5),
                child: Icon(Icons.delete_outline, size: 14, color: Colors.red),
              ),
            ),
          ],
        ],
      ),
    );
  }
 Widget _buildHideSwitch() {
    return GestureDetector(
      onTap: () => setState(() => _hideSettledEntries = !_hideSettledEntries),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 72,
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: _hideSettledEntries ? const Color(0xFF047857) : const Color(0xFFE2E8F0),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: _hideSettledEntries ? Alignment.centerLeft : Alignment.centerRight,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: _hideSettledEntries ? 10 : 8),
                child: Text(
                  _hideSettledEntries ? 'HIDE' : 'SHOW',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            AnimatedAlign(
              duration: const Duration(milliseconds: 200),
              alignment: _hideSettledEntries ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 2))],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
 void _calculateInvoiceTotals() {
    setState(() {
      // Triggers rebuild; your getters (_invTotalGoodsQty, _invGunniesAmount,
      // _invLoadingAmount, _invGrandTotal, etc.) automatically compute live.
    });
  }
  void _saveStateToHistory() {
    try {
      final currentJson = _generateFullDatabaseJson();
      if (_undoStack.isEmpty || _undoStack.last != currentJson) {
        _undoStack.add(currentJson);
        if (_undoStack.length > _maxHistorySize) {
          _undoStack.removeAt(0);
        }
        _redoStack.clear(); // Clear redo on new actions
      }
    } catch (e) {
      debugPrint("Error saving state to history: $e");
    }
  }

  void _undo() {
    if (_undoStack.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nothing to undo!'), duration: Duration(milliseconds: 1000)),
      );
      return;
    }
    try {
      final currentJson = _generateFullDatabaseJson();
      _redoStack.add(currentJson);

      final previousJson = _undoStack.removeLast();
      final decoded = jsonDecode(previousJson) as Map<String, dynamic>;
      
      _applyStateFromMap(decoded);
      _calculateOverdueBills(_trucks);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: Color(0xFF047857), content: Text('Undo successful! (Ctrl+Z)'), duration: Duration(milliseconds: 1200)),
      );
    } catch (e) {
      debugPrint("Undo error: $e");
    }
  }

  void _redo() {
    if (_redoStack.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nothing to redo!'), duration: Duration(milliseconds: 1000)),
      );
      return;
    }
    try {
      final currentJson = _generateFullDatabaseJson();
      _undoStack.add(currentJson);

      final nextJson = _redoStack.removeLast();
      final decoded = jsonDecode(nextJson) as Map<String, dynamic>;

      _applyStateFromMap(decoded);
      _calculateOverdueBills(_trucks);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: Color(0xFF047857), content: Text('Redo successful! (Ctrl+Y)'), duration: Duration(milliseconds: 1200)),
      );
    } catch (e) {
      debugPrint("Redo error: $e");
    }
  }
void _loadPaymentIntoForm(PaymentEntry p) {
    setState(() {
      _selectedTab = 'payments';
      _editingPaymentId = p.id;
      _payType = p.type;
      _paySeller = p.seller;
      _payBuyer = p.buyer;
      _payAmountCtrl.text = p.amount > 0 ? p.amount.toStringAsFixed(0) : '0';
      _payTransportReceivedCtrl.text = p.transportReceived > 0 ? p.transportReceived.toStringAsFixed(0) : '0';
      _paySettlementCtrl.text = p.settlement > 0 ? p.settlement.toStringAsFixed(0) : '0';
      _payCommAdjustedCtrl.text = p.commissionAdjusted > 0 ? p.commissionAdjusted.toStringAsFixed(0) : '0';
      _payMode = ["DIRECT", "CASH", "ICICI BANK", "KOTAK BANK", "STATE BANK OF INDIA"].contains(p.mode) ? p.mode : "DIRECT";
      _payDateCtrl.text = p.date;
      _paySelectedTruckId = p.truckId;
      _saveStateToHistory();
    });
  }

  void _clearPaymentForm() {
    setState(() {
      _editingPaymentId = null;
      _payAmountCtrl.clear();
      _payTransportReceivedCtrl.text = "0";
      _paySettlementCtrl.text = "0";
      _payCommAdjustedCtrl.text = "0";
      _paySeller = "";
      _payBuyer = "";
      _paySelectedTruckId = "";
    });
  }
 @override
  void initState() {
    super.initState();
    _initializeAppData();
    _listenToCloudFirestore(); // Starts live Firestore sync
  }

 
  static const MethodChannel _nativeSmsChannel = MethodChannel('com.cocotrade.sms/dispatch');
  
Future<void> _recordSyncTimestamp() async {
  final now = DateTime.now();
  final dd = now.day.toString().padLeft(2, '0');
  final mm = now.month.toString().padLeft(2, '0');
  final yy = now.year.toString();
  final hour = now.hour % 12 == 0 ? 12 : now.hour % 12;
  final minute = now.minute.toString().padLeft(2, '0');
  final ampm = now.hour >= 12 ? 'PM' : 'AM';

  final formatted = "$dd-$mm-$yy at $hour:$minute $ampm";
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('last_cloud_sync_time', formatted);

  if (mounted) {
    setState(() {
      _lastSyncTime = formatted;
    });
  }
}
  Future<void> _processPendingSmsQueue() async {
    if (kIsWeb || !Platform.isAndroid) return;

    final pending = _smsQueue.where((item) => item.status == 'PENDING').toList();
    if (pending.isEmpty) return;

    // Check and request runtime permission
    var status = await Permission.sms.status;
    if (!status.isGranted) {
      status = await Permission.sms.request();
      if (!status.isGranted) {
        debugPrint("SMS permission denied by user.");
        return;
      }
    }

    bool stateChanged = false;

    for (var item in pending) {
      final cleanPhone = item.phone.replaceAll(RegExp(r'[^0-9]'), '');
      final targetPhone = cleanPhone.length >= 10 ? cleanPhone.substring(cleanPhone.length - 10) : cleanPhone;

      if (targetPhone.length == 10) {
        try {
          final res = await _nativeSmsChannel.invokeMethod<String>('sendSms', {
            'phone': targetPhone,
            'message': item.message,
          });

          if (res == 'SENT') {
            item.status = 'SENT';
            stateChanged = true;
          } else {
            item.status = 'FAILED';
            stateChanged = true;
          }
        } catch (e) {
          debugPrint("Native SMS channel error: $e");
          item.status = 'FAILED';
          stateChanged = true;
        }
      } else {
        item.status = 'FAILED';
        stateChanged = true;
      }
    }

    if (stateChanged) {
      setState(() {});
      await _commitToLocalDrive();
    }
  }  
      Future<void> _initializeAppData() async {
    // Safety timer: guarantees the spinner NEVER stays on screen longer than 1.5s
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted && _isLoading) {
        setState(() {
          _isLocked = true;
          _isLoading = false;
        });
      }
    });

    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Load company profile, letterhead, and templates
      _isProfileSetupDone = prefs.getBool('is_profile_setup_done') ?? false;
      _companyName = prefs.getString('company_name') ?? 'CocoTrade ERP';
      _companyPhone = prefs.getString('company_phone') ?? '';
      _companyAddress = prefs.getString('company_address') ?? '';
      _myCompany.statementName = prefs.getString('company_statement_name') ?? _companyName;
      _customPdfSaveDir = prefs.getString('custom_pdf_save_dir');
      final savedInv = prefs.getString('company_invocation');
      if (savedInv != null && savedInv.trim().isNotEmpty) {
        _myCompany.invocation = savedInv.trim();
      }
      _lastSyncTime = prefs.getString('last_cloud_sync_time') ?? 'Never';
      final savedSellerMsg = prefs.getString('sms_seller_template');
      if (savedSellerMsg != null && savedSellerMsg.isNotEmpty) {
        _sellerMsgTemplate = savedSellerMsg;
      }
      final savedBuyerMsg = prefs.getString('sms_buyer_template');
      if (savedBuyerMsg != null && savedBuyerMsg.isNotEmpty) {
        _buyerMsgTemplate = savedBuyerMsg;
      }

      // 2. Load auth & licensing state together (prevents license screen flashing)
      _isFirstLoginDone = prefs.getBool(_prefFirstLoginKey) ?? false;
      _isLicensed = prefs.getBool(_prefIsLicensedKey) ?? false;
      _savedEmail = prefs.getString(_prefEmailKey) ?? "admin@cocotrade.com";
      _savedPassword = prefs.getString(_prefPassKey) ?? "admin123";
      _savedPin = prefs.getString(_prefPinKey) ?? "1234";
      _savedLicenseKey = prefs.getString(_prefLicenseKeyString) ?? "YOUR-NEW-LICENSE-KEY";
      
      try {       
    // 3. Read local database from disk
    if (!kIsWeb) {
      try {
        final localData = await LocalDriveManager.readFromDrive();
        if (localData != null) {
          // If you already have cloud Firestore streams populating state,
          // local disk loading is only a fallback on desktop:
          debugPrint("Local drive data read successfully");
        }
      } catch (e) {
        debugPrint("Error reading local database: $e");
      }
    }
      } catch (dbErr) {
        debugPrint("Error reading local database: $dbErr");
      }

      // 4. Calculate pending balances & invoice numbers
      if (_trucks.isNotEmpty) {
        try {
          _calculateOverdueBills(_trucks);
          _updateNextInvoiceNumber();
        } catch (calcErr) {
          debugPrint("Error calculating stats: $calcErr");
        }
      }
    } catch (e) {
      debugPrint("Startup initialization error: $e");
    } finally {
      // 5. GUARANTEED: Instantly unlock and show the PIN screen
      if (mounted) {
        setState(() {
          _isLocked = true;
          _isLoading = false;
        });
      }
    }    
  }

   DateTime _getFYStartDate(String fy) {
    final startYear = int.parse(fy.split('-')[0]);
    return DateTime(startYear, 4, 1);
   }

   DateTime _getFYEndDate(String fy) {
    final startYear = int.parse(fy.split('-')[0]);
    return DateTime(startYear + 1, 3, 31, 23, 59, 59);
    }

   bool _isDateInFY(String dateStr, String fy) {
    final date = parseFlexibleDate(dateStr);
    return date.isAfter(_getFYStartDate(fy).subtract(const Duration(seconds: 1))) &&
           date.isBefore(_getFYEndDate(fy).add(const Duration(seconds: 1)));
    }

    String _toIso(String input) {
    final d = parseFlexibleDate(input);
    return "${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}";
    }

    Map<String, dynamic> _exportStateMap() {
    final safeTrucks = _trucks.map((t) {
      var json = (t as dynamic).toJson();
      json['date'] = _toIso(json['date']);
      return json;
    }).toList();

    final safePayments = _payments.map((p) {
      var json = (p as dynamic).toJson();
      json['date'] = _toIso(json['date']);
      return json;
    }).toList();

    return {
      'app': 'COCOTRADE_ERP', 'version': '2.0.0', 'lastSaved': DateTime.now().toUtc().toIso8601String(),
      'companyProfile': _myCompany.toJson(),
      'parties': _parties.map((p) => (p as dynamic).toJson()).toList(),
      'trucks': safeTrucks,
      'bankAccounts': _bankAccounts.map((b) => b.toJson()).toList(),
      'payments': safePayments,
      'transportPayments': _transportPayments.map((tp) => (tp as dynamic).toJson()).toList(),
      'confirmations': _confirmations.map((c) => (c as dynamic).toJson()).toList(),
      'coconutTypes': _coconutTypes,
      'paymentModes': _paymentModes,
      'smsQueue': _smsQueue.map((s) => s.toJson()).toList(),
      'savedPin': _savedPin,
      'isLicensed': _isLicensed,
      'savedEmail': _savedEmail,
    };
    }

   String _generateFullDatabaseJson() => jsonEncode(_exportStateMap());   

Timer? _saveDebounceTimer;

  Future<void> _commitToLocalDrive() async {
    _saveDebounceTimer?.cancel();
    _saveDebounceTimer = Timer(const Duration(milliseconds: 400), () async {
      final nowUtcIso = DateTime.now().toUtc().toIso8601String();
      final appState = _exportStateMap();

      // Only write to Windows hard drive when NOT on web
      if (!kIsWeb) {
        await LocalDriveManager.writeToDrive(appState);
      }
      if (Firebase.apps.isNotEmpty) {
      // Sync to Cloud Firestore for both Windows and Web/iPad
      try {
        final db = FirebaseFirestore.instance;
        final batch = db.batch();

        final metaRef = db.collection('app_metadata').doc('master_config');
        batch.set(metaRef, {
      'companyProfile': _myCompany.toJson(),
      'parties': _parties.map((p) => (p as dynamic).toJson()).toList(),
      'bankAccounts': _bankAccounts.map((b) => b.toJson()).toList(),
      'transportPayments': _transportPayments.map((tp) => (tp as dynamic).toJson()).toList(),
      'confirmations': _confirmations.map((c) => (c as dynamic).toJson()).toList(),
      'coconutTypes': _coconutTypes,
      'paymentModes': _paymentModes,
      'savedPin': _savedPin,       // <-- ADDED
      'savedEmail': _savedEmail,   // <-- ADDED
      'isLicensed': _isLicensed,   // <-- ADDED
      'lastSaved': nowUtcIso,
    }, SetOptions(merge: true));

        for (var truck in _trucks) {
          final t = truck as TruckEntry;
          t.updatedAt = nowUtcIso;
          final docRef = db.collection('trucks').doc(t.id);
          batch.set(docRef, t.toJson(), SetOptions(merge: true));
        }

        for (var payment in _payments) {
          final p = payment as PaymentEntry;
          p.updatedAt = nowUtcIso;
          final docRef = db.collection('payments').doc(p.id);
          batch.set(docRef, p.toJson(), SetOptions(merge: true));
        }

        await batch.commit();
        if (mounted) {
          await _recordSyncTimestamp();
          setState(() {
            _syncHealthStatus = 'CONNECTED';
            _syncHealthLabel = 'Live Synced';
          });
        }
      } catch (e) {
        debugPrint("Firestore sync error: $e");
        if (mounted) {
          setState(() {
            _syncHealthStatus = 'QUEUED';
            _syncHealthLabel = 'Offline Queued';
          });
        }
      }
  }});
  }

void _markCustomBillAsPaid(dynamic truckEntry, double settleAmount, {bool isBuyerSide = false, bool isBothSides = false}) {
  if (settleAmount <= 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('This bill is already fully settled!')),
    );
    return;
  }

  final nowStr = formatDisplayDate(DateTime.now().toIso8601String());
  final nowMs = "${DateTime.now().microsecondsSinceEpoch}_${DateTime.now().millisecond}";

  setState(() {
    if (isBothSides) {
      _payments.add(PaymentEntry(
        id: '${nowMs}_direct',
        state: _selectedState,
        type: "DIRECT SETTLEMENT",
        seller: truckEntry.supplier.toString().trim().toUpperCase(),
        buyer: truckEntry.buyer.toString().trim().toUpperCase(),
        amount: settleAmount,
        transportReceived: 0,
        settlement: 0,
        mode: "DIRECT",
        date: nowStr,
        truckId: truckEntry.id,
      ));
    } else {
      _payments.add(PaymentEntry(
        id: '${nowMs}_${isBuyerSide ? 'buyer' : 'seller'}',
        state: _selectedState,
        type: isBuyerSide ? "RECEIPT FROM BUYER" : "PAYMENT TO SELLER",
        seller: truckEntry.supplier.toString().trim().toUpperCase(),
        buyer: truckEntry.buyer.toString().trim().toUpperCase(),
        amount: settleAmount,
        transportReceived: 0,
        settlement: 0,
        mode: "DIRECT",
        date: nowStr,
        truckId: truckEntry.id,
      ));
    }
    _calculateOverdueBills(_trucks);
  });

  _commitToLocalDrive();

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: const Color(0xFF047857),
      content: Text('Recorded payment of ${money(settleAmount)} for ${truckEntry.buyer}'),
    ),
  );
}
void _updateNextInvoiceNumber() {
  int maxNum = 0;
  for (var t in _trucks) {
    if (t.isInvoice == true) {
      final rawDigits = t.invoiceNo.isNotEmpty
          ? t.invoiceNo.replaceAll(RegExp(r'[^0-9]'), '')
          : (t.truck.startsWith('INV-') ? t.truck.replaceAll(RegExp(r'[^0-9]'), '') : '');
      final val = int.tryParse(rawDigits) ?? 0;
      if (val > maxNum) maxNum = val;
    }
  }
  if (_editingInvoiceId == null) {
    _invNCtrl.text = "INV-${(maxNum + 1).toString().padLeft(5, '0')}";
  }
}
  void _applyStateFromMap(Map<String, dynamic> data) async {
    setState(() {
      if (data['smsQueue'] != null) {
        _smsQueue = (data['smsQueue'] as List).map((i) => SmsQueueItem.fromJson(i)).toList();
      }
      if (data['companyProfile'] != null) _myCompany = CompanyProfile.fromJson(data['companyProfile']);
      if (data['parties'] != null) _parties = (data['parties'] as List).map((i) => Party.fromJson(i)).toList();
      if (data['trucks'] != null) _trucks = (data['trucks'] as List).map((i) => TruckEntry.fromJson(i)).toList();_updateNextInvoiceNumber();
      if (data['bankAccounts'] != null) {
        _bankAccounts = (data['bankAccounts'] as List).map((i) => BankAccount.fromJson(i)).toList();
        if (_bankAccounts.isNotEmpty) _selectedBank = _bankAccounts.first;
      }
      if (data['payments'] != null) _payments = (data['payments'] as List).map((i) => PaymentEntry.fromJson(i)).toList();
      if (data['transportPayments'] != null) _transportPayments = (data['transportPayments'] as List).map((i) => TransportPayment.fromJson(i)).toList();
      if (data['confirmations'] != null) _confirmations = (data['confirmations'] as List).map((i) => TradeConfirmation.fromJson(i)).toList();
      if (data['coconutTypes'] != null) _coconutTypes = List<String>.from(data['coconutTypes']);
      if (data['paymentModes'] != null) _paymentModes = List<String>.from(data['paymentModes']);
      // ADD THESE LINES TO SYNC YOUR CUSTOM PIN & LOGIN FROM CLOUD
            if (data.containsKey('savedPin')) {
              _savedPin = data['savedPin'];
              SharedPreferences.getInstance().then((p) => p.setString(_prefPinKey, _savedPin));
            }
            if (data.containsKey('savedEmail')) {
              _savedEmail = data['savedEmail'];
              SharedPreferences.getInstance().then((p) => p.setString(_prefEmailKey, _savedEmail));
            }
            if (data.containsKey('isLicensed')) {
              _isLicensed = data['isLicensed'];
              SharedPreferences.getInstance().then((p) => p.setBool(_prefIsLicensedKey, _isLicensed));
            }
      if (data.containsKey('savedPin')) _savedPin = data['savedPin'];
      if (data.containsKey('isLicensed')) _isLicensed = data['isLicensed'];
      if (data.containsKey('savedEmail')) _savedEmail = data['savedEmail'];
    });

    final prefs = await SharedPreferences.getInstance();
    if (data.containsKey('savedPin')) await prefs.setString(_prefPinKey, data['savedPin']);
    if (data.containsKey('isLicensed')) await prefs.setBool(_prefIsLicensedKey, data['isLicensed']);
    if (data.containsKey('savedEmail')) await prefs.setString(_prefEmailKey, data['savedEmail']);
    
    // GUARANTEE LOCAL PERSISTENCE ON ANDROID
    await LocalDriveManager.writeToDrive(data);

    if (!kIsWeb && Platform.isAndroid) {
      _processPendingSmsQueue();
    }
  } 

  void _addGoodsRow({String desc = 'COCONUT', String qty = '', String rate = ''}) {
    final item = GoodsItemController(desc: desc.toUpperCase(), qty: qty, rate: rate);
    item.descCtrl.addListener(() => setState(() {}));
    item.qtyCtrl.addListener(() => setState(() {}));
    item.rateCtrl.addListener(() => setState(() {}));
    _invoiceGoods.add(item);
  }

  List<String> get _sellerNames {
    final Set<String> names = {};
    for (var p in _parties) {
      if (p.type.toString().trim().toUpperCase() == "SELLER" && p.name.toString().trim().isNotEmpty) {
        names.add(p.name.toString().trim().toUpperCase());
      }
    }
    final list = names.toList()..sort();
    return list;
  }

  List<String> get _buyerNames {
    final Set<String> names = {};
    for (var p in _parties) {
      if (p.type.toString().trim().toUpperCase() == "BUYER" && p.name.toString().trim().isNotEmpty) {
        names.add(p.name.toString().trim().toUpperCase());
      }
    }
    final list = names.toList()..sort();
    return list;
  }

  List<String> get _transporterNames {
    final Set<String> names = {};
    for (var p in _parties) {
      if (p.type.toString().trim().toUpperCase() == "TRANSPORTER" && p.name.toString().trim().isNotEmpty) {
        names.add(p.name.toString().trim().toUpperCase());
      }
    }
    final list = names.toList()..sort();
    return list;
  }
  List<String> get _sellerRespectiveBuyers {
    if (_repSeller.trim().isEmpty) return _buyerNames;
    final set = _trucks.where((t) => t.state == _selectedState && t.supplier.toUpperCase() == _repSeller.toUpperCase() && t.buyer.isNotEmpty).map((t) => t.buyer.toUpperCase()).toSet();
    return set.isNotEmpty ? set.toList().cast<String>() : _buyerNames;
  }
  List<String> get _buyerRespectiveSellers {
    if (_repBuyer.trim().isEmpty) return _sellerNames;
    final set = _trucks.where((t) => t.state == _selectedState && t.buyer.toUpperCase() == _repBuyer.toUpperCase() && t.supplier.isNotEmpty).map((t) => t.supplier.toUpperCase()).toSet();
    return set.isNotEmpty ? set.toList().cast<String>() : _sellerNames;
  }

  static DateTime parseFlexibleDate(String input) {
    if (input.trim().isEmpty) return DateTime(1970);
    final clean = input.trim().replaceAll('/', '-').replaceAll(' ', '-');
    try {
      final parts = clean.split('-');
      if (parts.length == 3) {
        if (parts[0].length == 4) {
          return DateTime(int.parse(parts[0]), _parseMonth(parts[1]), int.parse(parts[2]));
        }
        int year = int.parse(parts[2]);
        if (year < 100) year += 2000;
        return DateTime(year, _parseMonth(parts[1]), int.parse(parts[0]));
      }
    } catch (_) {}
    return DateTime.now();
  }

  static String formatDisplayDate(String rawDate) {
    if (rawDate.trim().isEmpty) return '—';
    final dt = parseFlexibleDate(rawDate);
    final dd = dt.day.toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    final yy = (dt.year % 100).toString().padLeft(2, '0');
    return "$dd-$mm-$yy";
  }

  static int _parseMonth(String m) {
    final num = int.tryParse(m); if (num != null) return num;
    final months = {"JAN": 1, "FEB": 2, "MAR": 3, "APR": 4, "MAY": 5, "JUN": 6, "JUL": 7, "AUG": 8, "SEP": 9, "OCT": 10, "NOV": 11, "DEC": 12};
    return months[m.toUpperCase()] ?? 1;
  }

  static bool isDateInRange(String entryDateStr, String fromDateStr, String toDateStr) {
    DateTime entryDate = parseFlexibleDate(entryDateStr);
    if (fromDateStr.trim().isNotEmpty && entryDate.isBefore(parseFlexibleDate(fromDateStr))) return false;
    if (toDateStr.trim().isNotEmpty && entryDate.isAfter(parseFlexibleDate(toDateStr))) return false;
    return true;
  }

 static String money(dynamic val) {
    if (val == null) return "₹0";
    final double dVal = (val is num) ? val.toDouble() : (double.tryParse(val.toString()) ?? 0.0);
    if (dVal == 0) return "₹0";
    bool isNeg = dVal < 0; double absVal = dVal.abs();
    String formatted = absVal.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d+?)(?=(\d\d)+(\d)(?!\d))'), (m) => '${m[1]},');
    return isNeg ? '-₹$formatted' : '₹$formatted';
  }

  static String pdfMoney(dynamic val) {
    if (val == null) return "0";
    final double dVal = (val is num) ? val.toDouble() : (double.tryParse(val.toString().replaceAll('₹', '').replaceAll(',', '').trim()) ?? 0.0);
    if (dVal == 0) return "0";
    bool isNeg = dVal < 0;
    double absVal = dVal.abs();
    String formatted = absVal.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d+?)(?=(\d\d)+(\d)(?!\d))'), (m) => '${m[1]},');
    return isNeg ? '-$formatted' : formatted;
  }

  static String numFmt(dynamic val) {
    if (val == null) return "0";
    final double dVal = (val is num) ? val.toDouble() : (double.tryParse(val.toString()) ?? 0.0);
    return dVal.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d+?)(?=(\d\d)+(\d)(?!\d))'), (m) => '${m[1]},');
  }
  static String wordsToIndian(double numVal) {
    int num = numVal.floor(); if (num <= 0) return "ZERO";
    final a = ["", "ONE", "TWO", "THREE", "FOUR", "FIVE", "SIX", "SEVEN", "EIGHT", "NINE", "TEN", "ELEVEN", "TWELVE", "THIRTEEN", "FOURTEEN", "FIFTEEN", "SIXTEEN", "SEVENTEEN", "EIGHTEEN", "NINETEEN"];
    final b = ["", "", "TWENTY", "THIRTY", "FORTY", "FIFTY", "SIXTY", "SEVENTY", "EIGHTY", "NINETY"];
    String two(int n) => n < 20 ? a[n] : "${b[n ~/ 10]}${n % 10 != 0 ? " ${a[n % 10]}" : ""}";
    String three(int n) => n < 100 ? two(n) : "${a[n ~/ 100]} HUNDRED${n % 100 != 0 ? " ${two(n % 100)}" : ""}";
    List<String> p = [];
    if (num >= 10000000) { p.add("${three(num ~/ 10000000)} CRORE"); num %= 10000000; }
    if (num >= 100000) { p.add("${three(num ~/ 100000)} LAKH"); num %= 100000; }
    if (num >= 1000) { p.add("${three(num ~/ 1000)} THOUSAND"); num %= 1000; }
    if (num > 0) p.add(three(num));
    return p.join(" ").trim();
  }

  // Helper to handle responsive rows safely (must be private _responsiveRow)
  Widget _responsiveRow(List<Widget> children, {CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.end}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // If available width is less than 850px (e.g. iPad with sidebar open), stack fields vertically
        if (constraints.maxWidth < 850) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children
                .where((c) => !(c is SizedBox && c.width != null && (c.height == null || c.height == 0)))
                .map((c) {
              Widget inner = c;
              if (c is Expanded) inner = c.child;
              else if (c is Flexible) inner = c.child;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: inner,
              );
            }).toList(),
          );
        } else {
          return Row(crossAxisAlignment: crossAxisAlignment, children: children);
        }
      },
    );
  }

  // Helper for license key checks (must be private _verifyLicenseKey)
  bool _verifyLicenseKey(String email, String key) {
    if (email.trim().isEmpty || key.trim().isEmpty) return false;
    final cleanMail = email.trim().toLowerCase();
    final bytes = utf8.encode(cleanMail);
    final hmacSha256 = Hmac(sha256, utf8.encode("COCOTRADE_SECRET_2026"));
    final digest = hmacSha256.convert(bytes);
    final hashed = digest.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join().toUpperCase();
    final expectedKey = "COCO-${hashed.substring(0, 4)}-${hashed.substring(4, 8)}-${hashed.substring(8, 12)}-${hashed.substring(12, 16)}";
    return key.trim().toUpperCase() == expectedKey;
  }
  Future<void> _selectDateForController(TextEditingController ctrl) async {
    DateTime initial = ctrl.text.isNotEmpty ? parseFlexibleDate(ctrl.text) : DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF047857),
            onPrimary: Colors.white,
            onSurface: Color(0xFF0F172A),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      final dd = picked.day.toString().padLeft(2, '0');
      final mm = picked.month.toString().padLeft(2, '0');
      final yy = (picked.year % 100).toString().padLeft(2, '0');
      setState(() => ctrl.text = "$dd-$mm-$yy");
    }
  }

  void _calculateOverdueBills(List<dynamic> allTrucks) {
  final DateTime today = DateTime.now();
  List<Map<String, dynamic>> overdue = [];

  // 1. Separate truck-specific payments from general unallocated payments
  final validPayments = _payments.where((p) => p.state == _selectedState).toList();
  validPayments.sort((a, b) => parseFlexibleDate(a.date).compareTo(parseFlexibleDate(b.date)));

  Map<String, double> directTruckBuyerPaid = {};
  Map<String, double> directTruckSellerPaid = {};
  List<Map<String, dynamic>> unallocatedBuyerBuckets = [];
  List<Map<String, dynamic>> unallocatedSellerBuckets = [];

  for (var p in validPayments) {
    final double totalPay = ((p.amount ?? 0) as num).toDouble() +
        ((p.settlement ?? 0) as num).toDouble() +
        ((p.commissionAdjusted ?? 0) as num).toDouble();

    final bool isBuyer = p.type.contains("BUYER") || (p.mode == "DIRECT" && !p.id.endsWith("_seller"));
    final bool isSeller = p.type.contains("SELLER") || (p.mode == "DIRECT" && !p.id.endsWith("_buyer"));

    // If linked to a specific bill/truck
    if (p.truckId.isNotEmpty) {
      if (isBuyer) {
        directTruckBuyerPaid[p.truckId] = (directTruckBuyerPaid[p.truckId] ?? 0.0) + totalPay;
      }
      if (isSeller) {
        directTruckSellerPaid[p.truckId] = (directTruckSellerPaid[p.truckId] ?? 0.0) + totalPay;
      }
    } else {
      // General on-account payments (FIFO)
      if (isBuyer) {
        unallocatedBuyerBuckets.add({'entry': p, 'remaining': totalPay});
      }
      if (isSeller) {
        unallocatedSellerBuckets.add({'entry': p, 'remaining': totalPay});
      }
    }
  }

  // 2. Sort trucks chronologically
  List<dynamic> sortedTrucks = List.from(allTrucks.where((t) =>
      t.state == _selectedState &&
      (t.buyerBill > 0 || t.supplierBill > 0)));
  sortedTrucks.sort((a, b) => parseFlexibleDate(a.date).compareTo(parseFlexibleDate(b.date)));

  for (var t in sortedTrucks) {
    final String bKey = t.buyer.toString().trim().toUpperCase();
    final String sKey = t.supplier.toString().trim().toUpperCase();

    final double bBill = (t.buyerBill > 0) ? t.buyerBill : t.supplierBill;
    final double sBill = t.supplierBill;

    // Start with payments explicitly linked to this bill
    double bPaid = directTruckBuyerPaid[t.id] ?? 0.0;
    double sPaid = directTruckSellerPaid[t.id] ?? 0.0;

    // Allocate on-account payments only if bill is not cleared
    if (bPaid < bBill) {
      for (var bucket in unallocatedBuyerBuckets) {
        if ((bucket['remaining'] as double) <= 0) continue;
        final p = bucket['entry'] as PaymentEntry;
        final pBuyer = p.buyer.trim().toUpperCase();
        final pSeller = p.seller.trim().toUpperCase();

        if (pBuyer == bKey && (pSeller.isEmpty || sKey.isEmpty || pSeller == sKey) && pBuyer.isNotEmpty) {
          final double needed = bBill - bPaid;
          final double rem = bucket['remaining'] as double;
          if (rem >= needed) {
            bPaid += needed;
            bucket['remaining'] = rem - needed;
            break;
          } else {
            bPaid += rem;
            bucket['remaining'] = 0.0;
          }
        }
      }
    }

    if (sPaid < sBill) {
      for (var bucket in unallocatedSellerBuckets) {
        if ((bucket['remaining'] as double) <= 0) continue;
        final p = bucket['entry'] as PaymentEntry;
        final pSeller = p.seller.trim().toUpperCase();
        final pBuyer = p.buyer.trim().toUpperCase();

        if (pSeller == sKey && (pBuyer.isEmpty || bKey.isEmpty || pBuyer == bKey) && pBuyer.isNotEmpty) {
          final double needed = sBill - sPaid;
          final double rem = bucket['remaining'] as double;
          if (rem >= needed) {
            sPaid += needed;
            bucket['remaining'] = rem - needed;
            break;
          } else {
            sPaid += rem;
            bucket['remaining'] = 0.0;
          }
        }
      }
    }

    final double bBal = (bBill - bPaid).clamp(0.0, double.infinity);
    final double sBal = (sBill - sPaid).clamp(0.0, double.infinity);

    final int daysSinceEntry = today.difference(parseFlexibleDate(t.date)).inDays;

    if (daysSinceEntry > 10 && (bBal > 0 || sBal > 0)) {
      overdue.add({
        'truck': t,
        'buyerBill': bBill,
        'sellerBill': sBill,
        'buyerBal': bBal,
        'sellerBal': sBal,
      });
    }
  }

  setState(() => _overdueBills = overdue);
}

  Widget _buildMobileDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF062317),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFF047857)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(_companyName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const Text('Coconut Canvassing Suite', style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          _neoNavItem('dashboard', 'Dashboard', Icons.space_dashboard_outlined),
          _neoNavItem('parties', 'Parties Directory', Icons.contacts_outlined),
          _neoNavItem('trucks', 'Truck Logistics', Icons.local_shipping_outlined),
          _neoNavItem('invoice', 'Invoice Ledger', Icons.receipt_long_outlined),
          _neoNavItem('payments', 'Payment Ledger', Icons.account_balance_wallet_outlined),
          _neoNavItem('reports', 'Party Ledgers', Icons.analytics_outlined),
          _neoNavItem('transport', 'Transport Logs', Icons.commute_outlined),
          _neoNavItem('estimate', 'Cost Estimator', Icons.calculate_outlined),
        ],
      ),
    );
  }

  Widget _buildActiveTabContent() {
    Widget content;
    switch (_selectedTab) {
      case 'dashboard':
        content = _buildDashboardView();
        break;
      case 'parties':
        content = _buildPartiesView();
        break;
      case 'trucks':
        content = _buildTruckLogisticsView();
        break;
      case 'invoice':
        content = _buildInvoiceView();
        break;
      case 'payments':
        content = _buildPaymentsView();
        break;
      case 'reports':
        content = _buildReportsView();
        break;
      case 'transport':
        content = _buildTransportView();
        break;
      case 'estimate':
        content = _buildEstimateView();
        break;
      default:
        content = _buildDashboardView();
    }
    return Material(
      color: Colors.transparent,
      child: content,
    );
  }

 @override
  Widget build(BuildContext context) {
    // 1. Loading screen guard
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: Color(0xFF047857))),
      );
    }

    // 2. Authentication and setup guards
    if (!_isLicensed && _isTrialExpired) return _buildFirstTimeEmailLoginScreen();
    if (!_isFirstLoginDone || _forceEmailLogin) return _buildFirstTimeEmailLoginScreen();
    if (!_isProfileSetupDone) return _buildCompanyProfileScreen();
    if (_isLocked) return _buildPinLockScreen();

    // 3. Main Application Interface with Android Back-Gesture Handling
    return PopScope(
      canPop: _selectedTab == 'dashboard' || isMobile == false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_selectedTab != 'dashboard') {
          setState(() => _selectedTab = 'dashboard');
        }
      },
      child: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyZ): _undo,
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyY): _redo,
        },
        child: Focus(
          autofocus: true,
          child: NeoScaffold(
            activeTab: _selectedTab,
            onTabChanged: (tab) => setState(() {
              _selectedTab = tab;
              if (tab == 'trucks' && _editingTruckId == null) _clearTruckForm();
              if (tab == 'invoice' && _editingInvoiceId == null) _clearInvoiceForm();
              _calculateOverdueBills(_trucks);
            }),
            onLock: () => setState(() => _isLocked = true),
            onSettings: _showStorageSettingsDialog,
            activeState: _selectedState,
            onStateChanged: (st) => setState(() {
              _selectedState = st;
              _calculateOverdueBills(_trucks);
            }),
            financialYear: _selectedFinancialYear,
            syncHealthStatus: _syncHealthStatus,
            syncHealthLabel: _syncHealthLabel,
            body: _buildActiveTabContent(),
          ),
        ),
      ),
    );
  }

  // ---------------- NEO-SAAS SIDEBAR (EXPANDED OR GEMINI RAIL) ----------------
  Widget _buildNeoSidebar() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      width: _isSidebarExpanded ? 250 : 72,
      decoration: const BoxDecoration(
        color: Color(0xFF062317),
        border: Border(right: BorderSide(color: Color(0x1AFFFFFF))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header / Logo
          Padding(
            padding: EdgeInsets.fromLTRB(_isSidebarExpanded ? 20 : 16, 20, _isSidebarExpanded ? 20 : 16, 16),
            child: Row(
              mainAxisAlignment: _isSidebarExpanded ? MainAxisAlignment.start : MainAxisAlignment.center,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF10B981), Color(0xFF047857)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: const [BoxShadow(color: Color(0x3310B981), blurRadius: 10, offset: Offset(0, 4))],
                  ),
                  child: const Icon(Icons.eco_rounded, color: Colors.white, size: 20),
                ),
                if (_isSidebarExpanded) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _companyName.toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Text('CANVASSING SUITE', style: TextStyle(color: Color(0xFF6EE7B7), fontSize: 9.5, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0x14FFFFFF)),
          const SizedBox(height: 10),

          // Nav Items List
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(horizontal: _isSidebarExpanded ? 12 : 8),
              children: [
                if (_isSidebarExpanded) _sidebarSectionLabel('OPERATIONS') else const SizedBox(height: 6),
                _neoNavItem('dashboard', 'Dashboard', Icons.space_dashboard_outlined),
                _neoNavItem('parties', 'Parties Directory', Icons.contacts_outlined),
                _neoNavItem('trucks', 'Truck Logistics', Icons.local_shipping_outlined),
                if (_isSidebarExpanded) const SizedBox(height: 14) else const SizedBox(height: 8),
                if (_isSidebarExpanded) _sidebarSectionLabel('FINANCIALS'),
                _neoNavItem('invoice', 'Invoice Ledger', Icons.receipt_long_outlined),
                _neoNavItem('payments', 'Payment Ledger', Icons.account_balance_wallet_outlined),
                _neoNavItem('reports', 'Party Ledgers', Icons.analytics_outlined),
                _neoNavItem('transport', 'Transport Logs', Icons.commute_outlined),
                _neoNavItem('estimate', 'Cost Estimator', Icons.calculate_outlined),
              ],
            ),
          ),

          // Footer Lock / Status Box
          Container(
            padding: EdgeInsets.all(_isSidebarExpanded ? 12 : 8),
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0x14FFFFFF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0x1FFFFFFF)),
            ),
            child: _isSidebarExpanded
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('SYSTEM ACTIVE', style: TextStyle(color: Color(0xFF6EE7B7), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
                          Text('FY $_selectedFinancialYear', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(Icons.power_settings_new_rounded, color: Color(0xFFF87171), size: 18),
                        tooltip: 'Lock ERP',
                        onPressed: () => setState(() => _isLocked = true),
                      ),
                    ],
                  )
                : Center(
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.power_settings_new_rounded, color: Color(0xFFF87171), size: 18),
                      tooltip: 'Lock ERP',
                      onPressed: () => setState(() => _isLocked = true),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _sidebarSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, top: 12, bottom: 6),
      child: Text(label, style: const TextStyle(color: Color(0xFF4B6E5B), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
    );
  }

  Widget _neoNavItem(String key, String title, IconData icon) {
    final bool active = _selectedTab == key;

    Widget navItem = Container(
      margin: const EdgeInsets.symmetric(vertical: 2.5),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            setState(() {
              _selectedTab = key;
              if (key == 'trucks' && _editingTruckId == null) _clearTruckForm();
              if (key == 'invoice' && _editingInvoiceId == null) _clearInvoiceForm();
              _calculateOverdueBills(_trucks);
            });
            if (isMobile && Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: EdgeInsets.symmetric(
              horizontal: _isSidebarExpanded ? 14 : 0, 
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: active ? const Color(0xFF10B981) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              boxShadow: active
                  ? const [BoxShadow(color: Color(0x3310B981), blurRadius: 12, offset: Offset(0, 4))]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: _isSidebarExpanded ? MainAxisAlignment.start : MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20, color: active ? Colors.white : const Color(0xFF86A393)),
                if (_isSidebarExpanded) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: active ? FontWeight.bold : FontWeight.w600,
                        color: active ? Colors.white : const Color(0xFFC7D7CF),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    // Show hover tooltip only when sidebar is in collapsed icon rail mode
    if (!_isSidebarExpanded && !isMobile) {
      return Tooltip(
        message: title,
        preferBelow: false,
        verticalOffset: 0,
        margin: const EdgeInsets.only(left: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF064E3B),
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 2))],
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
        child: navItem,
      );
    }

    return navItem;
  }

  Widget _buildExecutiveHeader() {
    if (isMobile) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [_statePill("Andhra Pradesh"), _statePill("Tamil Nadu")]),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFA7F3D0))),
                  child: Text('FY $_selectedFinancialYear', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF047857))),
                ),
                const SizedBox(width: 8),
                // Settings button added for mobile
                IconButton.filledTonal(
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFF1F5F9),
                    minimumSize: const Size(36, 36),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.settings_outlined, size: 17, color: Color(0xFF0F172A)),
                  onPressed: _showStorageSettingsDialog,
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _selectedTab.toUpperCase(),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 2),
              Text(
                _companyAddress.isNotEmpty ? '$_companyAddress • Tel: $_companyPhone' : 'Live Management Console',
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
              ),
            ],
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [_statePill("Andhra Pradesh"), _statePill("Tamil Nadu")],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.date_range_rounded, size: 14, color: Color(0xFF047857)),
                    const SizedBox(width: 6),
                    Text('FY $_selectedFinancialYear', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF047857))),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filledTonal(
                style: IconButton.styleFrom(backgroundColor: const Color(0xFFF1F5F9), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                icon: const Icon(Icons.settings_outlined, size: 18, color: Color(0xFF0F172A)),
                onPressed: _showStorageSettingsDialog,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statePill(String stateName) {
    final bool active = _selectedState == stateName;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedState = stateName;
          _calculateOverdueBills(_trucks);
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF047857) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          stateName,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: active ? Colors.white : const Color(0xFF475569)),
        ),
      ),
    );
  }

  Widget _neoKpiCard({required String label, required String value, required String subtitle, required IconData icon, required Color accentColor}) {
    Widget card = Container(
      padding: EdgeInsets.all(isMobile ? 12 : 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 16, offset: Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: isMobile ? 10 : 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: EdgeInsets.all(isMobile ? 5 : 8),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: isMobile ? 15 : 18, color: accentColor),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: isMobile ? 19 : 22,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF0F172A),
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(width: 6, height: 6, decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: isMobile ? 10 : 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
    return isMobile ? SizedBox(width: 165, child: card) : Expanded(child: card);
  } 
  // ---------------- DASHBOARD ADVANCES (DUAL-SIDE: BUYERS BLUE / SELLERS RED GLOW) ----------------
  Widget _buildDashboardAdvancesCard() {
    final curStateClean = _selectedState.trim().toUpperCase();

    // 1. Filter current state & FY payments
    final curPayments = _payments.where((p) {
      final pState = p.state.toString().trim().toUpperCase();
      final matchState = pState.isEmpty || pState == curStateClean;
      final matchFY = _isDateInFY(p.date, _selectedFinancialYear);
      return matchState && matchFY;
    }).toList();

    // 2. Buyer Advances & Paid-on-Behalf entries
    final buyerAdvances = curPayments.where((p) {
      final bool isLinkedTruck = p.truckId.toString().trim().isNotEmpty;
      final bool hasBuyer = p.buyer.toString().trim().isNotEmpty && p.buyer.toString().trim().toUpperCase() != "SELECT BUYER";
      final bool isSellerPayout = p.type.toString().trim().toUpperCase().contains("SELLER");
      return hasBuyer && !isSellerPayout && !isLinkedTruck;
    }).toList()..sort((a, b) => parseFlexibleDate(a.date).compareTo(parseFlexibleDate(b.date)));

    // 3. Seller Advances
    final sellerAdvances = curPayments.where((p) {
      final bool isLinkedTruck = p.truckId.toString().trim().isNotEmpty;
      final bool hasSeller = p.seller.toString().trim().isNotEmpty && p.seller.toString().trim().toUpperCase() != "SELECT SELLER";
      final bool isSellerType = p.type.toString().trim().toUpperCase().contains("SELLER");
      final bool emptyBuyer = p.buyer.toString().trim().isEmpty || p.buyer.toString().trim().toUpperCase() == "SELECT BUYER";
      return hasSeller && isSellerType && emptyBuyer && !isLinkedTruck;
    }).toList()..sort((a, b) => parseFlexibleDate(a.date).compareTo(parseFlexibleDate(b.date)));

    final List<Map<String, dynamic>> buyerCards = [];
    final List<Map<String, dynamic>> sellerCards = [];

    // --- GROUP BUYER ADVANCES (INCLUDES NORMAL ADVANCES & ON-BEHALF DEBITS) ---
    final Set<String> allActiveBuyers = {
      ...buyerAdvances.map((a) => a.buyer.toString().trim().toUpperCase()),
      ...curPayments.where((p) => p.buyer.trim().isNotEmpty && p.buyer.trim().toUpperCase() != "SELECT BUYER").map((p) => p.buyer.trim().toUpperCase()),
    };

    for (var buyerName in allActiveBuyers) {
      if (buyerName.isEmpty) continue;

      // 1. Total unallocated advance deposits from buyer
      final double totalDeposits = curPayments.where((p) {
        final bool isLinkedTruck = p.truckId.toString().trim().isNotEmpty;
        final bool isBuyerType = !p.type.toString().trim().toUpperCase().contains("SELLER");
        return isBuyerType && !isLinkedTruck && p.buyer.trim().toUpperCase() == buyerName;
      }).fold<double>(0.0, (s, a) => s + a.amount + a.settlement);

      // 2. Total money you paid to sellers on behalf of this buyer (Drawdowns)
      final double totalPaidOutForBuyer = curPayments.where((p) {
        final bool isSellerPayout = p.type.toString().trim().toUpperCase().contains("SELLER");
        return isSellerPayout && p.buyer.trim().toUpperCase() == buyerName;
      }).fold<double>(0.0, (s, p) => s + p.amount + p.settlement + p.commissionAdjusted);

      // 3. Net remaining advance pool      
      final double netBalance = totalDeposits - totalPaidOutForBuyer;

      // CHANGE THIS CONDITION: Only show buyers who actually have a positive advance credit balance
      if (netBalance > 0.05) {
        buyerCards.add({
          'name': buyerName,
          'balance': netBalance,
          'isDebit': false,
        });
      }
    }

    // --- GROUP SELLER ADVANCES (DYNAMICALLY DEDUCT ADJUSTED BILL PAYMENTS) ---
    final Map<String, List<PaymentEntry>> sellerGroups = {};
    for (var sAdv in sellerAdvances) {
      sellerGroups.putIfAbsent(sAdv.seller.toString().trim().toUpperCase(), () => []).add(sAdv);
    }

    sellerGroups.forEach((sellerName, advList) {
      final double totalAdv = advList.fold<double>(0.0, (s, a) => s + a.amount + a.settlement);

      final double totalAdjusted = curPayments.where((p) {
        if (advList.any((a) => a.id == p.id)) return false;
        final bool sameSeller = p.seller.trim().toUpperCase() == sellerName;
        if (!sameSeller) return false;

        final bool isAllocated = p.truckId.trim().isNotEmpty ||
            (p.buyer.trim().isNotEmpty && p.buyer.trim().toUpperCase() != "SELECT BUYER");
        if (!isAllocated) return false;

        final pMode = p.mode.trim().toUpperCase();
        final bool isAdvAdj = pMode.contains("ADVANCE") ||
            pMode.contains("ADJUST") ||
            advList.any((a) => a.mode.trim().toUpperCase() == pMode);

        return isAdvAdj;
      }).fold<double>(0.0, (s, p) => s + p.amount + p.settlement);

      final double netSellerBalance = (totalAdv - totalAdjusted).clamp(0.0, double.infinity);

      if (netSellerBalance > 0.05) {
        sellerCards.add({
          'name': sellerName,
          'balance': netSellerBalance,
          'isDebit': false,
        });
      }
    });

    if (buyerCards.isEmpty && sellerCards.isEmpty) return const SizedBox.shrink();

    final int totalActiveParties = buyerCards.length + sellerCards.length;

    // Helper to render individual glowing item (Renders Red & Minus for Debits)
    Widget buildGlowItem({
      required String name,
      required double balance,
      required bool isBuyer,
      bool isDebit = false,
    }) {
      final bool isNegative = isDebit || balance < 0;
      final Color glowColor = isNegative ? const Color(0xFFEF4444) : (isBuyer ? const Color(0xFF3B82F6) : const Color(0xFFEF4444));
      final Color surfaceColor = isNegative ? const Color(0xFFFFF5F5) : (isBuyer ? const Color(0xFFF4F8FF) : const Color(0xFFFFF5F5));
      final Color borderColor = isNegative ? const Color(0xFFFECACA) : (isBuyer ? const Color(0xFFBFDBFE) : const Color(0xFFFECACA));
      final Color primaryText = isNegative ? const Color(0xFFDC2626) : (isBuyer ? const Color(0xFF1D4ED8) : const Color(0xFFDC2626));
      final String formattedAmt = balance < 0 ? '-${money(balance.abs())}' : money(balance);

      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8.5),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: glowColor.withOpacity(0.12),
              blurRadius: 8,
              spreadRadius: 0.5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              formattedAmt,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: primaryText,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      );
    }

    // Sub-panel container for each side
    Widget buildSideColumn({
      required String title,
      required List<Map<String, dynamic>> items,
      required bool isBuyer,
    }) {
      final Color headerBadgeColor = isBuyer ? const Color(0xFF1D4ED8) : const Color(0xFFDC2626);
      final Color headerBadgeBg = isBuyer ? const Color(0xFFDBEAFE) : const Color(0xFFFEE2E2);

      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isBuyer ? const Color(0xFFF8FAFC) : const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF1F5F9)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: headerBadgeColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: headerBadgeColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: headerBadgeBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${items.length}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: headerBadgeColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Text(
                    'No active ${isBuyer ? "buyer" : "seller"} advances',
                    style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF94A3B8)),
                  ),
                ),
              )
            else
              ...items.map((it) => buildGlowItem(
                    name: it['name'] as String,
                    balance: (it['balance'] as num).toDouble(),
                    isBuyer: isBuyer,
                    isDebit: it['isDebit'] == true,
                  )),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x04000000), blurRadius: 10, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.account_balance_wallet_outlined, size: 15, color: Color(0xFF475569)),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'ADVANCES',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF334155),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  '$totalActiveParties Active Parties',
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    buildSideColumn(title: 'BUYER ADVANCES', items: buyerCards, isBuyer: true),
                    const SizedBox(height: 10),
                    buildSideColumn(title: 'SELLER ADVANCES', items: sellerCards, isBuyer: false),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: buildSideColumn(title: 'BUYER ADVANCES', items: buyerCards, isBuyer: true),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: buildSideColumn(title: 'SELLER ADVANCES', items: sellerCards, isBuyer: false),
                    ),
                  ],
                ),
        ],
      ),
    );
  }
 // ---------------- MODERN BENTO DASHBOARD VIEW ----------------
  Widget _buildDashboardView() {
    final curConfirmations = _confirmations.where((c) => c.status == 'PENDING').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. ACTIVE ADVANCES AT THE VERY TOP
        _buildDashboardAdvancesCard(),

       // 2. TWO INTERACTIVE ACTION CARDS (MUTUALLY EXCLUSIVE TOGGLE)
        isMobile
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _dashboardActionCard(
                    label: 'Quick Trade',
                    value: curConfirmations.isNotEmpty ? '${curConfirmations.length} Pending' : 'Create Trade',
                    subtitle: _dashShowQuickTrade ? 'Tap to hide' : 'Trade & Dispatch Desk',
                    icon: Icons.bolt_rounded,
                    accentColor: const Color(0xFF047857),
                    bgColor: const Color(0xFFECFDF5),
                    isActive: _dashShowQuickTrade,
                    onTap: () => setState(() {
                      _dashShowQuickTrade = !_dashShowQuickTrade;
                      if (_dashShowQuickTrade) _dashShowOverdue = false;
                    }),
                  ),
                  const SizedBox(height: 10),
                  _dashboardActionCard(
                    label: 'Overdue Bills',
                    value: '${_overdueBills.length} Invoices',
                    subtitle: _dashShowOverdue ? 'Tap to hide' : 'Awaiting Settlement > 10 Days',
                    icon: Icons.warning_amber_rounded,
                    accentColor: const Color(0xFFEF4444),
                    bgColor: const Color(0xFFFEF2F2),
                    isActive: _dashShowOverdue,
                    onTap: () => setState(() {
                      _dashShowOverdue = !_dashShowOverdue;
                      if (_dashShowOverdue) _dashShowQuickTrade = false;
                    }),
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(
                    child: _dashboardActionCard(
                      label: 'Quick Trade',
                      value: curConfirmations.isNotEmpty ? '${curConfirmations.length} Pending' : 'Create Trade',
                      subtitle: _dashShowQuickTrade ? 'Click to hide desk' : 'Trade Desk & Dispatch',
                      icon: Icons.bolt_rounded,
                      accentColor: const Color(0xFF047857),
                      bgColor: const Color(0xFFECFDF5),
                      isActive: _dashShowQuickTrade,
                      onTap: () => setState(() {
                        _dashShowQuickTrade = !_dashShowQuickTrade;
                        if (_dashShowQuickTrade) _dashShowOverdue = false;
                      }),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _dashboardActionCard(
                      label: 'Overdue Invoices',
                      value: '${_overdueBills.length} Invoices',
                      subtitle: _dashShowOverdue ? 'Click to hide' : 'Awaiting Settlement > 10 Days',
                      icon: Icons.warning_amber_rounded,
                      accentColor: const Color(0xFFEF4444),
                      bgColor: const Color(0xFFFEF2F2),
                      isActive: _dashShowOverdue,
                      onTap: () => setState(() {
                        _dashShowOverdue = !_dashShowOverdue;
                        if (_dashShowOverdue) _dashShowQuickTrade = false;
                      }),
                    ),
                  ),
                ],
              ),
        const SizedBox(height: 18),

        // 3. QUICK TRADE CONSOLE & PENDING TRADES (OVERFLOW-PROOF)
        if (_dashShowQuickTrade) ...[
          Container(
            padding: EdgeInsets.all(isMobile ? 14 : 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF047857).withOpacity(0.35), width: 1.5),
              boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 16, offset: Offset(0, 6))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.bolt_rounded, color: Color(0xFF047857), size: 22),
                        SizedBox(width: 8),
                        Text(
                          'Quick Trade Confirmation',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -0.3),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18, color: Color(0xFF64748B)),
                      tooltip: 'Close Quick Trade',
                      onPressed: () => setState(() => _dashShowQuickTrade = false),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Top Inputs: Date, Seller, Buyer
                isMobile
                    ? Column(
                        children: [
                          _customField('Date *', _confDateCtrl, icon: Icons.calendar_today_outlined, onTap: () => _selectDateForController(_confDateCtrl)),
                          const SizedBox(height: 10),
                          _customAutocomplete('Seller *', _sellerNames, _confSeller, 'SELECT SELLER', (v) => setState(() => _confSeller = v)),
                          const SizedBox(height: 10),
                          _customAutocomplete('Buyer *', _buyerNames, _confBuyer, 'SELECT BUYER', (v) => setState(() => _confBuyer = v)),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(child: _customField('Date *', _confDateCtrl, icon: Icons.calendar_today_outlined, onTap: () => _selectDateForController(_confDateCtrl))),
                          const SizedBox(width: 12),
                          Expanded(child: _customAutocomplete('Seller *', _sellerNames, _confSeller, 'SELECT SELLER', (v) => setState(() => _confSeller = v))),
                          const SizedBox(width: 12),
                          Expanded(child: _customAutocomplete('Buyer *', _buyerNames, _confBuyer, 'SELECT BUYER', (v) => setState(() => _confBuyer = v))),
                        ],
                      ),
                const SizedBox(height: 14),

                // Bottom Inputs: Type, Rate, and Save Action
                isMobile
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Coconut Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                                  InkWell(onTap: _showManageCommoditiesDialog, child: const Text('+ Manage', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF047857)))),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Container(
                                height: 42,
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFCBD5E1))),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _coconutTypes.contains(_confType) ? _confType : (_coconutTypes.isNotEmpty ? _coconutTypes.first : null),
                                    isExpanded: true,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                    items: _coconutTypes.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                                    onChanged: (val) => setState(() => _confType = val!),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _customField('Rate (₹) *', _confRateCtrl, isNum: true),
                          const SizedBox(height: 14),
                          SizedBox(
                            height: 44,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF047857),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: _saveQuickTradeEntry,
                              icon: const Icon(Icons.check_circle_outline, size: 18),
                              label: const Text('Save Trade Confirmation', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            flex: 4,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Coconut Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                                    InkWell(onTap: _showManageCommoditiesDialog, child: const Text('+ Manage', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF047857)))),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                Container(
                                  height: 42,
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFCBD5E1))),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _coconutTypes.contains(_confType) ? _confType : (_coconutTypes.isNotEmpty ? _coconutTypes.first : null),
                                      isExpanded: true,
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                      items: _coconutTypes.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                                      onChanged: (val) => setState(() => _confType = val!),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 3,
                            child: _customField('Rate (₹) *', _confRateCtrl, isNum: true),
                          ),
                          const SizedBox(width: 14),
                          SizedBox(
                            height: 42,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF047857),
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: _saveQuickTradeEntry,
                              icon: const Icon(Icons.check_circle_outline, size: 18),
                              label: const Text('Save Trade', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _buildPendingTradesTable(curConfirmations),
          const SizedBox(height: 18),
        ],

        // 4. OVERDUE INVOICES ALERT TABLE
        if (_dashShowOverdue) ...[
          _buildOverdueAlertCard(),
          const SizedBox(height: 18),
        ],
      ],
    );
  }
  Future<void> _saveQuickTradeEntry() async {
    final sRate = double.tryParse(_confRateCtrl.text.trim()) ?? 0.0;
    if (_confSeller.trim().isEmpty || _confBuyer.trim().isEmpty || sRate <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text('Please select Seller, Buyer, and enter a valid Rate.'),
        ),
      );
      return;
    }

    setState(() {
      _saveStateToHistory();
      _confirmations.add(TradeConfirmation(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        date: _confDateCtrl.text.trim(),
        seller: _confSeller.trim().toUpperCase(),
        buyer: _confBuyer.trim().toUpperCase(),
        coconutType: _confType,
        rate: sRate,
        status: 'PENDING',
      ));
      _confRateCtrl.clear();
      _confSeller = "";
      _confBuyer = "";
      _confCocotype = "TENDER"; // Always maintain TENDER default
    });

    await _commitToLocalDrive();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: Color(0xFF047857), content: Text('Trade Confirmation saved to Pending Trades!')),
      );
    }
  }
  // --- REUSABLE INTERACTIVE ACTION CARD ---
  Widget _dashboardActionCard({
    required String label,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required Color bgColor,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.all(isMobile ? 14 : 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isActive ? accentColor : const Color(0xFFE2E8F0),
              width: isActive ? 2.0 : 1.2,
            ),
            boxShadow: isActive
                ? [BoxShadow(color: accentColor.withOpacity(0.12), blurRadius: 14, offset: const Offset(0, 4))]
                : const [BoxShadow(color: Color(0x04000000), blurRadius: 12, offset: Offset(0, 4))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      label.toUpperCase(),
                      style: TextStyle(
                        fontSize: isMobile ? 10 : 11,
                        fontWeight: FontWeight.w900,
                        color: isActive ? accentColor : const Color(0xFF64748B),
                        letterSpacing: 0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: isMobile ? 16 : 18, color: accentColor),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: accentColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: isMobile ? 10 : 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    isActive ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    size: 16,
                    color: isActive ? accentColor : const Color(0xFF94A3B8),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper widget for Bento Metric Cards
  Widget _bentoMetricCard(String label, String value, String subtitle, IconData icon, Color accentColor, Color bgColor) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: const [BoxShadow(color: Color(0x04000000), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: TextStyle(fontSize: isMobile ? 9.5 : 10.5, fontWeight: FontWeight.w900, color: const Color(0xFF64748B), letterSpacing: 0.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: isMobile ? 15 : 17, color: accentColor),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(fontSize: isMobile ? 18 : 22, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A), letterSpacing: -0.5),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(width: 5, height: 5, decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  subtitle,
                  style: TextStyle(fontSize: isMobile ? 10 : 10.5, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPendingTradesTable(List<dynamic> curConfirmations) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 16, offset: Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Pending Trade Confirmations (Awaiting Dispatch)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE2E8F0))),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                  columns: const [
                    DataColumn(label: Text('DATE', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('SELLER', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('BUYER', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('TYPE', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('RATE', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('ACTIONS', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold))),
                  ],
                  rows: curConfirmations.isEmpty
                      ? [
                          const DataRow(cells: [
                            DataCell(SizedBox()), DataCell(SizedBox()),
                            DataCell(Center(child: Text('No pending trades.', style: TextStyle(color: Color(0xFF94A3B8))))),
                            DataCell(SizedBox()), DataCell(SizedBox()), DataCell(SizedBox()),
                          ])
                        ]
                      : curConfirmations.map((c) {
                          return DataRow(cells: [
                            DataCell(Text(c.date, style: const TextStyle(fontWeight: FontWeight.w600))),
                            DataCell(Text(c.seller, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)))),
                            DataCell(Text(c.buyer, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)))),
                            DataCell(Text(c.coconutType)),
                            DataCell(Text(money(c.rate), style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF047857)))),
                            DataCell(Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), side: const BorderSide(color: Colors.blue)),
                                  onPressed: () => _routeToTruck(c),
                                  icon: const Icon(Icons.local_shipping_rounded, size: 14, color: Colors.blue),
                                  label: const Text('Truck', style: TextStyle(fontSize: 11, color: Colors.blue)),
                                ),
                                const SizedBox(width: 6),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), side: const BorderSide(color: Color(0xFF047857))),
                                  onPressed: () => _routeToInvoice(c),
                                  icon: const Icon(Icons.receipt_long_rounded, size: 14, color: Color(0xFF047857)),
                                  label: const Text('Invoice', style: TextStyle(fontSize: 11, color: Color(0xFF047857))),
                                ),
                                const SizedBox(width: 6),
                                IconButton(
                                  icon: const Icon(Icons.cancel_outlined, size: 18, color: Colors.red),
                                  onPressed: () { setState(() => c.status = 'CANCELLED'); _commitToLocalDrive(); },
                                ),
                              ],
                            )),
                          ]);
                        }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

 Widget _buildOverdueAlertCard() {
    if (_overdueBills.isEmpty) return const SizedBox.shrink();

    final ScrollController verticalScroll = ScrollController();
    final ScrollController horizontalScroll = ScrollController();

    const Map<int, TableColumnWidth> colWidths = {
      0: FlexColumnWidth(1.15), // DATE
      1: FlexColumnWidth(2.5),  // SELLER
      2: FlexColumnWidth(2.3),  // BUYER
      3: FlexColumnWidth(1.2),  // BILL
      4: FlexColumnWidth(1.3),  // BUYER BAL
      5: FlexColumnWidth(1.3),  // SELLER BAL
      6: FlexColumnWidth(0.95), // ACTION
    };

    Widget cellHeader(String title, {TextAlign align = TextAlign.left}) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Text(
        title,
        textAlign: align,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          color: Color(0xFF991B1B),
        ),
      ),
    );

    Widget cellText(String text, {bool isBold = false, Color? color, TextAlign align = TextAlign.left}) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8.5),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
          color: color ?? const Color(0xFF1E293B),
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );

    // Height calculation: ~38px per row * 7 visible rows = 266px fixed body height
    final double bodyHeight = _overdueBills.length > 7 ? 266.0 : (_overdueBills.length * 38.0);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFECACA), width: 1.2),
        boxShadow: const [
          BoxShadow(color: Color(0x0C991B1B), blurRadius: 18, offset: Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Premium Header Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFEF2F2), Color(0xFFFFF1F2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
              border: Border(bottom: BorderSide(color: Color(0xFFFEE2E2), width: 1.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 18),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Overdue Invoices',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5, color: Color(0xFF991B1B), letterSpacing: -0.2),
                        ),
                        Text(
                          'Awaiting settlement over 10+ days',
                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500, color: Colors.red.shade700),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [BoxShadow(color: Color(0x33DC2626), blurRadius: 6, offset: Offset(0, 2))],
                  ),
                  child: Text(
                    '${_overdueBills.length} PENDING',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10.5, color: Colors.white, letterSpacing: 0.5),
                  ),
                ),
              ],
            ),
          ),

          // 2. Table Component with Pinned Header and 7-Row Viewport
          LayoutBuilder(
            builder: (context, constraints) {
              final double tableWidth = constraints.maxWidth < 880 ? 880 : constraints.maxWidth;

              return Scrollbar(
                controller: horizontalScroll,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: horizontalScroll,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: tableWidth,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Pinned Header
                        Table(
                          columnWidths: colWidths,
                          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                          children: [
                            TableRow(
                              decoration: const BoxDecoration(color: Color(0xFFFFF1F2)),
                              children: [
                                cellHeader('DATE'),
                                cellHeader('SELLER'),
                                cellHeader('BUYER'),
                                cellHeader('BILL'),
                                cellHeader('BUYER BAL'),
                                cellHeader('SELLER BAL'),
                                cellHeader('ACTION', align: TextAlign.center),
                              ],
                            ),
                          ],
                        ),
                        const Divider(height: 1, color: Color(0xFFFEE2E2)),

                        // Scrollable Body locked to 7 Rows
                        SizedBox(
                          height: bodyHeight,
                          child: Scrollbar(
                            controller: verticalScroll,
                            thumbVisibility: true,
                            trackVisibility: true,
                            child: SingleChildScrollView(
                              controller: verticalScroll,
                              scrollDirection: Axis.vertical,
                              child: Table(
                                columnWidths: colWidths,
                                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                                border: const TableBorder(
                                  horizontalInside: BorderSide(color: Color(0xFFF8FAFC), width: 1),
                                ),
                                children: _overdueBills.asMap().entries.map((entry) {
                                  final idx = entry.key;
                                  final item = entry.value;
                                  final t = item['truck'];
                                  final double billAmount = (item['buyerBill'] as num?)?.toDouble() ?? 0.0;
                                  final double bBal = (item['buyerBal'] as num?)?.toDouble() ?? 0.0;
                                  final double sBal = (item['sellerBal'] as num?)?.toDouble() ?? 0.0;
                                  final bool isEven = idx % 2 == 0;

                                  return TableRow(
                                    decoration: BoxDecoration(
                                      color: isEven ? Colors.white : const Color(0xFFFAFAFA),
                                    ),
                                    children: [
                                      cellText(formatDisplayDate(t.date)),
                                      cellText(t.supplier.isNotEmpty ? t.supplier : '—', isBold: true),
                                      cellText(t.buyer.isNotEmpty ? t.buyer : 'Unknown'),
                                      cellText(money(billAmount), isBold: true, color: const Color(0xFF0F172A)),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                        child: bBal > 0
                                            ? Text(money(bBal), style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFDC2626), fontSize: 12))
                                            : Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(4)),
                                                child: const Text('CLEAR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 9.5, color: Color(0xFF047857))),
                                              ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                        child: sBal > 0
                                            ? Text(money(sBal), style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFDC2626), fontSize: 12))
                                            : Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(4)),
                                                child: const Text('CLEAR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 9.5, color: Color(0xFF047857))),
                                              ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        child: Center(
                                          child: FilledButton(
                                            style: FilledButton.styleFrom(
                                              backgroundColor: const Color(0xFF047857),
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                              minimumSize: const Size(44, 26),
                                              elevation: 0,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                            ),
                                            onPressed: () => _markBillAsPaid(item),
                                            child: const Text('Pay', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
  void _markBillAsPaid(dynamic overdueItem) {
  final t = overdueItem['truck'];
  final double bBal = (overdueItem['buyerBal'] as num?)?.toDouble() ?? 0.0;
  final double sBal = (overdueItem['sellerBal'] as num?)?.toDouble() ?? 0.0;

  if (bBal <= 0 && sBal <= 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('This bill is already fully settled!')),
    );
    return;
  }

  final nowStr = formatDisplayDate(DateTime.now().toIso8601String());
  final nowMs = "${DateTime.now().microsecondsSinceEpoch}_${DateTime.now().millisecond}";

  setState(() {
    if (bBal > 0 && sBal > 0 && bBal == sBal) {
      // Both parties have identical pending amounts: single direct entry clears both
      _payments.add(PaymentEntry(
        id: '${nowMs}_direct',
        state: _selectedState,
        type: "DIRECT SETTLEMENT",
        seller: t.supplier,
        buyer: t.buyer,
        amount: bBal,
        transportReceived: 0,
        settlement: 0,
        mode: "DIRECT",
        date: nowStr,
        truckId: t.id,
      ));
    } else {
      // Clear Buyer side if pending without affecting the seller
      if (bBal > 0) {
        _payments.add(PaymentEntry(
          id: '${nowMs}_buyer',
          state: _selectedState,
          type: "RECEIPT FROM BUYER",
          seller: t.supplier,
          buyer: t.buyer,
          amount: bBal,
          transportReceived: 0,
          settlement: 0,
          mode: "DIRECT",
          date: nowStr,
          truckId: t.id,
        ));
      }
      // Clear Seller side if pending without affecting the buyer
      if (sBal > 0) {
        _payments.add(PaymentEntry(
          id: '${nowMs}_seller',
          state: _selectedState,
          type: "PAYMENT TO SELLER",
          seller: t.supplier,
          buyer: t.buyer,
          amount: sBal,
          transportReceived: 0,
          settlement: 0,
          mode: "DIRECT",
          date: nowStr,
          truckId: t.id,
        ));
      }
    }

    _calculateOverdueBills(_trucks);
  });

  _commitToLocalDrive();

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: const Color(0xFF047857),
      content: Text(
        'Cleared ${t.truck.isNotEmpty ? t.truck : "Invoice"}! (Buyer: ${money(bBal)}, Seller: ${money(sBal)})',
      ),
    ),
  );
}

   void _carryForwardFinancialYearBalances(String newYear) {
    final startYear = newYear.split('-')[0];
    final String openingDate = "$startYear-04-01";
    int buyerCount = 0;
    int sellerCount = 0;

    for (var buyerName in _buyerNames) {
      final double totalBilled = _trucks
          .where((t) => t.state == _selectedState && t.buyer.toUpperCase() == buyerName.toUpperCase())
          .fold(0.0, (sum, t) => sum + (t.buyerBill > 0 ? t.buyerBill : t.supplierBill));

      final double totalPaid = _payments
          .where((p) => p.state == _selectedState && p.buyer.toUpperCase() == buyerName.toUpperCase())
          .fold(0.0, (sum, p) => sum + p.amount + p.settlement);

      final double pending = totalBilled - totalPaid;

      if (pending > 0) {
        final alreadyLogged = _trucks.any((t) =>
            t.buyer.toUpperCase() == buyerName.toUpperCase() &&
            t.type == "OPENING BALANCE" &&
            t.date == openingDate);

        if (!alreadyLogged) {
          _trucks.add(TruckEntry(
            id: 'OB-BUYER-${DateTime.now().millisecondsSinceEpoch}-$buyerCount',
            state: _selectedState,
            date: openingDate,
            truck: 'OPENING BAL',
            supplier: '—',
            buyer: buyerName.toUpperCase(),
            transporter: '—',
            type: 'OPENING BALANCE',
            qty: 0,
            supplierBill: 0,
            buyerBill: pending,
            commission: 0,
            transportExp: 0,
            freight: 0,
            advance: 0,
          ));
          buyerCount++;
        }
      }
    }

    for (var sellerName in _sellerNames) {
      final double totalBilled = _trucks
          .where((t) => t.state == _selectedState && t.supplier.toUpperCase() == sellerName.toUpperCase())
          .fold(0.0, (sum, t) => sum + t.supplierBill);

      final double totalPaid = _payments
          .where((p) => p.state == _selectedState && p.seller.toUpperCase() == sellerName.toUpperCase())
          .fold(0.0, (sum, p) => sum + p.amount + p.settlement);

      final double pending = totalBilled - totalPaid;

      if (pending > 0) {
        final alreadyLogged = _trucks.any((t) =>
            t.supplier.toUpperCase() == sellerName.toUpperCase() &&
            t.type == "OPENING BALANCE" &&
            t.date == openingDate);

        if (!alreadyLogged) {
          _trucks.add(TruckEntry(
            id: 'OB-SELLER-${DateTime.now().millisecondsSinceEpoch}-$sellerCount',
            state: _selectedState,
            date: openingDate,
            truck: 'OPENING BAL',
            supplier: sellerName.toUpperCase(),
            buyer: '—',
            transporter: '—',
            type: 'OPENING BALANCE',
            qty: 0,
            supplierBill: pending,
            buyerBill: 0,
            commission: 0,
            transportExp: 0,
            freight: 0,
            advance: 0,
          ));
          sellerCount++;
        }
      }
    }

    setState(() => _selectedFinancialYear = newYear);
    _commitToLocalDrive();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF047857),
        content: Text('Balances rolled into FY $newYear! ($buyerCount Buyers, $sellerCount Sellers carried forward).'),
      ),
    );
  }

  void _routeToTruck(dynamic conf) {
    setState(() {
      _selectedTab = 'trucks'; _editingTruckId = null; _editingInvoiceId = null;
      _tDateCtrl.text = conf.date; _tSupplier = conf.seller; _tBuyer = conf.buyer; _tCoconutType = conf.coconutType;
      conf.status = 'DISPATCHED';
    });
    _commitToLocalDrive();
  }

  void _routeToInvoice(dynamic conf) {
    setState(() {
      _selectedTab = 'invoice'; _editingTruckId = null; _editingInvoiceId = null;
      _iDateCtrl.text = conf.date; _iSeller = conf.seller; _iBuyer = conf.buyer;
      if (_invoiceGoods.isNotEmpty) {
        _invoiceGoods[0].descCtrl.text = conf.coconutType; _invoiceGoods[0].rateCtrl.text = conf.rate.toString();
      }
      final matchedBuyer = _parties.firstWhere((p) => p.name == conf.buyer, orElse: () => Party(name: "", type: "", phone: "", address: ""));
      _iAddressCtrl.text = matchedBuyer.address; _iPhoneCtrl.text = matchedBuyer.phone;
      conf.status = 'INVOICED';
    });
    _commitToLocalDrive();
  }

  void _clearTruckForm() {
    _tRemarksCtrl.clear();
    setState(() {
      _editingTruckId = null;
      _hasCustomBuyerBill = false; // Reset to single bill field
      _tTruckCtrl.clear();
      _tQtyCtrl.clear();
      _tSBillCtrl.clear();
      _tBBillCtrl.clear();
      _tCommCtrl.text = "500";
      _tExpCtrl.text = "0";
      _tFreightCtrl.text = "0";
      _tAdvCtrl.text = "0";
      _tSupplier = "";
      _tBuyer = "";
      _tTransporter = "";
      _tCoconutType = "TENDER";
      _tSourceSeller = "";
    });
  }

  void _clearInvoiceForm() {
    setState(() {
      _editingInvoiceId = null; _iBuyer = ""; _iSeller = ""; _iTransporter = "";
      _iSellerAmountCtrl.clear(); _iTransportExpCtrl.clear(); _iAddressCtrl.clear(); _iPhoneCtrl.clear(); _iLorryCtrl.clear(); _iDriverCtrl.clear();
      _iBagsCtrl.text = "0"; _iBagRateCtrl.text = "0"; _iLoadingManual = false; _iLoadManualAmountCtrl.text = "0"; _iLoadRateCtrl.text = "0";
      _iAmcCtrl.text = "0"; _iInsCtrl.text = "0"; _iCommCtrl.text = "0"; _iAdvCtrl.text = "0"; _iFreightCtrl.text = "0";
      for (var it in _invoiceGoods) { it.dispose(); }
      _invoiceGoods.clear(); _addGoodsRow();
    });
  }

  void _editFromReport(dynamic t) {
  _tRemarksCtrl.text = t.remarks;
  if (t.isInvoice) {
    setState(() {
      _selectedTab = 'invoice';
      _editingInvoiceId = t.id;
      _editingTruckId = null;
      _iNoCtrl.text = t.invoiceNo.isNotEmpty ? t.invoiceNo : "INV-00001";
      _iDateCtrl.text = t.date;
      _tSourceSeller = t.sourceSeller;
      _iBuyer = t.buyer;
      _iSeller = t.supplier == '—' ? '' : t.supplier;
      _iTransporter = t.transporter == '—' ? '' : t.transporter;
      _iLorryCtrl.text = t.truck == '—' ? '' : t.truck;
      _iSellerAmountCtrl.text = t.supplierBill > 0 ? t.supplierBill.toStringAsFixed(0) : '';
      _iTransportExpCtrl.text = t.transportExp > 0 ? t.transportExp.toStringAsFixed(0) : '';
      _iFreightCtrl.text = t.freight > 0 ? t.freight.toStringAsFixed(0) : '';
      _iAdvCtrl.text = t.advance > 0 ? t.advance.toStringAsFixed(0) : '';
      _iCommCtrl.text = t.commission > 0 ? t.commission.toStringAsFixed(0) : '';
      _iBagsCtrl.text = t.bags > 0 ? t.bags.toStringAsFixed(0) : '0';
      _iBagRateCtrl.text = t.bagRate > 0 ? t.bagRate.toStringAsFixed(0) : '0';
      _iLoadRateCtrl.text = t.loadRate > 0 ? t.loadRate.toStringAsFixed(0) : '0';
      _iInsCtrl.text = t.insurance > 0 ? t.insurance.toStringAsFixed(0) : '0';
      _iAmcCtrl.text = t.amc > 0 ? t.amc.toStringAsFixed(0) : '0';
      _iLoadingManual = t.isLoadManual;
      _iLoadManualAmountCtrl.text = t.loadManualAmt > 0 ? t.loadManualAmt.toStringAsFixed(0) : '0';
      _tSourceSeller = t.sourceSeller;
    
      final matchedBuyer = _parties.firstWhere(
        (p) => p.name.toUpperCase() == t.buyer.toUpperCase(),
        orElse: () => Party(name: "", type: "", phone: "", address: ""),
      );
      _iAddressCtrl.text = matchedBuyer.address;
      _iPhoneCtrl.text = matchedBuyer.phone;

      for (var it in _invoiceGoods) { it.dispose(); }
      _invoiceGoods.clear();
      _addGoodsRow(
        desc: t.type.isNotEmpty ? t.type : "COCONUT",
        qty: t.qty > 0 ? t.qty.toStringAsFixed(0) : '',
        rate: t.rate > 0 ? t.rate.toStringAsFixed(0) : '',
      );
    });
  } else {
    setState(() {
      _selectedTab = 'trucks';
      _editingTruckId = t.id;
      _editingInvoiceId = null;
      _hasCustomBuyerBill = (t.buyerBill > 0 && t.buyerBill != t.supplierBill);
      _tTruckCtrl.text = t.truck == '—' ? '' : t.truck;
      _tDateCtrl.text = t.date;
      _tSupplier = t.supplier == '—' ? '' : t.supplier;
      _tBuyer = t.buyer;
      _tTransporter = t.transporter == '—' ? '' : t.transporter;
      _tCoconutType = t.type;
      _tQtyCtrl.text = t.qty > 0 ? t.qty.toStringAsFixed(0) : '';
      _tSBillCtrl.text = t.supplierBill > 0 ? t.supplierBill.toStringAsFixed(0) : '';
      _tBBillCtrl.text = t.buyerBill > 0 ? t.buyerBill.toStringAsFixed(0) : '';
      _tCommCtrl.text = t.commission > 0 ? t.commission.toStringAsFixed(0) : '500';
      _tExpCtrl.text = t.transportExp > 0 ? t.transportExp.toStringAsFixed(0) : '0';
      _tFreightCtrl.text = t.freight > 0 ? t.freight.toStringAsFixed(0) : '0';
      _tAdvCtrl.text = t.advance > 0 ? t.advance.toStringAsFixed(0) : '0';
    });
  }
}
void _openOrGenerateInvoiceForTruck(dynamic t) {
    setState(() {
      _selectedTab = 'invoice';
      _editingTruckId = t.id;
      _editingInvoiceId = null;

      _iDateCtrl.text = t.date;
      _iBuyer = t.buyer;
      _iSeller = t.supplier == '—' ? '' : t.supplier;
      _iTransporter = t.transporter == '—' ? '' : t.transporter;
      _iLorryCtrl.text = t.truck == '—' ? '' : t.truck;
      _iSellerAmountCtrl.text = t.supplierBill > 0 ? t.supplierBill.toStringAsFixed(0) : '';
      _iTransportExpCtrl.text = t.transportExp > 0 ? t.transportExp.toStringAsFixed(0) : '';
      _iFreightCtrl.text = t.freight > 0 ? t.freight.toStringAsFixed(0) : '';
      _iAdvCtrl.text = t.advance > 0 ? t.advance.toStringAsFixed(0) : '';
      _iCommCtrl.text = t.commission > 0 ? t.commission.toStringAsFixed(0) : '500';

      final matchedBuyer = _parties.firstWhere(
        (p) => p.name.toUpperCase() == t.buyer.toUpperCase(),
        orElse: () => Party(name: "", type: "", phone: "", address: ""),
      );
      _iAddressCtrl.text = matchedBuyer.address;
      _iPhoneCtrl.text = matchedBuyer.phone;

      for (var it in _invoiceGoods) {
        it.dispose();
      }
      _invoiceGoods.clear();
      _addGoodsRow(
        desc: t.type.isNotEmpty ? t.type : "COCONUT",
        qty: t.qty > 0 ? t.qty.toStringAsFixed(0) : '',
        rate: t.rate > 0 ? t.rate.toStringAsFixed(0) : '',
      );

      _calculateInvoiceTotals();
    });
  }
  void _editPaymentEntryDialog(dynamic p) {
    final amtCtrl = TextEditingController(text: p.amount.toStringAsFixed(0));
    final discCtrl = TextEditingController(text: p.settlement.toStringAsFixed(0));
    final commAdjCtrl = TextEditingController(text: (p.commissionAdjusted as num?)?.toStringAsFixed(0) ?? '0');
    final dateCtrl = TextEditingController(text: p.date);
    String mode = p.mode.toString().trim().toUpperCase();
    if (mode.isEmpty) mode = "DIRECT";

    // Build a dynamic, deduplicated list containing all active modes PLUS the current mode
    final List<String> availableModes = {
      ..._paymentModes,
      p.mode.toString().trim(),
      "DIRECT",
      "CASH",
    }.where((m) => m.isNotEmpty).toSet().toList();

    // Ensure the selected value strictly exists in the list
    final String selectedMode = availableModes.contains(p.mode) 
        ? p.mode 
        : (availableModes.isNotEmpty ? availableModes.first : "DIRECT");

    String selectedSeller = p.seller;
    String selectedBuyer = p.buyer;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.edit_note_rounded, color: Color(0xFF047857)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Edit Payment (${p.type})',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. Reassign Seller / Supplier
                  _customAutocomplete(
                    'Seller / Supplier',
                    _sellerNames,
                    selectedSeller,
                    'SELECT SELLER',
                    (val) => setDlgState(() => selectedSeller = val),
                  ),
                  const SizedBox(height: 10),

                  // 2. Reassign Buyer
                  _customAutocomplete(
                    'Buyer',
                    _buyerNames,
                    selectedBuyer,
                    'SELECT BUYER',
                    (val) => setDlgState(() => selectedBuyer = val),
                  ),
                  const SizedBox(height: 10),

                  // 3. Payment amounts
                  _customField('Amount (₹)', amtCtrl, isNum: true),
                  const SizedBox(height: 10),
                  _customField('Discount / Settlement (₹)', discCtrl, isNum: true),
                  const SizedBox(height: 10),
                  _customField('Commission Adjusted (₹)', commAdjCtrl, isNum: true),
                  const SizedBox(height: 10),

                  // 4. Payment Mode (Safe & Deduplicated)
                  DropdownButtonFormField<String>(
      value: selectedMode,
      items: availableModes
          .map((m) => DropdownMenuItem(value: m, child: Text(m)))
          .toList(),
      onChanged: (val) {
        if (val != null) setDlgState(() => mode = val);
      },      
                    decoration: InputDecoration(
                      labelText: 'Payment Mode',
                      labelStyle: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // 5. Date
                  _customField('Date', dateCtrl, readOnly: true, icon: Icons.calendar_today_outlined, onTap: () => _selectDateForController(dateCtrl)),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF047857),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                final sClean = selectedSeller.trim().toUpperCase();
                final bClean = selectedBuyer.trim().toUpperCase();

                final rawAmt = amtCtrl.text.replaceAll('₹', '').replaceAll(',', '').trim();
                List<double> splitAmts = [];
                if (rawAmt.contains('+')) {
                  splitAmts = rawAmt.split('+').map((s) => double.tryParse(s.trim()) ?? 0.0).where((a) => a > 0).toList();
                } else {
                  final a = double.tryParse(rawAmt) ?? 0.0;
                  if (a > 0) splitAmts.add(a);
                }

                setState(() {
                  if (sClean != p.seller.trim().toUpperCase() || bClean != p.buyer.trim().toUpperCase()) {
                    p.truckId = '';
                  }
                  p.seller = sClean;
                  p.buyer = bClean;
                  p.amount = splitAmts.isNotEmpty ? splitAmts.first : p.amount;
                  p.settlement = double.tryParse(discCtrl.text) ?? p.settlement;
                  p.commissionAdjusted = double.tryParse(commAdjCtrl.text) ?? p.commissionAdjusted;
                  p.mode = mode;
                  p.date = dateCtrl.text.trim();

                  if (splitAmts.length > 1) {
                    final baseId = DateTime.now().millisecondsSinceEpoch;
                    for (int i = 1; i < splitAmts.length; i++) {
                      _payments.add(PaymentEntry(
                        id: '${baseId}_split_$i',
                        state: _selectedState,
                        type: p.type,
                        seller: sClean,
                        buyer: bClean,
                        amount: splitAmts[i],
                        transportReceived: 0,
                        settlement: 0,
                        commissionAdjusted: 0,
                        mode: mode,
                        date: dateCtrl.text.trim(),
                        truckId: p.truckId,
                      ));
                    }
                  }

                  _calculateOverdueBills(_trucks);
                });

                _commitToLocalDrive();
                Navigator.pop(ctx);
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context, String itemTitle) async {
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirm Deletion', style: TextStyle(fontWeight: FontWeight.w900)),
        content: Text('Are you sure you want to delete "$itemTitle"? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)), onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    ) ?? false;
  }

 // ---------------- PARTIES DIRECTORY (WITH SEARCH & SORT/FILTER) ----------------
  Widget _buildPartiesView() {
    final query = _partySearchCtrl.text.trim().toLowerCase();
    final filteredParties = _parties.where((p) {
      final matchesType = _partyTypeFilter == 'ALL' || p.type.toUpperCase() == _partyTypeFilter;
      final matchesQuery = query.isEmpty ||
          p.name.toLowerCase().contains(query) ||
          p.phone.toLowerCase().contains(query) ||
          p.address.toLowerCase().contains(query);
      return matchesType && matchesQuery;
    }).toList();

    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 16, offset: Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Parties Directory', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF047857), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                onPressed: () => _showAddPartyDialog(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Party'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Search Bar & Filter Chips
          _responsiveRow([
            Expanded(
              flex: 3,
              child: SizedBox(
                height: 40,
                child: TextField(
                  controller: _partySearchCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search by name, phone, address...',
                    prefixIcon: const Icon(Icons.search, size: 16),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 4,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['ALL', 'BUYER', 'SELLER', 'TRANSPORTER'].map((type) {
                    final bool active = _partyTypeFilter == type;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(type),
                        selected: active,
                        selectedColor: const Color(0xFF047857),
                        labelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: active ? Colors.white : const Color(0xFF64748B)),
                        onSelected: (_) => setState(() => _partyTypeFilter = type),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE2E8F0))),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                  columns: const [
                    DataColumn(label: Text('PARTY NAME', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                    DataColumn(label: Text('TYPE', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                    DataColumn(label: Text('PHONE', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                    DataColumn(label: Text('ADDRESS', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                    DataColumn(label: Text('ACTIONS', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                  ],
                  rows: filteredParties.isEmpty
                      ? [
                          const DataRow(cells: [
                            DataCell(SizedBox()), DataCell(SizedBox()),
                            DataCell(Center(child: Text('No matching parties found.', style: TextStyle(color: Color(0xFF94A3B8))))),
                            DataCell(SizedBox()), DataCell(SizedBox()),
                          ])
                        ]
                      : filteredParties.map((p) => DataRow(cells: [
                          DataCell(Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: p.type == "BUYER" ? const Color(0xFFECFDF5) : (p.type == "SELLER" ? const Color(0xFFFFFBEB) : const Color(0xFFEFF6FF)),
                                child: Text(
                                  p.name.isNotEmpty ? p.name.substring(0, 1) : 'P',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: p.type == "BUYER" ? const Color(0xFF047857) : (p.type == "SELLER" ? const Color(0xFFB45309) : const Color(0xFF1D4ED8))),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                            ],
                          )),
                          DataCell(Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: p.type == "BUYER" ? const Color(0xFFECFDF5) : (p.type == "SELLER" ? const Color(0xFFFFFBEB) : const Color(0xFFEFF6FF)),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: p.type == "BUYER" ? const Color(0xFFA7F3D0) : (p.type == "SELLER" ? const Color(0xFFFDE68A) : const Color(0xFFBFDBFE))),
                            ),
                            child: Text(
                              p.type,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10.5, color: p.type == "BUYER" ? const Color(0xFF047857) : (p.type == "SELLER" ? const Color(0xFFB45309) : const Color(0xFF1D4ED8))),
                            ),
                          )),
                          DataCell(Text(p.phone)),
                          DataCell(Text(p.address)),
                          DataCell(Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(icon: const Icon(Icons.edit, color: Color(0xFF047857), size: 18), onPressed: () => _showAddPartyDialog(party: p)),
                              IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18), onPressed: () async {
                                if (await _confirmDelete(context, p.name)) {
                                  _saveStateToHistory();
                                  setState(() => _parties.remove(p));
                                  _commitToLocalDrive();
                                }
                              }),
                            ],
                          )),
                        ])).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  void _showManagePaymentModesDialog({Function(String)? onAdded}) {
    final ctrl = TextEditingController();

    // Helper dialog to edit/rename a payment mode
    void showEditModeDialog(String oldMode, StateSetter setParentState) {
      final editCtrl = TextEditingController(text: oldMode);
      showDialog(
        context: context,
        builder: (ctx2) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Edit Payment Mode',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          content: TextField(
            controller: editCtrl,
            inputFormatters: [UpperCaseTextFormatter()],
            autofocus: true,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            decoration: InputDecoration(
              labelText: 'Mode Name',
              hintText: 'e.g. HDFC BANK, RTGS',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF047857), width: 1.5),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx2),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF047857),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                final newMode = editCtrl.text.trim().toUpperCase();
                if (newMode.isNotEmpty && newMode != oldMode) {
                  setState(() {
                    _saveStateToHistory();
                    final idx = _paymentModes.indexOf(oldMode);
                    if (idx != -1) {
                      _paymentModes[idx] = newMode;
                    }
                    if (_payMode == oldMode) {
                      _payMode = newMode;
                    }
                    // Update all existing records for consistency
                    for (var p in _payments) {
                      if (p.mode.trim().toUpperCase() == oldMode) {
                        p.mode = newMode;
                      }
                    }
                    for (var tp in _transportPayments) {
                      if (tp.bank.trim().toUpperCase() == oldMode) {
                        tp.bank = newMode;
                      }
                    }
                    _calculateOverdueBills(_trucks);
                  });

                  setParentState(() {});
                  _commitToLocalDrive();
                }
                Navigator.pop(ctx2);
              },
              child: const Text('Update'),
            ),
          ],
        ),
      );
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Manage Payment Modes',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
          ),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Input Row to Add New Mode
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 42,
                        child: TextField(
                          controller: ctrl,
                          inputFormatters: [UpperCaseTextFormatter()],
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            hintText: 'e.g. HDFC BANK, CHEQUE, RTGS',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF047857),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        final val = ctrl.text.trim().toUpperCase();
                        if (val.isNotEmpty && !_paymentModes.contains(val)) {
                          setDlgState(() => _paymentModes.add(val));
                          setState(() {
                            if (!_paymentModes.contains(val)) _paymentModes.add(val);
                            _payMode = val;
                          });
                          _commitToLocalDrive();
                          if (onAdded != null) onAdded(val);
                          ctrl.clear();
                        }
                      },
                      child: const Text('Add'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Mode List with Edit and Delete Icons
                Container(
                  constraints: const BoxConstraints(maxHeight: 260),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _paymentModes.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    itemBuilder: (c, i) {
                      final mode = _paymentModes[i];
                      final isSystemDefault = ["DIRECT", "CASH"].contains(mode);

                      return ListTile(
                        dense: true,
                        title: Text(
                          mode,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Edit Icon
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, color: Color(0xFF047857), size: 17),
                              tooltip: 'Edit Mode Name',
                              onPressed: () => showEditModeDialog(mode, setDlgState),
                            ),
                            // Delete Icon (Protected for default DIRECT/CASH)
                            if (!isSystemDefault)
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 17),
                                tooltip: 'Delete Mode',
                                onPressed: () {
                                  setDlgState(() => _paymentModes.removeAt(i));
                                  setState(() {
                                    if (!_paymentModes.contains(_payMode) && _paymentModes.isNotEmpty) {
                                      _payMode = _paymentModes.first;
                                    }
                                  });
                                  _commitToLocalDrive();
                                },
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close', style: TextStyle(color: Color(0xFF64748B))),
            ),
          ],
        ),
      ),
    );
  }
  void _showManageCommoditiesDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Manage Coconut Types', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
          content: SizedBox(
            width: 340,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 42,
                        child: TextField(
                          controller: ctrl,
                          inputFormatters: [UpperCaseTextFormatter()],
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            hintText: 'e.g. GOTTA, BOMBAY CHEEL',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFF047857), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                      onPressed: () {
                        final val = ctrl.text.trim().toUpperCase();
                        if (val.isNotEmpty && !_coconutTypes.contains(val)) {
                          setDlgState(() => _coconutTypes.add(val));
                          setState(() {});
                          _commitToLocalDrive();
                          ctrl.clear();
                        }
                      },
                      child: const Text('Add'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  constraints: const BoxConstraints(maxHeight: 280),
                  decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE2E8F0)), borderRadius: BorderRadius.circular(12)),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _coconutTypes.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    itemBuilder: (c, i) => ListTile(
                      dense: true,
                      title: Text(_coconutTypes[i], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 18),
                        onPressed: () {
                          setDlgState(() => _coconutTypes.removeAt(i));
                          setState(() {
                            if (!_coconutTypes.contains(_confType) && _coconutTypes.isNotEmpty) _confType = _coconutTypes.first;
                            if (!_coconutTypes.contains(_tCoconutType) && _coconutTypes.isNotEmpty) _tCoconutType = _coconutTypes.first;
                          });
                          _commitToLocalDrive();
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close', style: TextStyle(color: Color(0xFF64748B))))],
        ),
      ),
    );
  }

  void _showAddPartyDialog({dynamic party, String? initialName, String? initialType, Function(String)? onCreated}) {
    final nameCtrl = TextEditingController(text: party?.name ?? (initialName != null ? initialName.toUpperCase() : ''));
    final phoneCtrl = TextEditingController(text: party?.phone ?? '');
    final addrCtrl = TextEditingController(text: party?.address ?? '');
    String pType = party?.type ?? initialType ?? "BUYER";

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          void savePartyAction() {
            final name = nameCtrl.text.toUpperCase().trim();
            if (name.isNotEmpty) {
              setState(() {
                if (party != null) {
                  party.name = name;
                  party.type = pType;
                  party.phone = phoneCtrl.text.trim();
                  party.address = addrCtrl.text.toUpperCase().trim();
                } else {
                  _parties.add(Party(name: name, type: pType, phone: phoneCtrl.text.trim(), address: addrCtrl.text.toUpperCase().trim()));
                }
              });
              _commitToLocalDrive();
              if (onCreated != null) onCreated(name);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: const Color(0xFF10B981), content: Text('$name saved successfully!')));
            }
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(party != null ? 'Edit Party Details' : 'Add New Party', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF0F172A))),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _customField('Party Name', nameCtrl, onSubmitted: (_) => savePartyAction()),
                const SizedBox(height: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Party Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                    const SizedBox(height: 5),
                    Container(
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE2E8F0))),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: pType,
                          isExpanded: true,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          items: ["BUYER", "SELLER", "TRANSPORTER"].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                          onChanged: (v) => setDlgState(() => pType = v!),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _customField('Phone', phoneCtrl, isNum: true, onSubmitted: (_) => savePartyAction()),
                const SizedBox(height: 12),
                _customField('Address', addrCtrl, onSubmitted: (_) => savePartyAction()),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B)))),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF047857), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                onPressed: savePartyAction,
                child: Text(party != null ? 'Update Party' : 'Save & Select'),
              ),
            ],
          );
        },
      ),
    );
  }

 // ---------------- 2. TRUCK LOGISTICS CONSOLE (FORM ONLY) ----------------
  Widget _buildTruckLogisticsView() {
    final double curFreight = double.tryParse(_tFreightCtrl.text) ?? 0.0;
    final double curAdv = double.tryParse(_tAdvCtrl.text) ?? 0.0;
    final double freightBal = curFreight - curAdv;

    Widget sectionTitle(String title, IconData icon) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, size: 14, color: const Color(0xFF047857)),
            ),
            const SizedBox(width: 8),
            Text(
              title.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: Color(0xFF475569),
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: const [
          BoxShadow(color: Color(0x04000000), blurRadius: 14, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF047857), Color(0xFF065F46)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: const [
                        BoxShadow(color: Color(0x22047857), blurRadius: 8, offset: Offset(0, 3)),
                      ],
                    ),
                    child: const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _editingTruckId != null ? 'Edit Truck Entry' : 'Create Direct Truck Entry',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -0.3),
                      ),
                      Text(
                        'Dispatch and logistics booking console',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              ),
              if (_editingTruckId != null)
                TextButton.icon(
                  onPressed: _clearTruckForm,
                  icon: const Icon(Icons.close_rounded, size: 16, color: Colors.red),
                  label: const Text('Cancel Edit', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 16),

          // SECTION A: ROUTE & PARTIES
          sectionTitle('1. Route & Parties', Icons.map_outlined),
          _responsiveRow([
            Expanded(child: _customField('Truck Number', _tTruckCtrl, hint: 'TRUCK NO (OPTIONAL)')),
            const SizedBox(width: 12),
            Expanded(child: _customField('Date *', _tDateCtrl, icon: Icons.calendar_today_outlined, onTap: () => _selectDateForController(_tDateCtrl))),
            const SizedBox(width: 12),
            Expanded(
              child: _customAutocomplete(
                'Supplier *', _sellerNames, _tSupplier, 'SELECT SELLER',
                (v) => setState(() => _tSupplier = v),
                focusNode: _tSupplierFocus,
                nextFocusNode: _tBuyerFocus,
                onAddPressed: () => _showAddPartyDialog(initialType: 'SELLER', onCreated: (name) => setState(() => _tSupplier = name)),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          _responsiveRow([
            Expanded(
              child: _customAutocomplete(
                'Seller Bought', _sellerNames, _tSourceSeller, 'SELF / DIRECT',
                (v) => setState(() => _tSourceSeller = v),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _customAutocomplete(
                'Buyer *', _buyerNames, _tBuyer, 'SELECT BUYER',
                (v) => setState(() => _tBuyer = v),
                focusNode: _tBuyerFocus,
                nextFocusNode: _tTransporterFocus,
                onAddPressed: () => _showAddPartyDialog(initialType: 'BUYER', onCreated: (name) => setState(() => _tBuyer = name)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _customAutocomplete(
                'Transporter *', _transporterNames, _tTransporter, 'SELECT TRANSPORTER',
                (v) => setState(() => _tTransporter = v),
                focusNode: _tTransporterFocus,
                nextFocusNode: _tQtyFocus,
                onAddPressed: () => _showAddPartyDialog(initialType: 'TRANSPORTER', onCreated: (name) => setState(() => _tTransporter = name)),
              ),
            ),
          ]),

          const SizedBox(height: 20),

          // SECTION B: CONSIGNMENT & COMMERCIALS (SPLIT INTO 2 BALANCED ROWS)
          sectionTitle('2. Consignment & Commercials', Icons.inventory_2_outlined),
          _responsiveRow([
            // Coconut Type
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Coconut Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                      InkWell(
                        onTap: _showManageCommoditiesDialog,
                        child: const Text('+ Manage', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF047857))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _coconutTypes.contains(_tCoconutType) ? _tCoconutType : (_coconutTypes.isNotEmpty ? _coconutTypes.first : null),
                        isExpanded: true,
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        items: _coconutTypes.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _tCoconutType = val);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Quantity
            Expanded(child: _customField('Quantity (Nuts)', _tQtyCtrl, isNum: true)),
          ]),

          const SizedBox(height: 12),

          _responsiveRow([
            // Bill Amount Field(s)
            if (!_hasCustomBuyerBill) ...[
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Bill Amount *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                        InkWell(
                          onTap: () {
                            setState(() {
                              _hasCustomBuyerBill = true;
                              if (_tBBillCtrl.text.isEmpty || _tBBillCtrl.text == "0") {
                                _tBBillCtrl.text = _tSBillCtrl.text;
                              }
                            });
                          },
                          child: const Text('+ Separate Buyer Bill', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF047857))),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    SizedBox(
                      height: 40,
                      child: TextField(
                        controller: _tSBillCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          hintText: 'SELLER & BUYER BILL',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF047857), width: 1.5)),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Expanded(flex: 2, child: _customField('Supplier Bill *', _tSBillCtrl, isNum: true)),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Buyer Bill *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                        InkWell(
                          onTap: () {
                            setState(() {
                              _hasCustomBuyerBill = false;
                              _tBBillCtrl.clear();
                            });
                          },
                          child: const Text('× Match Seller', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    SizedBox(
                      height: 40,
                      child: TextField(
                        controller: _tBBillCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          hintText: 'BUYER BILL',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF047857), width: 1.5)),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(width: 12),
            Expanded(child: _customField('Commission (₹)', _tCommCtrl, isNum: true)),
            const SizedBox(width: 12),
            Expanded(child: _customField('Transport Exp (₹)', _tExpCtrl, isNum: true)),
          ]),

          const SizedBox(height: 20),

          // SECTION C: FREIGHT & FINANCIALS
          sectionTitle('3. Freight & Financials', Icons.payments_outlined),
          _responsiveRow([
            Expanded(child: _customField('Freight (₹)', _tFreightCtrl, isNum: true, onChanged: (_) => setState(() {}))),
            const SizedBox(width: 12),
            Expanded(child: _customField('Advance (₹)', _tAdvCtrl, isNum: true, onChanged: (_) => setState(() {}))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Freight Balance', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                  const SizedBox(height: 5),
                  Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    alignment: Alignment.centerLeft,
                    child: Text(
                      money(freightBal),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: freightBal > 0 ? const Color(0xFFDC2626) : const Color(0xFF047857),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(flex: 2, child: _customField('Remarks / Notes', _tRemarksCtrl, hint: 'ENTER OPTIONAL DISPATCH REMARKS')),
          ]),

          const SizedBox(height: 22),

          // Action Buttons
          Row(
            children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF047857),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  final double sBill = double.tryParse(_tSBillCtrl.text) ?? 0;
                  final double bBill = _hasCustomBuyerBill
                      ? (double.tryParse(_tBBillCtrl.text) ?? sBill)
                      : sBill;

                  final sName = _tSupplier.trim().toUpperCase();
                  final bName = _tBuyer.trim().toUpperCase();
                  final tName = _tTransporter.trim().toUpperCase();
                  final srcSeller = _tSourceSeller.trim().toUpperCase();

                  if (sName.isEmpty || sName == 'SELECT SELLER' ||
                      bName.isEmpty || bName == 'SELECT BUYER' ||
                      tName.isEmpty || tName == 'SELECT TRANSPORTER') {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        backgroundColor: Colors.red,
                        content: Text('Error: Supplier, Buyer, and Transporter are ALL mandatory!'),
                      ),
                    );
                    return;
                  }

                  if (sBill <= 0 && bBill <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        backgroundColor: Colors.red,
                        content: Text('Error: Please enter a valid Bill Amount!'),
                      ),
                    );
                    return;
                  }

                  if (_editingTruckId != null) {
                    final idx = _trucks.indexWhere((x) => x.id == _editingTruckId);
                    if (idx != -1) {
                      setState(() {
                        _trucks[idx] = TruckEntry(
                          id: _editingTruckId!,
                          state: _selectedState,
                          date: _tDateCtrl.text.trim(),
                          truck: _tTruckCtrl.text.trim().toUpperCase(),
                          supplier: sName,
                          sourceSeller: srcSeller,
                          buyer: bName,
                          transporter: tName,
                          type: _tCoconutType,
                          qty: double.tryParse(_tQtyCtrl.text) ?? 0,
                          supplierBill: sBill,
                          buyerBill: bBill,
                          commission: double.tryParse(_tCommCtrl.text) ?? 500,
                          transportExp: double.tryParse(_tExpCtrl.text) ?? 0,
                          freight: double.tryParse(_tFreightCtrl.text) ?? 0,
                          advance: double.tryParse(_tAdvCtrl.text) ?? 0,
                          isInvoice: false,
                          remarks: _tRemarksCtrl.text.trim().toUpperCase(),
                          invoiceNo: _iNoCtrl.text.trim(),
                        );
                        _clearTruckForm();
                      });
                      _commitToLocalDrive();
                      _calculateOverdueBills(_trucks);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Color(0xFF047857), content: Text('Truck entry updated.')));
                    }
                  } else {
                    setState(() {
                      _trucks.add(TruckEntry(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        state: _selectedState,
                        date: _tDateCtrl.text.trim(),
                        truck: _tTruckCtrl.text.trim().toUpperCase(),
                        supplier: sName,
                        sourceSeller: srcSeller,
                        buyer: bName,
                        transporter: tName,
                        type: _tCoconutType,
                        qty: double.tryParse(_tQtyCtrl.text) ?? 0,
                        supplierBill: sBill,
                        buyerBill: bBill,
                        commission: double.tryParse(_tCommCtrl.text) ?? 500,
                        transportExp: double.tryParse(_tExpCtrl.text) ?? 0,
                        freight: double.tryParse(_tFreightCtrl.text) ?? 0,
                        advance: double.tryParse(_tAdvCtrl.text) ?? 0,
                        isInvoice: false,
                        remarks: _tRemarksCtrl.text.trim().toUpperCase(),
                        invoiceNo: _iNoCtrl.text.trim(),
                      ));
                      _clearTruckForm();
                    });
                    _commitToLocalDrive();
                    _calculateOverdueBills(_trucks);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Color(0xFF047857), content: Text('Truck entry recorded.')));
                  }
                },
                icon: const Icon(Icons.check_circle_outline, size: 17),
                label: Text(_editingTruckId != null ? 'Update Entry' : 'Save Truck Entry', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                onPressed: _clearTruckForm,
                child: const Text('Reset Form', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------- INVOICE VIEW & MODERN CANVAS ----------------
  Widget _buildInvoiceView() {
    Widget formBox = Container(
      padding: EdgeInsets.all(isMobile ? 16 : 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 16, offset: Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_editingInvoiceId != null ? 'Edit Tax Invoice' : 'Invoice Details', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
              if (_editingInvoiceId != null)
                TextButton.icon(
                  onPressed: _clearInvoiceForm,
                  icon: const Icon(Icons.cancel, size: 16, color: Colors.red),
                  label: const Text('Cancel Edit', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _responsiveRow([
            Expanded(child: _customField('Invoice No.', _iNoCtrl, readOnly: true)),
            const SizedBox(width: 12),
            Expanded(child: _customField('Invoice Date', _iDateCtrl, icon: Icons.calendar_today_outlined, onTap: () => _selectDateForController(_iDateCtrl))),
            const SizedBox(width: 12),
            Expanded(
              child: _customAutocomplete('Buyer *', _buyerNames, _iBuyer, 'SELECT BUYER', (val) {
                setState(() {
                  _iBuyer = val;
                  final matched = _parties.firstWhere((p) => p.name == val, orElse: () => Party(name: "", type: "", phone: "", address: ""));
                  if (matched.address.isNotEmpty) _iAddressCtrl.text = matched.address;
                  if (matched.phone.isNotEmpty) _iPhoneCtrl.text = matched.phone;
                });
              }, onAddPressed: () => _showAddPartyDialog(initialType: 'BUYER', onCreated: (name) => setState(() {
                  _iBuyer = name;
                  final matched = _parties.firstWhere((p) => p.name == name, orElse: () => Party(name: "", type: "", phone: "", address: ""));
                  if (matched.address.isNotEmpty) _iAddressCtrl.text = matched.address;
                  if (matched.phone.isNotEmpty) _iPhoneCtrl.text = matched.phone;
              }))),
            ),
          ]),
          const SizedBox(height: 12),
          _responsiveRow([
            Expanded(child: _customAutocomplete('Seller', _sellerNames, _iSeller, 'SELECT SELLER', (v) => setState(() => _iSeller = v), onAddPressed: () => _showAddPartyDialog(initialType: 'SELLER', onCreated: (name) => setState(() => _iSeller = name)))),
            const SizedBox(width: 12),
            Expanded(child: _customField('SELLER AMOUNT (MANUAL)', _iSellerAmountCtrl, isNum: true)),
            const SizedBox(width: 12),
            Expanded(child: _customAutocomplete('Transporter', _transporterNames, _iTransporter, 'SELECT TRANSPORTER', (v) => setState(() => _iTransporter = v), onAddPressed: () => _showAddPartyDialog(initialType: 'TRANSPORTER', onCreated: (name) => setState(() => _iTransporter = name)))),
          ]),
          const SizedBox(height: 12),
          _responsiveRow([
            Expanded(child: _customField('Transport Expense', _iTransportExpCtrl, isNum: true)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Divisor', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                  const SizedBox(height: 5),
                  Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE2E8F0))),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<double>(
                        value: _iDivisor,
                        isExpanded: true,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        items: const [DropdownMenuItem(value: 1000, child: Text('1000')), DropdownMenuItem(value: 1010, child: Text('1010')), DropdownMenuItem(value: 1020, child: Text('1020'))],
                        onChanged: (val) => setState(() => _iDivisor = val!),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Payment Terms', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                  const SizedBox(height: 5),
                  Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE2E8F0))),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _iTerms,
                        isExpanded: true,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        items: const [DropdownMenuItem(value: 'CASH', child: Text('CASH')), DropdownMenuItem(value: 'CREDIT (15 DAYS)', child: Text('CREDIT (15 DAYS)')), DropdownMenuItem(value: 'CREDIT (30 DAYS)', child: Text('CREDIT (30 DAYS)'))],
                        onChanged: (val) => setState(() => _iTerms = val!),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 12),
          _customField('Buyer Address', _iAddressCtrl, onChanged: (_) => setState(() {})),
          const SizedBox(height: 12),
          _responsiveRow([
            Expanded(child: _customField('Telephone', _iPhoneCtrl, isNum: true, onChanged: (_) => setState(() {}))),
            const SizedBox(width: 12),
            Expanded(child: _customField('Lorry No.', _iLorryCtrl, onChanged: (_) => setState(() {}))),
            const SizedBox(width: 12),
            Expanded(child: _customField('Driver No.', _iDriverCtrl, isNum: true, onChanged: (_) => setState(() {}))),
          ]),
          const SizedBox(height: 18),
          const Text('Goods Details', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 10),
          ..._invoiceGoods.asMap().entries.map((entry) {
            final idx = entry.key; final item = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: [
                  Expanded(flex: 4, child: _customField(idx == 0 ? 'Description' : '', item.descCtrl, hint: 'COCONUT')),
                  const SizedBox(width: 8),
                  Expanded(flex: 2, child: _customField(idx == 0 ? 'Qty (Nuts)' : '', item.qtyCtrl, isNum: true)),
                  const SizedBox(width: 8),
                  Expanded(flex: 2, child: _customField(idx == 0 ? 'Rate (₹)' : '', item.rateCtrl, isNum: true)),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: _customField(
                      idx == 0 ? 'Amount' : '',
                      TextEditingController(text: item.calculateAmount(_iDivisor) > 0 ? money(item.calculateAmount(_iDivisor)) : ''),
                      readOnly: true,
                    ),
                  ),
                  if (_invoiceGoods.length > 1)
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red, size: 18),
                      onPressed: () {
                        setState(() {
                          final removed = _invoiceGoods.removeAt(idx);
                          removed.dispose();
                        });
                      },
                    ),
                ],
              ),
            );
          }),
          OutlinedButton(
            style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () => setState(() => _addGoodsRow()),
            child: const Text('+ Add Goods'),
          ),
          const SizedBox(height: 18),
          const Text('Charges & Levies', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 10),
          Table(
            columnWidths: const {0: FlexColumnWidth(4), 1: FlexColumnWidth(4), 2: FlexColumnWidth(2.5)},
            border: TableBorder.all(color: const Color(0xFFE2E8F0)),
            children: [
              TableRow(
                decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
                children: const [
                  Padding(padding: EdgeInsets.all(8), child: Text('CHARGE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B)))),
                  Padding(padding: EdgeInsets.all(8), child: Text('INPUT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B)))),
                  Padding(padding: EdgeInsets.all(8), child: Text('AMOUNT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B)))),
                ],
              ),
              TableRow(children: [
                const Padding(padding: EdgeInsets.all(8), child: Text('Gunnies', style: TextStyle(fontSize: 12))),
                Padding(padding: const EdgeInsets.all(6), child: Row(children: [Expanded(child: _chargeInlineField(_iBagsCtrl, '0', isNum: true)), const Padding(padding: EdgeInsets.symmetric(horizontal: 2), child: Text('×')), Expanded(child: _chargeInlineField(_iBagRateCtrl, '0', isNum: true))])),
                Padding(padding: const EdgeInsets.all(8), child: Text(money(_invGunniesAmount), style: const TextStyle(fontWeight: FontWeight.bold))),
              ]),
              TableRow(children: [
                Padding(
  padding: const EdgeInsets.all(6),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      const Text('Loading', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      Wrap(
        spacing: 3,
        runSpacing: 3,
        children: [
          // AP Chip
          GestureDetector(
            onTap: () {
              setState(() {
                _iLoadingManual = false;
                _iLoadRateCtrl.text = '650';
                _calculateInvoiceTotals();
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: (!_iLoadingManual && _iLoadRateCtrl.text == '650')
                    ? const Color(0xFF047857)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'AP',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                  color: (!_iLoadingManual && _iLoadRateCtrl.text == '650')
                      ? Colors.white
                      : const Color(0xFF64748B),
                ),
              ),
            ),
          ),
          // TN Chip
          GestureDetector(
            onTap: () {
              setState(() {
                _iLoadingManual = false;
                _iLoadRateCtrl.text = '650';
                _calculateInvoiceTotals();
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: (!_iLoadingManual && _iLoadRateCtrl.text == '650')
                    ? const Color(0xFF047857)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'TN',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                  color: (!_iLoadingManual && _iLoadRateCtrl.text == '650')
                      ? Colors.white
                      : const Color(0xFF64748B),
                ),
              ),
            ),
          ),
          // Manual Chip
          GestureDetector(
            onTap: () {
              setState(() {
                _iLoadingManual = !_iLoadingManual;
                if (!_iLoadingManual) {
                  _iLoadRateCtrl.text = '650';
                }
                _calculateInvoiceTotals();
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: _iLoadingManual ? const Color(0xFF047857) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Manual',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                  color: _iLoadingManual ? Colors.white : const Color(0xFF64748B),
                ),
              ),
            ),
          ),
        ],
      ),
    ],
  ),
),
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: _iLoadingManual
                      ? _chargeInlineField(_iLoadManualAmountCtrl, 'Amt', isNum: true)
                      : _chargeInlineField(_iLoadRateCtrl, 'Rate/1000', isNum: true),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(money(_invLoadingAmount), style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ]),
              TableRow(children: [
                const Padding(padding: EdgeInsets.all(8), child: Text('AMC', style: TextStyle(fontSize: 12))),
                Padding(padding: const EdgeInsets.all(6), child: _chargeInlineField(_iAmcCtrl, '0', isNum: true)),
                Padding(padding: const EdgeInsets.all(8), child: Text(money(_invAmc), style: const TextStyle(fontWeight: FontWeight.bold))),
              ]),
              TableRow(children: [
                const Padding(padding: EdgeInsets.all(8), child: Text('Insurance', style: TextStyle(fontSize: 12))),
                Padding(padding: const EdgeInsets.all(6), child: _chargeInlineField(_iInsCtrl, '0', isNum: true)),
                Padding(padding: const EdgeInsets.all(8), child: Text(money(_invInsurance), style: const TextStyle(fontWeight: FontWeight.bold))),
              ]),
              TableRow(children: [
                const Padding(padding: EdgeInsets.all(8), child: Text('Commission', style: TextStyle(fontSize: 12))),
                Padding(padding: const EdgeInsets.all(6), child: _chargeInlineField(_iCommCtrl, '0', isNum: true)),
                Padding(padding: const EdgeInsets.all(8), child: Text(money(_invCommission), style: const TextStyle(fontWeight: FontWeight.bold))),
              ]),
              TableRow(children: [
                const Padding(padding: EdgeInsets.all(8), child: Text('Advance', style: TextStyle(fontSize: 12))),
                Padding(padding: const EdgeInsets.all(6), child: _chargeInlineField(_iAdvCtrl, '0', isNum: true)),
                Padding(padding: const EdgeInsets.all(8), child: Text(money(_invAdvance), style: const TextStyle(fontWeight: FontWeight.bold))),
              ]),
            ],
          ),
          const SizedBox(height: 18),
          _responsiveRow([
            Expanded(child: _customField('Freight (Manual)', _iFreightCtrl, isNum: true, onChanged: (_) => setState(() {}))),
            const SizedBox(width: 12),
            Expanded(child: _customField('Truck Advance', TextEditingController(text: money(_invAdvance)), readOnly: true)),
            const SizedBox(width: 12),
            Expanded(child: _customField('Balance (Auto)', TextEditingController(text: money(_invTruckBalance)), readOnly: true)),
          ]),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF047857), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                onPressed: _saveInvoice,
                child: Text(_editingInvoiceId != null ? 'Update Invoice' : 'Save Invoice'),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF062317), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                onPressed: _openPrintPreviewModal,
                icon: const Icon(Icons.print_rounded, size: 16),
                label: const Text('Print Preview (A4)'),
              ),
              OutlinedButton(
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                onPressed: _clearInvoiceForm,
                child: const Text('Clear'),
              ),
            ],
          ),
        ],
      ),
    );

    Widget previewBox = Container(
      padding: EdgeInsets.all(isMobile ? 16 : 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 16, offset: Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Live Preview', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
              TextButton.icon(onPressed: _openPrintPreviewModal, icon: const Icon(Icons.fullscreen, size: 16), label: const Text('Full Screen')),
            ],
          ),
          const SizedBox(height: 12),
          _buildPrintableInvoicePaper(),
        ],
      ),
    );

    return LayoutBuilder(
  builder: (context, constraints) {
    if (constraints.maxWidth < 1100) {
      // iPad and Android (Stacked vertically)
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          formBox,
          const SizedBox(height: 16),
          previewBox,
        ],
      );
    } else {
      // Windows (Side-by-side)
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 6, child: formBox),
          const SizedBox(width: 16),
          Expanded(flex: 5, child: previewBox),
        ],
      );
    }
  },
);
}
  void _saveInvoice() {
    final bName = _iBuyer.trim().toUpperCase();
    final sName = _iSeller.trim().toUpperCase();
    final tName = _iTransporter.trim().toUpperCase();

    // STRICT VALIDATION FOR ALL 3 PARTIES
    if (bName.isEmpty || bName == 'SELECT BUYER' ||
        sName.isEmpty || sName == 'SELECT SELLER' ||
        tName.isEmpty || tName == 'SELECT TRANSPORTER') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text('Error: Buyer, Seller, and Transporter are ALL mandatory to save an Invoice!'),
        ),
      );
      return;
    }

    if (_editingInvoiceId != null) {
      final idx = _trucks.indexWhere((x) => x.id == _editingInvoiceId);
      if (idx != -1) {
        setState(() {
          _trucks[idx] = TruckEntry(
            id: _editingInvoiceId!,
            state: _selectedState,
            date: _iDateCtrl.text.trim(),
            truck: _iLorryCtrl.text.trim().toUpperCase().isEmpty ? "—" : _iLorryCtrl.text.trim().toUpperCase(),
            supplier: sName,
            buyer: bName,
            transporter: tName,
            type: "COCONUT",
            qty: _invTotalGoodsQty,
            supplierBill: double.tryParse(_iSellerAmountCtrl.text) ?? 0,
            buyerBill: _invGrandTotal,
            commission: _invCommission > 0 ? _invCommission : 500,
            transportExp: double.tryParse(_iTransportExpCtrl.text) ?? 0,
            freight: _invFreight,
            advance: _invAdvance,
            isInvoice: true,
            rate: _invoiceGoods.isNotEmpty ? _invoiceGoods.first.rate : 0,
            bags: double.tryParse(_iBagsCtrl.text) ?? 0,
            bagRate: double.tryParse(_iBagRateCtrl.text) ?? 0,
            loadRate: double.tryParse(_iLoadRateCtrl.text) ?? 0,
            insurance: double.tryParse(_iInsCtrl.text) ?? 0,
            amc: double.tryParse(_iAmcCtrl.text) ?? 0,
            isLoadManual: _iLoadingManual,
            loadManualAmt: double.tryParse(_iLoadManualAmountCtrl.text) ?? 0,
          );
          _clearInvoiceForm();
        });
        _commitToLocalDrive();
        _calculateOverdueBills(_trucks);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Color(0xFF047857), content: Text('Invoice updated.')));
        return;
      }
    }

    setState(() {
      _trucks.add(TruckEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        state: _selectedState,
        date: _iDateCtrl.text.trim(),
        truck: _iLorryCtrl.text.trim().toUpperCase().isEmpty ? "—" : _iLorryCtrl.text.trim().toUpperCase(),
        supplier: sName,
        buyer: bName,
        transporter: tName,
        type: "COCONUT",
        qty: _invTotalGoodsQty,
        supplierBill: double.tryParse(_iSellerAmountCtrl.text) ?? 0,
        buyerBill: _invGrandTotal,
        commission: _invCommission > 0 ? _invCommission : 500,
        transportExp: double.tryParse(_iTransportExpCtrl.text) ?? 0,
        freight: _invFreight,
        advance: _invAdvance,
        isInvoice: true,
        rate: _invoiceGoods.isNotEmpty ? _invoiceGoods.first.rate : 0,
        bags: double.tryParse(_iBagsCtrl.text) ?? 0,
        bagRate: double.tryParse(_iBagRateCtrl.text) ?? 0,
        loadRate: double.tryParse(_iLoadRateCtrl.text) ?? 0,
        insurance: double.tryParse(_iInsCtrl.text) ?? 0,
        amc: double.tryParse(_iAmcCtrl.text) ?? 0,
        isLoadManual: _iLoadingManual,
        loadManualAmt: double.tryParse(_iLoadManualAmountCtrl.text) ?? 0,
      ));
      _updateNextInvoiceNumber();
      _clearInvoiceForm();
    });
    _commitToLocalDrive();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Color(0xFF047857), content: Text('Invoice saved to database!')));
  }

  void _openPrintPreviewModal() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.all(24),
        child: Container(
          width: 920,
          height: 820,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Print Preview (A4)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  Row(
                    children: [
                      // Save Invoice to Custom Windows Folder
                      if (!kIsWeb && Platform.isWindows)
                        FilledButton.icon(
                          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF047857)),
                          icon: const Icon(Icons.save_alt_rounded, size: 15),
                          label: const Text('Save to Folder', style: TextStyle(fontSize: 11.5)),
                          onPressed: () async {
                            final pdfBytes = await _generatePdfInvoice(PdfPageFormat.a4);
                            if (!context.mounted) return;
                            await _exportPdfToCustomDirOrShare(
                              context: context,
                              fileName: '${_iNoCtrl.text.isNotEmpty ? _iNoCtrl.text : "INVOICE"}.pdf',
                              pdfBytes: pdfBytes,
                            );
                          },
                        ),
                      const SizedBox(width: 8),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: PdfPreview(
                  build: (format) => _generatePdfInvoice(format),
                  canChangeOrientation: false,
                  canChangePageFormat: false,
                  canDebug: false,
                  allowSharing: true,
                  allowPrinting: true,
                  initialPageFormat: PdfPageFormat.a4,
                  pdfFileName: '${_iNoCtrl.text}.pdf',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<Uint8List> _generatePdfInvoice(PdfPageFormat format) async {
    final pdf = pw.Document();
    final prefs = await SharedPreferences.getInstance();
    final customLogoPath = prefs.getString('custom_logo_path');
    pw.MemoryImage? logoImage;
    if (customLogoPath != null && customLogoPath.trim().isNotEmpty && customLogoPath != 'NONE' && await File(customLogoPath).exists()) {
      try {
        final Uint8List customBytes = await File(customLogoPath).readAsBytes();
        logoImage = pw.MemoryImage(customBytes);
      } catch (_) { logoImage = null; }
    }

    // Page 1: No "ORIGINAL" text label
    pdf.addPage(pw.Page(pageFormat: PdfPageFormat.a4, margin: const pw.EdgeInsets.symmetric(horizontal: 22, vertical: 18), build: (ctx) => _buildPdfPageContent("", logoImage)));
    // Page 2: Keep "DUPLICATE" text label
    pdf.addPage(pw.Page(pageFormat: PdfPageFormat.a4, margin: const pw.EdgeInsets.symmetric(horizontal: 22, vertical: 18), build: (ctx) => _buildPdfPageContent("DUPLICATE", logoImage)));
    return pdf.save();
  }

  pw.Widget _buildPdfPageContent(String copyLabel, pw.MemoryImage? logoImage) {
    const greenBorder = PdfColor.fromInt(0xFF4D8B61); 
    const titleGreen = PdfColor.fromInt(0xFF126B35); 
    const redAccent = PdfColor.fromInt(0xFFBD2020);

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: const pw.BoxDecoration(
        border: pw.Border.fromBorderSide(pw.BorderSide(color: greenBorder, width: 1.8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch, 
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Stack(
                children: [
                  pw.Align(
                    alignment: pw.Alignment.topCenter,
                    child: pw.Text(
                      _myCompany.invocation.isNotEmpty ? _myCompany.invocation : 'Om Sri Ganesaya Namaha', 
                      style: pw.TextStyle(fontSize: 9.5, fontStyle: pw.FontStyle.italic, color: titleGreen),
                    ),
                  ),
                  pw.Align(
                    alignment: pw.Alignment.topRight,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: _myCompany.phone.split(',').map((num) => 
                        pw.Text('Cell : ${num.trim()}', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold))
                      ).toList(),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 4),
              if (copyLabel.isNotEmpty)
                pw.Center(
                  child: pw.Text(copyLabel, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: titleGreen)),
                ),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  if (logoImage != null) ...[
                    pw.Image(logoImage, width: 34, height: 34),
                    pw.SizedBox(width: 8),
                  ],
                  pw.Text(
                    _myCompany.name, 
                    style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: titleGreen, letterSpacing: 0.5),
                  ),
                ],
              ),
              pw.SizedBox(height: 3),
              pw.Center(
                child: pw.Text(_myCompany.tagline, style: pw.TextStyle(fontSize: 11, letterSpacing: 4, fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(height: 3),
              pw.Center(
                child: pw.Text(_myCompany.address, textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: redAccent)),
              ),
              pw.SizedBox(height: 6),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 4), 
                decoration: const pw.BoxDecoration(
                  border: pw.Border(top: pw.BorderSide(color: greenBorder, width: 1), bottom: pw.BorderSide(color: greenBorder, width: 1)),
                ), 
                child: pw.Center(
                  child: pw.Text(
                    'AS PER G.O.MS.No.575(AP VAT)    Dt. 4-4-2008    COCONUT EXEMPTED FROM TAX\nG.O.MS.No.576(CST)', 
                    textAlign: pw.TextAlign.center, 
                    style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 5), 
            decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: greenBorder, width: 1))), 
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, 
              children: [
                pw.Text('Invoice No. ${_iNoCtrl.text.toUpperCase()}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)), 
                pw.Text('Date : ${_iDateCtrl.text.toUpperCase()}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 6), 
            decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: greenBorder, width: 1))),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  flex: 6, 
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start, 
                    children: [
                      pw.Text("Buyer's Name : ${_iBuyer.isEmpty ? '-' : _iBuyer.toUpperCase()}", style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold)), 
                      pw.SizedBox(height: 3), 
                      pw.Text("Address : ${_iAddressCtrl.text.isEmpty ? '-' : _iAddressCtrl.text.toUpperCase()}", style: const pw.TextStyle(fontSize: 10)), 
                      pw.SizedBox(height: 3), 
                      pw.Text("Telephone No. : ${_iPhoneCtrl.text.isEmpty ? '-' : _iPhoneCtrl.text}", style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                ),
                pw.Container(width: 1, height: 46, color: greenBorder), 
                pw.SizedBox(width: 10),
                pw.Expanded(
                  flex: 4, 
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start, 
                    children: [
                      pw.Text("Terms : ${_iTerms.toUpperCase()}", style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold)), 
                      pw.SizedBox(height: 3), 
                      pw.Text("Lorry No. : ${_iLorryCtrl.text.isEmpty ? '-' : _iLorryCtrl.text.toUpperCase()}", style: const pw.TextStyle(fontSize: 10)), 
                      pw.SizedBox(height: 3), 
                      pw.Text("Driver No. : ${_iDriverCtrl.text.isEmpty ? '-' : _iDriverCtrl.text}", style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          pw.Container(
            decoration: const pw.BoxDecoration(border: pw.Border.fromBorderSide(pw.BorderSide(color: greenBorder, width: 1))),
            child: pw.Table(
              border: const pw.TableBorder(horizontalInside: pw.BorderSide(color: greenBorder, width: 1), verticalInside: pw.BorderSide(color: greenBorder, width: 1)),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF2F7F3)), 
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('#', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold))), 
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Description of Goods', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold))), 
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Quantity (Nos.)', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold))), 
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Rate (Rs)', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold))), 
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Amount (Rs)', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold))),
                  ],
                ),
                ..._invoiceGoods.asMap().entries.map((e) => pw.TableRow(
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('${e.key + 1}', style: const pw.TextStyle(fontSize: 10))), 
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(e.value.description.toUpperCase(), style: const pw.TextStyle(fontSize: 10))), 
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('${numFmt(e.value.qty)} NUTS', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 10))), 
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(pdfMoney(e.value.rate), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 10))), 
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(pdfMoney(e.value.calculateAmount(_iDivisor)), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
                  ],
                )),
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF7FAF8)), 
                  children: [
                    pw.SizedBox(), 
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Total Quantity', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))), 
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('${numFmt(_invTotalGoodsQty)} NUTS', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))), 
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Total Goods Amount', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold))), 
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(pdfMoney(_invTotalGoodsAmount), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
                  ],
                ),
              ],
            ),
          ),
          pw.Container(
            decoration: const pw.BoxDecoration(border: pw.Border.fromBorderSide(pw.BorderSide(color: greenBorder, width: 1))),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  flex: 5,
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start, 
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start, 
                          children: [
                            pw.Text('Amount in Words :', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)), 
                            pw.SizedBox(height: 3), 
                            pw.Text(wordsToIndian(_invGrandTotal), style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: titleGreen)),
                          ],
                        ),
                        pw.SizedBox(height: 24),
                        pw.Container(
                          padding: const pw.EdgeInsets.all(5), 
                          decoration: const pw.BoxDecoration(border: pw.Border.fromBorderSide(pw.BorderSide(color: greenBorder, width: 1))), 
                          child: pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, 
                            children: [
                              pw.Text('Freight ${pdfMoney(_invFreight)}', style: const pw.TextStyle(fontSize: 8.5)), 
                              pw.Text('Adv ${pdfMoney(_invAdvance)}', style: const pw.TextStyle(fontSize: 8.5)), 
                              pw.Text('Bal ${pdfMoney(_invTruckBalance)}', style: const pw.TextStyle(fontSize: 8.5)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                pw.Container(width: 1, height: 105, color: greenBorder),
                pw.Expanded(
                  flex: 5,
                  child: pw.Column(
                    children: [
                      pw.Container(
                        color: const PdfColor.fromInt(0xFFF3F7F4), 
                        padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 6), 
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, 
                          children: [
                            pw.Text('Particulars', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)), 
                            pw.Text('Amount (Rs)', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                          ],
                        ),
                      ),
                      _pdfParticularRow('Gunnies', pdfMoney(_invGunniesAmount)), 
                      _pdfParticularRow('Loading Charges', pdfMoney(_invLoadingAmount)), 
                      _pdfParticularRow('AMC', pdfMoney(_invAmc)), 
                      _pdfParticularRow('Insurance', pdfMoney(_invInsurance)), 
                      _pdfParticularRow('Commission', pdfMoney(_invCommission)), 
                      _pdfParticularRow('Truck Advance', pdfMoney(_invAdvance)),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4), 
                        decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF3F7F4), border: pw.Border(top: pw.BorderSide(color: greenBorder, width: 1))), 
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, 
                          children: [
                            pw.Text('Total Charges', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)), 
                            pw.Text(pdfMoney(_invTotalCharges), style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 12), 
            decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF1F8F3), border: pw.Border.fromBorderSide(pw.BorderSide(color: greenBorder, width: 1.5))), 
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, 
              children: [
                pw.Text('TOTAL INVOICE AMOUNT', style: pw.TextStyle(fontSize: 11.5, fontWeight: pw.FontWeight.bold, color: titleGreen)), 
                pw.Text('Rs. ${pdfMoney(_invGrandTotal)}', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: titleGreen)),
              ],
            ),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.all(7), 
            decoration: const pw.BoxDecoration(border: pw.Border.fromBorderSide(pw.BorderSide(color: greenBorder, width: 1))),
            child: pw.Row(
              children: [
                pw.Expanded(
                  flex: 5, 
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start, 
                    children: [
                      pw.Text('Bank Name : ${_selectedBank.name}', style: const pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)), 
                      pw.Text('A/c No. : ${_selectedBank.account}', style: const pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)), 
                      pw.Text('IFSC Code : ${_selectedBank.ifsc}', style: const pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)), 
                      pw.Text('Branch : ${_selectedBank.branch}', style: const pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ),
                pw.Container(width: 1, height: 42, color: greenBorder), 
                pw.SizedBox(width: 6),
                pw.Expanded(
                  flex: 5, 
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start, 
                    children: [
                      pw.Text('Rupees : ${wordsToIndian(_invGrandTotal)}', style: const pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)), 
                      pw.SizedBox(height: 4), 
                      pw.Text(_selectedBank.note, style: const pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 2), 
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, 
              children: [
                pw.Text('Customer Signature', style: const pw.TextStyle(fontSize: 9)), 
                pw.Text('For ${_myCompany.name}', style: const pw.TextStyle(fontSize: 9)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfParticularRow(String label, String value) {
    return pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 2.5), child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text(label, style: const pw.TextStyle(fontSize: 8.5)), pw.Text(value, style: const pw.TextStyle(fontSize: 8.5))]));
  }

  Widget _particularRow(String label, String value) {
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(fontSize: 9)), Text(value, style: const TextStyle(fontSize: 9))]));
  }

  Widget _chargeInlineField(TextEditingController ctrl, String hint, {bool isNum = false}) {
    return SizedBox(
      height: 28,
      child: TextField(
        controller: ctrl, inputFormatters: isNum ? null : [UpperCaseTextFormatter()], keyboardType: isNum ? TextInputType.number : TextInputType.text, onChanged: (_) => setState(() {}), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
        decoration: InputDecoration(hintText: hint, contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4), border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: Color(0xFFE2E8F0))), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF047857))), filled: true, fillColor: Colors.white),
      ),
    );
  }

  Widget _buildPrintableInvoicePaper() {
    return Container(
      padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF4D8B61), width: 1.5)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: Text('Om Sri Ganesaya Namaha', style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Color(0xFF17231B)))), const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(width: 80),
              const Text('TAX INVOICE', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF126B35))),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: _myCompany.phone.split(',').map((num) => 
                  Text('Cell : ${num.trim()}', style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF17231B)))
                ).toList(),
              ),
            ],
          ),
          Center(child: Text(_myCompany.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF126B35)))), const SizedBox(height: 3),
          Center(child: Text(_myCompany.tagline, style: const TextStyle(fontSize: 10, letterSpacing: 3, fontWeight: FontWeight.w600, color: Color(0xFF17231B)))), const SizedBox(height: 3),
          Center(child: Text(_myCompany.address, textAlign: TextAlign.center, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFFBD2020)))), const SizedBox(height: 6),
          Container(padding: const EdgeInsets.symmetric(vertical: 4), decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFF4D8B61)), bottom: BorderSide(color: Color(0xFF4D8B61)))), child: const Text('AS PER G.O.MS.No.575(AP VAT)    Dt. 4-4-2008    COCONUT EXEMPTED FROM TAX\nG.O.MS.No.576(CST)', textAlign: TextAlign.center, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: Color(0xFF17231B)))),
          Container(padding: const EdgeInsets.symmetric(vertical: 4), decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFF4D8B61)))), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Invoice No. ${_iNoCtrl.text.toUpperCase()}', style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold)), Text('Date : ${_iDateCtrl.text.toUpperCase()}', style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold))])),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6), decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFF4D8B61)))),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 6, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("Buyer's Name : ${_iBuyer.isEmpty ? '—' : _iBuyer.toUpperCase()}", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)), const SizedBox(height: 2), Text("Address : ${_iAddressCtrl.text.isEmpty ? '—' : _iAddressCtrl.text.toUpperCase()}", style: const TextStyle(fontSize: 9.5)), const SizedBox(height: 2), Text("Telephone No. : ${_iPhoneCtrl.text.isEmpty ? '—' : _iPhoneCtrl.text}", style: const TextStyle(fontSize: 9.5))])),
                Container(width: 1, height: 45, color: const Color(0xFF4D8B61)), const SizedBox(width: 8),
                Expanded(flex: 4, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("Terms : ${_iTerms.toUpperCase()}", style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold)), const SizedBox(height: 2), Text("Lorry No. : ${_iLorryCtrl.text.isEmpty ? '—' : _iLorryCtrl.text.toUpperCase()}", style: const TextStyle(fontSize: 9.5)), const SizedBox(height: 2), Text("Driver No. : ${_iDriverCtrl.text.isEmpty ? '—' : _iDriverCtrl.text}", style: const TextStyle(fontSize: 9.5))])),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Container(
            decoration: BoxDecoration(border: Border.all(color: const Color(0xFF4D8B61))),
            child: Column(
              children: [
                Container(color: const Color(0xFFF2F7F3), padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6), child: Row(children: const [SizedBox(width: 20, child: Text('#', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold))), Expanded(flex: 4, child: Text('Description of Goods', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold))), Expanded(flex: 2, child: Text('Quantity (Nos.)', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold), textAlign: TextAlign.right)), Expanded(flex: 2, child: Text('Rate (₹)', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold), textAlign: TextAlign.right)), Expanded(flex: 2, child: Text('Amount (₹)', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold), textAlign: TextAlign.right))])),
                const Divider(height: 1, color: Color(0xFF4D8B61)),
                ..._invoiceGoods.asMap().entries.map((e) {
                  final i = e.key; final item = e.value;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 6),
                    child: Row(children: [SizedBox(width: 20, child: Text('${i + 1}', style: const TextStyle(fontSize: 9.5))), Expanded(flex: 4, child: Text(item.description.toUpperCase(), style: const TextStyle(fontSize: 9.5))), Expanded(flex: 2, child: Text('${numFmt(item.qty)} NUTS', style: const TextStyle(fontSize: 9.5), textAlign: TextAlign.right)), Expanded(flex: 2, child: Text(money(item.rate), style: const TextStyle(fontSize: 9.5), textAlign: TextAlign.right)), Expanded(flex: 2, child: Text(money(item.calculateAmount(_iDivisor)), style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold), textAlign: TextAlign.right))]),
                  );
                }),
                const Divider(height: 1, color: Color(0xFF4D8B61)),
                Container(color: const Color(0xFFF7FAF8), padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6), child: Row(children: [const SizedBox(width: 20), const Expanded(flex: 4, child: Text('Total Quantity', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold))), Expanded(flex: 2, child: Text('${numFmt(_invTotalGoodsQty)} NUTS', style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold), textAlign: TextAlign.right)), const Expanded(flex: 2, child: Text('Total Goods Amount', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold), textAlign: TextAlign.right)), Expanded(flex: 2, child: Text(money(_invTotalGoodsAmount), style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold), textAlign: TextAlign.right))])),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Container(
            decoration: BoxDecoration(border: Border.all(color: const Color(0xFF4D8B61))),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 5, child: Padding(padding: const EdgeInsets.all(6.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Amount in Words :', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)), const SizedBox(height: 2), Text(wordsToIndian(_invGrandTotal), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFF064E3B)))]), Container(decoration: BoxDecoration(border: Border.all(color: const Color(0xFF4D8B61))), padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Freight ${money(_invFreight)}', style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold)), Text('Adv ${money(_invAdvance)}', style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold)), Text('Bal ${money(_invTruckBalance)}', style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold))]))]))),
                  Container(width: 1, color: const Color(0xFF4D8B61)),
                  Expanded(flex: 5, child: Column(children: [Container(color: const Color(0xFFF3F7F4), padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 6), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: const [Text('Particulars', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold)), Text('Amount (₹)', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold))])), _particularRow('Gunnies', money(_invGunniesAmount)), _particularRow('Loading Charges', money(_invLoadingAmount)), _particularRow('AMC', money(_invAmc)), _particularRow('Insurance', money(_invInsurance)), _particularRow('Commission', money(_invCommission)), _particularRow('Truck Advance', money(_invAdvance)), Container(color: const Color(0xFFF3F7F4), padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 6), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Total Charges', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold)), Text(money(_invTotalCharges), style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold))]))])),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Container(padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 8), decoration: BoxDecoration(color: const Color(0xFFF1F8F3), border: Border.all(color: const Color(0xFF4D8B61), width: 1.5)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('TOTAL INVOICE AMOUNT', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF16773A))), Text(money(_invGrandTotal), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: Color(0xFF16773A)))])),
          const SizedBox(height: 4),
          Container(padding: const EdgeInsets.all(5), decoration: BoxDecoration(border: Border.all(color: const Color(0xFF4D8B61))), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 5, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Bank Name : ${_selectedBank.name}', style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold)), Text('A/c No. : ${_selectedBank.account}', style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold)), Text('IFSC Code : ${_selectedBank.ifsc}', style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold)), Text('Branch : ${_selectedBank.branch}', style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold))])), Container(width: 1, height: 42, color: const Color(0xFF4D8B61)), const SizedBox(width: 6), Expanded(flex: 5, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Rupees : ${wordsToIndian(_invGrandTotal)}', style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold)), const SizedBox(height: 4), Text(_selectedBank.note, style: const TextStyle(fontSize: 8, fontStyle: FontStyle.italic))]))])),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Customer Signature', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold)), Text('For ${_myCompany.name}', style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold))]),
        ],
      ),
    );
  }

  // ---------------- PAYMENTS VIEW (CLEAN MANUAL CONSOLE) ----------------
  Widget _buildPaymentsView() {
    final query = _paySearchCtrl.text.trim().toLowerCase();
    final payList = _payments.where((p) {
      final matchesState = p.state == _selectedState;
      final matchesQuery = query.isEmpty ||
          p.party.toLowerCase().contains(query) ||
          p.type.toLowerCase().contains(query) ||
          p.mode.toLowerCase().contains(query) ||
          p.date.toLowerCase().contains(query) ||
          p.amount.toString().contains(query);
      return matchesState && matchesQuery;
    }).toList()
      ..sort((a, b) {
        int cmp = parseFlexibleDate(b.date).compareTo(parseFlexibleDate(a.date));
        if (cmp != 0) return cmp;
        return b.id.compareTo(a.id);
      });

    final ScrollController payScroll = ScrollController();

    Widget sectionTitle(String title, IconData icon) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, size: 14, color: const Color(0xFF047857)),
            ),
            const SizedBox(width: 8),
            Text(
              title.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: Color(0xFF475569),
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. TRANSACTION ENTRY CONSOLE
        Container(
          padding: EdgeInsets.all(isMobile ? 14 : 22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
            boxShadow: const [
              BoxShadow(color: Color(0x04000000), blurRadius: 14, offset: Offset(0, 4)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with "+ Add Amount Paid / Received" button like "+ Add New Party"
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF047857), Color(0xFF065F46)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: const [
                            BoxShadow(color: Color(0x22047857), blurRadius: 8, offset: Offset(0, 3)),
                          ],
                        ),
                        child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _editingPaymentId != null ? 'Edit Transaction Record' : 'Record Transaction',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -0.3),
                          ),
                          Text(
                            'Financial voucher and payment recording desk',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (_editingPaymentId != null)
                    TextButton.icon(
                      onPressed: _clearPaymentForm,
                      icon: const Icon(Icons.close_rounded, size: 16, color: Colors.red),
                      label: const Text('Cancel Edit', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                ],
              ),
              OutlinedButton.icon(
  style: OutlinedButton.styleFrom(
    side: const BorderSide(color: Color(0xFF047857)),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  ),
  icon: const Icon(Icons.call_split_rounded, size: 15, color: Color(0xFF047857)),
  label: const Text('Bulk Allocate to Trucks', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF047857))),
  onPressed: _showBulkPaymentAllocationDialog,
),
              const SizedBox(height: 20),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 16),

              // SECTION A: VOUCHER TYPE & PARTIES
              sectionTitle('1. Voucher Type & Parties', Icons.badge_outlined),
              _responsiveRow([
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Transaction Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                      const SizedBox(height: 5),
                      Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _payType,
                            isExpanded: true,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            items: [
  "PAYMENT TO SELLER",
  "RECEIPT FROM BUYER",
].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                            onChanged: (val) => setState(() => _payType = val!),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _customAutocomplete(
                    'Seller / Supplier', _sellerNames, _paySeller, 'SELECT SELLER',
                    (val) => setState(() {
                      _paySeller = val;
                      if (!_filteredPaymentBuyers.contains(_payBuyer)) {
                        _payBuyer = "";
                      }
                    }),
                    onAddPressed: () => _showAddPartyDialog(initialType: 'SELLER', onCreated: (name) => setState(() => _paySeller = name)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _customAutocomplete(
                    'Buyer', _filteredPaymentBuyers, _payBuyer, 'SELECT BUYER',
                    (val) => setState(() => _payBuyer = val),
                    onAddPressed: () => _showAddPartyDialog(initialType: 'BUYER', onCreated: (name) => setState(() => _payBuyer = name)),
                  ),
                ),
              ]),

              const SizedBox(height: 16),

              // SECTION B: BILL ALLOCATION (LIVE DUE DEDUCTION)
              sectionTitle('2. Bill Allocation', Icons.receipt_long_outlined),
              Builder(
                builder: (context) {
                  final bool isSeller = _payType.contains("SELLER");
                  final double liveEnteredAmount = parseMathExpression(_payAmountCtrl.text);
                  final double liveDiscount = double.tryParse(_paySettlementCtrl.text.trim()) ?? 0.0;
                  final double liveCommAdj = double.tryParse(_payCommAdjustedCtrl.text.trim()) ?? 0.0;
                  final double totalPayingNow = liveEnteredAmount + liveDiscount + liveCommAdj;

                  final candidateTrucks = _trucks.where((t) {
                    final matchState = t.state == _selectedState;
                    final matchSeller = _paySeller.isEmpty || t.supplier.toUpperCase() == _paySeller.toUpperCase();
                    final matchBuyer = _payBuyer.isEmpty || t.buyer.toUpperCase() == _payBuyer.toUpperCase();
                    return matchState && matchSeller && matchBuyer;
                  }).toList()
                    ..sort((a, b) => parseFlexibleDate(a.date).compareTo(parseFlexibleDate(b.date)));

                  Map<String, double> directPaid = {};
                  double unallocatedPool = 0.0;

                  for (var p in _payments.where((p) => p.state == _selectedState)) {
                    final bool matchesType = isSeller
                        ? (p.type.contains("SELLER") || p.mode == "DIRECT")
                        : (p.type.contains("BUYER") || p.mode == "DIRECT");
                    if (!matchesType) continue;

                    final bool sellerMatch = _paySeller.isEmpty || p.seller.toUpperCase() == _paySeller.toUpperCase();
                    final bool buyerMatch = _payBuyer.isEmpty || p.buyer.toUpperCase() == _payBuyer.toUpperCase();
                    if (!sellerMatch || !buyerMatch) continue;

                    final double totalPay = ((p.amount ?? 0) as num).toDouble() +
                        ((p.settlement ?? 0) as num).toDouble() +
                        ((p.commissionAdjusted ?? 0) as num).toDouble();

                    if (p.truckId.isNotEmpty) {
                      directPaid[p.truckId] = (directPaid[p.truckId] ?? 0.0) + totalPay;
                    } else {
                      unallocatedPool += totalPay;
                    }
                  }

                  List<Map<String, dynamic>> pendingTrucks = [];
                  for (var t in candidateTrucks) {
                    final double billAmt = isSeller
                        ? t.supplierBill
                        : (t.buyerBill > 0 ? t.buyerBill : t.supplierBill);
                    if (billAmt <= 0) continue;

                    double linked = directPaid[t.id] ?? 0.0;
                    double remaining = billAmt - linked;

                    double fifoUsed = 0.0;
                    if (remaining > 0 && unallocatedPool > 0) {
                      if (unallocatedPool >= remaining) {
                        fifoUsed = remaining;
                        unallocatedPool -= remaining;
                      } else {
                        fifoUsed = unallocatedPool;
                        unallocatedPool = 0.0;
                      }
                    }

                    double finalPending = (remaining - fifoUsed).clamp(0.0, double.infinity);

                    if (finalPending > 0.5 || t.id == _paySelectedTruckId) {
                      pendingTrucks.add({
                        'truck': t,
                        'bill': billAmt,
                        'pending': finalPending,
                      });
                    }
                  }

                  pendingTrucks.sort((a, b) => parseFlexibleDate((b['truck'] as dynamic).date)
                      .compareTo(parseFlexibleDate((a['truck'] as dynamic).date)));

                  final bool hasSelection = pendingTrucks.any((m) => (m['truck'] as dynamic).id == _paySelectedTruckId);

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.link_rounded, size: 18, color: Color(0xFF047857)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: hasSelection ? _paySelectedTruckId : "",
                              isExpanded: true,
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              items: [
                                const DropdownMenuItem(
                                  value: "",
                                  child: Text('AUTO-ALLOCATE / ON ACCOUNT (ADVANCE DEPOSIT)', style: TextStyle(color: Color(0xFF64748B))),
                                ),
                                ...pendingTrucks.map((item) {
                                  final t = item['truck'];
                                  final double baseDue = (item['pending'] as num).toDouble();
                                  final double totalAmt = (item['bill'] as num).toDouble();
                                  final bool isThisSelected = t.id == _paySelectedTruckId;

                                  // Live Due subtraction: immediately updates as you type in Amount Paid / Discount
                                  final double liveDue = isThisSelected
                                      ? (baseDue - totalPayingNow).clamp(0.0, double.infinity)
                                      : baseDue;

                                  final String partyName = isSeller
                                      ? (t.supplier.isNotEmpty ? t.supplier : 'SELLER')
                                      : (t.buyer.isNotEmpty ? t.buyer : 'BUYER');

                                  String dueText = money(liveDue);
                                  if (isThisSelected && totalPayingNow > 0 && liveDue == 0) {
                                    dueText = '₹0 (SETTLED)';
                                  }

                                  return DropdownMenuItem<String>(
                                    value: t.id,
                                    child: Text(
                                      '${formatDisplayDate(t.date)}  •  $partyName  •  Due: $dueText  (Bill: ${money(totalAmt)})',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: isThisSelected && liveDue == 0 && totalPayingNow > 0
                                            ? const Color(0xFF047857)
                                            : const Color(0xFF0F172A),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  );
                                }),
                              ],
                              onChanged: (val) {
                                setState(() {
                                  _paySelectedTruckId = val ?? "";
                                  if (_paySelectedTruckId.isNotEmpty) {
                                    final selected = pendingTrucks.firstWhere((m) => (m['truck'] as dynamic).id == _paySelectedTruckId);
                                    final double due = (selected['pending'] as num).toDouble();
                                    _payAmountCtrl.text = due.toStringAsFixed(0);
                                  }
                                });
                              },
                            ),
                          ),
                        ),
                        if (_paySelectedTruckId.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.clear, size: 16, color: Colors.red),
                            tooltip: 'Clear Bill Selection',
                            onPressed: () => setState(() => _paySelectedTruckId = ""),
                          ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),

              // SECTION C: PAYMENT DETAILS (MANUAL DATE + AMOUNTS + SETTLEMENT/DISCOUNT)
              sectionTitle('3. Payment Details & Settlement', Icons.payment_outlined),
              _responsiveRow([
                // 1. Manual Date Input (No Calendar Popup)
                Expanded(
                  flex: 3,
                  child: _customField('Payment Date (DD-MM-YY) *', _payDateCtrl, hint: 'DD-MM-YY'),
                ),
                const SizedBox(width: 12),

                // 2. Amount Field with Math Auto-Sum & "+ Add Amount Paid/Received" Quick Link
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _payType.contains("SELLER") ? 'Amount Paid (₹) *' : 'Amount Received (₹) *',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                          ),
                          InkWell(
                            onTap: _showAddMultiplePaymentsDialog,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              child: Text(
                                _payType.contains("SELLER") ? '+ Add Amount Paid' : '+ Add Amount Received',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      SizedBox(
                        height: 40,
                        child: TextField(
                          controller: _payAmountCtrl,
                          keyboardType: TextInputType.text,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          decoration: InputDecoration(
                            hintText: 'e.g. 95000 or 95000+25000',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF047857), width: 1.5)),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // 3. Payment Mode Dropdown with "+ Add New"
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Payment Mode', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                          InkWell(
                            onTap: () => _showManagePaymentModesDialog(),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              child: Text(
                                '+ Add New',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _paymentModes.contains(_payMode)
                                ? _payMode
                                : (_paymentModes.isNotEmpty ? _paymentModes.first : null),
                            isExpanded: true,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            items: _paymentModes
                                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _payMode = val);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ]),

              const SizedBox(height: 12),

              // Row 2: Discount/Settlement, Commission Adjusted, Transport Received
              _responsiveRow([
                Expanded(
                  child: _customField('Discount / Settlement (₹)', _paySettlementCtrl, hint: '0', isNum: true),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _customField('Commission Adjusted (₹)', _payCommAdjustedCtrl, hint: '0', isNum: true),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _customField('Transport Received (₹)', _payTransportReceivedCtrl, hint: '0', isNum: true),
                ),
              ]),

              const SizedBox(height: 22),

              // Action Buttons
             // Action Buttons
              Row(
                children: [
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF047857),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      final sName = _paySeller.trim().toUpperCase();
                      final bName = _payBuyer.trim().toUpperCase();

                     final bool hasSeller = sName.isNotEmpty && sName != 'SELECT SELLER';
final bool hasBuyer = bName.isNotEmpty && bName != 'SELECT BUYER';

if (!hasSeller && !hasBuyer) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      backgroundColor: Colors.red,
      content: Text('Error: Please select either Seller or Buyer!'),
    ),
  );
  return;
}

                      final cleanSeller = hasSeller ? sName : "";
                      final cleanBuyer = hasBuyer ? bName : "";

                      final rawText = _payAmountCtrl.text.replaceAll('₹', '').replaceAll(',', '').trim();
                      List<double> splitAmts = [];
                      if (rawText.contains('+')) {
                        splitAmts = rawText
                            .split('+')
                            .map((p) => double.tryParse(p.trim()) ?? 0.0)
                            .where((a) => a > 0)
                            .toList();
                      } else {
                        final d = double.tryParse(rawText) ?? 0.0;
                        if (d > 0) splitAmts.add(d);
                      }

                      final double disc = double.tryParse(_paySettlementCtrl.text.trim()) ?? 0;
                      final double commAdj = double.tryParse(_payCommAdjustedCtrl.text.trim()) ?? 0;

                      if (splitAmts.isEmpty && disc == 0 && commAdj == 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(backgroundColor: Colors.red, content: Text('Please enter an amount or settlement discount!')),
                        );
                        return;
                      }

                      if (splitAmts.isEmpty) splitAmts.add(0.0);

                      final nowMs = DateTime.now().millisecondsSinceEpoch;
                      final pDate = _payDateCtrl.text.trim();
                      final transRec = double.tryParse(_payTransportReceivedCtrl.text) ?? 0;

                      setState(() {
                        _saveStateToHistory();

                        if (_editingPaymentId != null) {
                          final idx = _payments.indexWhere((x) => x.id == _editingPaymentId);
                          if (idx != -1) {
                            _payments[idx] = PaymentEntry(
                              id: _editingPaymentId!,
                              state: _selectedState,
                              type: _payType,
                              seller: cleanSeller,
                              buyer: cleanBuyer,
                              amount: splitAmts.first,
                              transportReceived: transRec,
                              settlement: disc,
                              commissionAdjusted: commAdj,
                              mode: _payMode,
                              date: pDate,
                              truckId: _paySelectedTruckId,
                            );
                          }
                          _clearPaymentForm();
                        } else {
                          for (int i = 0; i < splitAmts.length; i++) {
                            _payments.add(PaymentEntry(
                              id: '${nowMs}_$i',
                              state: _selectedState,
                              type: _payType,
                              seller: cleanSeller,
                              buyer: cleanBuyer,
                              amount: splitAmts[i],
                              transportReceived: i == 0 ? transRec : 0,
                              settlement: i == 0 ? disc : 0,
                              commissionAdjusted: i == 0 ? commAdj : 0,
                              mode: _payMode,
                              date: pDate,
                              truckId: _paySelectedTruckId,
                            ));
                          }
                          _clearPaymentForm();
                        }

                        _calculateOverdueBills(_trucks);
                      });

                      _commitToLocalDrive();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(backgroundColor: Color(0xFF047857), content: Text('Transaction saved successfully!')),
                      );
                    },
                    icon: const Icon(Icons.check_circle_outline, size: 17),
                    // RENAMED TO: Save Transaction
                    label: Text(_editingPaymentId != null ? 'Update Transaction' : 'Save Transaction', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    onPressed: _clearPaymentForm,
                    // RENAMED TO: Reset
                    child: const Text('Reset', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),
        // Remainder of Transaction History Table remains intact

        // 2. TRANSACTION HISTORY CARD & LEDGER TABLE
        Container(
          padding: EdgeInsets.all(isMobile ? 14 : 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(color: Color(0x04000000), blurRadius: 14, offset: Offset(0, 4)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header & Quick Search Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Transaction History',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${payList.length} Entries',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569)),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    width: isMobile ? 140 : 260,
                    height: 36,
                    child: TextField(
                      controller: _paySearchCtrl,
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        hintText: 'Search ledger...',
                        hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                        prefixIcon: const Icon(Icons.search, size: 16, color: Color(0xFF64748B)),
                        suffixIcon: _paySearchCtrl.text.isNotEmpty
                            ? InkWell(
                                onTap: () => setState(() => _paySearchCtrl.clear()),
                                child: const Icon(Icons.clear, size: 14, color: Color(0xFF94A3B8)),
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF047857))),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Ledger Table
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE2E8F0))),
                  child: SingleChildScrollView(
                    controller: payScroll,
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 920),
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                        dataRowMinHeight: 42,
                        dataRowMaxHeight: 46,
                        columns: const [
                          DataColumn(label: Text('DATE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF64748B)))),
                          DataColumn(label: Text('TYPE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF64748B)))),
                          DataColumn(label: Text('PARTY NAME', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF64748B)))),
                          DataColumn(label: Text('AMOUNT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF64748B)))),
                          DataColumn(label: Text('PAYMENT MODE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF64748B)))),
                          DataColumn(label: Text('DISCOUNT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF64748B)))),
                          DataColumn(label: Text('ACTIONS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF64748B)))),
                        ],
                        rows: payList.isEmpty
                            ? [
                                const DataRow(cells: [
                                  DataCell(Text('No transaction entries found.')),
                                  DataCell(SizedBox()),
                                  DataCell(SizedBox()),
                                  DataCell(SizedBox()),
                                  DataCell(SizedBox()),
                                  DataCell(SizedBox()),
                                  DataCell(SizedBox()),
                                ])
                              ]
                            : payList.map((p) {
                                final bool isSeller = p.type.contains("SELLER");
                                final bool isDirect = p.type.contains("DIRECT");

                                Color badgeBg = isDirect ? const Color(0xFFF1F5F9) : (isSeller ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5));
                                Color badgeText = isDirect ? const Color(0xFF475569) : (isSeller ? const Color(0xFFDC2626) : const Color(0xFF047857));

                                return DataRow(cells: [
                                  DataCell(Text(formatDisplayDate(p.date), style: const TextStyle(fontSize: 11.5))),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                      decoration: BoxDecoration(
                                        color: badgeBg,
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      child: Text(
                                        p.type,
                                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 9.5, color: badgeText),
                                      ),
                                    ),
                                  ),
                                  DataCell(Text(p.party.isEmpty ? '—' : p.party, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Color(0xFF0F172A)))),
                                  DataCell(Text(money(p.amount), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Color(0xFF047857)))),
                                  DataCell(Text(p.mode, style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569)))),
                                  DataCell(Text(money(p.settlement), style: const TextStyle(fontSize: 11.5))),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        InkWell(
                                          onTap: () => _editPaymentEntryDialog(p),
                                          child: const Padding(
                                            padding: EdgeInsets.all(4.0),
                                            child: Icon(Icons.edit_outlined, size: 16, color: Color(0xFF047857)),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        InkWell(
                                          onTap: () async {
                                            if (await _confirmDelete(context, "Payment entry for ${p.party}")) {
                                              setState(() {
  _saveStateToHistory();
  _payments.remove(p);
  _calculateOverdueBills(_trucks);
});
_deleteDocumentFromFirestore('payments', p.id);
_commitToLocalDrive();
                                            }
                                          },
                                          child: const Padding(
                                            padding: EdgeInsets.all(4.0),
                                            child: Icon(Icons.delete_outline, size: 16, color: Colors.red),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ]);
                              }).toList(),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatPaymentSummary(PaymentEntry p) {
    final dateStr = formatDisplayDate(p.date);

    List<String> parts = [];
    if (p.amount > 0) {
      parts.add('${money(p.amount)} (${p.mode})');
    }
    if (p.settlement > 0) {
      parts.add('${money(p.settlement)} (SETTLEMENT)');
    }
    if (p.commissionAdjusted > 0) {
      parts.add('${money(p.commissionAdjusted)} (COMM ADJ)');
    }
    if (p.transportReceived > 0) {
      parts.add('${money(p.transportReceived)} (TRANS)');
    }

    if (parts.isEmpty) {
      return '${money(p.amount)} (${p.mode})';
    }

    return '${parts.join(' + ')} on $dateStr';
  }
 // ---------------- 5. REPORTS VIEW (RESPONSIVE DUAL TAB CONSOLE) ----------------
  Widget _buildReportsView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Tab Switcher Pill
        Container(
          margin: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 14, vertical: 8),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildReportTogglePill('buyer', 'Buyer Statement'),
              _buildReportTogglePill('seller', 'Seller Statement'),
            ],
          ),
        ),
        // Active Tab Display
        _reportsSelectedTab == 'buyer'
            ? _buildBuyerReportTab()
            : _buildSellerReportTab(),
      ],
    );
  }

  Widget _buildReportTogglePill(String tabKey, String label) {
    final bool active = _reportsSelectedTab == tabKey;
    return GestureDetector(
      onTap: () => setState(() => _reportsSelectedTab = tabKey),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: isMobile ? 6 : 8),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF047857) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: active
              ? const [BoxShadow(color: Color(0x22047857), blurRadius: 8, offset: Offset(0, 2))]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: isMobile ? 12 : 13,
            fontWeight: FontWeight.w800,
            color: active ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  // FEATURE 5: Compares seller payouts vs buyer receipts per truck
  List<Map<String, dynamic>> _getBuyerPaidOnBehalfItems(String buyerName) {
    if (buyerName.trim().isEmpty) return [];
    final bClean = buyerName.trim().toUpperCase();
    final List<Map<String, dynamic>> items = [];

    // 1. Calculate Sunil's total unallocated advance deposits across the active FY & State
    final double totalBuyerAdvances = _payments.where((p) {
      final pState = p.state.toString().trim().toUpperCase();
      final matchState = pState.isEmpty || pState == _selectedState.trim().toUpperCase();
      final matchFY = _isDateInFY(p.date, _selectedFinancialYear);
      final isBuyer = p.buyer.toString().trim().toUpperCase() == bClean;
      final isSellerPayout = p.type.toString().trim().toUpperCase().contains("SELLER");
      final isLinkedTruck = p.truckId.toString().trim().isNotEmpty;
      return matchState && matchFY && isBuyer && !isSellerPayout && !isLinkedTruck;
    }).fold<double>(0.0, (s, p) => s + p.amount + p.settlement);

    // 2. Scan trucks for this buyer in the active FY
    final buyerTrucks = _trucks.where((t) =>
      t.state == _selectedState &&
      t.buyer.toString().trim().toUpperCase() == bClean &&
      _isDateInFY(t.date, _selectedFinancialYear)
    ).toList();

    double cumulativeUncoveredOnBehalf = 0.0;

    for (var t in buyerTrucks) {
      // Total amount disbursed to the seller for this truck from your accounts
      final double paidToSeller = _payments.where((p) =>
        p.state == t.state &&
        p.truckId.trim() == t.id.trim() &&
        (p.type.toString().trim().toUpperCase().contains("SELLER") || p.id.endsWith("_seller") || p.id.endsWith("_direct"))
      ).fold<double>(0.0, (s, p) => s + p.amount + p.settlement + p.commissionAdjusted);

      // Total amount received from the buyer explicitly for this truck
      final double receivedFromBuyer = _payments.where((p) =>
        p.state == t.state &&
        p.truckId.trim() == t.id.trim() &&
        (p.type.toString().trim().toUpperCase().contains("BUYER") || (p.mode == "DIRECT" && !p.id.endsWith("_seller")) || p.id.endsWith("_buyer"))
      ).fold<double>(0.0, (s, p) => s + p.amount + p.settlement + p.commissionAdjusted);

      // Net diff for this specific truck
      final double diff = paidToSeller - receivedFromBuyer;
      if (diff > 0.05) {
        cumulativeUncoveredOnBehalf += diff;
        items.add({
          'truck': t,
          'truckId': t.id,
          'seller': t.supplier.toString().trim().toUpperCase(),
          'buyer': bClean,
          'date': formatDisplayDate(t.date),
          'paidToSeller': paidToSeller,
          'receivedFromBuyer': receivedFromBuyer,
          'balanceOwed': diff,
        });
      }
    }

    // 3. If Sunil's general advance pool covers the "Paid on Behalf" amount, 
    // it absorbs the debit, so the red card disappears or reduces accordingly!
    if (totalBuyerAdvances >= cumulativeUncoveredOnBehalf) {
      return []; // Advance fully covers what was paid on behalf—no red card needed!
    } else {
      // If he owes more than his advance covers, adjust the remaining balance
      double remainingOwed = cumulativeUncoveredOnBehalf - totalBuyerAdvances;
      if (items.isNotEmpty) {
        // Adjust the first item to reflect only the portion not covered by his advance
        items.first['balanceOwed'] = remainingOwed;
      }
      return items;
    }
  }

  // Resolves line 8357: Returns total sum of advances owed
  double _calculateBuyerPaidOnBehalfRemaining(String buyerName) {
    final items = _getBuyerPaidOnBehalfItems(buyerName);
    return items.fold<double>(0.0, (sum, it) => sum + (it['balanceOwed'] as double));
  }

  // Flexible settlement dialog that accepts either (item) or (buyerName, pendingAmt)
  void _settleBuyerPaidOnBehalfDialog(dynamic target, [double? pendingAmt]) {
    String buyerName;
    String sellerName = '';
    String truckId = '';
    double amtToSettle = 0.0;

    if (target is Map<String, dynamic>) {
      buyerName = target['buyer']?.toString() ?? '';
      sellerName = target['seller']?.toString() ?? '';
      truckId = target['truckId']?.toString() ?? '';
      amtToSettle = (target['balanceOwed'] as num?)?.toDouble() ?? 0.0;
    } else {
      buyerName = target.toString();
      amtToSettle = pendingAmt ?? _calculateBuyerPaidOnBehalfRemaining(buyerName);
      final items = _getBuyerPaidOnBehalfItems(buyerName);
      if (items.isNotEmpty) {
        sellerName = items.first['seller']?.toString() ?? '';
        truckId = items.first['truckId']?.toString() ?? '';
      }
    }

    final amtCtrl = TextEditingController(text: amtToSettle.toStringAsFixed(0));
    final dateCtrl = TextEditingController(text: formatDisplayDate(DateTime.now().toIso8601String()));
    String mode = "DIRECT";

    final List<String> availableModes = {
      ..._paymentModes.map((m) => m.trim().toUpperCase()),
      "DIRECT", "CASH", "SBI", "STATE BANK OF INDIA", "ICICI BANK", "KOTAK BANK",
    }.where((m) => m.isNotEmpty).toList()..sort();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Reimburse Advance: $buyerName', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (sellerName.isNotEmpty)
                Text(
                  'Clearing amount paid to $sellerName on your behalf',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.bold),
                ),
              const SizedBox(height: 12),
              _customField('Reimbursement Amount (₹)', amtCtrl, isNum: true),
              const SizedBox(height: 10),
              _customField('Date (DD-MM-YY)', dateCtrl, hint: 'DD-MM-YY'),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: availableModes.contains(mode) ? mode : availableModes.first,
                items: availableModes.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (val) => setDlgState(() => mode = val!),
                decoration: InputDecoration(
                  labelText: 'Payment Mode',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF047857)),
              onPressed: () {
                final double amt = double.tryParse(amtCtrl.text.trim()) ?? 0;
                if (amt <= 0) return;
                final nowMs = DateTime.now().millisecondsSinceEpoch;
                setState(() {
                  _saveStateToHistory();
                  _payments.add(PaymentEntry(
                    id: '${nowMs}_onbehalf_reimburse',
                    state: _selectedState,
                    type: "RECEIPT FROM BUYER",
                    seller: sellerName,
                    buyer: buyerName.toUpperCase(),
                    amount: amt,
                    transportReceived: 0,
                    settlement: 0,
                    commissionAdjusted: 0,
                    mode: mode,
                    date: dateCtrl.text.trim(),
                    truckId: truckId, // Linked to the consignment so both accounts balance out
                  ));
                  _calculateOverdueBills(_trucks);
                });
                _commitToLocalDrive();
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: const Color(0xFF047857),
                    content: Text('Received ${money(amt)} from $buyerName! Card cleared to ₹0.'),
                  ),
                );
              },
              child: const Text('Confirm Receipt & Clear'),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- BUYER STATEMENT TAB ----------------
  Widget _buildBuyerReportTab() {
    final bool hasSpecificBuyer = _repBuyer.trim().isNotEmpty;

    final filteredTrucks = _trucks.where((t) {
      final matchesState = t.state == _selectedState;
      final matchesBuyer = !hasSpecificBuyer || t.buyer.toUpperCase() == _repBuyer.toUpperCase();
      final matchesSeller = _repBuyerSellerFilter.isEmpty || t.supplier.toUpperCase() == _repBuyerSellerFilter.toUpperCase();
      final matchesFY = _isDateInFY(t.date, _selectedFinancialYear);
      final matchesRange = isDateInRange(t.date, _repBuyerFromCtrl.text, _repBuyerToCtrl.text);
      return matchesState && matchesBuyer && matchesSeller && matchesFY && matchesRange;
    }).toList();

    final Set<String> visibleTruckIds = filteredTrucks.map((t) => (t.id as String).trim()).toSet();

    final buyerPayments = _payments.where((p) {
      final matchesState = p.state == _selectedState;
      final matchesBuyer = !hasSpecificBuyer || p.buyer.toUpperCase() == _repBuyer.toUpperCase();
      final matchesSeller = _repBuyerSellerFilter.isEmpty || p.seller.isEmpty || p.seller.toUpperCase() == _repBuyerSellerFilter.toUpperCase();
      final matchesFY = _isDateInFY(p.date, _selectedFinancialYear);
      final bool isLinkedToVisibleTruck = p.truckId.trim().isNotEmpty && visibleTruckIds.contains(p.truckId.trim());
      final matchesRange = isLinkedToVisibleTruck || isDateInRange(p.date, _repBuyerFromCtrl.text, _repBuyerToCtrl.text);
      final bool belongsToBuyer = p.buyer.trim().isNotEmpty && matchesBuyer;
      return matchesState && belongsToBuyer && matchesSeller && matchesFY && matchesRange;
    }).toList();

    final List<PaymentEntry> directPayments = [];
    final List<PaymentEntry> buyerAdvanceEntries = [];

    for (final p in buyerPayments) {
      final bool isPaymentToSeller = p.type.toUpperCase().contains("SELLER");

      if (isPaymentToSeller) {
        if (p.mode == "DIRECT") {
          directPayments.add(p);
        }
      } else {
        if (p.mode == "DIRECT" || (p.truckId).trim().isNotEmpty) {
          directPayments.add(p);
        } else {
          buyerAdvanceEntries.add(p);
        }
      }
    }

    // Chronologically sort advance deposits for FIFO allocation
    buyerAdvanceEntries.sort((a, b) => parseFlexibleDate(a.date).compareTo(parseFlexibleDate(b.date)));
    List<Map<String, dynamic>> advanceBuckets = [];
    for (var adv in buyerAdvanceEntries) {
      final double totalDeposit = adv.amount + adv.settlement;
      advanceBuckets.add({
        'entry': adv,
        'original': totalDeposit,
        'available': totalDeposit,
      });
    }

    final sortedTrucks = List<dynamic>.from(filteredTrucks)
      ..sort((a, b) => parseFlexibleDate(a.date).compareTo(parseFlexibleDate(b.date)));

    final List<Map<String, dynamic>> statementRows = [];
    for (final t in sortedTrucks) {
      final double billAmount = (t.buyerBill > 0 ? t.buyerBill : t.supplierBill).toDouble();
      final double qty = (t.qty as num?)?.toDouble() ?? 0.0;

      final matchedDirectList = directPayments.where((p) => p.truckId.trim() == t.id.trim()).toList();
      final double directPaid = matchedDirectList.fold<double>(0.0, (sum, p) => sum + p.amount + p.settlement);

      double remainingDue = (billAmount - directPaid).clamp(0.0, double.infinity);
      double advanceAdjusted = 0.0;
      List<String> advanceAuditTrails = [];

      if (hasSpecificBuyer && remainingDue > 0) {
        for (var b in advanceBuckets) {
          double avail = b['available'] as double;
          if (avail <= 0.05) continue;

          final advEntry = b['entry'] as PaymentEntry;
          final double origDeposit = b['original'] as double;
          final String dt = formatDisplayDate(advEntry.date);

          if (avail >= remainingDue) {
            b['available'] = avail - remainingDue;
            advanceAdjusted += remainingDue;
            advanceAuditTrails.add('Adv dt. $dt of ${money(origDeposit)} adj. ${money(remainingDue)}');
            remainingDue = 0.0;
            break;
          } else {
            advanceAdjusted += avail;
            remainingDue -= avail;
            b['available'] = 0.0;
            advanceAuditTrails.add('Adv dt. $dt of ${money(origDeposit)} adj. ${money(avail)}');
          }
        }
      }

      final double totalRowPaid = directPaid + advanceAdjusted;
      final double rowBalance = (billAmount - totalRowPaid).clamp(0.0, double.infinity);

      statementRows.add({
        'truck': t,
        'date': formatDisplayDate(t.date),
        'seller': t.supplier,
        'qty': numFmt(qty),
        'bill': money(billAmount),
        'billAmount': billAmount,
        'directPaid': directPaid,
        'advanceAdjusted': advanceAdjusted,
        'advanceAuditTrails': advanceAuditTrails,
        'totalPaid': totalRowPaid,
        'balance': money(rowBalance),
        'rawBalance': rowBalance,
        'payments': matchedDirectList,
      });
    }

    List<Map<String, dynamic>> displayedBuyerRows = statementRows;
    if (_hideSettledEntries) {
      displayedBuyerRows = statementRows.where((row) => (row['rawBalance'] as double) > 0.05).toList();
    }

    final double visibleQty = displayedBuyerRows.fold(0.0, (sum, r) => sum + (double.tryParse((r['qty'] as String).replaceAll(',', '')) ?? 0.0));
    final double visibleBills = displayedBuyerRows.fold(0.0, (sum, r) => sum + (r['billAmount'] as double));
    final double visiblePaid = displayedBuyerRows.fold(0.0, (sum, r) => sum + (r['totalPaid'] as double));
    final double visibleBalance = (visibleBills - visiblePaid).clamp(0.0, double.infinity);

    // FEATURE 5: Calculate outstanding advance paid on behalf of this buyer
    final double onBehalfBalance = hasSpecificBuyer ? _calculateBuyerPaidOnBehalfRemaining(_repBuyer) : 0.0;

    /// FEATURE 8: Calculate cross-state pending dues using the exact same calculation
    final String otherState = _selectedState == "Andhra Pradesh" ? "Tamil Nadu" : "Andhra Pradesh";
    double otherStatePendingDues = 0.0;
    int otherStatePendingBillsCount = 0;

    if (hasSpecificBuyer) {
      final otherRows = _computeBuyerStatementRows(
        stateName: otherState,
        buyerName: _repBuyer,
      );
      for (var r in otherRows) {
        final bal = r['rawBalance'] as double;
        if (bal > 0.05) {
          otherStatePendingDues += bal;
          otherStatePendingBillsCount++;
        }
      }
    }
    final onBehalfItems = hasSpecificBuyer ? _getBuyerPaidOnBehalfItems(_repBuyer) : <Map<String, dynamic>>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [

        // Filter Controls Card
        Container(
          padding: EdgeInsets.all(isMobile ? 12 : 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [BoxShadow(color: Color(0x04000000), blurRadius: 10, offset: Offset(0, 4))],
          ),
          child: Column(
            children: [
              _responsiveRow([
                Expanded(
                  flex: 3,
                  child: _customAutocomplete('Filter Buyer', _buyerNames, _repBuyer, 'CHOOSE BUYER', (v) => setState(() => _repBuyer = v)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: _customAutocomplete('Filter Seller', _buyerRespectiveSellers, _repBuyerSellerFilter, 'ALL SELLERS', (v) => setState(() => _repBuyerSellerFilter = v)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: _customField('From Date', _repBuyerFromCtrl, hint: 'DD-MM-YY', onChanged: (_) => setState(() {})),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: _customField('To Date', _repBuyerToCtrl, hint: 'DD-MM-YY', onChanged: (_) => setState(() {})),
                ),
              ]),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildHideSwitch(),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          minimumSize: const Size(0, 36),
                        ),
                        onPressed: () => setState(() {
                          _repBuyer = "";
                          _repBuyerSellerFilter = "";
                          _repBuyerFromCtrl.clear();
                          _repBuyerToCtrl.clear();
                        }),
                        child: const Text(
                          'Reset Filters',
                          style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),                      
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16, vertical: 8),
                          minimumSize: const Size(0, 36),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.print_rounded, size: 15),
                        label: Text(
                          'Print Statement',
                          style: TextStyle(fontSize: isMobile ? 11.5 : 13, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () => _openBuyerReportPrintModal(
                          _repBuyer.isEmpty ? "ALL BUYERS" : _repBuyer,
                          _repBuyerSellerFilter,
                          displayedBuyerRows,
                          visibleQty,
                          visibleBills,
                          visiblePaid,
                          visibleBalance,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // FEATURE 8: Cross-State Pending Alert Card
        if (hasSpecificBuyer && otherStatePendingDues > 0.05) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
            ),
            child: Row(
              children: [
                const Icon(Icons.swap_horiz_rounded, color: Color(0xFFB45309), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(fontSize: isMobile ? 11.5 : 12.5, color: const Color(0xFF92400E)),
                      children: [
                        TextSpan(text: 'Pending $otherState Payment: ', style: const TextStyle(fontWeight: FontWeight.bold)),
                        TextSpan(text: money(otherStatePendingDues), style: const TextStyle(fontWeight: FontWeight.w900)),
                        TextSpan(text: ' ($otherStatePendingBillsCount Pending Bills in $otherState)'),
                      ],
                    ),
                  ),
                ),
                FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFEF3C7),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: const Size(0, 30),
                  ),
                  onPressed: () {
                    setState(() {
                      _selectedState = otherState;
                      _calculateOverdueBills(_trucks);
                    });
                  },
                  child: Text('Switch to $otherState', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFB45309))),
                ),
              ],
            ),
          ),
        ],

        // FEATURE 5: Red Debit Card for Amount Paid on Behalf of Buyer
        if (hasSpecificBuyer) ...[
          ..._getBuyerPaidOnBehalfItems(_repBuyer).map((item) {
            final double owed = (item['balanceOwed'] as num).toDouble();
            final String sName = item['seller'] as String;
            final String dateStr = item['date'] as String;
            final double sPaid = (item['paidToSeller'] as num).toDouble();
            final double bPaid = (item['receivedFromBuyer'] as num).toDouble();

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFECACA), width: 1.5),
                boxShadow: const [
                  BoxShadow(color: Color(0x1ADC2626), blurRadius: 10, offset: Offset(0, 3)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PAID ON BEHALF: $sName ($dateStr)',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11.5, color: Color(0xFF991B1B)),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Buyer pending amount: -${money(owed)}',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFFDC2626)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Paid to Seller: ${money(sPaid)}  •  Received from Buyer: ${money(bPaid)}',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.red.shade800),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.check_circle_outline, size: 15),
                    label: const Text('Reimburse / Clear', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () => _settleBuyerPaidOnBehalfDialog(item),
                  ),
                ],
              ),
            );
          }),
        ],
        // Statement Data Table
        // Statement Data Table
        if (_repBuyer.trim().isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person_search_rounded, size: 42, color: Color(0xFF94A3B8)),
                  SizedBox(height: 12),
                  Text('Select a Buyer above to view their Statement of Account', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                ],
              ),
            ),
          )
        else
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: (isMobile || isTablet)
            ? SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: 1250,
                  child: _buildBuyerTableContent(displayedBuyerRows, visibleQty, visibleBills, visiblePaid, visibleBalance),
                ),
              )
            : _buildBuyerTableContent(displayedBuyerRows, visibleQty, visibleBills, visiblePaid, visibleBalance),
          ),
      ],
    );
  }

  // --- SUB-METHOD: TABLE WITH DETAILED AUDIT ADVANCE TEXT ---
  Widget _buildBuyerTableContent(List<Map<String, dynamic>> rows, double vQty, double vBills, double vPaid, double vBal) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Table Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: const Row(
            children: [
              SizedBox(width: 85, child: Text('DATE', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B), fontSize: 11))),
              SizedBox(width: 220, child: Text('SELLER', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B), fontSize: 11))),
              SizedBox(width: 95, child: Text('QTY', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B), fontSize: 11))),
              SizedBox(width: 105, child: Text('BILL', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B), fontSize: 11))),
              SizedBox(width: 280, child: Text('PAID DETAILS', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B), fontSize: 11))),
              SizedBox(width: 110, child: Text('BALANCE', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B), fontSize: 11))),
              SizedBox(width: 80, child: Text('ACTIONS', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B), fontSize: 11))),
            ],
          ),
        ),

        // Body Rows
        if (rows.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            alignment: Alignment.center,
            child: const Text('No records found for the selected filters.', style: TextStyle(color: Color(0xFF94A3B8), fontStyle: FontStyle.italic)),
          )
        else
          ...rows.map((row) {
            final t = row['truck'];
            final double bal = (row['rawBalance'] as num).toDouble();
            final pList = row['payments'] as List<dynamic>;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(width: 85, child: Text(row['date'], style: const TextStyle(fontSize: 11.5))),
                  SizedBox(
                width: 220,
                child: Text(
                  row['seller'].toString().toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
                  overflow: TextOverflow.visible,
                ),
              ),
                  SizedBox(width: 95, child: Text('${row['qty']} NUTS', style: const TextStyle(fontSize: 11.5))),
                  SizedBox(width: 105, child: Text(row['bill'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                  // Dedicated 280px width showing direct payments and advances
                  SizedBox(
                    width: 280,
                    child: _buildSingleLinePaidDetailsCell(
                      pList,
                      advanceAdjusted: (row['advanceAdjusted'] as num?)?.toDouble() ?? 0.0,
                      advanceAuditTrails: row['advanceAuditTrails'] as List<String>?,
                    ),
                  ),
                  SizedBox(
                    width: 110,
                    child: Text(
                      money(bal),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: bal == 0 ? const Color(0xFF047857) : const Color(0xFFDC2626),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 80,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: () => _editFromReport(t),
                          child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.edit, size: 14, color: Color(0xFF047857))),
                        ),
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: () async {
                            if (await _confirmDelete(context, "Bill of ${row['bill']}")) {
                              setState(() {
  _saveStateToHistory();
  _trucks.remove(t);
  _calculateOverdueBills(_trucks);
});
_deleteDocumentFromFirestore('trucks', t.id);
_commitToLocalDrive();
                            }
                          },
                          child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.delete_outline, size: 14, color: Colors.red)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),

        // Single Accurate Footer Total Row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: const BoxDecoration(
            color: Color(0xFFECFDF5),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
            border: Border(top: BorderSide(color: Color(0xFFD1FAE5))),
          ),
          child: Row(
            children: [
              const SizedBox(width: 85, child: Text('TOTAL', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF047857), fontSize: 12))),
              const SizedBox(width: 220, child: Text('—', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF047857)))),
              SizedBox(width: 95, child: Text('${numFmt(vQty)} NUTS', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF047857), fontSize: 12))),
              SizedBox(width: 105, child: Text(money(vBills), style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF047857), fontSize: 12))),
              SizedBox(width: 280, child: Text(money(vPaid), style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF047857), fontSize: 12))),
              SizedBox(
                width: 110,
                child: Text(
                  money(vBal),
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Color(0xFF047857)),
                ),
              ),
              const SizedBox(width: 80),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------- SELLER STATEMENT TAB (CRASH-PROOF & RESPONSIVE) ----------------
  Widget _buildSellerReportTab() {
    final sellerAllStateTrucks = _trucks.where((t) {
      final matchesSeller = _repSeller.isNotEmpty && t.supplier.toUpperCase() == _repSeller.toUpperCase();
      final matchesBuyer = _repSellerBuyerFilter.isEmpty || t.buyer.toUpperCase() == _repSellerBuyerFilter.toUpperCase();
      final matchesFY = _isDateInFY(t.date, _selectedFinancialYear);
      final matchesRange = isDateInRange(t.date, _repSellerFromCtrl.text, _repSellerToCtrl.text);
      return matchesSeller && matchesBuyer && matchesFY && matchesRange;
    }).toList();

    double apCommissionTotal = 0.0;
    double tnCommissionTotal = 0.0;

    for (final t in sellerAllStateTrucks) {
      final double truckQty = (t.qty as num?)?.toDouble() ?? 0.0;
      final double commAmt = (t.commission as num?)?.toDouble() ?? (truckQty * 0.05);
      if (t.state.toUpperCase() == "TAMIL NADU") {
        tnCommissionTotal += commAmt;
      } else {
        apCommissionTotal += commAmt;
      }
    }

    final sellerTrucks = sellerAllStateTrucks.where((t) => t.state == _selectedState).toList();
    sellerTrucks.sort((a, b) => parseFlexibleDate(a.date).compareTo(parseFlexibleDate(b.date)));

    final Set<String> visibleSellerTruckIds = sellerTrucks.map((t) => (t.id as String).trim()).toSet();

    final sellerPayments = _payments.where((p) {
      final matchesState = p.state == _selectedState;
      final matchesSeller = _repSeller.isEmpty || p.seller.toUpperCase() == _repSeller.toUpperCase();
      final matchesBuyer = _repSellerBuyerFilter.isEmpty || p.buyer.isEmpty || p.buyer.toUpperCase() == _repSellerBuyerFilter.toUpperCase();
      final matchesFY = _isDateInFY(p.date, _selectedFinancialYear);

      final bool isLinkedToTruck = p.truckId.trim().isNotEmpty && visibleSellerTruckIds.contains(p.truckId.trim());
      final matchesRange = isLinkedToTruck || isDateInRange(p.date, _repSellerFromCtrl.text, _repSellerToCtrl.text);

      if (!matchesState || !matchesSeller || !matchesBuyer || !matchesFY || !matchesRange) {
        return false;
      }

      final isSellerType = p.type.toUpperCase().contains("SELLER");
      final isDirect = p.mode.toUpperCase() == "DIRECT";
      return isSellerType || isDirect;
    }).toList();

    final List<PaymentEntry> sellerAdvanceEntries = [];
    final List<PaymentEntry> matchedSellerPayments = [];

    for (final p in sellerPayments) {
      final tId = (p.truckId).trim();
      final buyerName = (p.buyer).trim();

      if (p.type.toUpperCase().contains("SELLER") && tId.isEmpty && (buyerName.isEmpty || buyerName == "SELECT BUYER")) {
        sellerAdvanceEntries.add(p);
      } else {
        matchedSellerPayments.add(p);
      }
    }

    final List<Map<String, dynamic>> sellerRows = [];
    for (final t in sellerTrucks) {
      final double bill = (t.supplierBill as num).toDouble();
      final double qty = (t.qty as num).toDouble();
      final double comm = (t.commission as num).toDouble();

      final matchedPayments = sellerPayments.where((p) => p.truckId.trim() == t.id.trim()).toList();
      final double pSum = matchedPayments.fold<double>(0.0, (s, p) => s + p.amount + p.settlement + p.commissionAdjusted);
      final double rowBal = (bill - pSum).clamp(0.0, double.infinity);

      sellerRows.add({
        'truck': t,
        'date': formatDisplayDate(t.date),
        'sourceSeller': t.sourceSeller.isNotEmpty ? t.sourceSeller : '—', // <-- Sourced Party
        'buyer': t.buyer,
        'qty': numFmt(qty),
        'commission': money(comm),
        'sellerBill': money(bill),
        'payments': matchedPayments,
        'balance': money(rowBal),
        'rawBalance': rowBal,
      });
    }

    List<Map<String, dynamic>> displayedSellerRows = sellerRows;
    if (_hideSettledEntries) {
      displayedSellerRows = sellerRows.where((row) => (row['rawBalance'] as double) > 0.05).toList();
    }

    final double visibleSellerQty = displayedSellerRows.fold(0.0, (s, r) => s + (r['truck'].qty as num).toDouble());
    final double visibleSellerComm = displayedSellerRows.fold(0.0, (s, r) => s + (r['truck'].commission as num).toDouble());
    final double visibleSellerBilled = displayedSellerRows.fold(0.0, (s, r) => s + (r['truck'].supplierBill as num).toDouble());
    final double visibleSellerPaid = displayedSellerRows.fold(0.0, (s, r) {
      final List<dynamic> pList = r['payments'];
      return s + pList.fold<double>(0.0, (sum, p) => sum + p.amount + p.settlement + p.commissionAdjusted);
    });
    final double visibleSellerBalance = (visibleSellerBilled - visibleSellerPaid).clamp(0.0, double.infinity);

    final double sCommRate = double.tryParse(_repSellerCommRateCtrl.text) ?? 0;
    final double divisor = _repSellerCommDivisor > 0 ? _repSellerCommDivisor : 1000;
    final double calculatedQtyComm = sCommRate > 0 ? ((visibleSellerQty * sCommRate) / divisor).roundToDouble() : 0.0;
    final double combinedCommission = visibleSellerComm + calculatedQtyComm + tnCommissionTotal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. TN Commission Banner (if applicable)
        if (_repSeller.trim().isNotEmpty && tnCommissionTotal > 0) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(
              children: [
                const Icon(Icons.swap_horiz_rounded, color: Color(0xFF1D4ED8), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(fontSize: isMobile ? 11.5 : 13, color: const Color(0xFF1E40AF)),
                      children: [
                        const TextSpan(text: 'TN COMMISSION LINKED: ', style: TextStyle(fontWeight: FontWeight.bold)),
                        TextSpan(text: money(tnCommissionTotal), style: const TextStyle(fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        // 2. Filter Bar
        Container(
          padding: EdgeInsets.all(isMobile ? 12 : 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [BoxShadow(color: Color(0x04000000), blurRadius: 10, offset: Offset(0, 4))],
          ),
          child: Column(
            children: [
              _responsiveRow([
                Expanded(
                  flex: 3,
                  child: _customAutocomplete('Filter Seller', _sellerNames, _repSeller, 'CHOOSE SELLER', (v) => setState(() => _repSeller = v)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: _customAutocomplete('Filter Buyer', _sellerRespectiveBuyers, _repSellerBuyerFilter, 'ALL BUYERS', (v) => setState(() => _repSellerBuyerFilter = v)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: _customField('From Date', _repSellerFromCtrl, hint: 'DD-MM-YY', onChanged: (_) => setState(() {})),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: _customField('To Date', _repSellerToCtrl, hint: 'DD-MM-YY', onChanged: (_) => setState(() {})),
                ),
              ]),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildHideSwitch(),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF047857)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 14, vertical: isMobile ? 4 : 8),
                    ),
                    icon: const Icon(Icons.table_chart_rounded, size: 15, color: Color(0xFF047857)),
                    label: Text('Commission Summary', style: TextStyle(color: const Color(0xFF047857), fontWeight: FontWeight.bold, fontSize: isMobile ? 11 : 12)),
                    onPressed: _showAllSellersCommissionDialog,
                  ),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    children: [
                      TextButton(
                        onPressed: () => setState(() {
                          _repSeller = "";
                          _repSellerBuyerFilter = "";
                          _repSellerFromCtrl.clear();
                          _repSellerToCtrl.clear();
                        }),
                        child: const Text('Reset Filters', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                      ),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.print_rounded, size: 15),
                        label: const Text('Print Statement'),
                        onPressed: () => _openSellerReportPrintModal(
                          _repSeller.isEmpty ? "ALL SELLERS" : _repSeller,
                          _repSellerBuyerFilter,
                          displayedSellerRows,
                          visibleSellerQty,
                          visibleSellerComm,
                          calculatedQtyComm,
                          tnCommissionTotal,
                          combinedCommission,
                          visibleSellerBilled,
                          visibleSellerPaid,
                          visibleSellerBalance,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 3. Seller Advances Banners (Dynamically Shows Net Remaining Advance)
        if (_repSeller.trim().isNotEmpty && sellerAdvanceEntries.isNotEmpty) ...[
          ...sellerAdvanceEntries.map((adv) {
            final double origAmt = adv.amount + adv.settlement;

            // Calculate payments that were adjusted/allocated from this advance
            final double adjustedAmt = sellerPayments.where((p) {
              if (p.id == adv.id) return false;
              final bool sameSeller = p.seller.trim().toUpperCase() == adv.seller.trim().toUpperCase();
              if (!sameSeller) return false;

              final bool isAllocated = p.truckId.trim().isNotEmpty ||
                  (p.buyer.trim().isNotEmpty && p.buyer.trim().toUpperCase() != "SELECT BUYER");
              if (!isAllocated) return false;

              final pMode = p.mode.trim().toUpperCase();
              final advMode = adv.mode.trim().toUpperCase();

              final bool isAdvAdj = pMode == advMode ||
                  pMode.contains("ADVANCE") ||
                  pMode.contains("ADJUST");

              return isAdvAdj;
            }).fold<double>(0.0, (s, p) => s + p.amount + p.settlement);

            final double remainingAdv = (origAmt - adjustedAmt).clamp(0.0, double.infinity);

            // If the advance has been 100% adjusted, hide the banner
            if (remainingAdv <= 0.05) return const SizedBox.shrink();

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.outbox_rounded, color: Color(0xFF1D4ED8), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(fontSize: isMobile ? 11.5 : 13, color: const Color(0xFF1E40AF)),
                        children: [
                          const TextSpan(text: 'SELLER ADVANCE REMAINING: ', style: TextStyle(fontWeight: FontWeight.bold)),
                          TextSpan(text: money(remainingAdv), style: const TextStyle(fontWeight: FontWeight.w900)),
                          TextSpan(
                            text: ' (${adv.mode.isNotEmpty ? adv.mode : 'BANK'} on ${formatDisplayDate(adv.date)})',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          if (adjustedAmt > 0)
                            TextSpan(
                              text: ' • [Original: ${money(origAmt)} | Adjusted: ${money(adjustedAmt)}]',
                              style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          TextSpan(
                            text: ' — [Pending Buyer Assignment]',
                            style: TextStyle(color: Colors.blueGrey.shade700, fontSize: 11, fontStyle: FontStyle.italic),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Edit Advance Record',
                    icon: const Icon(Icons.edit, size: 16, color: Color(0xFF1D4ED8)),
                    onPressed: () => _editPaymentEntryDialog(adv),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                    onPressed: () async {
                      if (await _confirmDelete(context, "Seller Advance of ${money(origAmt)}")) {
                        setState(() {
                          _saveStateToHistory();
                          _payments.removeWhere((item) => item.id == adv.id);
                          _calculateOverdueBills(_trucks);
                        });
                        _commitToLocalDrive();
                      }
                    },
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 4),
        ],

       // 4. Main Statement Table Container
        if (_repSeller.trim().isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.storefront_rounded, size: 42, color: Color(0xFF94A3B8)),
                  SizedBox(height: 12),
                  Text('Select a Seller above to view their Statement of Account', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                ],
              ),
            ),
          )
        else
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 1120) {
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: (isMobile || isTablet)
            ? SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: 1300,
                  child: _buildSellerTableContent(displayedSellerRows, visibleSellerQty, visibleSellerComm, visibleSellerBilled, visibleSellerPaid, visibleSellerBalance),
                ),
              )
            : _buildSellerTableContent(displayedSellerRows, visibleSellerQty, visibleSellerComm, visibleSellerBilled, visibleSellerPaid, visibleSellerBalance),
                  );
                }
                return _buildSellerTableContent(displayedSellerRows, visibleSellerQty, visibleSellerComm, visibleSellerBilled, visibleSellerPaid, visibleSellerBalance);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildSellerTableContent(List<Map<String, dynamic>> rows, double vQty, double vComm, double vBilled, double vPaid, double vBal) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: const Row(
            children: [
              SizedBox(width: 85, child: Text('DATE', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B), fontSize: 11))),
              SizedBox(width: 120, child: Text('SELLER BOUGHT', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B), fontSize: 11))),
              SizedBox(width: 220, child: Text('BUYER', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B), fontSize: 11))),
              SizedBox(width: 90, child: Text('QTY', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B), fontSize: 11))),
              SizedBox(width: 90, child: Text('COMM', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B), fontSize: 11))),
              SizedBox(width: 100, child: Text('BILL', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B), fontSize: 11))),
              SizedBox(width: 270, child: Text('PAID DETAILS', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B), fontSize: 11))),
              SizedBox(width: 105, child: Text('BALANCE', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B), fontSize: 11))),
              SizedBox(width: 90, child: Text('ACTIONS', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B), fontSize: 11))),
            ],
          ),
        ),

        // Body Rows
        if (rows.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            alignment: Alignment.center,
            child: const Text('No records found for the selected filters.', style: TextStyle(color: Color(0xFF94A3B8), fontStyle: FontStyle.italic)),
          )
        else
          ...rows.map((row) {
            final t = row['truck'];
            final List<dynamic> pList = row['payments'];
            final double bal = row['rawBalance'];

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(width: 85, child: Text(row['date'], style: const TextStyle(fontSize: 11.5))),
                  SizedBox(
                    width: 130,
                    child: Text(
                      row['sourceSeller'],
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: row['sourceSeller'] != '—' ? FontWeight.w900 : FontWeight.normal,
                        color: row['sourceSeller'] != '—' ? const Color(0xFF047857) : const Color(0xFF94A3B8),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(
                width: 220,
                child: Text(
                  row['buyer'].toString().toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
                  overflow: TextOverflow.visible,
                ),
              ),
                  SizedBox(width: 90, child: Text(row['qty'], style: const TextStyle(fontSize: 11.5))),
                  SizedBox(width: 90, child: Text(row['commission'], style: const TextStyle(fontSize: 11.5))),
                  SizedBox(width: 100, child: Text(row['sellerBill'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                  // Grouped Paid Details: ₹50,000 + ₹25,000 + ₹5,000 (DIRECT) on 24-09-26
                 SizedBox(
                    width: 280,
                    child: _buildSingleLinePaidDetailsCell(pList),
                  ),
                  SizedBox(
                    width: 105,
                    child: Text(
                      row['balance'],
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11.5,
                        color: bal == 0 ? const Color(0xFF047857) : const Color(0xFFDC2626),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 90,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (bal > 0)
                          Padding(
                            padding: const EdgeInsets.only(right: 4.0),
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                minimumSize: const Size(0, 24),
                                side: const BorderSide(color: Color(0xFF047857)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              ),
                              onPressed: () => _markCustomBillAsPaid(t, bal, isBuyerSide: false, isBothSides: true),
                              child: const Text('Pay', style: TextStyle(fontSize: 9.5, color: Color(0xFF047857), fontWeight: FontWeight.bold)),
                            ),
                          ),
                        InkWell(
                          onTap: () => _editFromReport(t),
                          child: const Icon(Icons.edit, size: 14, color: Color(0xFF047857)),
                        ),
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: () async {
                            if (await _confirmDelete(context, "Bill for ${row['buyer']}")) {
                             setState(() {
  _trucks.remove(t);
  _calculateOverdueBills(_trucks);
});
_deleteDocumentFromFirestore('trucks', t.id);
_commitToLocalDrive();
                            }
                          },
                          child: const Padding(padding: EdgeInsets.all(2), child: Icon(Icons.delete_outline, size: 14, color: Colors.red)),
                        ),
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: () => _openOrGenerateInvoiceForTruck(t),
                          child: const Icon(Icons.receipt_long_outlined, size: 14, color: Color(0xFF0284C7)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),

        // Total Footer Row (Properly Aligned)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: const BoxDecoration(
            color: Color(0xFFECFDF5),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
          ),
          child: Row(
            children: [
              const SizedBox(width: 85, child: Text('TOTAL', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF047857), fontSize: 12))),
              const SizedBox(width: 130, child: Text('—', style: TextStyle(color: Color(0xFF047857)))),
              const SizedBox(width: 220, child: Text('—', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF047857)))),
              SizedBox(width: 90, child: Text(numFmt(vQty), style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF047857), fontSize: 12))),
              SizedBox(width: 90, child: Text(money(vComm), style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF047857), fontSize: 12))),
              SizedBox(width: 100, child: Text(money(vBilled), style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF047857), fontSize: 12))),
              SizedBox(width: 270, child: Text(money(vPaid), style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF047857), fontSize: 12))),
              SizedBox(width: 105, child: Text(money(vBal), style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF047857), fontSize: 12))),
              const SizedBox(width: 90),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------- CONSOLIDATED COMMISSION REPORT (FIXED PDF) ----------------
  void _showAllSellersCommissionDialog() async {
    final double sCommRate = double.tryParse(_repSellerCommRateCtrl.text) ?? 0;
    final double divisor = _repSellerCommDivisor > 0 ? _repSellerCommDivisor : 1000;
    List<Map<String, dynamic>> sellerSummaries = [];
    double grandTotalCommission = 0;
    double grandTotalQty = 0;
    double grandTotalAdjComm = 0;

    for (var seller in _sellerNames) {
      final sellerTrucks = _trucks.where((t) {
        return t.state == _selectedState &&
            t.supplier.toUpperCase() == seller.toUpperCase() &&
            _isDateInFY(t.date, _selectedFinancialYear) &&
            isDateInRange(t.date, _repSellerFromCtrl.text, _repSellerToCtrl.text);
      }).toList();

      final double totalQty = sellerTrucks.fold<double>(0.0, (s, t) => s + t.qty);
      final double directComm = sellerTrucks.fold<double>(0.0, (s, t) => s + t.commission);
      final double qtyComm = sCommRate > 0 ? ((totalQty * sCommRate) / divisor).roundToDouble() : 0.0;
      final double adjComm = _payments
          .where((p) =>
              p.state == _selectedState &&
              p.seller.toUpperCase() == seller.toUpperCase() &&
              _isDateInFY(p.date, _selectedFinancialYear) &&
              isDateInRange(p.date, _repSellerFromCtrl.text, _repSellerToCtrl.text))
          .fold<double>(0.0, (s, p) => s + p.commissionAdjusted);
      final double totalComm = directComm + qtyComm;

      if (totalComm > 0 || totalQty > 0 || adjComm > 0) {
        sellerSummaries.add({'name': seller, 'qty': totalQty, 'adjComm': adjComm, 'totalComm': totalComm});
        grandTotalCommission += totalComm;
        grandTotalQty += totalQty;
        grandTotalAdjComm += adjComm;
      }
    }
    sellerSummaries.sort((a, b) => (b['totalComm'] as double).compareTo(a['totalComm'] as double));

    const greenBorder = PdfColor.fromInt(0xFF4D8B61);
    const titleGreen = PdfColor.fromInt(0xFF126B35);
    const redAccent = PdfColor.fromInt(0xFFBD2020);

    final prefs = await SharedPreferences.getInstance();
    final customLogoPath = prefs.getString('custom_logo_path');
    pw.MemoryImage? logoImage;
    if (customLogoPath != null &&
        customLogoPath.trim().isNotEmpty &&
        customLogoPath != 'NONE' &&
        await File(customLogoPath).exists()) {
      try {
        final Uint8List customBytes = await File(customLogoPath).readAsBytes();
        logoImage = pw.MemoryImage(customBytes);
      } catch (_) {
        logoImage = null;
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Container(
          width: 840,
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.94),
          decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Consolidated Commission Report',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: PdfPreview(
                    build: (format) async {
                      final pdf = pw.Document();
                      pdf.addPage(
                        pw.Page(
                          pageFormat: PdfPageFormat.a4,
                          margin: const pw.EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                          build: (ctx) => pw.Container(
                            padding: const pw.EdgeInsets.all(10),
                            decoration: const pw.BoxDecoration(
                              border: pw.Border.fromBorderSide(pw.BorderSide(color: greenBorder, width: 1.5)),
                            ),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                              children: [
                                pw.Stack(
                                  children: [
                                    pw.Align(
                                      alignment: pw.Alignment.topCenter,
                                      child: pw.Text(
                                        _myCompany.invocation.isNotEmpty
                                            ? _myCompany.invocation
                                            : 'Om Sri Ganesaya Namaha',
                                        style: pw.TextStyle(
                                          fontSize: 9.5,
                                          fontStyle: pw.FontStyle.italic,
                                          color: titleGreen,
                                        ),
                                      ),
                                    ),
                                    pw.Align(
                                      alignment: pw.Alignment.topRight,
                                      child: pw.Column(
                                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                                        children: _myCompany.phone
                                            .split(',')
                                            .map((num) => pw.Text('Cell : ${num.trim()}',
                                                style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)))
                                            .toList(),
                                      ),
                                    ),
                                  ],
                                ),
                                pw.SizedBox(height: 4),
                                pw.Row(
                                  mainAxisAlignment: pw.MainAxisAlignment.center,
                                  children: [
                                    if (logoImage != null) ...[
                                      pw.Image(logoImage, width: 34, height: 34),
                                      pw.SizedBox(width: 8),
                                    ],
                                    pw.Text(
                                      _myCompany.name,
                                      style: pw.TextStyle(
                                        fontSize: 25,
                                        fontWeight: pw.FontWeight.bold,
                                        color: titleGreen,
                                        letterSpacing: 0.6,
                                      ),
                                    ),
                                  ],
                                ),
                                pw.SizedBox(height: 2),
                                pw.Center(
                                  child: pw.Text(
                                    _myCompany.tagline,
                                    style: pw.TextStyle(
                                      fontSize: 10,
                                      letterSpacing: 3,
                                      fontWeight: pw.FontWeight.bold,
                                    ),
                                  ),
                                ),
                                pw.SizedBox(height: 2),
                                pw.Center(
                                  child: pw.Text(
                                    _myCompany.address,
                                    textAlign: pw.TextAlign.center,
                                    style: pw.TextStyle(
                                      fontSize: 9,
                                      fontWeight: pw.FontWeight.bold,
                                      color: redAccent,
                                    ),
                                  ),
                                ),
                                pw.SizedBox(height: 8),
                                pw.Center(
                                  child: pw.Container(
                                    padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    decoration: pw.BoxDecoration(
                                      color: const PdfColor.fromInt(0xFFEBF5EE),
                                      border: pw.Border.all(color: greenBorder),
                                    ),
                                    child: pw.Text(
                                      'CONSOLIDATED COMMISSION REPORT',
                                      style: pw.TextStyle(
                                        fontSize: 10,
                                        fontWeight: pw.FontWeight.bold,
                                        color: titleGreen,
                                      ),
                                    ),
                                  ),
                                ),
                                pw.SizedBox(height: 10),
                                pw.Container(
                                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: pw.BoxDecoration(
                                    color: const PdfColor.fromInt(0xFFEBF5EE),
                                    border: pw.Border.all(color: greenBorder),
                                  ),
                                  child: pw.Row(
                                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                    children: [
                                      pw.Text(
                                        'FINANCIAL YEAR: FY $_selectedFinancialYear',
                                        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: titleGreen),
                                      ),
                                      pw.Text(
                                        'STATE: ${_selectedState.toUpperCase()}',
                                        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: titleGreen),
                                      ),
                                      pw.Text(
                                        'DATE: ${formatDisplayDate(DateTime.now().toIso8601String())}',
                                        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: titleGreen),
                                      ),
                                    ],
                                  ),
                                ),
                                pw.SizedBox(height: 8),
                                pw.Table(
                                  columnWidths: const {
                                    0: pw.FlexColumnWidth(0.8),
                                    1: pw.FlexColumnWidth(4.2),
                                    2: pw.FlexColumnWidth(2.5),
                                    3: pw.FlexColumnWidth(2.2),
                                    4: pw.FlexColumnWidth(2.5),
                                  },
                                  border: pw.TableBorder.all(color: greenBorder, width: 0.8),
                                  children: [
                                    pw.TableRow(
                                      decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF2F7F3)),
                                      children: [
                                        pw.Padding(
                                          padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
                                          child: pw.Text('#', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: titleGreen)),
                                        ),
                                        pw.Padding(
                                          padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 6),
                                          child: pw.Text('SELLER NAME', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: titleGreen)),
                                        ),
                                        pw.Padding(
                                          padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 6),
                                          child: pw.Text('TOTAL NUTS', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: titleGreen)),
                                        ),
                                        pw.Padding(
                                          padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 6),
                                          child: pw.Text('COMM ADJ', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: titleGreen)),
                                        ),
                                        pw.Padding(
                                          padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 6),
                                          child: pw.Text('TOTAL COMM', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: titleGreen)),
                                        ),
                                      ],
                                    ),
                                    if (sellerSummaries.isEmpty)
                                      pw.TableRow(
                                        children: [
                                          pw.Padding(
                                            padding: const pw.EdgeInsets.all(10),
                                            child: pw.Text(''),
                                          ),
                                          pw.Padding(
                                            padding: const pw.EdgeInsets.all(10),
                                            child: pw.Text('No commission records found for this period.', style: const pw.TextStyle(fontSize: 9)),
                                          ),
                                          pw.Padding(padding: const pw.EdgeInsets.all(10), child: pw.Text('')),
                                          pw.Padding(padding: const pw.EdgeInsets.all(10), child: pw.Text('')),
                                          pw.Padding(padding: const pw.EdgeInsets.all(10), child: pw.Text('')),
                                        ],
                                      )
                                    else
                                      ...sellerSummaries.asMap().entries.map((entry) {
                                        final idx = entry.key + 1;
                                        final item = entry.value;
                                        return pw.TableRow(
                                          children: [
                                            pw.Padding(
                                              padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
                                              child: pw.Text('$idx', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 9)),
                                            ),
                                            pw.Padding(
                                              padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 6),
                                              child: pw.Text(item['name'], style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                                            ),
                                            pw.Padding(
                                              padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 6),
                                              child: pw.Text('${numFmt(item['qty'])} NUTS', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 9)),
                                            ),
                                            pw.Padding(
                                              padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 6),
                                              child: pw.Text(money(item['adjComm']).replaceAll('₹', 'Rs. '), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                                            ),
                                            pw.Padding(
                                              padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 6),
                                              child: pw.Text(money(item['totalComm']).replaceAll('₹', 'Rs. '), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: titleGreen)),
                                            ),
                                          ],
                                        );
                                      }),
                                    pw.TableRow(
                                      decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFEBF5EE)),
                                      children: [
                                        pw.SizedBox(),
                                        pw.Padding(
                                          padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 6),
                                          child: pw.Text('GRAND TOTAL', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: titleGreen)),
                                        ),
                                        pw.Padding(
                                          padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 6),
                                          child: pw.Text('${numFmt(grandTotalQty)} NUTS', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: titleGreen)),
                                        ),
                                        pw.Padding(
                                          padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 6),
                                          child: pw.Text(money(grandTotalAdjComm).replaceAll('₹', 'Rs. '), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: titleGreen)),
                                        ),
                                        pw.Padding(
                                          padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 6),
                                          child: pw.Text(money(grandTotalCommission).replaceAll('₹', 'Rs. '), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: titleGreen)),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                pw.SizedBox(height: 20),
                                pw.Padding(
                                  padding: const pw.EdgeInsets.symmetric(vertical: 4),
                                  child: pw.Row(
                                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                    children: [
                                      pw.Text('Authorized Signature', style: const pw.TextStyle(fontSize: 8.5)),
                                      pw.Text('For ${_myCompany.name}', style: const pw.TextStyle(fontSize: 8.5)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                      return pdf.save();
                    },
                    canChangeOrientation: false,
                    canChangePageFormat: false,
                    canDebug: false,
                    allowSharing: true,
                    allowPrinting: true,
                    initialPageFormat: PdfPageFormat.a4,
                    pdfFileName: 'CONSOLIDATED_COMMISSION_REPORT.pdf',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      "",
      "JANUARY",
      "FEBRUARY",
      "MARCH",
      "APRIL",
      "MAY",
      "JUNE",
      "JULY",
      "AUGUST",
      "SEPTEMBER",
      "OCTOBER",
      "NOVEMBER",
      "DECEMBER"
    ];
    return (month >= 1 && month <= 12) ? months[month] : "";
  }

  // ---------------- 6. TRANSPORT VIEW (TYPE-SAFE MONTHLY STATEMENT) ----------------
  String _getTruckBillMonth(dynamic t) {
    final dt = parseFlexibleDate(t.date);
    return "${_getMonthName(dt.month)} ${dt.year}";
  }

  String _getPaymentBillMonth(TransportPayment p) {
    if (p.billMonth.trim().isNotEmpty) {
      return p.billMonth.trim().toUpperCase();
    }
    final dt = parseFlexibleDate(p.date);
    return "${_getMonthName(dt.month)} ${dt.year}";
  }

  List<String> _getAvailableFinancialMonths() {
    final Set<String> months = {};
    for (var t in _trucks) {
      if (t.state == _selectedState && t.transporter.isNotEmpty && t.transporter != '—') {
        months.add(_getTruckBillMonth(t));
      }
    }
    for (var p in _transportPayments) {
      if (p.state == _selectedState && p.transporter.isNotEmpty) {
        months.add(_getPaymentBillMonth(p));
      }
    }

    final startYear = int.tryParse(_selectedFinancialYear.split('-')[0]) ?? DateTime.now().year;
    final List<String> fyMonths = [
      "APRIL $startYear", "MAY $startYear", "JUNE $startYear",
      "JULY $startYear", "AUGUST $startYear", "SEPTEMBER $startYear",
      "OCTOBER $startYear", "NOVEMBER $startYear", "DECEMBER $startYear",
      "JANUARY ${startYear + 1}", "FEBRUARY ${startYear + 1}", "MARCH ${startYear + 1}",
    ];
    months.addAll(fyMonths);

    final sorted = months.toList()..sort((a, b) {
      final dtA = parseFlexibleDate("01-$a");
      final dtB = parseFlexibleDate("01-$b");
      return dtA.compareTo(dtB);
    });

    return ["ALL MONTHS", ...sorted];
  }

  Widget _buildTransportView() {
    final filterTrans = _analysisTransporter.trim().toUpperCase();
    final allMonthsList = _getAvailableFinancialMonths();

    // 1. Filter trucks by transporter
    final transporterTrucks = _trucks.where((t) {
      final matchesState = t.state == _selectedState;
      final hasTransporter = t.transporter.isNotEmpty && t.transporter != '—';
      final matchesTrans = filterTrans.isEmpty || filterTrans == 'ALL TRANSPORTERS' || t.transporter.toUpperCase() == filterTrans;
      return matchesState && hasTransporter && matchesTrans;
    }).toList();

    // 2. Filter payments by transporter
    final matchedTransPayments = _transportPayments.where((p) {
      final matchesState = p.state == _selectedState;
      final matchesTrans = filterTrans.isEmpty || filterTrans == 'ALL TRANSPORTERS' || p.transporter.toUpperCase() == filterTrans;
      return matchesState && matchesTrans;
    }).toList();

    // 3. Group and aggregate data by BILLING MONTH with safe num-to-double conversions
    Map<String, Map<String, dynamic>> monthlyMap = {};

    for (var t in transporterTrucks) {
      final mKey = _getTruckBillMonth(t);
      if (!monthlyMap.containsKey(mKey)) {
        monthlyMap[mKey] = {
          'month': mKey,
          'totalExp': 0.0,
          'totalPaid': 0.0,
          'trips': <dynamic>[],
          'payments': <TransportPayment>[],
        };
      }
      final double exp = (t.transportExp is num)
          ? (t.transportExp as num).toDouble()
          : (double.tryParse(t.transportExp?.toString() ?? '') ?? 0.0);
      monthlyMap[mKey]!['totalExp'] = ((monthlyMap[mKey]!['totalExp'] as num?)?.toDouble() ?? 0.0) + exp;
      (monthlyMap[mKey]!['trips'] as List<dynamic>).add(t);
    }

    for (var p in matchedTransPayments) {
      final mKey = _getPaymentBillMonth(p);
      if (!monthlyMap.containsKey(mKey)) {
        monthlyMap[mKey] = {
          'month': mKey,
          'totalExp': 0.0,
          'totalPaid': 0.0,
          'trips': <dynamic>[],
          'payments': <TransportPayment>[],
        };
      }
      final double amt = (p.amount is num)
          ? (p.amount as num).toDouble()
          : (double.tryParse(p.amount?.toString() ?? '') ?? 0.0);
      monthlyMap[mKey]!['totalPaid'] = ((monthlyMap[mKey]!['totalPaid'] as num?)?.toDouble() ?? 0.0) + amt;
      (monthlyMap[mKey]!['payments'] as List<TransportPayment>).add(p);
    }

    // Sort months chronologically
    final sortedMonths = monthlyMap.keys.toList()..sort((a, b) {
      return parseFlexibleDate("01-$a").compareTo(parseFlexibleDate("01-$b"));
    });

    List<Map<String, dynamic>> monthlySummaryRows = [];
    double grandTotalExp = 0.0;
    double grandTotalPaid = 0.0;

    for (var m in sortedMonths) {
      final data = monthlyMap[m]!;
      final double exp = (data['totalExp'] as num?)?.toDouble() ?? 0.0;
      final double paid = (data['totalPaid'] as num?)?.toDouble() ?? 0.0;
      final double bal = exp - paid;

      grandTotalExp += exp;
      grandTotalPaid += paid;

      monthlySummaryRows.add({
        'month': m,
        'tripsCount': (data['trips'] as List).length,
        'expense': exp,
        'paid': paid,
        'balance': bal,
        'trips': data['trips'],
        'payments': data['payments'],
      });
    }

    final double grandTotalBalance = grandTotalExp - grandTotalPaid;

    Widget _tableHeader(String text) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
    );

    Widget _tableData(String text, {bool isBold = false, Color? color}) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Text(text, style: TextStyle(fontSize: 12.5, fontWeight: isBold ? FontWeight.bold : FontWeight.w500, color: color ?? const Color(0xFF1E293B))),
    );

    final bool isSingleMonthSelected = _selectedTransportMonth != "ALL MONTHS";
    final singleMonthData = monthlyMap[_selectedTransportMonth];
    final double sExp = (singleMonthData?['totalExp'] as num?)?.toDouble() ?? 0.0;
    final double sPaid = (singleMonthData?['totalPaid'] as num?)?.toDouble() ?? 0.0;
    final double sBal = sExp - sPaid;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(isMobile ? 14 : 22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 16, offset: Offset(0, 6))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              isMobile
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Transporter Monthly Freight Statement', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            FilledButton.icon(
                              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF047857), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                              onPressed: () => _showRecordTransportPaymentDialog(),
                              icon: const Icon(Icons.payment_rounded, size: 16),
                              label: const Text('Record Monthly Payment'),
                            ),
                            FilledButton.icon(
                              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF062317), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                              onPressed: () => _openTransportReportPrintModal(
                                _analysisTransporter.isEmpty ? "ALL TRANSPORTERS" : _analysisTransporter,
                                monthlySummaryRows, grandTotalExp, grandTotalPaid, grandTotalBalance,
                              ),
                              icon: const Icon(Icons.print_rounded, size: 16),
                              label: const Text('Print Statement'),
                            ),
                          ],
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Transporter Monthly Freight Statement', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                        Wrap(
                          spacing: 10,
                          children: [
                            FilledButton.icon(
                              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF047857), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                              onPressed: () => _showRecordTransportPaymentDialog(),
                              icon: const Icon(Icons.payment_rounded, size: 16),
                              label: const Text('Record Monthly Payment'),
                            ),
                            FilledButton.icon(
                              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF062317), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                              onPressed: () => _openTransportReportPrintModal(
                                _analysisTransporter.isEmpty ? "ALL TRANSPORTERS" : _analysisTransporter,
                                monthlySummaryRows, grandTotalExp, grandTotalPaid, grandTotalBalance,
                              ),
                              icon: const Icon(Icons.print_rounded, size: 16),
                              label: const Text('Print Statement'),
                            ),
                          ],
                        ),
                      ],
                    ),
              const SizedBox(height: 16),

              _responsiveRow([
                Expanded(
                  flex: 3,
                  child: _customAutocomplete('Filter Transporter', _transporterNames, _analysisTransporter, 'ALL TRANSPORTERS', (v) => setState(() => _analysisTransporter = v)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Billing Month', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                      const SizedBox(height: 5),
                      Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE2E8F0))),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: allMonthsList.contains(_selectedTransportMonth) ? _selectedTransportMonth : "ALL MONTHS",
                            isExpanded: true,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            items: allMonthsList.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedTransportMonth = val);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ]),

              const SizedBox(height: 20),

              if (isSingleMonthSelected) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Statement for: $_selectedTransportMonth', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF047857))),
                    TextButton.icon(
                      onPressed: () => setState(() => _selectedTransportMonth = "ALL MONTHS"),
                      icon: const Icon(Icons.arrow_back, size: 16),
                      label: const Text('View All Months', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFA7F3D0))),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Text('Total Trips: ${singleMonthData?['trips']?.length ?? 0}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Text('Freight: ${money(sExp)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Text('Paid for this Month: ${money(sPaid)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF047857))),
                      Text('Pending Balance: ${money(sBal)}', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: sBal > 0 ? Colors.red : const Color(0xFF047857))),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                const Text('Trips / Loads Dispatched in this Month:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                const SizedBox(height: 8),

                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE2E8F0))),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                        columns: const [
                          DataColumn(label: Text('DATE', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('TRUCK NO', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('TRANSPORTER', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('SUPPLIER', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('BUYER', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('FREIGHT EXPENSE', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        rows: (singleMonthData?['trips'] as List<dynamic>? ?? []).map((t) => DataRow(cells: [
                          DataCell(Text(formatDisplayDate(t.date))),
                          DataCell(Text(t.truck, style: const TextStyle(fontWeight: FontWeight.bold))),
                          DataCell(Text(t.transporter)),
                          DataCell(Text(t.supplier)),
                          DataCell(Text(t.buyer)),
                          DataCell(Text(money(t.transportExp), style: const TextStyle(fontWeight: FontWeight.bold))),
                        ])).toList(),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                const Text('Payments Credited Against this Month:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                const SizedBox(height: 8),

                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE2E8F0))),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                        columns: const [
                          DataColumn(label: Text('PAYMENT DATE', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('TRANSPORTER', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('BANK / MODE', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('ALLOCATED BILL MONTH', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('AMOUNT PAID', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        rows: (singleMonthData?['payments'] as List<TransportPayment>? ?? []).map((p) => DataRow(cells: [
                          DataCell(Text(formatDisplayDate(p.date))),
                          DataCell(Text(p.transporter, style: const TextStyle(fontWeight: FontWeight.bold))),
                          DataCell(Text(p.bank)),
                          DataCell(Text(p.billMonth.isNotEmpty ? p.billMonth : _selectedTransportMonth, style: const TextStyle(color: Color(0xFF047857), fontWeight: FontWeight.bold))),
                          DataCell(Text(money(p.amount), style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF047857)))),
                        ])).toList(),
                      ),
                    ),
                  ),
                ),
              ] else ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE2E8F0))),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        const double minTableWidth = 840.0;
                        final double tableWidth = constraints.maxWidth < minTableWidth ? minTableWidth : constraints.maxWidth;
                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: tableWidth,
                            child: Table(
                              columnWidths: const {
                                0: FlexColumnWidth(2.2),
                                1: FlexColumnWidth(1.4),
                                2: FlexColumnWidth(2.0),
                                3: FlexColumnWidth(2.0),
                                4: FlexColumnWidth(2.0),
                                5: FlexColumnWidth(1.6),
                              },
                              border: const TableBorder(horizontalInside: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
                              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                              children: [
                                TableRow(
                                  decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
                                  children: [
                                    _tableHeader('MONTH'),
                                    _tableHeader('TRIPS COUNT'),
                                    _tableHeader('FREIGHT CHARGES'),
                                    _tableHeader('PAID FOR MONTH'),
                                    _tableHeader('PENDING BALANCE'),
                                    _tableHeader('ACTION'),
                                  ],
                                ),
                                if (monthlySummaryRows.isEmpty)
                                  TableRow(
                                    children: [
                                      _tableData('No freight records found.'),
                                      _tableData('—'),
                                      _tableData('—'),
                                      _tableData('—'),
                                      _tableData('—'),
                                      _tableData('—'),
                                    ],
                                  )
                                else
                                  ...monthlySummaryRows.map((row) {
                                    final double bal = (row['balance'] as num?)?.toDouble() ?? 0.0;
                                    return TableRow(
                                      children: [
                                        _tableData(row['month'], isBold: true, color: const Color(0xFF0F172A)),
                                        _tableData('${row['tripsCount']} Loads'),
                                        _tableData(money(row['expense']), isBold: true),
                                        _tableData(money(row['paid']), isBold: true, color: const Color(0xFF047857)),
                                        _tableData(money(bal), isBold: true, color: bal > 0 ? Colors.red : const Color(0xFF047857)),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 4),
                                          child: OutlinedButton(
                                            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), side: const BorderSide(color: Color(0xFF047857))),
                                            onPressed: () => setState(() => _selectedTransportMonth = row['month']),
                                            child: const Text('View Details', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF047857))),
                                          ),
                                        ),
                                      ],
                                    );
                                  }),
                                TableRow(
                                  decoration: const BoxDecoration(color: Color(0xFFECFDF5)),
                                  children: [
                                    _tableData('TOTAL', isBold: true, color: const Color(0xFF047857)),
                                    _tableData('${transporterTrucks.length} Loads', isBold: true, color: const Color(0xFF047857)),
                                    _tableData(money(grandTotalExp), isBold: true, color: const Color(0xFF047857)),
                                    _tableData(money(grandTotalPaid), isBold: true, color: const Color(0xFF047857)),
                                    _tableData(money(grandTotalBalance), isBold: true, color: const Color(0xFF065F46)),
                                    const SizedBox(),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _showRecordTransportPaymentDialog() {
    String trans = _transporterNames.isNotEmpty ? _transporterNames.first : "";
    final amtCtrl = TextEditingController();
    final dateCtrl = TextEditingController(text: _tDateCtrl.text);

    // Default Bill Month to current active month
    final now = DateTime.now();
    String billMonth = "${_getMonthName(now.month)} ${now.year}";
    final months = _getAvailableFinancialMonths().where((m) => m != "ALL MONTHS").toList();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Record Transport Monthly Payment', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _customAutocomplete('Transporter *', _transporterNames, trans, 'SELECT TRANSPORTER', (v) => setDlgState(() => trans = v)),
                const SizedBox(height: 12),
                _customField('Amount Paid (₹) *', amtCtrl, isNum: true),
                const SizedBox(height: 12),

                // ALLOCATE TO SPECIFIC BILLING MONTH
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('For Billing Month (Statement to Clear) *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                    const SizedBox(height: 5),
                    Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE2E8F0))),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: months.contains(billMonth) ? billMonth : (months.isNotEmpty ? months.first : null),
                          isExpanded: true,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          items: months.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                          onChanged: (v) {
                            if (v != null) setDlgState(() => billMonth = v);
                          },
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                _customField('Payment Date *', dateCtrl, readOnly: true, icon: Icons.calendar_today_outlined, onTap: () => _selectDateForController(dateCtrl)),
                const SizedBox(height: 12),
                _customField('Bank / Payment Mode *', _tpBankCtrl),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B)))),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF047857), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              onPressed: () {
                final double amt = double.tryParse(amtCtrl.text) ?? 0;
                if (trans.isEmpty || amt <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a transporter and enter a valid amount.')));
                  return;
                }
                setState(() {
                  _transportPayments.add(TransportPayment(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    state: _selectedState,
                    transporter: trans.toUpperCase().trim(),
                    bank: _tpBankCtrl.text.toUpperCase().trim(),
                    amount: amt,
                    date: dateCtrl.text.trim(),
                    billMonth: billMonth.toUpperCase().trim(),
                  ));
                });
                _commitToLocalDrive();
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: const Color(0xFF047857), content: Text('Payment of ₹${amt.toStringAsFixed(0)} credited to $billMonth for $trans!')));
              },
              child: const Text('Save Payment'),
            ),
          ],
        ),
      ),
    );
  }

  void _openTransportReportPrintModal(String transporterName, List<Map<String, dynamic>> rows, double totalExp, double totalPaid, double balanceDue) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), insetPadding: const EdgeInsets.all(24),
        child: Container(
          width: 920, height: 820, padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Transporter Statement — $transporterName', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)), IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx))]),
              const Divider(),
              Expanded(
                child: PdfPreview(
                  build: (format) => _generateTransportPdfReport(format, transporterName, rows, totalExp, totalPaid, balanceDue),
                  canChangeOrientation: false, canChangePageFormat: false, canDebug: false, allowSharing: true, allowPrinting: true,
                  initialPageFormat: PdfPageFormat.a4, pdfFileName: 'TRANSPORTER_STATEMENT.pdf',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<Uint8List> _generateTransportPdfReport(PdfPageFormat format, String transporter, List<Map<String, dynamic>> rows, double totalExp, double totalPaid, double balanceDue) async {
    final pdf = pw.Document(); 
    const greenBorder = PdfColor.fromInt(0xFF4D8B61); 
    const titleGreen = PdfColor.fromInt(0xFF126B35); 

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4, 
      margin: const pw.EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      build: (ctx) => pw.Container(
        padding: const pw.EdgeInsets.all(10), 
        decoration: const pw.BoxDecoration(border: pw.Border.fromBorderSide(pw.BorderSide(color: greenBorder, width: 1.5))),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch, 
          children: [
            pw.Center(
              child: pw.Text(
                _myCompany.statementName.isNotEmpty ? _myCompany.statementName : _myCompany.name, 
                style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: titleGreen, letterSpacing: 0.5),
              ),
            ),
            pw.SizedBox(height: 3),
            pw.Center(
              child: pw.Text(
                'TRANSPORTER MONTHLY FREIGHT STATEMENT', 
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: titleGreen),
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Container(
              padding: const pw.EdgeInsets.all(6), 
              color: const PdfColor.fromInt(0xFFEBF5EE), 
              child: pw.Text(
                'TRANSPORTER : ${transporter.toUpperCase()}', 
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: titleGreen),
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Table(
              border: const pw.TableBorder(
                horizontalInside: pw.BorderSide(color: greenBorder, width: 1), 
                verticalInside: pw.BorderSide(color: greenBorder, width: 1),
              ),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF2F7F3)), 
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('MONTH', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('TRIPS', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('FREIGHT EXPENSE (Rs)', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('PAID (Rs)', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('CUMULATIVE BALANCE (Rs)', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold))),
                  ],
                ),
                ...rows.map((row) {
                  return pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(row['month'] ?? '', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('${row['tripsCount']} Trips', style: const pw.TextStyle(fontSize: 8.5))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(pdfMoney(row['expense']), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8.5))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(pdfMoney(row['paid']), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(pdfMoney(row['balance']), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold))),
                    ],
                  );
                }),
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFEBF5EE)), 
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('TOTAL', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: titleGreen))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('-')),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Rs. ${pdfMoney(totalExp)}', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: titleGreen))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Rs. ${pdfMoney(totalPaid)}', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: titleGreen))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Rs. ${pdfMoney(balanceDue)}', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: titleGreen))),
                  ],
                ),
              ],
            ),
            pw.Spacer(),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 3), 
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, 
                children: [
                  pw.Text('Authorized Signature', style: const pw.TextStyle(fontSize: 8.5)),
                  pw.Text('For ${_myCompany.statementName.isNotEmpty ? _myCompany.statementName : _myCompany.name}', style: const pw.TextStyle(fontSize: 8.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    ));
    return pdf.save();
  }
  // ---------------- 7. ESTIMATE VIEW ----------------
  Widget _buildEstimateView() {
    final double b1TotalBags = double.tryParse(_b1BagsCtrl.text) ?? 0;
    final double b1TotalNuts = double.tryParse(_b1NutsCtrl.text) ?? 0;
    final double b1Weight = double.tryParse(_b1WeightCtrl.text) ?? 0;
    final double b1WeightRate = double.tryParse(_b1RateCtrl.text) ?? 0;
    final double b1WeightTotal = b1Weight * b1WeightRate;

    final double b1LoadingRate = double.tryParse(_b1LoadingRateCtrl.text) ?? 0;
    final double b1LoadingAmount = _b1LoadingType == "AP" ? ((b1TotalNuts * b1LoadingRate) / 1000) : (b1TotalBags * b1LoadingRate);
    final double b1Amc = double.tryParse(_b1AmcCtrl.text) ?? 0;
    final double b1Comm = double.tryParse(_b1CommCtrl.text) ?? 0;
    final double b1Ins = double.tryParse(_b1InsCtrl.text) ?? 0;
    final double b1Freight = double.tryParse(_b1FreightCtrl.text) ?? 0;

    final double b1TotalCharges = b1LoadingAmount + b1Amc + b1Comm + b1Ins + b1Freight;
    final double b1GrandTotal = b1WeightTotal + b1TotalCharges;
    final double b1PerBagValue = b1TotalBags > 0 ? (b1GrandTotal / b1TotalBags) : 0;

    final double b2Qty = double.tryParse(_b2QtyCtrl.text) ?? 0;
    final double b2Rate = double.tryParse(_b2RateCtrl.text) ?? 0;
    final double b2Divisor = (double.tryParse(_b2DivisorCtrl.text) ?? 1000) <= 0 ? 1 : (double.tryParse(_b2DivisorCtrl.text) ?? 1000);
    final double b2BaseTotal = (b2Qty * b2Rate) / b2Divisor;

    final double b2LoadingRate = double.tryParse(_b2LoadRateCtrl.text) ?? 0;
    final double b2LoadingAmount = _b2LoadingManual
        ? (double.tryParse(_b2LoadManualAmountCtrl.text) ?? 0)
        : (b2Qty * b2LoadingRate) / 1000;

    final double b2Amc = double.tryParse(_b2AmcCtrl.text) ?? 0;
    final double b2Comm = double.tryParse(_b2CommCtrl.text) ?? 0;
    final double b2Bags = double.tryParse(_b2BagsCtrl.text) ?? 0;
    final double b2BagRate = double.tryParse(_b2BagRateCtrl.text) ?? 0;
    final double b2BagsTotal = b2Bags * b2BagRate;
    final double b2Freight = double.tryParse(_b2FreightCtrl.text) ?? 0;

    final double b2TotalCharges = b2LoadingAmount + b2Amc + b2Comm + b2BagsTotal + b2Freight;
    final double b2GrandTotal = b2BaseTotal + b2TotalCharges;
    final double b2PerNutValue = b2Qty > 0 ? (b2GrandTotal / b2Qty) : 0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ==================== BOX 1 ESTIMATOR ====================
        Container(
          padding: EdgeInsets.all(isMobile ? 14 : 22),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E8F0)), boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 16, offset: Offset(0, 6))]),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isMobile) ...[
                const Text('Box 1: Weight & Bags Estimator', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(8)),
                  child: Text('Rate: ${money(b1PerBagValue)} / bag', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF047857))),
                ),
              ] else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Box 1: Weight & Bags Estimator', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(8)),
                      child: Text('Rate: ${money(b1PerBagValue)} / bag', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF047857))),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              const Text('1. Core Count & Parameters', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF064E3B))),
              const SizedBox(height: 8),
              _responsiveRow([
                Expanded(child: _customField('Total Bags', _b1BagsCtrl, hint: '55', isNum: true, onChanged: (_) => setState(() {}))),
                const SizedBox(width: 12),
                Expanded(child: _customField('Total Nuts', _b1NutsCtrl, hint: '4400', isNum: true, onChanged: (_) => setState(() {}))),
              ]),
              const SizedBox(height: 14),
              const Text('2. Weight Calculation', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF064E3B))),
              const SizedBox(height: 8),
              _responsiveRow([
                Expanded(child: _customField('Weight (Kgs)', _b1WeightCtrl, hint: '25000', isNum: true, onChanged: (_) => setState(() {}))),
                const SizedBox(width: 12),
                Expanded(child: _customField('Rate (₹/kg)', _b1RateCtrl, hint: '40', isNum: true, onChanged: (_) => setState(() {}))),
                const SizedBox(width: 12),
                Expanded(child: _customField('Weight Amount', TextEditingController(text: money(b1WeightTotal)), readOnly: true)),
              ]),
              const SizedBox(height: 14),
              const Text('3. Loading & Logistics', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF064E3B))),
              const SizedBox(height: 8),
              _responsiveRow([
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          const Text('Loading:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                          ChoiceChip(
                            label: const Text('AP (Nuts)'),
                            selected: _b1LoadingType == "AP",
                            onSelected: (val) => setState(() { _b1LoadingType = "AP"; _b1LoadingRateCtrl.text = "650"; }),
                          ),
                          ChoiceChip(
                            label: const Text('TN (Bags)'),
                            selected: _b1LoadingType == "TN",
                            onSelected: (val) => setState(() { _b1LoadingType = "TN"; _b1LoadingRateCtrl.text = "70"; }),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      _customField(_b1LoadingType == "AP" ? 'Loading Rate (₹/1000 nuts)' : 'Loading Rate (₹/bag)', _b1LoadingRateCtrl, isNum: true, onChanged: (_) => setState(() {})),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: _customField('AMC (₹)', _b1AmcCtrl, isNum: true, onChanged: (_) => setState(() {}))),
                const SizedBox(width: 12),
                Expanded(child: _customField('Commission (₹)', _b1CommCtrl, isNum: true, onChanged: (_) => setState(() {}))),
                const SizedBox(width: 12),
                Expanded(child: _customField('Insurance (₹)', _b1InsCtrl, isNum: true, onChanged: (_) => setState(() {}))),
                const SizedBox(width: 12),
                Expanded(child: _customField('Freight (₹)', _b1FreightCtrl, isNum: true, onChanged: (_) => setState(() {}))),
              ]),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF062317), Color(0xFF047857)]), borderRadius: BorderRadius.circular(12)),
                child: isMobile
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('BOX 1 ESTIMATED TOTAL', style: TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(money(b1GrandTotal), style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 6),
                          Text('${money(b1PerBagValue)} / bag', style: const TextStyle(color: Color(0xFF6EE7B7), fontSize: 18, fontWeight: FontWeight.w900)),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('BOX 1 ESTIMATED TOTAL', style: TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.bold)),
                              Text(money(b1GrandTotal), style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                            ],
                          ),
                          Text('${money(b1PerBagValue)} / bag', style: const TextStyle(color: Color(0xFF6EE7B7), fontSize: 20, fontWeight: FontWeight.w900)),
                        ],
                      ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // ==================== BOX 2 ESTIMATOR ====================
        Container(
          padding: EdgeInsets.all(isMobile ? 14 : 22),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E8F0)), boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 16, offset: Offset(0, 6))]),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isMobile) ...[
                const Text('Box 2: Quantity & Loading Estimator', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(8)),
                  child: Text('Rate: ₹${b2PerNutValue.toStringAsFixed(2)} / nut', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF047857))),
                ),
              ] else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Box 2: Quantity, Divisor & Loading Estimator', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(8)),
                      child: Text('Rate: ₹${b2PerNutValue.toStringAsFixed(2)} / nut', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF047857))),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              const Text('1. Base Rate & Divisor Calculation', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF064E3B))),
              const SizedBox(height: 8),
              _responsiveRow([
                Expanded(child: _customField('Quantity (Nuts)', _b2QtyCtrl, hint: '30500', isNum: true, onChanged: (_) => setState(() {}))),
                const SizedBox(width: 10),
                Expanded(child: _customField('Rate (₹)', _b2RateCtrl, hint: '2500', isNum: true, onChanged: (_) => setState(() {}))),
                const SizedBox(width: 10),
                Expanded(child: _customField('Divisor', _b2DivisorCtrl, hint: '1000', isNum: true, onChanged: (_) => setState(() {}))),
                const SizedBox(width: 10),
                Expanded(child: _customField('Base Amount', TextEditingController(text: money(b2BaseTotal)), readOnly: true)),
              ]),
              const SizedBox(height: 14),
              const Text('2. Loading & Levies', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF064E3B))),
              const SizedBox(height: 8),
              _responsiveRow([
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          const Text('Loading:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                          ChoiceChip(
                            label: const Text('Rate (/1000)'),
                            selected: !_b2LoadingManual,
                            onSelected: (val) => setState(() => _b2LoadingManual = false),
                          ),
                          ChoiceChip(
                            label: const Text('Manual Amt'),
                            selected: _b2LoadingManual,
                            onSelected: (val) => setState(() => _b2LoadingManual = true),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      _b2LoadingManual
                          ? _customField('Manual Amount (₹)', _b2LoadManualAmountCtrl, isNum: true, onChanged: (_) => setState(() {}))
                          : _customField('Loading Rate (₹/1000)', _b2LoadRateCtrl, hint: '650', isNum: true, onChanged: (_) => setState(() {})),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: _customField('AMC (₹)', _b2AmcCtrl, isNum: true, onChanged: (_) => setState(() {}))),
                const SizedBox(width: 12),
                Expanded(child: _customField('Commission (₹)', _b2CommCtrl, isNum: true, onChanged: (_) => setState(() {}))),
              ]),
              const SizedBox(height: 14),
              const Text('3. Packaging & Freight', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF064E3B))),
              const SizedBox(height: 8),
              _responsiveRow([
                Expanded(child: _customField('Bags Count', _b2BagsCtrl, isNum: true, onChanged: (_) => setState(() {}))),
                const SizedBox(width: 10),
                Expanded(child: _customField('Bag Rate (₹)', _b2BagRateCtrl, isNum: true, onChanged: (_) => setState(() {}))),
                const SizedBox(width: 10),
                Expanded(child: _customField('Bags Amount', TextEditingController(text: money(b2BagsTotal)), readOnly: true)),
                const SizedBox(width: 10),
                Expanded(child: _customField('Freight (₹)', _b2FreightCtrl, isNum: true, onChanged: (_) => setState(() {}))),
              ]),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF0F3928), Color(0xFF047857)]), borderRadius: BorderRadius.circular(12)),
                child: isMobile
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('BOX 2 ESTIMATED TOTAL', style: TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(money(b2GrandTotal), style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 6),
                          Text('₹${b2PerNutValue.toStringAsFixed(2)} / nut', style: const TextStyle(color: Color(0xFF6EE7B7), fontSize: 18, fontWeight: FontWeight.w900)),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('BOX 2 ESTIMATED TOTAL', style: TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.bold)),
                              Text(money(b2GrandTotal), style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                            ],
                          ),
                          Text('₹${b2PerNutValue.toStringAsFixed(2)} / nut', style: const TextStyle(color: Color(0xFF6EE7B7), fontSize: 20, fontWeight: FontWeight.w900)),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------- MODALS & HELPERS ----------------
  void _showAddEditBankDialog({BankAccount? account, VoidCallback? onSaved}) {
    final nameCtrl = TextEditingController(text: account?.name ?? '');
    final accCtrl = TextEditingController(text: account?.account ?? '');
    final ifscCtrl = TextEditingController(text: account?.ifsc ?? '');
    final branchCtrl = TextEditingController(text: account?.branch ?? '');
    final noteCtrl = TextEditingController(text: account?.note ?? 'Please Credit to our Account only');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(account != null ? 'Edit Bank Account' : 'Add New Bank Account', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _customField('Bank Name *', nameCtrl, hint: 'e.g. HDFC BANK'),
                const SizedBox(height: 8),
                _customField('Account Number *', accCtrl, hint: 'e.g. 50100234567890'),
                const SizedBox(height: 8),
                _customField('IFSC Code *', ifscCtrl, hint: 'e.g. HDFC0000123'),
                const SizedBox(height: 8),
                _customField('Branch *', branchCtrl, hint: 'e.g. MAIN BRANCH'),
                const SizedBox(height: 8),
                _customField('Note (Printed on Invoice)', noteCtrl),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF047857)),
            onPressed: () {
              final name = nameCtrl.text.trim().toUpperCase();
              final acc = accCtrl.text.trim();
              final ifsc = ifscCtrl.text.trim().toUpperCase();
              final branch = branchCtrl.text.trim().toUpperCase();
              final note = noteCtrl.text.trim();

              if (name.isEmpty || acc.isEmpty || ifsc.isEmpty || branch.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.red, content: Text('Please fill all required fields!')));
                return;
              }

              setState(() {
                if (account != null) {
                  account.name = name;
                  account.account = acc;
                  account.ifsc = ifsc;
                  account.branch = branch;
                  account.note = note;
                } else {
                  final newBank = BankAccount(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: name, account: acc, ifsc: ifsc, branch: branch, note: note,
                  );
                  _bankAccounts.add(newBank);
                }
              });

              _commitToLocalDrive();
              if (onSaved != null) onSaved();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Color(0xFF047857), content: Text('Bank Account saved and synced!')));
            },
            child: Text(account != null ? 'Update Bank' : 'Save Bank'),
          ),
        ],
      ),
    );
  }

  void _openSellerReportPrintModal(
    String sellerName,
    String buyerFilter,
    List<Map<String, dynamic>> rows,
    double totalQty,
    double totalComm,
    double calculatedQtyComm,
    double tnCommission,
    double combinedTotalCommission,
    double totalBilled,
    double totalPaid,
    double balanceDue,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.all(24),
        child: Container(
          width: 920,
          height: 820,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Statement — $sellerName', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  Row(
                    children: [
                      // FEATURE 6: Save to Custom Windows Folder button
                      if (!kIsWeb && Platform.isWindows)
                        FilledButton.icon(
                          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF047857)),
                          icon: const Icon(Icons.save_alt_rounded, size: 15),
                          label: const Text('Save to Folder', style: TextStyle(fontSize: 11.5)),
                          onPressed: () async {
                            final pdfBytes = await _generateSellerPdfReport(
                              PdfPageFormat.a4,
                              sellerName,
                              buyerFilter,
                              rows,
                              totalQty,
                              totalComm,
                              calculatedQtyComm,
                              tnCommission,
                              combinedTotalCommission,
                              totalBilled,
                              totalPaid,
                              balanceDue,
                            );
                            await _exportPdfToCustomDirOrShare(
                              context: context,
                              fileName: 'SELLER_STATEMENT_${sellerName.replaceAll(' ', '_')}.pdf',
                              pdfBytes: pdfBytes,
                            );
                          },
                        ),
                      const SizedBox(width: 8),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: PdfPreview(
                  build: (format) => _generateSellerPdfReport(
                    format,
                    sellerName,
                    buyerFilter,
                    rows,
                    totalQty,
                    totalComm,
                    calculatedQtyComm,
                    tnCommission,
                    combinedTotalCommission,
                    totalBilled,
                    totalPaid,
                    balanceDue,
                  ),
                  canChangeOrientation: false,
                  canChangePageFormat: false,
                  canDebug: false,
                  allowSharing: true,
                  allowPrinting: true,
                  initialPageFormat: PdfPageFormat.a4,
                  pdfFileName: 'SELLER_STATEMENT.pdf',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<Uint8List> _generateSellerPdfReport(PdfPageFormat format, String seller, String buyerFilter, List<Map<String, dynamic>> rows, double totalQty, double totalComm, double calculatedQtyComm,double tnCommission, double combinedTotalCommission, double totalBilled, double totalPaid, double balanceDue) async {
    final pdf = pw.Document(); 
    const greenBorder = PdfColor.fromInt(0xFF4D8B61); 
    const titleGreen = PdfColor.fromInt(0xFF126B35); 
    const redAccent = PdfColor.fromInt(0xFFBD2020);

    // Total FY trucks for this seller across the active financial year
    final int totalFySellerTrucks = _trucks.where((t) {
      final sName = t.supplier.toString().trim().toUpperCase();
      final targetSeller = seller.toString().trim().toUpperCase();
      return sName == targetSeller && _isDateInFY(t.date, _selectedFinancialYear);
    }).length;

    final prefs = await SharedPreferences.getInstance();
    final customLogoPath = prefs.getString('custom_logo_path');
    pw.MemoryImage? logoImage;
    if (customLogoPath != null && customLogoPath.trim().isNotEmpty && customLogoPath != 'NONE' && await File(customLogoPath).exists()) {
      try {
        final Uint8List customBytes = await File(customLogoPath).readAsBytes();
        logoImage = pw.MemoryImage(customBytes);
      } catch (_) { logoImage = null; }
    }

    // Check if any row in this specific statement has a "Seller Bought" party
    final bool hasSellerBought = rows.any((r) {
      final s = r['sourceSeller']?.toString().trim() ?? '';
      return s.isNotEmpty && s != '—' && s != '-' && s != 'SELF / DIRECT';
    });

    // Dynamic Column Widths: gives room back to Commission & Buyer if no Seller Bought
    final Map<int, pw.TableColumnWidth> pdfColWidths = hasSellerBought
        ? const {
            0: pw.FlexColumnWidth(1.6), // DATE
            1: pw.FlexColumnWidth(2.2), // SELLER BOUGHT
            2: pw.FlexColumnWidth(2.6), // BUYER
            3: pw.FlexColumnWidth(1.6), // QTY
            4: pw.FlexColumnWidth(1.7), // COMM
            5: pw.FlexColumnWidth(1.9), // BILL
            6: pw.FlexColumnWidth(3.8), // PAID
            7: pw.FlexColumnWidth(1.8), // BALANCE
          }
        : const {
            0: pw.FlexColumnWidth(1.8), // DATE
            1: pw.FlexColumnWidth(3.2), // BUYER (Expanded)
            2: pw.FlexColumnWidth(1.8), // QTY
            3: pw.FlexColumnWidth(1.8), // COMMISSION (No line wrap)
            4: pw.FlexColumnWidth(2.0), // BILL
            5: pw.FlexColumnWidth(4.4), // PAID WITH DATE & BANK
            6: pw.FlexColumnWidth(2.0), // BALANCE
          };

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      build: (ctx) => pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: const pw.BoxDecoration(border: pw.Border.fromBorderSide(pw.BorderSide(color: greenBorder, width: 1.5))),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Stack(
              children: [
                pw.Align(
                  alignment: pw.Alignment.topCenter,
                  child: pw.Text(_myCompany.invocation.isNotEmpty ? _myCompany.invocation : 'Om Sri Ganesaya Namaha', style: pw.TextStyle(fontSize: 9.5, fontStyle: pw.FontStyle.italic, color: titleGreen)),
                ),
                pw.Align(
                  alignment: pw.Alignment.topRight,
                  child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: _myCompany.phone.split(',').map((num) => pw.Text('Cell : ${num.trim()}', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold))).toList()),
                ),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Center(
              child: pw.Text(
                _myCompany.statementName.isNotEmpty ? _myCompany.statementName.toUpperCase() : _myCompany.name.toUpperCase(),
                style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: titleGreen, letterSpacing: 0.5),
              ),
            ),
            pw.SizedBox(height: 3),
            pw.Center(child: pw.Text(_myCompany.tagline, style: pw.TextStyle(fontSize: 10, letterSpacing: 2.5, fontWeight: pw.FontWeight.bold))),
            pw.SizedBox(height: 3),
            pw.Center(child: pw.Text(_myCompany.address, textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: redAccent))),
            pw.SizedBox(height: 8),
            pw.Center(
              child: pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFEBF5EE), border: pw.Border.fromBorderSide(pw.BorderSide(color: greenBorder, width: 1))),
                child: pw.Text('STATEMENT OF ACCOUNT', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: titleGreen)),
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 6),
              decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFEBF5EE)),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('SELLER : ${seller.toUpperCase()}', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: titleGreen)),
                  pw.Text('BUYER : ${buyerFilter.isNotEmpty ? buyerFilter.toUpperCase() : "ALL BUYERS"}', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: titleGreen))
                ],
              ),
            ),
            pw.SizedBox(height: 5),

            // Dynamic Table
            pw.Container(
              decoration: const pw.BoxDecoration(border: pw.Border.fromBorderSide(pw.BorderSide(color: greenBorder, width: 1))),
              child: pw.Table(
                columnWidths: pdfColWidths,
                border: const pw.TableBorder(
                  horizontalInside: pw.BorderSide(color: greenBorder, width: 1),
                  verticalInside: pw.BorderSide(color: greenBorder, width: 1),
                ),
                children: [
                  // Table Header
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF2F7F3)),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(3.5), child: pw.Text('DATE', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                      if (hasSellerBought)
                        pw.Padding(padding: const pw.EdgeInsets.all(3.5), child: pw.Text('SELLER BOUGHT', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(3.5), child: pw.Text('BUYER', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(3.5), child: pw.Text('QTY (NUTS)', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(3.5), child: pw.Text('COMMISSION', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(3.5), child: pw.Text('SELLER BILL', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(3.5), child: pw.Text('PAID WITH DATE & BANK', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(3.5), child: pw.Text('BALANCE', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                    ],
                  ),

                  // Data Rows
                  ...rows.map((row) {
                    final List<dynamic> pList = row['payments'] as List<dynamic>;

                    final Map<String, List<dynamic>> byDate = {};
                    for (var p in pList) {
                      byDate.putIfAbsent(p.date.toString().trim(), () => []).add(p);
                    }

                    String paidText = byDate.isEmpty
                        ? '-'
                        : byDate.entries.map((entry) {
                            final dt = formatDisplayDate(entry.key);
                            final dPays = entry.value;
                            final bool sameMode = dPays.map((p) => p.mode).toSet().length == 1;

                            if (sameMode) {
                              final amts = dPays.map((p) => "Rs. ${pdfMoney(p.amount)}").join(' + ');
                              return "$amts (${dPays.first.mode}) on $dt";
                            } else {
                              return dPays.map((p) => "Rs. ${pdfMoney(p.amount)} (${p.mode})").join(' + ') + " on $dt";
                            }
                          }).join('\n');

                    // Safe fallback character: standard hyphen '-' to prevent ☒
                    String sourceBought = row['sourceSeller']?.toString().trim() ?? '';
                    if (sourceBought.isEmpty || sourceBought == '—' || sourceBought == 'SELF / DIRECT') {
                      sourceBought = '-';
                    }

                    return pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(3.5), child: pw.Text(row['date'], style: const pw.TextStyle(fontSize: 8))),
                        if (hasSellerBought)
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(3.5),
                            child: pw.Text(
                              sourceBought,
                              style: pw.TextStyle(
                                fontSize: 8,
                                fontWeight: sourceBought != '-' ? pw.FontWeight.bold : pw.FontWeight.normal,
                              ),
                            ),
                          ),
                        pw.Padding(padding: const pw.EdgeInsets.all(3.5), child: pw.Text(row['buyer'], style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: const pw.EdgeInsets.all(3.5), child: pw.Text('${row['qty']} NUTS', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8))),
                        pw.Padding(padding: const pw.EdgeInsets.all(3.5), child: pw.Text(row['commission'].replaceAll('₹', 'Rs. '), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8))),
                        pw.Padding(padding: const pw.EdgeInsets.all(3.5), child: pw.Text('Rs. ${pdfMoney(row['truck'].supplierBill)}', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: const pw.EdgeInsets.all(3.5), child: pw.Text(paidText, style: pw.TextStyle(fontSize: 7.5, color: titleGreen, fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: const pw.EdgeInsets.all(3.5), child: pw.Text(row['balance'].replaceAll('₹', 'Rs. '), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                      ],
                    );
                  }),

                  // Table Footer Total Row
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFEBF5EE)),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(3.5), child: pw.Text('TOTAL', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: titleGreen))),
                      if (hasSellerBought)
                        pw.Padding(padding: const pw.EdgeInsets.all(3.5), child: pw.Text('-', style: const pw.TextStyle(fontSize: 8))),
                      pw.Padding(padding: const pw.EdgeInsets.all(3.5), child: pw.Text('-', style: const pw.TextStyle(fontSize: 8))),
                      pw.Padding(padding: const pw.EdgeInsets.all(3.5), child: pw.Text('${numFmt(totalQty)} NUTS', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: titleGreen))),
                      pw.Padding(padding: const pw.EdgeInsets.all(3.5), child: pw.Text('Rs. ${pdfMoney(totalComm)}', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: titleGreen))),
                      pw.Padding(padding: const pw.EdgeInsets.all(3.5), child: pw.Text('Rs. ${pdfMoney(totalBilled)}', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: titleGreen))),
                      pw.Padding(padding: const pw.EdgeInsets.all(3.5), child: pw.Text('Rs. ${pdfMoney(totalPaid)}', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: titleGreen))),
                      pw.Padding(padding: const pw.EdgeInsets.all(3.5), child: pw.Text('Rs. ${pdfMoney(balanceDue)}', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: titleGreen))),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 5),

            // Commission Summary Box with Total Trucks on the left
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: pw.BoxDecoration(
                color: const PdfColor.fromInt(0xFFF1F8F3),
                border: pw.Border.all(color: greenBorder, width: 1),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'TOTAL TRUCKS = $totalFySellerTrucks',
                    style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: titleGreen),
                  ),
                  pw.Text(
                    tnCommission > 0
                        ? 'Qty Comm (Rs. ${pdfMoney(calculatedQtyComm)}) + AP Comm (Rs. ${pdfMoney(totalComm)}) + TN Comm (Rs. ${pdfMoney(tnCommission)}) = TOTAL: Rs. ${pdfMoney(combinedTotalCommission)}'
                        : 'Qty Comm (Rs. ${pdfMoney(calculatedQtyComm)}) + AP Comm (Rs. ${pdfMoney(totalComm)}) = TOTAL: Rs. ${pdfMoney(combinedTotalCommission)}',
                    style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: titleGreen),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 3),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Customer Signature', style: const pw.TextStyle(fontSize: 8.5)),
                  pw.Text('For ${_myCompany.statementName.isNotEmpty ? _myCompany.statementName : _myCompany.name}', style: const pw.TextStyle(fontSize: 8.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    ));
    return pdf.save();
  }

  void _openBuyerReportPrintModal(
    String buyerName,
    String sellerFilter,
    List<Map<String, dynamic>> rows,
    double totalQty,
    double totalBilled,
    double totalPaid,
    double balanceDue,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: EdgeInsets.symmetric(
          horizontal: isMobile ? 12 : 24,
          vertical: isMobile ? 16 : 24,
        ),
        child: Container(
          width: isMobile ? MediaQuery.of(context).size.width : 920,
          height: MediaQuery.of(context).size.height * (isMobile ? 0.88 : 0.85),
          padding: EdgeInsets.all(isMobile ? 12 : 20),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Buyer Statement — $buyerName',
                      style: TextStyle(
                        fontSize: isMobile ? 14 : 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // FEATURE 6: Save to Custom Windows Folder button
                      if (!kIsWeb && Platform.isWindows)
                        FilledButton.icon(
                          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF047857)),
                          icon: const Icon(Icons.save_alt_rounded, size: 15),
                          label: const Text('Save to Folder', style: TextStyle(fontSize: 11.5)),
                          onPressed: () async {
                            final pdfBytes = await _generateBuyerPdfReport(
                              PdfPageFormat.a4,
                              buyerName,
                              sellerFilter,
                              rows,
                              totalQty,
                              totalBilled,
                              totalPaid,
                              balanceDue,
                            );
                            await _exportPdfToCustomDirOrShare(
                              context: context,
                              fileName: 'BUYER_STATEMENT_${buyerName.replaceAll(' ', '_')}.pdf',
                              pdfBytes: pdfBytes,
                            );
                          },
                        ),
                      // FEATURE 8: Consolidated AP + TN button
                      // Consolidated Multi-State Button
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF047857)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                ),
                icon: const Icon(Icons.library_books_rounded, size: 14, color: Color(0xFF047857)),
                label: const Text('Consolidated (AP + TN)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF047857))),
                onPressed: () {
                  Navigator.pop(ctx);
                  showDialog(
                    context: context,
                    builder: (c2) => Dialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      insetPadding: const EdgeInsets.all(24),
                      child: Container(
                        width: 920,
                        height: 820,
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Consolidated Statement — $buyerName (AP + TN)', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                                Row(
                                  children: [
                                    // Windows Save to Custom Folder Button
                                    if (!kIsWeb && Platform.isWindows)
                                      FilledButton.icon(
                                        style: FilledButton.styleFrom(backgroundColor: const Color(0xFF047857)),
                                        icon: const Icon(Icons.save_alt_rounded, size: 15),
                                        label: const Text('Save to Folder', style: TextStyle(fontSize: 11.5)),
                                        onPressed: () async {
                                          final pdfBytes = await _generateConsolidatedBuyerPdfReport(
                                            PdfPageFormat.a4,
                                            buyerName,
                                            sellerFilter,
                                          );
                                          if (!context.mounted) return;
                                          await _exportPdfToCustomDirOrShare(
                                            context: context,
                                            fileName: 'CONSOLIDATED_STATEMENT_${buyerName.replaceAll(' ', '_')}.pdf',
                                            pdfBytes: pdfBytes,
                                          );
                                        },
                                      ),
                                    const SizedBox(width: 8),
                                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(c2)),
                                  ],
                                ),
                              ],
                            ),
                            const Divider(),
                            Expanded(
                              child: PdfPreview(
                                build: (format) => _generateConsolidatedBuyerPdfReport(format, buyerName, sellerFilter),
                                canChangeOrientation: false,
                                canChangePageFormat: false,
                                canDebug: false,
                                allowSharing: true,
                                allowPrinting: true,
                                initialPageFormat: PdfPageFormat.a4,
                                pdfFileName: 'CONSOLIDATED_BUYER_STATEMENT.pdf',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Expanded(
                child: PdfPreview(
                  build: (format) => _generateBuyerPdfReport(
                    format,
                    buyerName,
                    sellerFilter,
                    rows,
                    totalQty,
                    totalBilled,
                    totalPaid,
                    balanceDue,
                  ),
                  canChangeOrientation: false,
                  canChangePageFormat: false,
                  canDebug: false,
                  allowSharing: true,
                  allowPrinting: true,
                  initialPageFormat: PdfPageFormat.a4,
                  pdfFileName: 'BUYER_STATEMENT.pdf',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<Uint8List> _generateBuyerPdfReport(PdfPageFormat format, String buyer, String sellerFilter, List<Map<String, dynamic>> rows, double totalQty, double totalBilled, double totalPaid, double balanceDue) async {
    final pdf = pw.Document(); 
    const greenBorder = PdfColor.fromInt(0xFF4D8B61); 
    const titleGreen = PdfColor.fromInt(0xFF126B35); 
    const redAccent = PdfColor.fromInt(0xFFBD2020);

    final prefs = await SharedPreferences.getInstance();
    final customLogoPath = prefs.getString('custom_logo_path');
    pw.MemoryImage? logoImage;
    if (customLogoPath != null && customLogoPath.trim().isNotEmpty && customLogoPath != 'NONE' && await File(customLogoPath).exists()) {
      try {
        final Uint8List customBytes = await File(customLogoPath).readAsBytes();
        logoImage = pw.MemoryImage(customBytes);
      } catch (_) { logoImage = null; }
    }

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4, margin: const pw.EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      build: (ctx) => pw.Container(
        padding: const pw.EdgeInsets.all(10), 
        decoration: const pw.BoxDecoration(border: pw.Border.fromBorderSide(pw.BorderSide(color: greenBorder, width: 1.5))),
        child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Stack(
                children: [
                  pw.Align(
                    alignment: pw.Alignment.topCenter,
                    child: pw.Text(_myCompany.invocation.isNotEmpty ? _myCompany.invocation : 'Om Sri Ganesaya Namaha', style: pw.TextStyle(fontSize: 9.5, fontStyle: pw.FontStyle.italic, color: titleGreen)),
                  ),
                  pw.Align(
                    alignment: pw.Alignment.topRight,
                    child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: _myCompany.phone.split(',').map((num) => pw.Text('Cell : ${num.trim()}', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold))).toList()),
                  ),
                ],
              ), 
              pw.SizedBox(height: 6),
              // SINGLE CLEAN STATEMENT HEADER NAME (Uses statementName exclusively)
              pw.Center(
                child: pw.Text(
                  _myCompany.statementName.isNotEmpty ? _myCompany.statementName.toUpperCase() : _myCompany.name.toUpperCase(), 
                  style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: titleGreen, letterSpacing: 0.5),
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Center(child: pw.Text(_myCompany.tagline, style: pw.TextStyle(fontSize: 10, letterSpacing: 2.5, fontWeight: pw.FontWeight.bold))), 
              pw.SizedBox(height: 3),
              pw.Center(child: pw.Text(_myCompany.address, textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: redAccent))), 
              pw.SizedBox(height: 8),
              pw.Center(
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFEBF5EE), border: pw.Border.fromBorderSide(pw.BorderSide(color: greenBorder, width: 1))),
                  child: pw.Text('STATEMENT OF ACCOUNT', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: titleGreen)),
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 6), 
              decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFEBF5EE)), 
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, 
                children: [
                  pw.Text('BUYER : ${buyer.toUpperCase()}', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: titleGreen)), 
                  pw.Text('SELLER : ${sellerFilter.isNotEmpty ? sellerFilter.toUpperCase() : "ALL SELLERS"}', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: titleGreen))
                ],
              ),
            ), 
            pw.SizedBox(height: 5),
            pw.Container(
              decoration: const pw.BoxDecoration(border: pw.Border.fromBorderSide(pw.BorderSide(color: greenBorder, width: 1))),
              child: pw.Table(
                columnWidths: const {0: pw.FlexColumnWidth(1.8), 1: pw.FlexColumnWidth(3.0), 2: pw.FlexColumnWidth(1.8), 3: pw.FlexColumnWidth(2.0), 4: pw.FlexColumnWidth(4.5), 5: pw.FlexColumnWidth(2.0)},
                border: const pw.TableBorder(horizontalInside: pw.BorderSide(color: greenBorder, width: 1), verticalInside: pw.BorderSide(color: greenBorder, width: 1)),
                children: [
                  pw.TableRow(decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF2F7F3)), children: [pw.Padding(padding: const pw.EdgeInsets.all(3.5), child: pw.Text('DATE', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))), pw.Padding(padding: const pw.EdgeInsets.all(3.5), child: pw.Text('SELLER', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))), pw.Padding(padding: const pw.EdgeInsets.all(3.5), child: pw.Text('QTY (NUTS)', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))), pw.Padding(padding: const pw.EdgeInsets.all(3.5), child: pw.Text('BILL', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))), pw.Padding(padding: const pw.EdgeInsets.all(3.5), child: pw.Text('PAID WITH DATE & BANK / DIRECT', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))), pw.Padding(padding: const pw.EdgeInsets.all(3.5), child: pw.Text('BALANCE', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)))]),
                  ...rows.map((row) {
                    final List<dynamic> pList = row['payments'] as List<dynamic>;
                    String paidText = pList.isEmpty
    ? '-'
    : pList.map((p) {
        final dt = formatDisplayDate(p.date);
        if (p.amount == 0 && p.settlement > 0) {
          return "Rs. ${pdfMoney(p.settlement)} (SETTLEMENT on $dt)";
        }
        if (p.amount > 0 && p.settlement > 0) {
          return "Rs. ${pdfMoney(p.amount)} (${p.mode}) + Rs. ${pdfMoney(p.settlement)} (SETTLEMENT) on $dt";
        }
        return "Rs. ${pdfMoney(p.amount)} (${p.mode} on $dt)";
      }).join('\n');
                    return pw.TableRow(children: [pw.Padding(padding: const pw.EdgeInsets.all(3.5), child: pw.Text(row['date'], style: const pw.TextStyle(fontSize: 8))), pw.Padding(padding: const pw.EdgeInsets.all(3.5), child: pw.Text(row['seller'] ?? '-', style: const pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))), pw.Padding(padding: const pw.EdgeInsets.all(3.5), child: pw.Text('${row['qty']} NUTS', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8))), pw.Padding(padding: const pw.EdgeInsets.all(3.5), child: pw.Text('Rs. ${pdfMoney(row['billAmount'])}', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))), pw.Padding(padding: const pw.EdgeInsets.all(3.5), child: pw.Text(paidText, style: pw.TextStyle(fontSize: 7.5, color: titleGreen, fontWeight: pw.FontWeight.bold))), pw.Padding(padding: const pw.EdgeInsets.all(3.5), child: pw.Text(row['balance'].replaceAll('₹', 'Rs. '), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)))]);
                  }),
                  pw.TableRow(decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFEBF5EE)), children: [pw.Padding(padding: const pw.EdgeInsets.all(3.5), child: pw.Text('TOTAL', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: titleGreen))), pw.Padding(padding: const pw.EdgeInsets.all(3.5), child: pw.Text('-', style: const pw.TextStyle(fontSize: 8))), pw.Padding(padding: const pw.EdgeInsets.all(3.5), child: pw.Text('${numFmt(totalQty)} NUTS', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: titleGreen))), pw.Padding(padding: const pw.EdgeInsets.all(3.5), child: pw.Text('Rs. ${pdfMoney(totalBilled)}', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: titleGreen))), pw.Padding(padding: const pw.EdgeInsets.all(3.5), child: pw.Text('Rs. ${pdfMoney(totalPaid)}', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: titleGreen))), pw.Padding(padding: const pw.EdgeInsets.all(3.5), child: pw.Text('Rs. ${pdfMoney(balanceDue)}', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: titleGreen)))]),
                ],
              ),
            ),
            pw.Spacer(),
            pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 3), child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Customer Signature', style: const pw.TextStyle(fontSize: 8.5)),pw.Text(
  'For ${_myCompany.statementName.isNotEmpty ? _myCompany.statementName : _myCompany.name}', 
  style: const pw.TextStyle(fontSize: 8.5),
)]))
          ],
        ),
      ),
    ));
    return pdf.save();
  }

  
  void _showStorageSettingsDialog() {
    _cNameCtrl.text = _companyName;
    _cPhoneCtrl.text = _companyPhone;
    _cAddressCtrl.text = _companyAddress;
    _cTaglineCtrl.text = _myCompany.tagline;
    _sellerMsgCtrl.text = _sellerMsgTemplate;
    _buyerMsgCtrl.text = _buyerMsgTemplate;
    _cInvocationCtrl.text = _myCompany.invocation;
    final invocationCtrl = TextEditingController(text: _myCompany.invocation);

    bool isSyncing = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSettingsState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.settings_outlined, color: Color(0xFF047857)),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'ERP Settings',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: MediaQuery.of(context).size.width * 0.92,
              height: MediaQuery.of(context).size.height * 0.70,
              child: DefaultTabController(
                length: 6, // Length is set to 6
                child: Column(
                  children: [
                    const TabBar(
  isScrollable: true,
  labelColor: const Color(0xFF047857),
  unselectedLabelColor: const Color(0xFF64748B),
  indicatorColor: const Color(0xFF047857),
  tabs: const [
    Tab(text: 'Security'),
    Tab(text: 'Bank Accounts'),
    Tab(text: 'SMS Templates'),
    Tab(text: 'Letterhead'),
    Tab(text: 'Data & Backup'),
    Tab(text: 'Fin. Year'),
  ],
),
                    const SizedBox(height: 14),
                    Expanded(
                      child: TabBarView(
                        children: [
                          // 1. Security Tab
                          SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _customField('Update Email', _settingsEmailCtrl, hint: _savedEmail),
                                const SizedBox(height: 12),
                                _customField('Update Master Password', _settingsPassCtrl, hint: _savedPassword),
                                const SizedBox(height: 12),
                                _customField('Update 4-Digit PIN', _settingsPinCtrl, hint: _savedPin, isNum: true),
                                const SizedBox(height: 20),
                                FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF047857),
                                    minimumSize: const Size(double.infinity, 44),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onPressed: () async {
                                    final newEmail = _settingsEmailCtrl.text.trim();
                                    final newPass = _settingsPassCtrl.text.trim();
                                    final newPin = _settingsPinCtrl.text.trim();
                                    final prefs = await SharedPreferences.getInstance();
                                    if (newPin.isNotEmpty && newPin.length == 4) {
                                      await prefs.setString(_prefPinKey, newPin);
                                      setState(() => _savedPin = newPin);
                                    }
                                    if (newEmail.isNotEmpty) {
                                      await prefs.setString(_prefEmailKey, newEmail);
                                      setState(() => _savedEmail = newEmail);
                                    }
                                    if (newPass.isNotEmpty) {
                                  await prefs.setString(_prefPassKey, newPass);
                                  setState(() => _savedPassword = newPass);
                                }
                                
                                // INSTANTLY SYNC NEW PIN TO FIREBASE
                                _commitToLocalDrive();

                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(backgroundColor: Color(0xFF047857), content: Text('Credentials Updated & Synced!')),
                                );
                              },
                              child: const Text('Save Credentials'),
                                ),
                              ],
                            ),
                          ),

                          // 2. Bank Accounts Tab (CLEAN RESPONSIVE CARDS)
                          SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Expanded(
                                      child: Text(
                                        'Company Bank Accounts',
                                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5, color: Color(0xFF0F172A)),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    FilledButton.icon(
                                      style: FilledButton.styleFrom(
                                        backgroundColor: const Color(0xFF047857),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        minimumSize: const Size(0, 32),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      icon: const Icon(Icons.add, size: 14),
                                      label: const Text('Add Bank', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                                      onPressed: () => _showAddEditBankDialog(onSaved: () => setSettingsState(() {})),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                ..._bankAccounts.map((bank) {
                                  final bool isSelected = _selectedBank.id == bank.id;
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isSelected ? const Color(0xFFF0FDF4) : Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSelected ? const Color(0xFF047857) : const Color(0xFFE2E8F0),
                                        width: isSelected ? 1.5 : 1,
                                      ),
                                      boxShadow: const [BoxShadow(color: Color(0x05000000), blurRadius: 4, offset: Offset(0, 2))],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Header: Icon + Bank Name + Active Badge
                                        Row(
                                          children: [
                                            Icon(Icons.account_balance_rounded, size: 18, color: isSelected ? const Color(0xFF047857) : const Color(0xFF64748B)),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                bank.name,
                                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF0F172A)),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (isSelected)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(color: const Color(0xFF047857), borderRadius: BorderRadius.circular(4)),
                                                child: const Text('ACTIVE', style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w900)),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                        const SizedBox(height: 8),

                                        // Body: Full-width Account details
                                        Text('A/c: ${bank.account}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                                        const SizedBox(height: 2),
                                        Text('IFSC: ${bank.ifsc}  •  Branch: ${bank.branch}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                        const SizedBox(height: 8),

                                        // Footer: Action Buttons Row
                                        Row(
                                          children: [
                                            if (!isSelected)
                                              OutlinedButton.icon(
                                                style: OutlinedButton.styleFrom(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  minimumSize: const Size(0, 28),
                                                  side: const BorderSide(color: Color(0xFF047857)),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                                ),
                                                icon: const Icon(Icons.check_circle_outline, size: 13, color: Color(0xFF047857)),
                                                label: const Text('Set Active', style: TextStyle(fontSize: 11, color: Color(0xFF047857), fontWeight: FontWeight.bold)),
                                                onPressed: () {
                                                  setState(() => _selectedBank = bank);
                                                  setSettingsState(() {});
                                                  _commitToLocalDrive();
                                                },
                                              ),
                                            const Spacer(),
                                            IconButton(
                                              padding: const EdgeInsets.all(4),
                                              constraints: const BoxConstraints(),
                                              icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF047857)),
                                              tooltip: 'Edit',
                                              onPressed: () => _showAddEditBankDialog(account: bank, onSaved: () => setSettingsState(() {})),
                                            ),
                                            if (_bankAccounts.length > 1) ...[
                                              const SizedBox(width: 8),
                                              IconButton(
                                                padding: const EdgeInsets.all(4),
                                                constraints: const BoxConstraints(),
                                                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                                tooltip: 'Delete',
                                                onPressed: () {
                                                  setState(() {
                                                    _bankAccounts.remove(bank);
                                                    if (_selectedBank.id == bank.id) _selectedBank = _bankAccounts.first;
                                                  });
                                                  setSettingsState(() {});
                                                  _commitToLocalDrive();
                                                },
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),

                          // 3. SMS Templates Tab
                          SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Available Tags: {date}, {seller}, {buyer}, {type}, {rate}, {company}',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                                ),
                                const SizedBox(height: 12),
                                _customField('Seller Confirmation Template', _sellerMsgCtrl, maxLines: 4),
                                const SizedBox(height: 12),
                                _customField('Buyer Confirmation Template', _buyerMsgCtrl, maxLines: 4),
                                const SizedBox(height: 16),
                                FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF047857),
                                    minimumSize: const Size(double.infinity, 44),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onPressed: () async {
                                    final prefs = await SharedPreferences.getInstance();
                                    await prefs.setString('sms_seller_template', _sellerMsgCtrl.text.trim());
                                    await prefs.setString('sms_buyer_template', _buyerMsgCtrl.text.trim());
                                    setState(() {
                                      _sellerMsgTemplate = _sellerMsgCtrl.text.trim();
                                      _buyerMsgTemplate = _buyerMsgCtrl.text.trim();
                                    });
                                    Navigator.pop(ctx);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        backgroundColor: Color(0xFF047857),
                                        content: Text('Message templates saved successfully!'),
                                      ),
                                    );
                                  },
                                  child: const Text('Save Templates'),
                                ),
                              ],
                            ),
                          ),

                          // Inside the 4th Tab (Letterhead) in _showStorageSettingsDialog():
SingleChildScrollView(
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Edit Business Profile & Letterhead', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
      const SizedBox(height: 12),
      _customField('Invoice Header Name (Company Name for Invoices)', _cNameCtrl),
      const SizedBox(height: 12),
      _customField('Statement Header Name (Company Name for Buyer/Seller Statements)', _cStatementNameCtrl..text = _myCompany.statementName),
      const SizedBox(height: 12),
      _customField('Address', _cAddressCtrl, maxLines: 2),
      const SizedBox(height: 12),
      _customField('Contact (Phone Numbers)', _cPhoneCtrl),
      const SizedBox(height: 12),
      _customField('Tagline / Subtitle', _cTaglineCtrl),
      const SizedBox(height: 12),
      _customField('Top Invocation', invocationCtrl),
      const SizedBox(height: 20),
      FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF047857),
          minimumSize: const Size(double.infinity, 46),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: () async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('company_name', _cNameCtrl.text.trim());
          await prefs.setString('company_statement_name', _cStatementNameCtrl.text.trim());
          await prefs.setString('company_phone', _cPhoneCtrl.text.trim());
          await prefs.setString('company_address', _cAddressCtrl.text.trim());
          await prefs.setString('company_tagline', _cTaglineCtrl.text.trim());
          await prefs.setString('company_invocation', invocationCtrl.text.trim());
          
          setState(() {
            _companyName = _cNameCtrl.text.trim();
            _myCompany.name = _companyName;
            _myCompany.statementName = _cStatementNameCtrl.text.trim();
            _myCompany.tagline = _cTaglineCtrl.text.trim();
            _myCompany.phone = _cPhoneCtrl.text.trim();
            _myCompany.address = _cAddressCtrl.text.trim();
            _myCompany.invocation = invocationCtrl.text.trim();
          });
          _commitToLocalDrive();
          Navigator.pop(ctx);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(backgroundColor: Color(0xFF047857), content: Text('Headers and profile updated successfully!')),
          );
        },
        child: const Text('Save Letterhead Profile'),
      ),
      if (!kIsWeb && Platform.isWindows) ...[
        const SizedBox(height: 16),
        const Text('WINDOWS PDF SAVE DESTINATION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF64748B), letterSpacing: 0.8)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE2E8F0))),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _customPdfSaveDir?.isNotEmpty == true ? _customPdfSaveDir! : 'Default (Documents\\CocoTrade_PDFs)',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE2E8F0)),
                icon: const Icon(Icons.folder_open, size: 16),
                label: const Text('Change Folder', style: TextStyle(fontSize: 11.5)),
                onPressed: () async {
              final String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
              if (selectedDirectory != null) {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('custom_pdf_save_dir', selectedDirectory);
                    setState(() => _customPdfSaveDir = selectedDirectory);
                    setSettingsState(() {});
                  }
                },
              ),
            ],
          ),
        ),
      ],
    ],
  ),
),

                          // 5. Data & Backup Tab
SingleChildScrollView(
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: _syncHealthStatus == 'CONNECTED'
                                        ? const Color(0xFFECFDF5)
                                        : (_syncHealthStatus == 'QUEUED' ? const Color(0xFFFFFBEB) : const Color(0xFFFEF2F2)),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: _syncHealthStatus == 'CONNECTED'
                                          ? const Color(0xFFA7F3D0)
                                          : (_syncHealthStatus == 'QUEUED' ? const Color(0xFFFDE68A) : const Color(0xFFFECACA)),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        _syncHealthStatus == 'CONNECTED'
                                            ? Icons.cloud_done_rounded
                                            : (_syncHealthStatus == 'QUEUED' ? Icons.cloud_queue_rounded : Icons.cloud_off_rounded),
                                        color: _syncHealthStatus == 'CONNECTED'
                                            ? const Color(0xFF047857)
                                            : (_syncHealthStatus == 'QUEUED' ? const Color(0xFFD97706) : const Color(0xFFDC2626)),
                                        size: 24,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _syncHealthStatus == 'CONNECTED'
                                                  ? 'Firebase Cloud Live Synced'
                                                  : (_syncHealthStatus == 'QUEUED' ? 'Offline: Changes Queued Locally' : 'Sync Error / Network Reconnecting'),
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                                color: _syncHealthStatus == 'CONNECTED'
                                                    ? const Color(0xFF047857)
                                                    : (_syncHealthStatus == 'QUEUED' ? const Color(0xFFB45309) : const Color(0xFFDC2626)),
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Status: $_syncHealthLabel • Last Commit: $_lastSyncTime',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: _syncHealthStatus == 'CONNECTED'
                                                    ? const Color(0xFF065F46)
                                                    : (_syncHealthStatus == 'QUEUED' ? const Color(0xFF92400E) : const Color(0xFF991B1B)),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
      const SizedBox(height: 20),
      const Text(
        'LOCAL DATABASE BACKUP & RESTORE',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF64748B), letterSpacing: 0.8),
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF047857),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.download_rounded, size: 16),
              label: const Text('Export Backup File'),
              onPressed: () async {
                try {
                  final nowStr = DateTime.now().toIso8601String().split('T')[0];
                  final fullJson = _generateFullDatabaseJson();
                  final encrypted = SecurityHelper.encrypt(fullJson);

                  final String? savePath = await FilePicker.platform.saveFile(
                dialogTitle: 'Save Backup',
                fileName: 'cocotrade_backup_$nowStr.secure',
              );

              if (savePath != null) {
                final file = File(savePath);
                    await file.writeAsString(encrypted, flush: true);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: const Color(0xFF047857),
                          content: Text('Backup exported to ${file.path}'),
                        ),
                      );
                    }
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(backgroundColor: Colors.red, content: Text('Export failed: $e')),
                  );
                }
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                side: const BorderSide(color: Color(0xFF047857)),
              ),
              icon: const Icon(Icons.file_open_rounded, size: 16, color: Color(0xFF047857)),
              label: const Text('Restore from File', style: TextStyle(color: Color(0xFF047857))),
              onPressed: () async {
                try {
              final FilePickerResult? result = await FilePicker.platform.pickFiles(
                type: FileType.custom,
                allowedExtensions: ['secure', 'json'],
              );

              if (result != null && result.files.single.path != null) {
                final file = File(result.files.single.path!);
                final rawContent = await file.readAsString();
                    Map<String, dynamic> dataToApply;
                    try {
                      final decrypted = SecurityHelper.decrypt(rawContent);
                      dataToApply = jsonDecode(decrypted);
                    } catch (_) {
                      dataToApply = jsonDecode(rawContent);
                    }

                    _applyStateFromMap(dataToApply);
                    await LocalDriveManager.writeToDrive(dataToApply);
                    await _commitToLocalDrive(); // Re-syncs restored database to Firestore
                    if (mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          backgroundColor: Color(0xFF047857),
                          content: Text('Database restored and synced across all devices!'),
                        ),
                      );
                    }
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(backgroundColor: Colors.red, content: Text('Restore failed: $e')),
                  );
                }
              },
            ),
          ),
        ],
      ),
    ],
  ),
),

                          // 6. Financial Year Tab
                          SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Switch Active Accounting Year', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                                const SizedBox(height: 10),
                                Container(
                                  height: 44,
                                  padding: const EdgeInsets.symmetric(horizontal: 14),
                                  decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE2E8F0)), borderRadius: BorderRadius.circular(10)),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _selectedFinancialYear,
                                      isExpanded: true,
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                      items: _financialYears.map((fy) => DropdownMenuItem(value: fy, child: Text('FY $fy'))).toList(),
                                      onChanged: (val) {
                                        if (val != null) {
                                          _carryForwardFinancialYearBalances(val);
                                          Navigator.pop(ctx);
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
 Widget _customField(String label, TextEditingController ctrl, {String hint = '', bool isNum = false, bool readOnly = false, IconData? icon, VoidCallback? onTap, ValueChanged<String>? onChanged, ValueChanged<String>? onSubmitted, int? maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label.isNotEmpty) ...[
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
          const SizedBox(height: 5),
        ],
        SizedBox(
          height: (maxLines ?? 1) > 1 ? null : 40,
          child: TextField(
            controller: ctrl, readOnly: readOnly, onTap: onTap, onChanged: onChanged, onSubmitted: onSubmitted, maxLines: maxLines,
            scrollPadding: const EdgeInsets.only(bottom: 80),
            keyboardType: isNum ? TextInputType.number : TextInputType.text,
            inputFormatters: isNum ? [] : [UpperCaseTextFormatter()],
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            decoration: InputDecoration(
              hintText: hint, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              suffixIcon: icon != null ? Icon(icon, size: 18, color: const Color(0xFF64748B)) : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF047857), width: 1.5)),
              filled: true, fillColor: readOnly ? const Color(0xFFF8FAFC) : Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _customAutocomplete(
    String label,
    List<String> options,
    String currentValue,
    String hint,
    ValueChanged<String> onSelected, {
    FocusNode? focusNode,
    FocusNode? nextFocusNode,
    VoidCallback? onAddPressed,
    void Function(String)? onAddNewNamed,
  }) {
    void Function(String)? effectiveAddNew = onAddNewNamed;
    if (effectiveAddNew == null) {
      String pType = 'BUYER';
      final lUpper = label.toUpperCase();
      if (lUpper.contains('SELLER') || lUpper.contains('SUPPLIER')) {
        pType = 'SELLER';
      } else if (lUpper.contains('TRANSPORTER')) {
        pType = 'TRANSPORTER';
      }
      effectiveAddNew = (String typedName) {
        _showAddPartyDialog(
          initialName: typedName,
          initialType: pType,
          onCreated: (createdName) {
            onSelected(createdName);
            if (nextFocusNode != null) {
              FocusScope.of(context).requestFocus(nextFocusNode);
            }
          },
        );
      };
    }

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
              if (onAddPressed != null)
                InkWell(
                  onTap: onAddPressed,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Text('+ Add New', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF047857))),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => _openMobileSearchPicker(
              title: label,
              hint: hint,
              options: options,
              currentValue: currentValue,
              onSelected: (val) {
                onSelected(val);
                if (nextFocusNode != null) {
                  FocusScope.of(context).requestFocus(nextFocusNode);
                }
              },
              onAddNewNamed: effectiveAddNew,
            ),
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      currentValue.isNotEmpty ? currentValue : hint,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: currentValue.isNotEmpty ? FontWeight.bold : FontWeight.normal,
                        color: currentValue.isNotEmpty ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (currentValue.isNotEmpty)
                    InkWell(
                      onTap: () => onSelected(''),
                      child: const Padding(
                        padding: EdgeInsets.all(4.0),
                        child: Icon(Icons.clear, size: 16, color: Color(0xFF94A3B8)),
                      ),
                    )
                  else
                    const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // DESKTOP: Named parameters call
    return _CustomAutocompleteField(
      label: label,
      optionsList: options,
      currentVal: currentValue,
      hint: hint,
      onSelect: onSelected,
      onAddPressed: onAddPressed,
      onAddNewNamed: effectiveAddNew,
      focusNode: focusNode,
      nextFocusNode: nextFocusNode,
    );
  }

  void _openMobileSearchPicker({
    required String title,
    required String hint,
    required List<String> options,
    required String currentValue,
    required ValueChanged<String> onSelected,
    void Function(String)? onAddNewNamed,
  }) {
    final TextEditingController searchController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final String query = searchController.text.trim().toUpperCase();
            final filtered = query.isEmpty
                ? options
                : options.where((o) => o.toUpperCase().contains(query)).toList();
            final bool hasExactMatch = options.any((o) => o.trim().toUpperCase() == query);
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;

            return AnimatedPadding(
              padding: EdgeInsets.only(bottom: bottomInset),
              duration: const Duration(milliseconds: 100),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.70,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 12),
                    Center(
                      child: Container(
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Text(
                        title.toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF0F172A), letterSpacing: 0.5),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: TextField(
                          controller: searchController,
                          autofocus: true,
                          inputFormatters: [UpperCaseTextFormatter()],
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Search or type new $title...',
                            hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5),
                            prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B), size: 18),
                            suffixIcon: searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 16, color: Color(0xFF94A3B8)),
                                    onPressed: () {
                                      searchController.clear();
                                      setModalState(() {});
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          onChanged: (_) => setModalState(() {}),
                          onSubmitted: (val) {
                            final q = val.trim().toUpperCase();
                            if (q.isEmpty) return;
                            Navigator.pop(ctx);
                            final match = options.firstWhere((o) => o.trim().toUpperCase() == q, orElse: () => '');
                            if (match.isNotEmpty) {
                              onSelected(match);
                            } else if (onAddNewNamed != null) {
                              onAddNewNamed(q);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        children: [
                          if (query.isNotEmpty && !hasExactMatch && onAddNewNamed != null)
                            ListTile(
                              dense: true,
                              tileColor: const Color(0xFFECFDF5),
                              leading: const Icon(Icons.add_circle_outline, color: Color(0xFF047857), size: 20),
                              title: Text('+ Add "$query"', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF047857), fontSize: 13)),
                              onTap: () {
                                Navigator.pop(ctx);
                                onAddNewNamed(query);
                              },
                            ),
                          if (filtered.isEmpty && (query.isEmpty || hasExactMatch))
                            Container(
                              padding: const EdgeInsets.all(24),
                              alignment: Alignment.center,
                              child: const Text('No matches found', style: TextStyle(color: Color(0xFF94A3B8), fontStyle: FontStyle.italic)),
                            )
                          else
                            ...filtered.map((item) {
                              final isSelected = item.toUpperCase() == currentValue.toUpperCase();
                              return ListTile(
                                dense: true,
                                title: Text(
                                  item,
                                  style: TextStyle(
                                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                                    color: isSelected ? const Color(0xFF047857) : const Color(0xFF1E293B),
                                  ),
                                ),
                                trailing: isSelected ? const Icon(Icons.check_circle, color: Color(0xFF047857), size: 18) : null,
                                onTap: () {
                                  onSelected(item);
                                  Navigator.pop(ctx);
                                },
                              );
                            }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
 // ---------------- WHITE FROSTED GLASS PIN LOCK SCREEN ----------------
  Widget _buildPinLockScreen() {
    final String activeStatementName = _myCompany.statementName.trim().isNotEmpty
        ? _myCompany.statementName.trim().toUpperCase()
        : _companyName.trim().toUpperCase();

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Stack(
        children: [
          // 1. Ghost Dashboard Background (Rendered in natural light tones)
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.55,
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      _buildExecutiveHeader(),
                      const SizedBox(height: 16),
                      _buildSyncHealthBadge(),
                      const SizedBox(width: 8),
                      _buildDashboardView(),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 2. Pure White Frosted Glass Blur Overlay
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withOpacity(0.75),
                      const Color(0xFFF8FAFC).withOpacity(0.85),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 3. Central Authentication Card
          Center(
            child: SingleChildScrollView(
              child: Container(
                width: 400,
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 38),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 30,
                      offset: Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Brand Shield Icon
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFECFDF5), Color(0xFFD1FAE5)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFA7F3D0), width: 1.5),
                        boxShadow: const [
                          BoxShadow(color: Color(0x14047857), blurRadius: 14, offset: Offset(0, 5)),
                        ],
                      ),
                      child: const Icon(Icons.shield_outlined, size: 38, color: Color(0xFF047857)),
                    ),
                    const SizedBox(height: 20),

                    // 1st Row: WELCOME
                    const Text(
                      'WELCOME',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.5,
                        color: Color(0xFF047857),
                      ),
                    ),
                    const SizedBox(height: 4),

                    // 2nd Row: STATEMENT NAME (DEEPAK PAREKH)
                    Text(
                      activeStatementName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Enter your 4-digit PIN to enter dashboard',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 26),

                    // PIN Input Field
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: TextField(
  controller: _pinCtrl,
  obscureText: true,
  maxLength: 4,
  autofocus: true,
  keyboardType: TextInputType.number,
  textAlign: TextAlign.center,
  style: const TextStyle(
    fontSize: 32,
    letterSpacing: 18,
    fontWeight: FontWeight.w900,
    color: Color(0xFF0F172A),
  ),
  decoration: const InputDecoration(
    counterText: "",
    hintText: "••••",
    hintStyle: TextStyle(letterSpacing: 18, color: Color(0xFF94A3B8)),
    border: InputBorder.none,
  ),
  onChanged: (val) {
    if (val.length == 4) {
      if (val == _savedPin) {
        setState(() {
          _isLocked = false;
        });
        _pinCtrl.clear();
      } else {
        _pinCtrl.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.red,
            content: Text('Incorrect PIN! Please try again.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  },
  onSubmitted: (val) {
    if (val == _savedPin) {
      setState(() {
        _isLocked = false;
      });
      _pinCtrl.clear();
    } else {
      _pinCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text('Incorrect PIN! Please try again.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  },
),
                    ),
                    const SizedBox(height: 20),

                    // Master Account Recovery Link
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF64748B),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onPressed: () => setState(() => _forceEmailLogin = true),
                      icon: const Icon(Icons.vpn_key_outlined, size: 16),
                      label: const Text(
                        'Login with Master Account',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFirstTimeEmailLoginScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Clean light slate
      body: Center(
        child: Container(
          width: 440,
          padding: const EdgeInsets.all(36),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 28, offset: Offset(0, 10))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: Column(
                  children: [
                    Icon(Icons.admin_panel_settings_rounded, size: 48, color: Color(0xFF047857)),
                    SizedBox(height: 12),
                    Text('CocoTrade Authentication', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                    SizedBox(height: 6),
                    Text('Enter your credentials or active license key', style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              _customField('Customer Email', _loginEmailCtrl),
              const SizedBox(height: 12),
              _customField('License Key', _licenseKeyCtrl),
              const SizedBox(height: 12),
              _customField('Password', _loginPassCtrl),
              const SizedBox(height: 24),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF047857), minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: () async {
                  final email = _loginEmailCtrl.text.trim();
                  final licKey = _licenseKeyCtrl.text.trim().toUpperCase();
                  if (_verifyLicenseKey(email, licKey) || (email.toLowerCase() == _savedEmail.toLowerCase() && _loginPassCtrl.text.trim() == _savedPassword)) {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool(_prefFirstLoginKey, true);
                    await prefs.setBool(_prefIsLicensedKey, true);
                    setState(() {
                      _isFirstLoginDone = true;
                      _isLicensed = true;
                      _isLocked = false;
                      _forceEmailLogin = false;
                    });
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.red, content: Text('Invalid License Key or Login!')));
                  }
                },
                child: const Text('Verify & Secure Login', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
              if (!_isLicensed && !_isTrialExpired) ...[
                const SizedBox(height: 12),
                Center(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF047857)), minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: () async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool(_prefFirstLoginKey, true);
                      setState(() {
                        _isFirstLoginDone = true;
                        _forceEmailLogin = false;
                        _isLocked = false;
                      });
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: const Color(0xFF047857), content: Text('Free Trial Active! $_trialDaysLeft days remaining.')));
                    },
                    child: Text('Start 2-Day Free Trial ($_trialDaysLeft days left)', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF047857))),
                  ),
                ),
              ],
              if (_isFirstLoginDone && _isLicensed)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: TextButton.icon(
                      onPressed: () => setState(() => _forceEmailLogin = false),
                      icon: const Icon(Icons.pin, size: 16, color: Color(0xFF047857)),
                      label: const Text('Back to PIN Unlock', style: TextStyle(color: Color(0xFF047857), fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompanyProfileScreen() {
    final nameCtrl = TextEditingController(text: _companyName);
    final phoneCtrl = TextEditingController(text: _companyPhone);
    final addrCtrl = TextEditingController(text: _companyAddress);
    return Scaffold(
      backgroundColor: const Color(0xFF081C15),
      body: Center(
        child: Container(
          width: 440,
          padding: const EdgeInsets.all(36),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 28, offset: Offset(0, 10))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Setup Business Profile', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
              const SizedBox(height: 8),
              const Text('This will appear on your tax invoices', style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
              const SizedBox(height: 24),
              _customField('Business Name', nameCtrl),
              const SizedBox(height: 12),
              _customField('Phone', phoneCtrl),
              const SizedBox(height: 12),
              _customField('Address', addrCtrl, maxLines: 2),
              const SizedBox(height: 24),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF047857), minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('is_profile_setup_done', true);
                  await prefs.setString('company_name', nameCtrl.text.trim());
                  await prefs.setString('company_phone', phoneCtrl.text.trim());
                  await prefs.setString('company_address', addrCtrl.text.trim());
                  setState(() {
                    _companyName = nameCtrl.text.trim();
                    _companyPhone = phoneCtrl.text.trim();
                    _companyAddress = addrCtrl.text.trim();
                    _isProfileSetupDone = true;
                  });
                },
                child: const Text('Save Profile & Enter ERP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            ],
          ),
        ),
      ),
    );
  }
} // Closes _MainLayoutScreenState
// ---------------------------------------------------------------------------
// FLUID NEO-FINTECH APP CONTAINER (WINDOWS & ANDROID RESPONSIVE)
// ---------------------------------------------------------------------------
class NeoScaffold extends StatelessWidget {
  final Widget body;
  final String activeTab;
  final Function(String) onTabChanged;
  final VoidCallback onLock;
  final VoidCallback onSettings;
  final String activeState;
  final Function(String) onStateChanged;
  final String financialYear;
  final String syncHealthStatus;
  final String syncHealthLabel;

  const NeoScaffold({
    super.key,
    required this.body,
    required this.activeTab,
    required this.onTabChanged,
    required this.onLock,
    required this.onSettings,
    required this.activeState,
    required this.onStateChanged,
    required this.financialYear,
    this.syncHealthStatus = 'CONNECTED',
    this.syncHealthLabel = 'Live Synced',
  });

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 960;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Stack(
        children: [
          // 1. Ambient Background Glow Accents
          Positioned(
            top: -120,
            right: -100,
            child: Container(
              width: 380,
              height: 380,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF10B981).withOpacity(0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -150,
            left: 200,
            child: Container(
              width: 450,
              height: 450,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF047857).withOpacity(0.05),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // 2. Primary Layout Switcher
          isMobile
              ? SafeArea(
                  child: Column(
                    children: [
                      _buildMobileTopBar(context),
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: body,
                        ),
                      ),
                    ],
                  ),
                )
              : Row(
                  children: [
                    _buildDesktopSidebar(),
                    Expanded(
                      child: Column(
                        children: [
                          _buildDesktopTopBar(),
                          Expanded(
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
                              child: body,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ],
      ),
      bottomNavigationBar: isMobile ? _buildMobileBottomNav() : null,
    );
  }

  // ---------------- DESKTOP FLOATING TOPBAR ----------------
  Widget _buildDesktopTopBar() {
return LayoutBuilder(
  builder: (context, constraints) {
    final bool isCompact = constraints.maxWidth < 950;
    
    return Container(
      height: 64,
      margin: const EdgeInsets.fromLTRB(28, 18, 28, 0),
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 10 : 18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                activeTab.toUpperCase(),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                  letterSpacing: 0.5,
                ),
              ),
              if (!isCompact) ...[
                const SizedBox(width: 14),
                Container(
                  height: 16,
                  width: 1.2,
                  color: const Color(0xFFCBD5E1),
                ),
                const SizedBox(width: 14),
                const Text(
                  'LIVE COMMERCE & AUDIT SUITE v2.2',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ],
          ),
          Row(
            children: [
              // Segmented State Pill
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    _buildPillItem("Andhra Pradesh", isCompact: isCompact),
                    _buildPillItem("Tamil Nadu", isCompact: isCompact),
                  ],
                ),
              ),
              SizedBox(width: isCompact ? 8 : 12),
              // Live Sync Health Badge
              if (!isCompact)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: syncHealthStatus == 'CONNECTED'
                        ? const Color(0xFFECFDF5)
                        : (syncHealthStatus == 'QUEUED' ? const Color(0xFFFFFBEB) : const Color(0xFFFEF2F2)),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: syncHealthStatus == 'CONNECTED'
                          ? const Color(0xFFA7F3D0)
                          : (syncHealthStatus == 'QUEUED' ? const Color(0xFFFDE68A) : const Color(0xFFFECACA)),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: syncHealthStatus == 'CONNECTED'
                              ? const Color(0xFF047857)
                              : (syncHealthStatus == 'QUEUED' ? const Color(0xFFD97706) : const Color(0xFFDC2626)),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        syncHealthLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: syncHealthStatus == 'CONNECTED'
                              ? const Color(0xFF047857)
                              : (syncHealthStatus == 'QUEUED' ? const Color(0xFFB45309) : const Color(0xFFDC2626)),
                        ),
                      ),
                    ],
                  ),
                )
              else
                // Compact Sync Badge (Just the dot)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: syncHealthStatus == 'CONNECTED'
                        ? const Color(0xFFECFDF5)
                        : (syncHealthStatus == 'QUEUED' ? const Color(0xFFFFFBEB) : const Color(0xFFFEF2F2)),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: syncHealthStatus == 'CONNECTED'
                          ? const Color(0xFFA7F3D0)
                          : (syncHealthStatus == 'QUEUED' ? const Color(0xFFFDE68A) : const Color(0xFFFECACA)),
                    ),
                  ),
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: syncHealthStatus == 'CONNECTED'
                          ? const Color(0xFF047857)
                          : (syncHealthStatus == 'QUEUED' ? const Color(0xFFD97706) : const Color(0xFFDC2626)),
                    ),
                  ),
                ),
              SizedBox(width: isCompact ? 8 : 10),
              // FY Badge
              Container(
                padding: EdgeInsets.symmetric(horizontal: isCompact ? 8 : 12, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.date_range_rounded, size: 13, color: Color(0xFF047857)),
                    if (!isCompact) const SizedBox(width: 6),
                    if (!isCompact)
                      Text(
                        'FY $financialYear',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF047857),
                        ),
                      ),
                  ],
                ),
              ),
              
              SizedBox(width: isCompact ? 6 : 10),
              IconButton.filledTonal(
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFF1F5F9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.settings_outlined, size: 17, color: Color(0xFF0F172A)),
                onPressed: onSettings,
              ),
              const SizedBox(width: 6),
              IconButton.filledTonal(
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFFEE2E2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.lock_outline_rounded, size: 17, color: Color(0xFFDC2626)),
                onPressed: onLock,
              ),
            ],
          ),
        ],
      ),
    );
  },
);
}
  Widget _buildPillItem(String title, {bool isCompact = false}) {
final bool active = activeState == title;
final String displayTitle = isCompact 
    ? (title == "Andhra Pradesh" ? "AP" : (title == "Tamil Nadu" ? "TN" : title)) 
    : title;
    
return GestureDetector(
  onTap: () => onStateChanged(title),
  child: AnimatedContainer(
    duration: const Duration(milliseconds: 140),
    padding: EdgeInsets.symmetric(horizontal: isCompact ? 10 : 12, vertical: 6),
    decoration: BoxDecoration(
      color: active ? const Color(0xFF047857) : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      displayTitle,
      style: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.bold,
        color: active ? Colors.white : const Color(0xFF64748B),
      ),
    ),
  ),
);
}

  // ---------------- DESKTOP EXPANDABLE GLASS SIDEBAR ----------------
  Widget _buildDesktopSidebar() {
    return Container(
      width: 230,
      margin: const EdgeInsets.fromLTRB(18, 18, 0, 18),
      decoration: BoxDecoration(
        color: const Color(0xFF062317),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A047857),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Brand Block
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF10B981), Color(0xFF047857)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: const [
                      BoxShadow(color: Color(0x3310B981), blurRadius: 10, offset: Offset(0, 3)),
                    ],
                  ),
                  child: const Icon(Icons.eco_rounded, color: Colors.white, size: 19),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'COCOTRADE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                    ),
                    Text(
                      'LOGISTICS ERP',
                      style: TextStyle(
                        color: Color(0xFF6EE7B7),
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0x14FFFFFF)),
          const SizedBox(height: 12),

          // Primary Navigation Links
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              children: [
                _buildSectionHeader('OPERATIONS'),
                _buildNavItem('dashboard', 'Dashboard', Icons.space_dashboard_rounded),
                _buildNavItem('parties', 'Parties Directory', Icons.contacts_rounded),
                _buildNavItem('trucks', 'Truck Logistics', Icons.local_shipping_rounded),
                const SizedBox(height: 16),
                _buildSectionHeader('FINANCIALS'),
                _buildNavItem('invoice', 'Invoice Ledger', Icons.receipt_long_rounded),
                _buildNavItem('payments', 'Payment Ledger', Icons.account_balance_wallet_rounded),
                _buildNavItem('reports', 'Party Ledgers', Icons.query_stats_rounded),
                _buildNavItem('transport', 'Transport Logs', Icons.commute_rounded),
                _buildNavItem('estimate', 'Cost Estimator', Icons.calculate_rounded),
              ],
            ),
          ),

          // System Session Footer
          Padding(
            padding: const EdgeInsets.all(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0x14FFFFFF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0x1AFFFFFF)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'LOCAL STORE',
                        style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: Color(0xFF6EE7B7), letterSpacing: 0.8),
                      ),
                      Text(
                        'Persistence Online',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Colors.white70),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: onLock,
                    child: const Padding(
                      padding: EdgeInsets.all(4.0),
                      child: Icon(Icons.power_settings_new_rounded, size: 16, color: Color(0xFFF87171)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 10, top: 8, bottom: 6),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w900,
          color: Color(0xFF4B6E5B),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildNavItem(String key, String title, IconData icon) {
    final bool active = activeTab == key;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => onTabChanged(key),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF10B981) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: active
                ? [
                    const BoxShadow(
                      color: Color(0x3310B981),
                      blurRadius: 10,
                      offset: Offset(0, 3),
                    )
                  ]
                : null,
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: active ? Colors.white : const Color(0xFF86A393)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: active ? FontWeight.w900 : FontWeight.w600,
                    color: active ? Colors.white : const Color(0xFFC7D7CF),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- MOBILE SLICK APP BAR ----------------
  Widget _buildMobileTopBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF047857),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.eco_rounded, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        activeTab.toUpperCase(),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(width: 8),
                      // Mobile Live Sync Dot & Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: syncHealthStatus == 'CONNECTED'
                              ? const Color(0xFFECFDF5)
                              : (syncHealthStatus == 'QUEUED' ? const Color(0xFFFFFBEB) : const Color(0xFFFEF2F2)),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: syncHealthStatus == 'CONNECTED'
                                ? const Color(0xFFA7F3D0)
                                : (syncHealthStatus == 'QUEUED' ? const Color(0xFFFDE68A) : const Color(0xFFFECACA)),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: syncHealthStatus == 'CONNECTED'
                                    ? const Color(0xFF047857)
                                    : (syncHealthStatus == 'QUEUED' ? const Color(0xFFD97706) : const Color(0xFFDC2626)),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              syncHealthStatus == 'CONNECTED' ? 'Live' : (syncHealthStatus == 'QUEUED' ? 'Queued' : 'Offline'),
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: syncHealthStatus == 'CONNECTED'
                                    ? const Color(0xFF047857)
                                    : (syncHealthStatus == 'QUEUED' ? const Color(0xFFB45309) : const Color(0xFFDC2626)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'FY $financialYear • $activeState',
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.swap_horiz_rounded, size: 20, color: Color(0xFF047857)),
                onPressed: () => onStateChanged(activeState == "Andhra Pradesh" ? "Tamil Nadu" : "Andhra Pradesh"),
                tooltip: 'Switch State',
              ),
              IconButton(
                icon: const Icon(Icons.settings_outlined, size: 18, color: Color(0xFF0F172A)),
                onPressed: onSettings,
                tooltip: 'Settings',
              ),
              IconButton(
                icon: const Icon(Icons.lock_outline_rounded, size: 18, color: Color(0xFF64748B)),
                onPressed: onLock,
                tooltip: 'Lock ERP',
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------- MOBILE BOTTOM DOCKED NAV BAR (SCROLLABLE FOR ALL TABS) ----------------
  Widget _buildMobileBottomNav() {
    return Container(
      height: 60,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            _buildMobileTabItem('dashboard', Icons.space_dashboard_rounded, 'Dash'),
            _buildMobileTabItem('parties', Icons.contacts_rounded, 'Parties'),
            _buildMobileTabItem('trucks', Icons.local_shipping_rounded, 'Logistics'),
            _buildMobileTabItem('invoice', Icons.receipt_long_rounded, 'Invoice'),
            _buildMobileTabItem('payments', Icons.account_balance_wallet_rounded, 'Ledger'),
            _buildMobileTabItem('reports', Icons.query_stats_rounded, 'Reports'),
            _buildMobileTabItem('transport', Icons.commute_rounded, 'Transport'),
            _buildMobileTabItem('estimate', Icons.calculate_rounded, 'Estimate'),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileTabItem(String key, IconData icon, String label) {
    final bool active = activeTab == key;
    return InkWell(
      onTap: () => onTabChanged(key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 19,
              color: active ? const Color(0xFF047857) : const Color(0xFF94A3B8),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: active ? FontWeight.w900 : FontWeight.w600,
                color: active ? const Color(0xFF047857) : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
// ---------------- CAPITALIZATION TEXT FORMATTER ----------------
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
      composing: newValue.composing,
    );
  }
}
class _CustomAutocompleteField extends StatefulWidget {
  final String label;
  final List<String> optionsList;
  final String currentVal;
  final String hint;
  final Function(String) onSelect;
  final VoidCallback? onAddPressed;
  final void Function(String)? onAddNewNamed; // <-- Defined here
  final FocusNode? focusNode;
  final FocusNode? nextFocusNode;

  const _CustomAutocompleteField({
    super.key,
    required this.label,
    required this.optionsList,
    required this.currentVal,
    required this.hint,
    required this.onSelect,
    this.onAddPressed,
    this.onAddNewNamed, // <-- Added to constructor
    this.focusNode,
    this.nextFocusNode,
  });

  @override
  State<_CustomAutocompleteField> createState() => _CustomAutocompleteFieldState();
}

class _CustomAutocompleteFieldState extends State<_CustomAutocompleteField> {
  late TextEditingController _controller;
  FocusNode? _internalFocusNode;
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  late final String _tapGroupId;

  FocusNode get _activeFocus => widget.focusNode ?? (_internalFocusNode ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _tapGroupId = 'tap_group_${widget.label}_${UniqueKey().toString()}';
    _controller = TextEditingController(text: widget.currentVal);
    _activeFocus.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    if (_activeFocus.hasFocus) {
      _showOverlay();
    } else {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted && !_activeFocus.hasFocus) {
          _hideOverlay();
        }
      });
    }
  }

  @override
  void didUpdateWidget(_CustomAutocompleteField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentVal != oldWidget.currentVal && widget.currentVal != _controller.text) {
      _controller.text = widget.currentVal;
    }
  }

 @override
void dispose() {
  _activeFocus.removeListener(_onFocusChanged);
  _internalFocusNode?.dispose();
  _controller.dispose();
  super.dispose();
}

  void _selectOption(String opt) {
    _controller.text = opt;
    widget.onSelect(opt);
    _hideOverlay();
    _activeFocus.unfocus();
    if (widget.nextFocusNode != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          FocusScope.of(context).requestFocus(widget.nextFocusNode);
        }
      });
    }
  }

  void _onSubmittedAction(String val) {
    final query = val.trim().toUpperCase();
    if (query.isEmpty) return;

    final exactMatch = widget.optionsList.firstWhere(
      (o) => o.trim().toUpperCase() == query,
      orElse: () => '',
    );

    if (exactMatch.isNotEmpty) {
      _selectOption(exactMatch);
    } else {
      _hideOverlay();
      _activeFocus.unfocus();
      if (widget.onAddNewNamed != null) {
        widget.onAddNewNamed!(query);
      } else if (widget.onAddPressed != null) {
        widget.onAddPressed!();
      } else {
        _selectOption(query);
      }
    }
  }

  // ---------------- OVERLAY LOGIC ----------------
  void _showOverlay() {
    if (_overlayEntry != null) return;

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _activeFocus.hasFocus && _overlayEntry == null) {
          _showOverlay();
        }
      });
      return;
    }

    final width = renderBox.size.width;

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Positioned(
          width: width,
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: const Offset(0.0, 44.0),
            child: TapRegion(
              groupId: _tapGroupId,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(10),
                color: Colors.white,
                shadowColor: const Color(0x33000000),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: _buildOverlayList(),
                ),
              ),
            ),
          ),
        );
      },
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
    }
  }

  Widget _buildOverlayList() {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _controller,
      builder: (context, value, child) {
        final query = value.text.trim().toUpperCase();
        final filtered = query.isEmpty
            ? widget.optionsList
            : widget.optionsList.where((o) => o.toUpperCase().contains(query)).toList();
        final bool hasExactMatch = widget.optionsList.any((o) => o.trim().toUpperCase() == query);

        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 4),
          shrinkWrap: true,
          children: [
            if (query.isNotEmpty && !hasExactMatch && widget.onAddNewNamed != null)
              Material(
                color: const Color(0xFFECFDF5),
                child: InkWell(
                  hoverColor: const Color(0xFFD1FAE5),
                  onTap: () => _onSubmittedAction(query),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        const Icon(Icons.add_circle_outline, size: 16, color: Color(0xFF047857)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '+ Add "$query" as new ${widget.label.replaceAll('*', '').trim()}',
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (filtered.isEmpty && (query.isEmpty || hasExactMatch))
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'No matches found. Click + Add New above.',
                  style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF94A3B8)),
                ),
              )
            else
              ...filtered.map((opt) {
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    hoverColor: const Color(0xFFECFDF5),
                    onTap: () => _selectOption(opt),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Text(
                        opt,
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return TapRegion(
      groupId: _tapGroupId,
      onTapOutside: (_) {
        _hideOverlay();
        if (_activeFocus.hasFocus) {
          _activeFocus.unfocus();
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(widget.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
              if (widget.onAddPressed != null)
                InkWell(
                  onTap: widget.onAddPressed,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Text('+ Add New', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF047857))),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          CompositedTransformTarget(
            link: _layerLink,
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _activeFocus,
                      inputFormatters: [UpperCaseTextFormatter()],
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: widget.hint,
                        hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: InputBorder.none,
                      ),
                      onChanged: (val) {
                        widget.onSelect(val.toUpperCase());
                        if (_overlayEntry == null && _activeFocus.hasFocus) {
                          _showOverlay();
                        }
                      },
                      onSubmitted: (val) => _onSubmittedAction(val),
                    ),
                  ),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _controller,
                    builder: (context, value, child) {
                      if (value.text.isNotEmpty) {
                        return IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Padding(
                            padding: EdgeInsets.only(right: 8.0),
                            child: Icon(Icons.clear, size: 15, color: Color(0xFF94A3B8)),
                          ),
                          onPressed: () {
                            _controller.clear();
                            widget.onSelect('');
                            _activeFocus.requestFocus();
                          },
                        );
                      }
                      return IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Padding(
                          padding: EdgeInsets.only(right: 8.0),
                          child: Icon(Icons.arrow_drop_down, size: 20, color: Color(0xFF64748B)),
                        ),
                        onPressed: () {
                          if (_activeFocus.hasFocus) {
                            if (_overlayEntry == null) {
                              _showOverlay();
                            } else {
                              _hideOverlay();
                              _activeFocus.unfocus();
                            }
                          } else {
                            _activeFocus.requestFocus();
                          }
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}