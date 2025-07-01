import 'package:drift/drift.dart';
import 'package:kiss_repository/kiss_repository.dart' as kiss;
import 'package:kiss_repository_tests/kiss_repository_tests.dart';

class DriftTestQueryBuilder implements kiss.QueryBuilder<Expression<bool>?> {
  const DriftTestQueryBuilder();

  @override
  Expression<bool>? build(kiss.Query query) {
    if (query is QueryByName) {
      return CustomExpression("data LIKE '%\"name\":\"${query.namePrefix}%'");
    }
    if (query is QueryByPriceGreaterThan) {
      return CustomExpression("CAST(JSON_EXTRACT(data, '\$.price') AS REAL) > ${query.price}");
    }
    if (query is QueryByPriceLessThan) {
      return CustomExpression("CAST(JSON_EXTRACT(data, '\$.price') AS REAL) < ${query.price}");
    }
    if (query is QueryByCreatedAfter) {
      return CustomExpression("created_at > '${query.date.toIso8601String()}'");
    }
    if (query is QueryByCreatedBefore) {
      return CustomExpression("created_at < '${query.date.toIso8601String()}'");
    }
    return null;
  }
}
