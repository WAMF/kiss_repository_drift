# Kiss Drift Repository

A Drift implementation of the `kiss_repository` interface for local SQLite database storage.

## Platform Support

✅ **Supported Platforms:**
- iOS
- Android  
- macOS
- Windows
- Linux
- **Web** (requires manual WASM setup)

📡 **Web Setup:**
On web platforms, you need to include SQLite WASM files in your `web/` directory:

**Required files:**
- `sqlite3.wasm` - Download from [sqlite3.dart releases](https://github.com/simolus3/sqlite3.dart/releases)
- `drift_worker.dart.js` - Compile manually (see setup below)

**Setup steps:**
1. Download `sqlite3.wasm`:
   ```bash
   curl -L -o web/sqlite3.wasm https://github.com/simolus3/sqlite3.dart/releases/latest/download/sqlite3.wasm
   ```

2. Create `web/drift_worker.dart`:
   ```dart
   import 'package:drift/wasm.dart';
   
   void main() => WasmDatabase.workerMainForOpen();
   ```

3. Compile the worker:
   ```bash
   dart compile js -O4 web/drift_worker.dart -o web/drift_worker.dart.js
   ```

**Alternative:** For easier web support without manual setup, consider using `kiss_firebase_repository` or `kiss_pocketbase_repository`.

## Features

- Local SQLite database with cross-platform support
- Type-safe operations and real-time streaming
- Collection-based data isolation with multiple repository instances
- Automatic table creation and batch operations
- Complete CRUD operations with streaming support

### 📡 Streaming Architecture
- ⚠️ **In-Process Streaming**: SQLite triggers - single application instance only
- ✅ **Local Real-time**: Changes trigger Dart streams within the same process
- ❌ **Multi-Instance**: Updates from other processes/servers are not streamed
- ✅ **Perfect for**: Single-instance desktop/mobile apps, local development
- ❌ **Not suitable for**: Multi-server web applications, microservices with shared data

**Multi-Instance Alternatives**: If you need real-time streaming across multiple server instances:
- `kiss_firebase_repository` - Server-side real-time listeners
- `kiss_pocketbase_repository` - WebSocket-based real-time subscriptions

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  kiss_drift_repository: ^0.1.0
```

## Usage

```dart
import 'package:kiss_drift_repository/kiss_drift_repository.dart';

// Create repository
final repository = await RepositoryDrift.create<MyModel>(
  tableName: 'my_models',
  toDrift: (model) => model.toJson(),
  fromDrift: (json) => MyModel.fromJson(json),
);

// Use standard kiss_repository interface
await repository.add(IdentifiedObject('id1', myModel));
final model = await repository.get('id1');
```

## Development

Run tests:
```bash
./scripts/run_tests.sh
```

## License

This project is licensed under the MIT License.
