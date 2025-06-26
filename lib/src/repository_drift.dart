// ignore_for_file: public_member_api_docs

import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:kiss_drift_repository/src/connection/connection.dart';
import 'package:kiss_repository/kiss_repository.dart' as kiss;
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
  AppDatabase([String? databasePath]) : super(connect(databasePath));

  @override
  int get schemaVersion => 1;
}

/// A Drift implementation of the KISS Repository interface.
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
    kiss.QueryBuilder<bool Function(T)?>? queryBuilder,
    String? databasePath,
  }) async {
    final database = AppDatabase(databasePath);

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
  final kiss.QueryBuilder<bool Function(T)?>? queryBuilder;
  final _uuid = const Uuid();

  @override
  String? get path => tableName;

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
    var hasEmittedData = false;

    return query.watchSingleOrNull().transform(
      StreamTransformer<Item?, T>.fromHandlers(
        handleData: (result, sink) {
          if (result == null) {
            if (!hasEmittedData) {
              // Document doesn't exist initially - emit error
              sink.addError(kiss.RepositoryException.notFound(id));
            } else {
              // Document was deleted after existing - close the stream
              sink.close();
            }
          } else {
            hasEmittedData = true;
            final jsonData = jsonDecode(result.data) as Map<String, Object?>;
            sink.add(fromDrift(jsonData));
          }
        },
        handleError: (error, stackTrace, sink) {
          sink.addError(kiss.RepositoryException.notFound(id));
        },
      ),
    );
  }

  @override
  Future<List<T>> query({kiss.Query query = const kiss.AllQuery()}) async {
    final selectQuery = database.select(database.items);
    final results = await selectQuery.get();

    // Convert all results to objects first
    final allObjects = results.map((result) {
      final jsonData = jsonDecode(result.data) as Map<String, Object?>;
      return fromDrift(jsonData);
    }).toList();

    // Handle AllQuery - return all objects
    if (query is kiss.AllQuery) {
      return allObjects;
    }

    // Handle custom queries using query builder
    if (queryBuilder == null) {
      throw kiss.RepositoryException(message: 'Query builder required for custom queries');
    }

    final filter = queryBuilder!.build(query);
    if (filter == null) {
      return allObjects;
    }

    // Apply client-side filtering using the filter function
    return allObjects.where(filter).toList();
  }

  @override
  Stream<List<T>> streamQuery({kiss.Query query = const kiss.AllQuery()}) async* {
    final selectQuery = database.select(database.items);
    
    // First, emit the current state immediately
    try {
      final currentResults = await selectQuery.get();
      final currentObjects = currentResults.map((result) {
        final jsonData = jsonDecode(result.data) as Map<String, Object?>;
        return fromDrift(jsonData);
      }).toList();
      
      // Apply filtering and emit initial state
      if (query is kiss.AllQuery) {
        yield currentObjects;
      } else {
        if (queryBuilder == null) {
          throw kiss.RepositoryException(message: 'Query builder required for custom queries');
        }
        final filter = queryBuilder!.build(query);
        yield filter == null ? currentObjects : currentObjects.where(filter).toList();
      }
    } catch (e) {
      // If initial query fails, emit empty list
      yield <T>[];
    }

    // Then watch for changes and emit them
    await for (final results in selectQuery.watch()) {
      // Convert all results to objects first
      final allObjects = results.map((result) {
        final jsonData = jsonDecode(result.data) as Map<String, Object?>;
        return fromDrift(jsonData);
      }).toList();

      // Handle AllQuery - yield all objects
      if (query is kiss.AllQuery) {
        yield allObjects;
        continue;
      }

      // Handle custom queries using query builder
      if (queryBuilder == null) {
        throw kiss.RepositoryException(message: 'Query builder required for custom queries');
      }

      final filter = queryBuilder!.build(query);
      if (filter == null) {
        yield allObjects;
        continue;
      }

      // Apply client-side filtering using the filter function
      yield allObjects.where(filter).toList();
    }
  }

  @override
  Future<T> add(kiss.IdentifiedObject<T> item) async {
    final jsonData = jsonEncode(toDrift(item.object));
    final now = DateTime.now();

    try {
      await database
          .into(database.items)
          .insert(
            ItemsCompanion(
              id: Value(item.id), 
              data: Value(jsonData), 
              createdAt: Value(now), 
              updatedAt: Value(now),
            ),
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
    return database.transaction(() async {

      final current = await get(id);
      final updated = updater(current);

      // Save updated item
      final jsonData = jsonEncode(toDrift(updated));
      final updateQuery = database
        .update(database.items)
        ..where((tbl) => tbl.id.equals(id));

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

  Future<bool> exists(String id) async {
    final query = database.select(database.items)..where((tbl) => tbl.id.equals(id));
    final result = await query.getSingleOrNull();
    return result != null;
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


  @override
  kiss.IdentifiedObject<T> autoIdentify(T object, {T Function(T object, String id)? updateObjectWithId}) {
    final id = _uuid.v4();
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
