// ignore_for_file: public_member_api_docs

import 'dart:async';
import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:kiss_drift_repository/src/connection/connection.dart';
import 'package:kiss_drift_repository/src/drift_identified_object.dart';
import 'package:kiss_repository/kiss_repository.dart' as kiss;

part 'repository_drift.g.dart';

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

  @override
  String? get path => tableName;

  @override
  Future<T> get(String id) async {
    final result = await (database.select(database.items)
      ..where((tbl) => tbl.id.equals(id)))
      .getSingleOrNull();

    if (result == null) {
      throw kiss.RepositoryException.notFound(id);
    }

    final jsonData = jsonDecode(result.data) as Map<String, Object?>;
    return fromDrift(jsonData);
  }

  @override
  Stream<T> stream(String id) {
    final query = database.select(database.items)..where((tbl) => tbl.id.equals(id));
    var emitted = false;

    return query.watchSingleOrNull().transform(
      StreamTransformer<Item?, T>.fromHandlers(
        handleData: (result, sink) {
          if (result == null) {
            if (!emitted) {
              sink.addError(kiss.RepositoryException.notFound(id));
            } else {
              sink.close();
            }
          } else {
            emitted = true;
            final jsonData = jsonDecode(result.data) as Map<String, Object?>;
            sink.add(fromDrift(jsonData));
          }
        },
        handleError: (_, __, sink) => sink.addError(kiss.RepositoryException.notFound(id)),
      ),
    );
  }

  @override
  Future<List<T>> query({kiss.Query query = const kiss.AllQuery()}) async {
    final results = await database.select(database.items).get();
    final all = results.map((result) {
      final jsonData = jsonDecode(result.data) as Map<String, Object?>;
      return fromDrift(jsonData);
    }).toList();

    if (query is kiss.AllQuery) return all;
    if (queryBuilder == null) throw kiss.RepositoryException(message: 'Query builder required');

    final filter = queryBuilder!.build(query);
    return filter == null ? all : all.where(filter).toList();
  }

  @override
  Stream<List<T>> streamQuery({kiss.Query query = const kiss.AllQuery()}) {
    final selectQuery = database.select(database.items);

    return selectQuery.watch().map((rows) {
      final objects = rows.map((row) {
        final json = jsonDecode(row.data) as Map<String, Object?>;
        return fromDrift(json);
      }).toList();
      return _applyQueryFilter(query, objects);
    });
  }

  List<T> _applyQueryFilter(kiss.Query query, List<T> items) {
    if (query is kiss.AllQuery) return items;
    if (queryBuilder == null) {
      throw kiss.RepositoryException(message: 'Query builder required for custom queries');
    }
    final filter = queryBuilder!.build(query);
    return filter == null ? items : items.where(filter).toList();
  }

  @override
  Future<T> add(kiss.IdentifiedObject<T> item) async {
    final json = jsonEncode(toDrift(item.object));
    final now = DateTime.now();

    try {
      await database.into(database.items).insert(ItemsCompanion(
        id: Value(item.id),
        data: Value(json),
        createdAt: Value(now),
        updatedAt: Value(now),
      ));
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
      final json = jsonEncode(toDrift(updated));

      final rows = await (database.update(
        database.items,
      )..where((tbl) => tbl.id.equals(id))).write(ItemsCompanion(data: Value(json), updatedAt: Value(DateTime.now())));

      if (rows == 0) throw kiss.RepositoryException.notFound(id);
      return updated;
    });
  }

  @override
  Future<void> delete(String id) async {
    await (database.delete(database.items)..where((tbl) => tbl.id.equals(id))).go();
  }

  @override
  Future<Iterable<T>> addAll(Iterable<kiss.IdentifiedObject<T>> items) async =>
      await database.transaction(() async => [for (final i in items) await add(i)]);

  @override
  Future<void> deleteAll(Iterable<String> ids) async =>
      await database.transaction(() async => [for (final id in ids) await delete(id)]);

  @override
  Future<Iterable<T>> updateAll(Iterable<kiss.IdentifiedObject<T>> items) async =>
      await database.transaction(() async => [for (final i in items) await update(i.id, (_) => i.object)]);

  @override
  kiss.IdentifiedObject<T> autoIdentify(T object, {T Function(T object, String id)? updateObjectWithId}) =>
      DriftIdentifiedObject(object, updateObjectWithId ?? (o, _) => o);

  @override
  Future<T> addAutoIdentified(T object, {T Function(T object, String id)? updateObjectWithId}) async =>
      await add(autoIdentify(object, updateObjectWithId: updateObjectWithId));

  @override
  void dispose() => database.close();
}
