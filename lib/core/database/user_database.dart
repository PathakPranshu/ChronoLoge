import 'package:sqflite_sqlcipher/sqflite.dart';
import 'app_database.dart';
import 'database_constants.dart';

class UserDatabase {
  const UserDatabase(this._appDatabase);
  
  final AppDatabase _appDatabase;

  // Inserts or updates the user profile in the local SQLite database
  Future<void> upsertUser({
    required String userId,
    required String name,
    required String email,
  }) async {
    final database = await _appDatabase.database;
    
    await database.insert(
      UserTable.name,
      {
        UserTable.userId: userId,
        UserTable.nameCol: name,
        UserTable.email: email,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Retrieves the local user profile
  Future<Map<String, Object?>?> getUser() async {
    final database = await _appDatabase.database;
    final rows = await database.query(
      UserTable.name,
      limit: 1,
    );
    
    if (rows.isEmpty) return null;
    return rows.single;
  }
}