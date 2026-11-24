import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_repository.dart';

class ChatScope extends InheritedWidget {
  const ChatScope({super.key, required this.chat, required super.child});

  final ChatCenter chat;

  static ChatCenter? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ChatScope>()?.chat;
  }

  @override
  bool updateShouldNotify(ChatScope oldWidget) => oldWidget.chat != chat;
}

class ChatCenter extends ChangeNotifier {
  AuthRepository? _auth;
  String me = '';
  List<ChatMessage> messages = const [];
  int unread = 0;
  Map<String, int> _reads = {};
  Timer? _timer;
  Future<void> _tail = Future<void>.value();

  Future<void> bind(AuthRepository auth, String name) async {
    _auth = auth;
    me = name;
    _timer?.cancel();
    await refresh();
    _timer = Timer.periodic(const Duration(seconds: 6), (_) => refresh());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> refresh() {
    _tail = _tail.catchError((Object _) {}).then((_) => _pull());
    return _tail;
  }

  Future<void> _pull() async {
    final auth = _auth;
    if (auth == null || me.isEmpty) return;
    try {
      _reads = await _loadReads();
      messages = await auth.allMessages();
      unread = _count();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> markItem(String itemId) async {
    var latest = _reads[itemId] ?? 0;
    for (final message in messages) {
      if (message.itemId == itemId && message.id > latest) latest = message.id;
    }
    _reads[itemId] = latest;
    unread = _count();
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('sharekit_reads_$me', jsonEncode(_reads));
    } catch (_) {}
  }

  int unreadFor(String itemId) {
    final seen = _reads[itemId] ?? 0;
    var count = 0;
    for (final message in messages) {
      if (message.itemId == itemId &&
          message.sender != me &&
          message.id > seen) {
        count += 1;
      }
    }
    return count;
  }

  int _count() {
    final items = messages.map((message) => message.itemId).toSet();
    var total = 0;
    for (final itemId in items) {
      total += unreadFor(itemId);
    }
    return total;
  }

  Future<Map<String, int>> _loadReads() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('sharekit_reads_$me');
      if (raw == null || raw.isEmpty) return {};
      final data = jsonDecode(raw);
      if (data is! Map) return {};
      return {
        for (final entry in data.entries)
          entry.key.toString(): (entry.value as num?)?.toInt() ?? 0,
      };
    } catch (_) {
      return {};
    }
  }
}
