import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';
import '../models/purchase_model.dart';
import '../models/sale_model.dart';
import '../models/expenditure_model.dart';
import 'auth_service.dart';

/// Communicates with Google Apps Script Web App.
/// Uses text/plain to avoid browser CORS preflight on web,
/// and enforces timeouts so the UI is never blocked.
class SheetsService {
  SheetsService._();

  static const Duration _timeout = Duration(seconds: 8);

  static String get _base => AppConstants.sheetsWebAppUrl;

  static Future<bool> _sendPost(Map<String, dynamic> payload) async {
    if (_base.isEmpty) return false;
    try {
      final enhancedPayload = {
        'env': AuthService.currentUserId ?? 'MarketP',
        ...payload,
      };
      final res = await http
          .post(
            Uri.parse(_base),
            // text/plain avoids CORS OPTIONS preflight in browsers (Flutter Web)
            headers: {'Content-Type': 'text/plain;charset=utf-8'},
            body: jsonEncode(enhancedPayload),
          )
          .timeout(_timeout);

      // In native Flutter (Android/iOS/Windows), Google Apps Script returns 302 Found
      if (res.statusCode == 302 && res.headers.containsKey('location')) {
        final redirectUrl = res.headers['location']!;
        if (redirectUrl.contains('accounts.google.com')) {
          // Redirected to login -> incorrect permissions on web app
          return false;
        }
        try {
          final followUp =
              await http.get(Uri.parse(redirectUrl)).timeout(_timeout);
          if (followUp.statusCode == 200 &&
              !followUp.body.contains('<!DOCTYPE html>')) {
            return followUp.body.contains('success');
          }
        } catch (_) {
          // If follow-up times out, the doPost already completed on the server
          return true;
        }
        return true;
      }

      // In Flutter Web or if client followed redirect automatically
      if (res.statusCode == 200 && !res.body.contains('<!DOCTYPE html>')) {
        return res.body.contains('success');
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Triggers Google Apps Script to fetch all current records from Supabase
  /// for the active environment (MarketP or MarketT) and populate Google Sheets.
  static Future<bool> triggerSupabaseSync() async {
    if (_base.isEmpty) return false;
    try {
      final env = AuthService.currentUserId ?? 'MarketP';
      final res = await http
          .get(Uri.parse('$_base?action=sync&env=$env'))
          .timeout(const Duration(seconds: 15));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> addPurchase(PurchaseModel purchase) async {
    return _sendPost({
      'action': 'addPurchase',
      'data': purchase.toJson(),
    });
  }

  static Future<bool> addSale(SaleModel sale) async {
    return _sendPost({
      'action': 'addSale',
      'data': sale.toJson(),
    });
  }

  static Future<bool> addExpenditure(ExpenditureModel expenditure) async {
    return _sendPost({
      'action': 'addExpenditure',
      'data': expenditure.toJson(),
    });
  }

  static Future<List<PurchaseModel>> fetchPurchases() async {
    if (_base.isEmpty) return [];
    try {
      final res = await http
          .get(Uri.parse('$_base?action=getPurchases'))
          .timeout(_timeout);

      if (res.statusCode != 200 || res.body.contains('<!DOCTYPE html>')) {
        return [];
      }
      final dynamic decoded = jsonDecode(res.body);
      if (decoded is! List) return [];

      return decoded
          .map((e) => PurchaseModel.fromJson(Map<String, dynamic>.from(e)))
          .toList()
        ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
    } catch (_) {
      return [];
    }
  }

  static Future<List<SaleModel>> fetchSales() async {
    if (_base.isEmpty) return [];
    try {
      final res = await http
          .get(Uri.parse('$_base?action=getSales'))
          .timeout(_timeout);

      if (res.statusCode != 200 || res.body.contains('<!DOCTYPE html>')) {
        return [];
      }
      final dynamic decoded = jsonDecode(res.body);
      if (decoded is! List) return [];

      return decoded
          .map((e) => SaleModel.fromJson(Map<String, dynamic>.from(e)))
          .toList()
        ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
    } catch (_) {
      return [];
    }
  }
}
