import 'package:kiss_drift_repository/src/sql_query_builder.dart';
import 'package:kiss_repository/kiss_repository.dart' as kiss;
import 'package:kiss_repository_tests/kiss_repository_tests.dart';

class DriftTestQueryBuilder extends SqlQueryBuilder<dynamic> {
  DriftTestQueryBuilder();

  @override
  SqlWhereClause? build(kiss.Query query) {
    if (query is QueryByName) {
      return SqlWhereClause("data LIKE ?", ['%"name":"${query.namePrefix}%']);
    }
    if (query is QueryByPriceGreaterThan) {
      return SqlWhereClause("CAST(JSON_EXTRACT(data, '\$.price') AS REAL) > ?", [query.price]);
    }
    if (query is QueryByPriceLessThan) {
      return SqlWhereClause("CAST(JSON_EXTRACT(data, '\$.price') AS REAL) < ?", [query.price]);
    }
    if (query is QueryByCreatedAfter) {
      return SqlWhereClause("created_at > ?", [query.date.millisecondsSinceEpoch]);
    }
    if (query is QueryByCreatedBefore) {
      return SqlWhereClause("created_at < ?", [query.date.millisecondsSinceEpoch]);
    }
    return null;
  }
}
