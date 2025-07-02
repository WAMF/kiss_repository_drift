// ignore_for_file: public_member_api_docs

import 'package:kiss_repository/kiss_repository.dart' as kiss;

/// Represents a SQL WHERE clause with arguments
class SqlWhereClause {
  const SqlWhereClause(this.clause, this.args);
  
  final String clause;
  final List<Object?> args;
}

/// Base class for query builders that generate SQL WHERE clauses
abstract class SqlQueryBuilder<T> implements kiss.QueryBuilder<SqlWhereClause?> {
  @override
  SqlWhereClause? build(kiss.Query query);
}