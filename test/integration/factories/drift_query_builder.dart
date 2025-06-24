import 'package:kiss_repository/kiss_repository.dart';
import 'package:kiss_repository_tests/kiss_repository_tests.dart';

class DriftQueryBuilder implements QueryBuilder<String> {
  @override
  String build(Query query) {
    switch (query.runtimeType) {
      case QueryByName:
        final nameQuery = query as QueryByName;
        return '"name":"${nameQuery.namePrefix}';
      case QueryByPriceGreaterThan:
        final priceQuery = query as QueryByPriceGreaterThan;
        return '"price":${priceQuery.price}';
      case QueryByPriceLessThan:
        final priceQuery = query as QueryByPriceLessThan;
        return '"price":${priceQuery.price}';
      case QueryByCreatedAfter:
        final dateQuery = query as QueryByCreatedAfter;
        return '"created":"${dateQuery.date.toIso8601String()}';
      case QueryByCreatedBefore:
        final dateQuery = query as QueryByCreatedBefore;
        return '"created":"${dateQuery.date.toIso8601String()}';
      default:
        return '';
    }
  }
}
