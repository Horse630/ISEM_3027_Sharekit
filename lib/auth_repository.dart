import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'database_factory.dart';

class AuthFailure implements Exception {
  AuthFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.displayName,
    required this.contact,
    required this.verified,
    required this.communityJoined,
    this.photo,
  });

  final int id;
  final String name;
  final String displayName;
  final String contact;
  final bool verified;
  final bool communityJoined;
  final Uint8List? photo;

  String get label => displayName.trim().isEmpty ? name : displayName.trim();
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.itemId,
    required this.sender,
    required this.body,
    required this.createdAt,
  });

  final int id;
  final String itemId;
  final String sender;
  final String body;
  final DateTime createdAt;
}

class VerificationChallenge {
  const VerificationChallenge({
    required this.name,
    required this.contact,
    required this.code,
  });

  final String name;
  final String contact;
  final String code;
}

class AuthRepository {
  AuthRepository({this.databasePath});

  static const demoName = 'Isem_3027';
  static const demoPassword = 'Isem_3027';

  final String? databasePath;
  Database? _db;

  Future<void> open() async {
    if (_db != null) return;
    configureDatabase();
    final path = databasePath ??
        p.join(await getDatabasesPath(), 'sharekit.db');
    _db = await openDatabase(
      path,
      version: 4,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE,
            password_hash TEXT NOT NULL,
            created_at TEXT NOT NULL,
            contact TEXT,
            verified INTEGER NOT NULL DEFAULT 0,
            display_name TEXT,
            community_joined INTEGER NOT NULL DEFAULT 0,
            photo BLOB
          )
        ''');
        await db.execute('''
          CREATE TABLE sessions (
            id INTEGER PRIMARY KEY CHECK (id = 1),
            user_id INTEGER NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE verification_codes (
            user_id INTEGER PRIMARY KEY,
            code TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');
        await _createMessages(db);
        await _createCatalog(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE users ADD COLUMN contact TEXT');
          await db.execute(
            'ALTER TABLE users ADD COLUMN verified INTEGER NOT NULL DEFAULT 0',
          );
          await db.execute('ALTER TABLE users ADD COLUMN display_name TEXT');
          await db.execute(
            'ALTER TABLE users ADD COLUMN community_joined INTEGER NOT NULL DEFAULT 0',
          );
          await db.execute('ALTER TABLE users ADD COLUMN photo BLOB');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS verification_codes (
              user_id INTEGER PRIMARY KEY,
              code TEXT NOT NULL,
              created_at TEXT NOT NULL
            )
          ''');
        }
        if (oldVersion < 3) await _createMessages(db);
        if (oldVersion < 4) await _createCatalog(db);
      },
    );
    await _seedDemoAccount();
    await _markDemoReady();
  }

  Future<AppUser?> currentUser() async {
    final db = _database;
    final rows = await db.rawQuery('''
      SELECT users.id, users.name, users.display_name, users.contact,
             users.verified, users.community_joined, users.photo
      FROM sessions
      JOIN users ON users.id = sessions.user_id
      WHERE sessions.id = 1
    ''');
    if (rows.isEmpty) return null;
    return _userFrom(rows.first);
  }

  Future<AppUser?> login({
    required String name,
    required String password,
  }) async {
    final db = _database;
    final rows = await db.query(
      'users',
      where: 'name = ?',
      whereArgs: [name],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    if (row['password_hash'] != _hash(password)) return null;
    if ((row['verified'] as int? ?? 0) != 1) {
      throw AuthFailure('請先驗證電郵或電話。');
    }
    final user = _userFrom(row);
    await db.insert(
      'sessions',
      {
        'id': 1,
        'user_id': user.id,
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return user;
  }

  Future<VerificationChallenge> register({
    required String name,
    required String password,
    required String contact,
  }) async {
    final trimmed = name.trim();
    final address = contact.trim();
    if (trimmed.isEmpty || password.isEmpty || address.isEmpty) {
      throw AuthFailure('請填名稱、密碼和電郵或電話。');
    }
    final db = _database;
    final existing = await db.query(
      'users',
      columns: ['id'],
      where: 'name = ?',
      whereArgs: [trimmed],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      throw AuthFailure('這個名稱已經有人用了。');
    }
    final id = await db.insert('users', {
      'name': trimmed,
      'password_hash': _hash(password),
      'created_at': DateTime.now().toIso8601String(),
      'contact': address,
      'verified': 0,
      'display_name': trimmed,
      'community_joined': 0,
    });
    final code = _code();
    await db.insert('verification_codes', {
      'user_id': id,
      'code': code,
      'created_at': DateTime.now().toIso8601String(),
    });
    return VerificationChallenge(name: trimmed, contact: address, code: code);
  }

  Future<AppUser> verify({required String name, required String code}) async {
    final db = _database;
    final rows = await db.query(
      'users',
      where: 'name = ?',
      whereArgs: [name],
      limit: 1,
    );
    if (rows.isEmpty) throw AuthFailure('找不到這個帳號。');
    final userId = rows.first['id'] as int;
    final codes = await db.query(
      'verification_codes',
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (codes.isEmpty || codes.first['code'] != code.trim()) {
      throw AuthFailure('驗證碼不對。');
    }
    await db.update(
      'users',
      {'verified': 1},
      where: 'id = ?',
      whereArgs: [userId],
    );
    await db.delete('verification_codes', where: 'user_id = ?', whereArgs: [userId]);
    final updated = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    final user = _userFrom(updated.first);
    await db.insert(
      'sessions',
      {
        'id': 1,
        'user_id': user.id,
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return user;
  }

  Future<AppUser> updateProfile({
    required int userId,
    required String displayName,
    Uint8List? photo,
  }) async {
    final name = displayName.trim();
    if (name.isEmpty) throw AuthFailure('請填顯示名稱。');
    final values = <String, Object?>{'display_name': name};
    if (photo != null) values['photo'] = photo;
    await _database.update('users', values, where: 'id = ?', whereArgs: [userId]);
    final rows = await _database.query(
      'users',
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    return _userFrom(rows.first);
  }

  Future<AppUser> joinCommunity(int userId) async {
    await _database.update(
      'users',
      {'community_joined': 1},
      where: 'id = ?',
      whereArgs: [userId],
    );
    final rows = await _database.query(
      'users',
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    return _userFrom(rows.first);
  }

  Future<void> logout() async {
    await _database.delete('sessions', where: 'id = 1');
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  Database get database => _database;

  Database get _database {
    final db = _db;
    if (db == null) {
      throw StateError('資料庫尚未開啟');
    }
    return db;
  }

  static Future<void> _createCatalog(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS items (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        owner TEXT NOT NULL,
        category TEXT NOT NULL,
        condition TEXT NOT NULL,
        distance_meters INTEGER NOT NULL,
        summary TEXT NOT NULL,
        rating REAL NOT NULL,
        review_count INTEGER NOT NULL,
        handovers INTEGER NOT NULL,
        daily_price REAL,
        photo BLOB,
        address TEXT NOT NULL,
        handover TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS bookings (
        id TEXT PRIMARY KEY,
        item_id TEXT NOT NULL,
        start_date TEXT NOT NULL,
        end_date TEXT NOT NULL,
        stage TEXT NOT NULL,
        pickup_code TEXT NOT NULL,
        note TEXT NOT NULL,
        deposit TEXT NOT NULL,
        return_condition TEXT,
        stars INTEGER,
        comment TEXT,
        issue TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS catalog_meta (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        sequence INTEGER NOT NULL
      )
    ''');
  }

  static Future<void> _createMessages(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        item_id TEXT NOT NULL,
        sender TEXT NOT NULL,
        body TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
  }

  Future<List<ChatMessage>> messagesFor(String itemId) async {
    final rows = await _database.query(
      'messages',
      where: 'item_id = ?',
      whereArgs: [itemId],
      orderBy: 'id ASC',
    );
    return [
      for (final row in rows)
        ChatMessage(
          id: row['id'] as int,
          itemId: row['item_id'] as String,
          sender: row['sender'] as String,
          body: row['body'] as String,
          createdAt: DateTime.parse(row['created_at'] as String),
        ),
    ];
  }

  Future<void> sendMessage({
    required String itemId,
    required String sender,
    required String body,
  }) async {
    final text = body.trim();
    if (text.isEmpty) return;
    await _database.insert('messages', {
      'item_id': itemId,
      'sender': sender,
      'body': text,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _seedDemoAccount() async {
    final db = _database;
    final existing = await db.query(
      'users',
      columns: ['id'],
      where: 'name = ?',
      whereArgs: [demoName],
      limit: 1,
    );
    if (existing.isNotEmpty) return;
    await db.insert('users', {
      'name': demoName,
      'password_hash': _hash(demoPassword),
      'created_at': DateTime.now().toIso8601String(),
      'contact': 'isem3027@sharekit.local',
      'verified': 1,
      'display_name': demoName,
      'community_joined': 1,
    });
  }

  Future<void> _markDemoReady() async {
    await _database.update(
      'users',
      {
        'verified': 1,
        'community_joined': 1,
        'display_name': demoName,
        'contact': 'isem3027@sharekit.local',
      },
      where: 'name = ?',
      whereArgs: [demoName],
    );
  }

  AppUser _userFrom(Map<String, Object?> row) {
    final photo = row['photo'];
    return AppUser(
      id: row['id'] as int,
      name: row['name'] as String,
      displayName: (row['display_name'] as String?) ?? row['name'] as String,
      contact: (row['contact'] as String?) ?? '',
      verified: (row['verified'] as int? ?? 0) == 1,
      communityJoined: (row['community_joined'] as int? ?? 0) == 1,
      photo: photo is Uint8List ? photo : null,
    );
  }

  String _code() {
    final value = Random().nextInt(900000) + 100000;
    return value.toString();
  }

  static String _hash(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }
}
