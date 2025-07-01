import 'package:kiss_repository_tests/kiss_repository_tests.dart';

import 'factories/drift_test_repository_factory.dart';

void main() {
  runRepositoryTests(
    implementationName: 'Drift',
    factoryProvider: DriftTestRepositoryFactory.new,
    cleanup: () {},
  );
}
