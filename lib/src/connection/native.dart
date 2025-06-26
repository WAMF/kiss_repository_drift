import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';

DatabaseConnection connect([String? databasePath]) {
  // Use in-memory database for tests
  if (databasePath == ':memory:') {
    return DatabaseConnection(NativeDatabase.memory());
  }

  if (databasePath != null) {
    return DatabaseConnection(NativeDatabase(File(databasePath)));
  }

  // Default database location in current directory for simplicity
  final file = File('drift_repository.db');
  return DatabaseConnection(NativeDatabase(file));
}
