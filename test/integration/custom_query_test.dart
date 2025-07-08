// ignore_for_file: avoid_print

import 'package:kiss_drift_repository/kiss_drift_repository.dart';
import 'package:kiss_drift_repository/src/db/database.dart';
import 'package:kiss_repository/kiss_repository.dart';
import 'package:kiss_repository_tests/kiss_repository_tests.dart';
import 'package:test/test.dart';

import 'factories/drift_test_query_builder.dart';

/// Test to verify collection-based data isolation between different repositories
void main() {
  group('Multi-Collection Data Isolation Tests', () {
    final database = AppDatabase(':memory:');
    late Repository<ProductModel> product1Repo;
    late Repository<ProductModel> product2Repo;
    late Repository<UserModel> userRepo;

    setUpAll(() async {
      // Create three different repository instances with different collections
      product1Repo = await RepositoryDrift.create<ProductModel>(
        tableName: 'product_1',
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
        queryBuilder: DriftTestQueryBuilder(),
        database: database,
      );

      product2Repo = await RepositoryDrift.create<ProductModel>(
        tableName: 'product_2',
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
        queryBuilder: DriftTestQueryBuilder(),
        database: database,
      );

      userRepo = await RepositoryDrift.create<UserModel>(
        tableName: 'users',
        toDrift: (model) => {
          'id': model.id,
          'name': model.name,
          'email': model.email,
          'created': model.created.toIso8601String(),
        },
        fromDrift: (json) => UserModel(
          id: json['id']! as String,
          name: json['name']! as String,
          email: json['email']! as String,
          created: DateTime.parse(json['created']! as String),
        ),
        database: database,
      );
    });

    tearDownAll(() async {
      product1Repo.dispose();
      product2Repo.dispose();
      userRepo.dispose();
    });

    setUp(() async {
      // Clean up before each test
      final allProduct1 = await product1Repo.query();
      if (allProduct1.isNotEmpty) {
        await product1Repo.deleteAll(allProduct1.map((p) => p.id));
      }

      final allProduct2 = await product2Repo.query();
      if (allProduct2.isNotEmpty) {
        await product2Repo.deleteAll(allProduct2.map((p) => p.id));
      }

      final allUsers = await userRepo.query();
      if (allUsers.isNotEmpty) {
        await userRepo.deleteAll(allUsers.map((u) => u.id));
      }
    });

    test('should support streaming with custom queries (raw SQL)', () async {
      // Test the complex streaming path with custom SQL queries

      // Add some initial products to product_1 collection
      final cheapProduct = ProductModel(
        id: 'cheap1',
        name: 'Cheap Product',
        price: 25.0,
        description: 'Affordable item',
        created: DateTime.now(),
      );

      final expensiveProduct = ProductModel(
        id: 'expensive1',
        name: 'Expensive Product',
        price: 150.0,
        description: 'Premium item',
        created: DateTime.now(),
      );

      await product1Repo.add(IdentifiedObject(cheapProduct.id, cheapProduct));
      await product1Repo.add(IdentifiedObject(expensiveProduct.id, expensiveProduct));

      // Start streaming expensive products (price > 100) using custom query
      final expensiveStream = product1Repo.streamQuery(query: QueryByPriceRange(minPrice: 100.0));

      final streamEvents = <List<ProductModel>>[];
      final subscription = expensiveStream.listen(streamEvents.add);

      // Wait for initial stream event
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Initial state should have 1 expensive product
      expect(streamEvents.isNotEmpty, isTrue);
      final initialEvent = streamEvents.last;
      expect(initialEvent, hasLength(1));
      expect(initialEvent.first.price, equals(150.0));

      // Add another expensive product - should trigger stream update
      final anotherExpensive = ProductModel(
        id: 'expensive2',
        name: 'Another Expensive',
        price: 200.0,
        description: 'Even more expensive',
        created: DateTime.now(),
      );

      await product1Repo.add(IdentifiedObject(anotherExpensive.id, anotherExpensive));
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Stream should now have 2 expensive products
      expect(streamEvents.length, greaterThan(1));
      final updatedEvent = streamEvents.last;
      expect(updatedEvent, hasLength(2));
      final prices = updatedEvent.map((p) => p.price).toList()..sort();
      expect(prices, equals([150.0, 200.0]));

      // Add a cheap product - should NOT trigger the expensive products stream
      final anotherCheap = ProductModel(
        id: 'cheap2',
        name: 'Another Cheap',
        price: 15.0,
        description: 'Very affordable',
        created: DateTime.now(),
      );

      await product1Repo.add(IdentifiedObject(anotherCheap.id, anotherCheap));
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Stream events should not have increased (cheap product doesn't match filter)
      // Note: This tests if the raw SQL WHERE clause is actually working in streaming
      final finalEvent = streamEvents.last;
      expect(finalEvent, hasLength(2)); // Still only 2 expensive products

      // Update an expensive product to become cheap - should remove from stream
      await product1Repo.update(
        'expensive1',
        (current) => ProductModel(
          id: current.id,
          name: current.name,
          price: 50.0, // Now cheap
          description: current.description,
          created: current.created,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Stream should now have only 1 expensive product
      final afterUpdateEvent = streamEvents.last;
      expect(afterUpdateEvent, hasLength(1));
      expect(afterUpdateEvent.first.price, equals(200.0));

      await subscription.cancel();

      print('✅ Custom query streaming with raw SQL works correctly');
    });
  });
}

// Simple UserModel for testing
class UserModel {
  final String id;
  final String name;
  final String email;
  final DateTime created;

  UserModel({required this.id, required this.name, required this.email, required this.created});
}
