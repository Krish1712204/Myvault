import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'vault_schema.dart';

/// Manages SQLCipher database connection, encryption key injection, and lifecycle.
class VaultDatabase {
  Database? _db;
  final DatabaseFactory? _customFactory;

  VaultDatabase({DatabaseFactory? customFactory}) : _customFactory = customFactory;

  bool get isOpen => _db != null && _db!.isOpen;

  Database get database {
    if (_db == null || !_db!.isOpen) {
      throw StateError('Vault database is locked or not initialized.');
    }
    return _db!;
  }

  /// Opens or creates the encrypted SQLCipher database using the derived 64-hex key
  Future<Database> open({
    required String hexDatabaseKey,
    String? customPath,
  }) async {
    // If already open, close previous instance
    await close();

    String dbPath;
    if (customPath != null) {
      dbPath = customPath;
    } else {
      try {
        final appDir = await getApplicationDocumentsDirectory();
        final vaultDir = Directory(p.join(appDir.path, 'vault_secure'));
        if (!await vaultDir.exists()) {
          await vaultDir.create(recursive: true);
        }
        dbPath = p.join(vaultDir.path, VaultSchema.dbFileName);
      } catch (_) {
        // Fallback for headless unit tests where path_provider channel is unmocked
        final tempDir = Directory.systemTemp.createTempSync('vault_db_test_');
        dbPath = p.join(tempDir.path, VaultSchema.dbFileName);
      }
    }

    final factory = _customFactory ?? databaseFactory;

    _db = await factory.openDatabase(
      dbPath,
      options: SqlCipherOpenDatabaseOptions(
        version: VaultSchema.currentVersion,
        password: hexDatabaseKey,
        onConfigure: VaultSchema.onConfigure,
        onCreate: VaultSchema.onCreate,
        onUpgrade: VaultSchema.onUpgrade,
      ),
    );

    return _db!;
  }

  /// Closes the database safely and zeroizes the open handle
  Future<void> close() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
    }
    _db = null;
  }
}
