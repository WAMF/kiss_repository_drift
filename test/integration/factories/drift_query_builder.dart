import 'package:kiss_repository/kiss_repository.dart';
import 'package:kiss_repository_tests/kiss_repository_tests.dart';

typedef ObjectFilter<T> = bool Function(T object);

class DriftQueryBuilder implements QueryBuilder<ObjectFilter<ProductModel>?> {
  @override
  ObjectFilter<ProductModel>? build(Query query) {
    switch (query.runtimeType) {
      case QueryByName:
        final nameQuery = query as QueryByName;
        return (product) => product.name.toLowerCase().contains(nameQuery.namePrefix.toLowerCase());

      case QueryByPriceGreaterThan:
        final priceQuery = query as QueryByPriceGreaterThan;
        return (product) => product.price > priceQuery.price;

      case QueryByPriceLessThan:
        final priceQuery = query as QueryByPriceLessThan;
        return (product) => product.price < priceQuery.price;

      case QueryByCreatedAfter:
        final dateQuery = query as QueryByCreatedAfter;
        return (product) => product.created.isAfter(dateQuery.date);

      case QueryByCreatedBefore:
        final dateQuery = query as QueryByCreatedBefore;
        return (product) => product.created.isBefore(dateQuery.date);

      default:
        return null;
    }
  }
}
