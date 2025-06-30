// ignore_for_file: public_member_api_docs

import 'package:drift/drift.dart';
import 'package:kiss_drift_repository/src/connection/connection.dart';

part 'database.g.dart';

class Items extends Table {
  TextColumn get id => text()();
  TextColumn get data => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Items])
class AppDatabase extends _$AppDatabase {
  AppDatabase([String? databasePath]) : super(connect(databasePath));
  @override
  int get schemaVersion => 1;
}
