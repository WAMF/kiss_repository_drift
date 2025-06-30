import 'package:test/test.dart';
import 'package:kiss_repository_tests/kiss_repository_tests.dart';
import 'factories/drift_repository_factory.dart';

void main() {
  group('Drift Stream Investigation Tests', () {
    late DriftRepositoryFactory factory;

    setUp(() {
      factory = DriftRepositoryFactory();
    });

    tearDown(() async {
      await factory.cleanup();
      factory.dispose();
    });

    test('Hypothesis 1: UPDATE operation triggers stream emission (no query builder)', () async {
      final repository = await factory.createRepository();

      // Use AllQuery (no custom query builder involved)
      final stream = repository.streamQuery();
      final emissions = <List<ProductModel>>[];

      final subscription = stream.listen((data) {
        print('📡 Stream emission ${emissions.length + 1}: ${data.length} items');
        emissions.add(data);
      });

      await Future.delayed(Duration(milliseconds: 100));

      print('🔄 Adding first product...');
      final product1 = await repository.addAutoIdentified(
        ProductModel.create(name: 'Product 1', price: 9.99),
        updateObjectWithId: (object, id) => object.copyWith(id: id),
      );

      await Future.delayed(Duration(milliseconds: 100));

      print('🔄 Updating first product...');
      await repository.update(product1.id, (current) => current.copyWith(name: 'Updated Product 1'));

      await Future.delayed(Duration(milliseconds: 100));

      await subscription.cancel();

      print('📊 Total emissions: ${emissions.length}');
      print('📊 Expected: 3 (empty, add, update)');

      expect(emissions.length, equals(3), reason: 'Should emit: empty list, after add, after update');
      if (emissions.length >= 3) {
        expect(emissions[0].length, equals(0));
        expect(emissions[1].length, equals(1));
        expect(emissions[1][0].name, equals('Product 1'));
        expect(emissions[2].length, equals(1));
        expect(emissions[2][0].name, equals('Updated Product 1'));
      }
    });

    test('Hypothesis 2: Multiple rapid operations without delays', () async {
      final repository = await factory.createRepository();

      final stream = repository.streamQuery();
      final emissions = <List<ProductModel>>[];

      final subscription = stream.listen((data) {
        print('📡 Rapid emission ${emissions.length + 1}: ${data.length} items');
        emissions.add(data);
      });

      await Future.delayed(Duration(milliseconds: 100));

      print('🔄 Rapid operations without delays...');

      // Do operations rapidly without delays
      final product1 = await repository.addAutoIdentified(
        ProductModel.create(name: 'Product 1', price: 9.99),
        updateObjectWithId: (object, id) => object.copyWith(id: id),
      );

      final product2 = await repository.addAutoIdentified(
        ProductModel.create(name: 'Product 2', price: 9.99),
        updateObjectWithId: (object, id) => object.copyWith(id: id),
      );

      await repository.update(product1.id, (current) => current.copyWith(name: 'Updated Product 1'));

      await Future.delayed(Duration(milliseconds: 200));

      await subscription.cancel();

      print('📊 Total emissions: ${emissions.length}');
      print('📊 Expected: 4 (empty, add1, add2, update)');

      // This will help us see if rapid operations cause batching
      expect(emissions.length, greaterThanOrEqualTo(1));
    });

    test('Hypothesis 3: With longer delays between operations', () async {
      final repository = await factory.createRepository();

      final stream = repository.streamQuery();
      final emissions = <List<ProductModel>>[];

      final subscription = stream.listen((data) {
        print('📡 Delayed emission ${emissions.length + 1}: ${data.length} items');
        emissions.add(data);
      });

      await Future.delayed(Duration(milliseconds: 100));

      print('🔄 Operations with longer delays...');

      final product1 = await repository.addAutoIdentified(
        ProductModel.create(name: 'Product 1', price: 9.99),
        updateObjectWithId: (object, id) => object.copyWith(id: id),
      );

      await Future.delayed(Duration(milliseconds: 500)); // Longer delay

      final product2 = await repository.addAutoIdentified(
        ProductModel.create(name: 'Product 2', price: 9.99),
        updateObjectWithId: (object, id) => object.copyWith(id: id),
      );

      await Future.delayed(Duration(milliseconds: 500)); // Longer delay

      await repository.update(product1.id, (current) => current.copyWith(name: 'Updated Product 1'));

      await Future.delayed(Duration(milliseconds: 500));

      await subscription.cancel();

      print('📊 Total emissions: ${emissions.length}');
      print('📊 Expected: 4 (empty, add1, add2, update)');

      expect(emissions.length, equals(4), reason: 'With delays, should get all 4 emissions');
    });

    test('Hypothesis 4: Direct database operations vs repository operations', () async {
      final repository = await factory.createRepository();

      final stream = repository.streamQuery();
      final emissions = <List<ProductModel>>[];

      final subscription = stream.listen((data) {
        print('📡 Direct DB emission ${emissions.length + 1}: ${data.length} items');
        emissions.add(data);
      });

      await Future.delayed(Duration(milliseconds: 100));

      print('🔄 Testing direct vs repository operations...');

      // Add through repository
      final product1 = await repository.addAutoIdentified(
        ProductModel.create(name: 'Product 1', price: 9.99),
        updateObjectWithId: (object, id) => object.copyWith(id: id),
      );

      await Future.delayed(Duration(milliseconds: 200));

      // Update through repository
      await repository.update(product1.id, (current) => current.copyWith(name: 'Updated Product 1'));

      await Future.delayed(Duration(milliseconds: 200));

      await subscription.cancel();

      print('📊 Total emissions: ${emissions.length}');

      expect(emissions.length, greaterThanOrEqualTo(2));
    });

    test('Hypothesis 5: Single operation at a time to isolate issue', () async {
      final repository = await factory.createRepository();

      print('🔄 Testing single ADD operation...');

      var stream = repository.streamQuery();
      var emissions = <List<ProductModel>>[];

      var subscription = stream.listen((data) {
        print('📡 ADD emission ${emissions.length + 1}: ${data.length} items');
        emissions.add(data);
      });

      await Future.delayed(Duration(milliseconds: 100));

      final product1 = await repository.addAutoIdentified(
        ProductModel.create(name: 'Product 1', price: 9.99),
        updateObjectWithId: (object, id) => object.copyWith(id: id),
      );

      await Future.delayed(Duration(milliseconds: 200));
      await subscription.cancel();

      print('📊 ADD emissions: ${emissions.length} (expected: 2)');
      expect(emissions.length, equals(2)); // empty + after add

      print('🔄 Testing single UPDATE operation...');

      stream = repository.streamQuery();
      emissions = <List<ProductModel>>[];

      subscription = stream.listen((data) {
        print('📡 UPDATE emission ${emissions.length + 1}: ${data.length} items');
        emissions.add(data);
      });

      await Future.delayed(Duration(milliseconds: 100));

      await repository.update(product1.id, (current) => current.copyWith(name: 'Updated Product 1'));

      await Future.delayed(Duration(milliseconds: 200));
      await subscription.cancel();

      print('📊 UPDATE emissions: ${emissions.length} (expected: 2)');
      expect(emissions.length, equals(2)); // current state + after update
    });
  });
}
