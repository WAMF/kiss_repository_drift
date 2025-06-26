// ignore_for_file: public_member_api_docs

import 'package:kiss_repository/kiss_repository.dart';
import 'package:uuid/uuid.dart';

class DriftIdentifiedObject<T> extends IdentifiedObject<T> {
  DriftIdentifiedObject(T object, this._updateObjectWithId) : super('', object);

  factory DriftIdentifiedObject.create(T object, T Function(T object, String id) updateObjectWithId) =>
      DriftIdentifiedObject(object, updateObjectWithId);

  final T Function(T object, String id) _updateObjectWithId;
  final _uuid = const Uuid();
  String? _cachedId;
  T? _cachedUpdatedObject;

  @override
  String get id {
    _cachedId ??= _generateDriftId();
    return _cachedId!;
  }

  @override
  T get object {
    if (_cachedUpdatedObject == null) {
      final generatedId = id;
      _cachedUpdatedObject = _updateObjectWithId(super.object, generatedId);
    }
    return _cachedUpdatedObject!;
  }

  String _generateDriftId() => _uuid.v4();
}
