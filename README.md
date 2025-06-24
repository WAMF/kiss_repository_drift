# KISS Drift Repository

A [Drift](https://drift.simonbinder.eu/) (SQLite) implementation of the [KISS Repository](https://github.com/WAMF/kiss_repository) interface. This package provides a local, embedded database solution using SQLite with Drift's type-safe query builder.

## Features

- ✅ **Embedded SQLite Database** - No external server required
- ✅ **Type-Safe Queries** - Drift's compile-time query validation
- ✅ **Fast Local Storage** - SQLite performance with in-memory or file-based storage
- ✅ **Cross-Platform** - Works on all Dart/Flutter platforms
- ✅ **Auto-Generated Code** - Drift handles table definitions and queries
- ✅ **ACID Transactions** - Full SQLite transaction support

## Installation

Add this package to your `pubspec.yaml`:

```yaml
dependencies:
  kiss_drift_repository: ^0.1.0
  
dev_dependencies:
  drift_dev: ^2.27.0
  build_runner: ^2.4.0
```

## Usage

```dart
import 'package:kiss_drift_repository/kiss_drift_repository.dart';

// Create repository with file-based storage
final repository = await RepositoryDrift.create<MyModel>(
  tableName: 'my_models',
  databasePath: 'my_app.db', // Or ':memory:' for in-memory
  toDrift: (model) => {
    'id': model.id,
    'name': model.name,
    'data': model.data,
  },
  fromDrift: (json) => MyModel(
    id: json['id'] as String,
    name: json['name'] as String,
    data: json['data'] as String,
  ),
  queryBuilder: MyQueryBuilder(),
);

// Use standard Repository interface
final item = await repository.add(IdentifiedObject('1', myModel));
final retrieved = await repository.get('1');
```

## Development Setup

### Prerequisites
- Dart SDK 3.8.0 or higher
- No external database server required!

### Running Tests

Drift uses embedded SQLite, so no external emulator is needed:

```bash
# Install dependencies and generate code
./scripts/run_tests.sh
```

Or manually:
```bash
dart pub get
dart run build_runner build --delete-conflicting-outputs
dart test
```

## Architecture

- **Storage**: SQLite database (file-based or in-memory)
- **ORM**: Drift for type-safe database operations
- **Code Generation**: Drift generates table definitions and queries
- **Transactions**: Full ACID transaction support via SQLite

## License

MIT License - see [LICENSE](LICENSE) file for details.
