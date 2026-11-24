import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import 'catalog_gateway.dart';
import 'database_factory.dart';
import 'remote_api.dart';

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
  var _opened = false;
  var _useRemote = false;
  final _api = RemoteApi();
  final Map<String, Map<String, dynamic>> _remoteUsers = {};

  static const _sessionKey = 'sharekit_session_name';

  Future<void> open() async {
    if (_opened) return;
    if (databasePath == null) {
      _useRemote = true;
      await _seedRemoteDemo();
      _opened = true;
      return;
    }
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
    _opened = true;
  }

  Future<AppUser?> currentUser() async {
    if (_useRemote) return _remoteCurrentUser();
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
    if (_useRemote) return _remoteLogin(name: name, password: password);
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
    if (_useRemote) {
      return _remoteRegister(name: name, password: password, contact: contact);
    }
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
    if (_useRemote) return _remoteVerify(name: name, code: code);
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
    if (_useRemote) {
      return _remoteUpdateProfile(
        userId: userId,
        displayName: displayName,
        photo: photo,
      );
    }
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
    if (_useRemote) return _remoteJoinCommunity(userId);
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
    if (_useRemote) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionKey);
      return;
    }
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
    if (_useRemote) return _remoteMessages(itemId);
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
    if (_useRemote) {
      return _remoteSendMessage(itemId: itemId, sender: sender, body: body);
    }
    final text = body.trim();
    if (text.isEmpty) return;
    await _database.insert('messages', {
      'item_id': itemId,
      'sender': sender,
      'body': text,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _loadRemoteUsers() async {
    final rows = await _api.list('users');
    _remoteUsers
      ..clear()
      ..addEntries(
        rows.where((row) => row['name'] is String).map(
          (row) => MapEntry(row['name'] as String, row),
        ),
      );
  }

  Future<void> _seedRemoteDemo() async {
    await _loadRemoteUsers();
    if (_remoteUsers.containsKey(demoName)) return;
    final created = await _api.create('users', {
      'user_id': 1,
      'name': demoName,
      'password_hash': _hash(demoPassword),
      'created_at': DateTime.now().toIso8601String(),
      'contact': 'isem3027@sharekit.local',
      'verified': 1,
      'display_name': demoName,
      'community_joined': 1,
      'verify_code': '',
    });
    _remoteUsers[demoName] = created;
  }

  Future<void> _saveRemoteSession(String? name) async {
    final prefs = await SharedPreferences.getInstance();
    if (name == null || name.isEmpty) {
      await prefs.remove(_sessionKey);
    } else {
      await prefs.setString(_sessionKey, name);
    }
  }

  Future<AppUser?> _remoteCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_sessionKey);
    if (name == null || name.isEmpty) return null;
    await _loadRemoteUsers();
    final row = _remoteUsers[name];
    if (row == null) return null;
    return _userFromRemote(row);
  }

  Future<AppUser?> _remoteLogin({
    required String name,
    required String password,
  }) async {
    await _loadRemoteUsers();
    final row = _remoteUsers[name];
    if (row == null || row['password_hash'] != _hash(password)) return null;
    if (!_flag(row['verified'])) {
      throw AuthFailure('請先驗證電郵或電話。');
    }
    await _saveRemoteSession(name);
    return _userFromRemote(row);
  }

  Future<VerificationChallenge> _remoteRegister({
    required String name,
    required String password,
    required String contact,
  }) async {
    final trimmed = name.trim();
    final address = contact.trim();
    if (trimmed.isEmpty || password.isEmpty || address.isEmpty) {
      throw AuthFailure('請填名稱、密碼和電郵或電話。');
    }
    await _loadRemoteUsers();
    if (_remoteUsers.containsKey(trimmed)) {
      throw AuthFailure('這個名稱已經有人用了。');
    }
    final nextId = _remoteUsers.values.fold<int>(1, (highest, row) {
      final id = (row['user_id'] as num?)?.toInt() ?? 0;
      return id >= highest ? id + 1 : highest;
    });
    final code = _code();
    final created = await _api.create('users', {
      'user_id': nextId,
      'name': trimmed,
      'password_hash': _hash(password),
      'created_at': DateTime.now().toIso8601String(),
      'contact': address,
      'verified': 0,
      'display_name': trimmed,
      'community_joined': 0,
      'verify_code': code,
    });
    _remoteUsers[trimmed] = created;
    return VerificationChallenge(name: trimmed, contact: address, code: code);
  }

  Future<AppUser> _remoteVerify({
    required String name,
    required String code,
  }) async {
    await _loadRemoteUsers();
    final row = _remoteUsers[name];
    if (row == null) throw AuthFailure('找不到這個帳號。');
    if ((row['verify_code'] as String? ?? '') != code.trim()) {
      throw AuthFailure('驗證碼不對。');
    }
    row['verified'] = 1;
    row['verify_code'] = '';
    await _api.replace('users', row['_id'] as String, row);
    await _saveRemoteSession(name);
    return _userFromRemote(row);
  }

  Future<AppUser> _remoteUpdateProfile({
    required int userId,
    required String displayName,
    Uint8List? photo,
  }) async {
    final name = displayName.trim();
    if (name.isEmpty) throw AuthFailure('請填顯示名稱。');
    await _loadRemoteUsers();
    final row = _remoteById(userId);
    row['display_name'] = name;
    if (photo != null) {
      final shrunk = shrinkPhotoBytes(photo);
      row['photo'] = shrunk == null ? '' : base64Encode(shrunk);
    }
    await _api.replace('users', row['_id'] as String, row);
    return _userFromRemote(row);
  }

  Future<AppUser> _remoteJoinCommunity(int userId) async {
    await _loadRemoteUsers();
    final row = _remoteById(userId);
    row['community_joined'] = 1;
    await _api.replace('users', row['_id'] as String, row);
    return _userFromRemote(row);
  }

  Map<String, dynamic> _remoteById(int userId) {
    for (final row in _remoteUsers.values) {
      if ((row['user_id'] as num?)?.toInt() == userId) return row;
    }
    throw AuthFailure('找不到這個帳號。');
  }

  Future<List<ChatMessage>> _remoteMessages(String itemId) async {
    final rows = await _api.list('messages');
    final messages = [
      for (final row in rows)
        if (row['item_id'] == itemId)
          ChatMessage(
            id: (row['message_id'] as num?)?.toInt() ?? 0,
            itemId: itemId,
            sender: (row['sender'] as String?) ?? '',
            body: (row['body'] as String?) ?? '',
            createdAt: DateTime.tryParse(row['created_at'] as String? ?? '') ??
                DateTime.now(),
          ),
    ]..sort((a, b) => a.id.compareTo(b.id));
    return messages;
  }

  Future<void> _remoteSendMessage({
    required String itemId,
    required String sender,
    required String body,
  }) async {
    final text = body.trim();
    if (text.isEmpty) return;
    await _api.create('messages', {
      'message_id': DateTime.now().millisecondsSinceEpoch,
      'item_id': itemId,
      'sender': sender,
      'body': text,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  AppUser _userFromRemote(Map<String, dynamic> row) {
    return AppUser(
      id: (row['user_id'] as num?)?.toInt() ?? 0,
      name: row['name'] as String,
      displayName: (row['display_name'] as String?) ?? row['name'] as String,
      contact: (row['contact'] as String?) ?? '',
      verified: _flag(row['verified']),
      communityJoined: _flag(row['community_joined']),
      photo: _photoOf(row['photo']),
    );
  }

  bool _flag(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    return false;
  }

  Uint8List? _photoOf(Object? photo) {
    if (photo == null || photo == '') return null;
    if (photo is Uint8List) return photo;
    if (photo is List) return Uint8List.fromList(photo.cast<int>());
    if (photo is String) return base64Decode(photo);
    return null;
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
