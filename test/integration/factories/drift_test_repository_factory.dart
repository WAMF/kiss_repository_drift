// ignore_for_file: avoid_print

import 'package:kiss_drift_repository/kiss_drift_repository.dart';
import 'package:kiss_repository/kiss_repository.dart';
import 'package:kiss_repository_tests/kiss_repository_tests.dart';

import 'drift_test_query_builder.dart';

class DriftTestRepositoryFactory implements RepositoryFactory<ProductModel> {
  Repository<ProductModel>? _repository;

  @override
  Future<Repository<ProductModel>> createRepository() async {
    _repository = await RepositoryDrift.create<ProductModel>(
      tableName: 'products',
      toDrift: (model) => {
        'id': model.id,
        'name': model.name,
        'price': model.price,
        'description': model.description,
        'created': model.created.toIso8601String(),
      },
      fromDrift: (json) => ProductModel(
        id: json['id']! as String,
        name: json['name']! as String,
        price: (json['price']! as num).toDouble(),
        description: json['description'] as String? ?? '',
        created: DateTime.parse(json['created']! as String),
      ),
      queryBuilder: const DriftTestQueryBuilder(),
      databasePath: ':memory:',
    );
    return _repository!;
  }

  @override
  Future<void> cleanup() async {
    if (_repository == null) {
      print('🧹 Cleanup: No repository to clean');
      return;
    }

    try {
      final allItems = await _repository!.query();
      print('🧹 Cleanup: Found ${allItems.length} items to delete');

      if (allItems.isNotEmpty) {
        final ids = allItems.map((item) => item.id).toList();
        await _repository!.deleteAll(ids);
        print('🧹 Cleanup: Deleted ${ids.length} items successfully');
      } else {
        print('🧹 Cleanup: Repository already empty');
      }
    } catch (e) {
      print('❌ Cleanup failed: $e');
    }
  }

  @override
  void dispose() {
    if (_repository != null) {
      _repository!.dispose();
      _repository = null;
    }
  }
}
