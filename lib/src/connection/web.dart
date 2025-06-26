import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';

DatabaseConnection connect([String? databasePath]) {
  return DatabaseConnection.delayed(
    Future(() async {
      try {
        final db = await WasmDatabase.open(
          databaseName: databasePath ?? 'drift_repository',
          sqlite3Uri: Uri.parse('sqlite3.wasm'),
          driftWorkerUri: Uri.parse('drift_worker.dart.js'),
        );
        return db.resolvedExecutor;
      } catch (e) {
        throw Exception(
          'Failed to initialize SQLite for web. Please ensure sqlite3.wasm and drift_worker.dart.js '
          'are available in your web/ directory. You can download them from:\n'
          '- sqlite3.wasm: https://github.com/simolus3/sqlite3.dart/releases\n'
          '- drift_worker.dart.js: https://github.com/simolus3/drift/releases\n\n'
          'For easier web support without manual setup, consider using:\n'
          '- kiss_firebase_repository\n'
          '- kiss_pocketbase_repository\n\n'
          'Error: $e',
        );
      }
    }),
  );
}
