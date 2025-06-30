import 'package:test/test.dart';

import 'kiss_tests.dart' as kiss_tests;

void main() {
  group('All Drift Integration Tests', () {
    group('KISS Repository Tests', kiss_tests.main);
  });
}
