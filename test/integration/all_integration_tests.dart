import 'package:test/test.dart';

import 'custom_query_test.dart' as custom_query_tests;
import 'kiss_tests.dart' as kiss_tests;
import 'multi_collection_test.dart' as multi_collection_tests;

void main() {
  group('All Drift Integration Tests', () {
    // group('KISS Repository Tests', kiss_tests.main);
    // group('Multi-Collection Tests', multi_collection_tests.main);
    group('Custom Query Tests', custom_query_tests.main);
  });
}
