import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConstants {
  AppConstants._();

  /// Edit this list to match the crops you deal in.
  static const List<String> crops = [
    'Wheat',
    'Rice',
    'Maize',
    'Cotton',
    'Sugarcane',
    'Soybean',
    'Groundnut',
    'Onion',
    'Potato',
    'Tomato',
    'Other',
  ];

  /// Units the user can pick for quantity.
  static const List<String> units = ['Quintal', 'Kg', 'Ton'];

  /// Standard categories for Other Expenditure.
  static const List<String> expenditureCategories = [
    'Transportation / Freight',
    'Loading & Unloading (Hamali)',
    'Gunny Bags / Packaging',
    'Diesel / Fuel',
    'Machinery & Vehicle Repair',
    'Toll & Weighbridge (Dharmakanta)',
    'Electricity & Water',
    'Food & Tea Expenses',
    'Rent & Office Expenses',
    'Labor / Daily Wages',
    'Other / Miscellaneous',
  ];

  /// Payment modes for expenditures and transactions.
  static const List<String> paymentModes = [
    'Cash',
    'UPI / Online',
    'Bank Transfer',
    'Cheque',
  ];

  /// Deployed Google Apps Script Web App URL loaded safely from .env file.
  static String get sheetsWebAppUrl =>
      dotenv.env['SHEETS_WEB_APP_URL'] ?? '';

  /// Supabase project URL from .env.
  static String get supabaseUrl => dotenv.env['SUPABASE_URL']?.trim() ?? '';

  /// Supabase anon / public API key from .env.
  static String get supabaseAnonKey =>
      dotenv.env['SUPABASE_ANON_KEY']?.trim() ?? '';

  /// True if valid Supabase configuration is present.
  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty &&
      supabaseUrl.startsWith('http') &&
      !supabaseUrl.contains('your-project-id') &&
      supabaseAnonKey.isNotEmpty;
}
