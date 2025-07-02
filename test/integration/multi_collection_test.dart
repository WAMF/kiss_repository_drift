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
        queryBuilder: const DriftTestQueryBuilder(),
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
        queryBuilder: const DriftTestQueryBuilder(),
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

    test('should isolate data between different collections', () async {
      // Add items to each collection
      final product1 = ProductModel(
        id: 'p1',
        name: 'Product 1',
        price: 10.0,
        description: 'First product',
        created: DateTime.now(),
      );

      final product2 = ProductModel(
        id: 'p2', 
        name: 'Product 2',
        price: 20.0,
        description: 'Second product',
        created: DateTime.now(),
      );

      final user = UserModel(
        id: 'u1',
        name: 'John Doe',
        email: 'john@example.com',
        created: DateTime.now(),
      );

      await product1Repo.add(IdentifiedObject(product1.id, product1));
      await product2Repo.add(IdentifiedObject(product2.id, product2));
      await userRepo.add(IdentifiedObject(user.id, user));

      // Verify each collection only contains its own data
      final product1Items = await product1Repo.query();
      final product2Items = await product2Repo.query();
      final userItems = await userRepo.query();

      expect(product1Items, hasLength(1));
      expect(product2Items, hasLength(1));
      expect(userItems, hasLength(1));

      expect(product1Items.first.id, equals('p1'));
      expect(product2Items.first.id, equals('p2'));
      expect(userItems.first.id, equals('u1'));

      print('✅ Data isolation between collections verified');
    });

    test('should allow same IDs in different collections', () async {
      const sharedId = 'shared_id';

      // Create items with the same ID but different content
      final product1 = ProductModel(
        id: sharedId,
        name: 'Product in Collection 1',
        price: 100.0,
        description: 'Product 1 description',
        created: DateTime.now(),
      );

      final product2 = ProductModel(
        id: sharedId,
        name: 'Product in Collection 2', 
        price: 200.0,
        description: 'Product 2 description',
        created: DateTime.now(),
      );

      final user = UserModel(
        id: sharedId,
        name: 'User with shared ID',
        email: 'shared@example.com',
        created: DateTime.now(),
      );

      // Add all items with the same ID to different collections
      await product1Repo.add(IdentifiedObject(sharedId, product1));
      await product2Repo.add(IdentifiedObject(sharedId, product2));
      await userRepo.add(IdentifiedObject(sharedId, user));

      // Verify each collection has its own version
      final retrievedProduct1 = await product1Repo.get(sharedId);
      final retrievedProduct2 = await product2Repo.get(sharedId);
      final retrievedUser = await userRepo.get(sharedId);

      expect(retrievedProduct1.name, equals('Product in Collection 1'));
      expect(retrievedProduct1.price, equals(100.0));

      expect(retrievedProduct2.name, equals('Product in Collection 2'));
      expect(retrievedProduct2.price, equals(200.0));

      expect(retrievedUser.name, equals('User with shared ID'));
      expect(retrievedUser.email, equals('shared@example.com'));

      print('✅ Same IDs in different collections supported');
    });

    test('should isolate CRUD operations between collections', () async {
      const sharedId = 'crud_test';

      // Add items with same ID to different collections
      final product1 = ProductModel(
        id: sharedId,
        name: 'Original Product 1',
        price: 50.0,
        description: 'Original description',
        created: DateTime.now(),
      );

      final product2 = ProductModel(
        id: sharedId,
        name: 'Original Product 2',
        price: 75.0,
        description: 'Another description',
        created: DateTime.now(),
      );

      await product1Repo.add(IdentifiedObject(sharedId, product1));
      await product2Repo.add(IdentifiedObject(sharedId, product2));

      // Update item in product_1 collection only
      await product1Repo.update(sharedId, (current) => ProductModel(
        id: current.id,
        name: 'Updated Product 1',
        price: 99.0,
        description: current.description,
        created: current.created,
      ));

      // Verify update only affected product_1 collection
      final updatedProduct1 = await product1Repo.get(sharedId);
      final unchangedProduct2 = await product2Repo.get(sharedId);

      expect(updatedProduct1.name, equals('Updated Product 1'));
      expect(updatedProduct1.price, equals(99.0));

      expect(unchangedProduct2.name, equals('Original Product 2'));
      expect(unchangedProduct2.price, equals(75.0));

      // Delete from product_2 collection only
      await product2Repo.delete(sharedId);

      // Verify product_1 still exists, product_2 is gone
      final stillExistsProduct1 = await product1Repo.get(sharedId);
      expect(stillExistsProduct1.name, equals('Updated Product 1'));

      expect(() => product2Repo.get(sharedId), 
        throwsA(isA<RepositoryException>()));

      print('✅ CRUD operations isolated between collections');
    });

    test('should isolate query operations between collections', () async {
      // Add products with different prices to different collections
      final expensiveProduct1 = ProductModel(
        id: 'exp1',
        name: 'Expensive Product 1',
        price: 150.0,
        description: 'Expensive item',
        created: DateTime.now(),
      );

      final cheapProduct1 = ProductModel(
        id: 'cheap1',
        name: 'Cheap Product 1',
        price: 25.0,
        description: 'Cheap item',
        created: DateTime.now(),
      );

      final expensiveProduct2 = ProductModel(
        id: 'exp2',
        name: 'Expensive Product 2',
        price: 175.0,
        description: 'Another expensive item',
        created: DateTime.now(),
      );

      await product1Repo.add(IdentifiedObject(expensiveProduct1.id, expensiveProduct1));
      await product1Repo.add(IdentifiedObject(cheapProduct1.id, cheapProduct1));
      await product2Repo.add(IdentifiedObject(expensiveProduct2.id, expensiveProduct2));

      // Query for expensive products (price > 100) in each collection
      final expensiveProduct1Items = await product1Repo.query(
        query: QueryByPriceGreaterThan(100.0),
      );
      final expensiveProduct2Items = await product2Repo.query(
        query: QueryByPriceGreaterThan(100.0),
      );

      // Verify queries only return items from their respective collections
      expect(expensiveProduct1Items, hasLength(1));
      expect(expensiveProduct1Items.first.id, equals('exp1'));
      expect(expensiveProduct1Items.first.price, equals(150.0));

      expect(expensiveProduct2Items, hasLength(1));
      expect(expensiveProduct2Items.first.id, equals('exp2'));
      expect(expensiveProduct2Items.first.price, equals(175.0));

      print('✅ Query operations isolated between collections');
    });

    test('should isolate streaming operations between collections', () async {
      const testId = 'stream_test';

      // Set up streams for both collections
      final product1Stream = product1Repo.streamQuery();
      final product2Stream = product2Repo.streamQuery();

      final product1Events = <List<ProductModel>>[];
      final product2Events = <List<ProductModel>>[];

      final subscription1 = product1Stream.listen(product1Events.add);
      final subscription2 = product2Stream.listen(product2Events.add);

      // Wait for initial empty events
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Add item to product_1 collection
      final product1 = ProductModel(
        id: testId,
        name: 'Stream Test Product 1',
        price: 30.0,
        description: 'Test streaming',
        created: DateTime.now(),
      );

      await product1Repo.add(IdentifiedObject(testId, product1));
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Add item to product_2 collection
      final product2 = ProductModel(
        id: testId,
        name: 'Stream Test Product 2',
        price: 40.0,
        description: 'Test streaming 2',
        created: DateTime.now(),
      );

      await product2Repo.add(IdentifiedObject(testId, product2));
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Verify each stream only received events for its collection
      expect(product1Events.length, greaterThanOrEqualTo(2)); // Initial empty + add
      expect(product2Events.length, greaterThanOrEqualTo(2)); // Initial empty + add

      // Latest events should contain only the items from their respective collections
      final latestProduct1Events = product1Events.last;
      final latestProduct2Events = product2Events.last;

      expect(latestProduct1Events, hasLength(1));
      expect(latestProduct1Events.first.name, equals('Stream Test Product 1'));

      expect(latestProduct2Events, hasLength(1));
      expect(latestProduct2Events.first.name, equals('Stream Test Product 2'));

      await subscription1.cancel();
      await subscription2.cancel();

      print('✅ Streaming operations isolated between collections');
    });
  });
}

// Simple UserModel for testing
class UserModel {
  final String id;
  final String name;
  final String email;
  final DateTime created;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.created,
  });
}