import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:kiss_repository/kiss_repository.dart' as kiss;
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

part 'repository_drift.g.dart';

// Define the generic items table
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
  AppDatabase(QueryExecutor e) : super(e);

  @override
  int get schemaVersion => 1;
}

/// A Drift implementation of the Repository interface.
///
/// This implementation uses SQLite through Drift for local data persistence
/// with type-safe database operations and real-time streaming capabilities.
class RepositoryDrift<T> implements kiss.Repository<T> {
  RepositoryDrift._({
    required this.database,
    required this.tableName,
    required this.toDrift,
    required this.fromDrift,
    this.queryBuilder,
  });

  /// Creates a new Drift repository instance.
  ///
  /// [tableName] - The name of the database table (for path identification)
  /// [toDrift] - Function to convert objects to JSON-serializable format
  /// [fromDrift] - Function to convert JSON data back to objects
  /// [queryBuilder] - Optional query builder for custom queries
  /// [databasePath] - Optional custom database path (uses default if null)
  static Future<RepositoryDrift<T>> create<T>({
    required String tableName,
    required Map<String, Object?> Function(T) toDrift,
    required T Function(Map<String, Object?>) fromDrift,
    kiss.QueryBuilder<String>? queryBuilder,
    String? databasePath,
  }) async {
    final executor = _createExecutor(databasePath);
    final database = AppDatabase(executor);

    return RepositoryDrift<T>._(
      database: database,
      tableName: tableName,
      toDrift: toDrift,
      fromDrift: fromDrift,
      queryBuilder: queryBuilder,
    );
  }

  final AppDatabase database;
  final String tableName;
  final Map<String, Object?> Function(T) toDrift;
  final T Function(Map<String, Object?>) fromDrift;
  final kiss.QueryBuilder<String>? queryBuilder;
  final _uuid = const Uuid();

  @override
  String? get path => tableName;

  static QueryExecutor _createExecutor(String? databasePath) {
    // Use in-memory database for tests
    if (databasePath == ':memory:') {
      return NativeDatabase.memory();
    }

    if (databasePath != null) {
      return NativeDatabase(File(databasePath));
    }

    // Default database location in current directory for simplicity
    final file = File('drift_repository.db');
    return NativeDatabase(file);
  }

  // Repository interface implementation
  @override
  Future<T> get(String id) async {
    final query = database.select(database.items)..where((tbl) => tbl.id.equals(id));

    final result = await query.getSingleOrNull();
    if (result == null) {
      throw kiss.RepositoryException.notFound(id);
    }

    final jsonData = jsonDecode(result.data) as Map<String, Object?>;
    return fromDrift(jsonData);
  }

  @override
  Stream<T> stream(String id) {
    final query = database.select(database.items)..where((tbl) => tbl.id.equals(id));

    return query.watchSingleOrNull().map((result) {
      if (result == null) {
        throw kiss.RepositoryException.notFound(id);
      }
      final jsonData = jsonDecode(result.data) as Map<String, Object?>;
      return fromDrift(jsonData);
    });
  }

  @override
  Future<List<T>> query({kiss.Query query = const kiss.AllQuery()}) async {
    var selectQuery = database.select(database.items);

    if (query is! kiss.AllQuery && queryBuilder != null) {
      final whereClause = queryBuilder!.build(query);
      // For now, we'll implement a simple JSON search
      // This is a basic implementation - could be enhanced with better SQL queries
      selectQuery = selectQuery..where((tbl) => tbl.data.contains(whereClause));
    }

    final results = await selectQuery.get();
    return results.map((result) {
      final jsonData = jsonDecode(result.data) as Map<String, Object?>;
      return fromDrift(jsonData);
    }).toList();
  }

  @override
  Stream<List<T>> streamQuery({kiss.Query query = const kiss.AllQuery()}) {
    var selectQuery = database.select(database.items);

    if (query is! kiss.AllQuery && queryBuilder != null) {
      final whereClause = queryBuilder!.build(query);
      selectQuery = selectQuery..where((tbl) => tbl.data.contains(whereClause));
    }

    return selectQuery.watch().map((results) {
      return results.map((result) {
        final jsonData = jsonDecode(result.data) as Map<String, Object?>;
        return fromDrift(jsonData);
      }).toList();
    });
  }

  @override
  Future<T> add(kiss.IdentifiedObject<T> item) async {
    final jsonData = jsonEncode(toDrift(item.object));
    final now = DateTime.now();

    try {
      await database
          .into(database.items)
          .insert(
            ItemsCompanion(id: Value(item.id), data: Value(jsonData), createdAt: Value(now), updatedAt: Value(now)),
          );
      return item.object;
    } catch (e) {
      if (e.toString().contains('UNIQUE constraint failed')) {
        throw kiss.RepositoryException.alreadyExists(item.id);
      }
      throw kiss.RepositoryException(message: 'Failed to add item: $e');
    }
  }

  @override
  Future<T> update(String id, T Function(T current) updater) async {
    return await database.transaction(() async {
      // Get current item
      final current = await get(id);

      // Apply update
      final updated = updater(current);

      // Save updated item
      final jsonData = jsonEncode(toDrift(updated));
      final updateQuery = database.update(database.items)..where((tbl) => tbl.id.equals(id));

      final rowsAffected = await updateQuery.write(
        ItemsCompanion(data: Value(jsonData), updatedAt: Value(DateTime.now())),
      );

      if (rowsAffected == 0) {
        throw kiss.RepositoryException.notFound(id);
      }

      return updated;
    });
  }

  @override
  Future<void> delete(String id) async {
    final deleteQuery = database.delete(database.items)..where((tbl) => tbl.id.equals(id));
    await deleteQuery.go();
    // Don't throw exception if item doesn't exist - delete should be idempotent
  }

  @override
  Future<void> clear() async {
    await database.delete(database.items).go();
  }

  @override
  Future<bool> exists(String id) async {
    final query = database.select(database.items)..where((tbl) => tbl.id.equals(id));
    final result = await query.getSingleOrNull();
    return result != null;
  }

  @override
  Future<void> close() async {
    await database.close();
  }

  // Batch operations - Fixed parameter types
  @override
  Future<Iterable<T>> addAll(Iterable<kiss.IdentifiedObject<T>> items) async {
    return await database.transaction(() async {
      final results = <T>[];
      for (final item in items) {
        results.add(await add(item));
      }
      return results;
    });
  }

  @override
  Future<void> deleteAll(Iterable<String> ids) async {
    await database.transaction(() async {
      for (final id in ids) {
        await delete(id); // Now safe since delete doesn't throw for non-existent items
      }
    });
  }

  @override
  Future<Iterable<T>> updateAll(Iterable<kiss.IdentifiedObject<T>> items) async {
    return await database.transaction(() async {
      final results = <T>[];
      for (final item in items) {
        results.add(await update(item.id, (_) => item.object));
      }
      return results;
    });
  }

  // Auto-identify functionality - Added missing methods
  @override
  String generateId() => _uuid.v4();

  @override
  kiss.IdentifiedObject<T> autoIdentify(T object, {T Function(T object, String id)? updateObjectWithId}) {
    final id = generateId();
    final updatedObject = updateObjectWithId?.call(object, id) ?? object;
    return kiss.IdentifiedObject(id, updatedObject);
  }

  @override
  Future<T> addAutoIdentified(T object, {T Function(T object, String id)? updateObjectWithId}) async {
    final identifiedObject = autoIdentify(object, updateObjectWithId: updateObjectWithId);
    return await add(identifiedObject);
  }

  @override
  void dispose() {
    // Close the database connection
    database.close();
  }
}
