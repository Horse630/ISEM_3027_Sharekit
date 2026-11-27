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
      notifyListeners();
    } catch (_) {}
  }

  static String threadKey(String itemId, String client) => '$itemId::$client';

  Future<void> markItem(String itemId) => markThread(itemId, '');

  Future<void> markThread(String itemId, String client, {Iterable<int>? ids}) async {
    final key = threadKey(itemId, client);
    var latest = _reads[key] ?? 0;
    final source = ids ??
        messages.where((message) => message.itemId == itemId).map((message) => message.id);
    for (final id in source) {
      if (id > latest) latest = id;
    }
    _reads[key] = latest;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('sharekit_reads_$me', jsonEncode(_reads));
    } catch (_) {}
  }

  int unreadForThread(String itemId, String client, Iterable<ChatMessage> thread) {
    final seen = _reads[threadKey(itemId, client)] ?? 0;
    var count = 0;
    for (final message in thread) {
      if (message.sender != me && message.id > seen) count += 1;
    }
    return count;
  }

  void publishUnread(int value) {
    if (unread == value) return;
    unread = value;
    notifyListeners();
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
