import 'package:drift/drift.dart';

/// Fallback for conditional imports pattern.
/// Ensures compilation on all platforms and provides clear error messages
/// for unsupported platforms instead of compile-time failures.
DatabaseConnection connect([String? databasePath]) {
  throw UnsupportedError('No database available on this platform!');
}
