import 'package:flutter/material.dart';

import 'auth_repository.dart';
import 'chat_center.dart';
import 'chat_page.dart';
import 'store.dart';
import 'text.dart';

class ChatsPage extends StatelessWidget {
  const ChatsPage({
    super.key,
    required this.center,
    required this.store,
    required this.auth,
    required this.user,
  });

  final ChatCenter center;
  final ShareStore store;
  final AuthRepository auth;
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListenableBuilder(
        listenable: center,
        builder: (context, _) {
          final threads = _threads();
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              Text(
                tr(context, '聊天', 'Chats'),
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                tr(
                  context,
                  '跟物主約交接時間，未讀訊息會標在下面。',
                  'Arrange a handover. Unread messages show a badge.',
                ),
                style: const TextStyle(color: Color(0xFF5E6A64)),
              ),
              const SizedBox(height: 16),
              if (threads.isEmpty)
                Text(
                  tr(
                    context,
                    '還沒有對話。打開一件物品，按「聯絡物主」。',
                    'No chats yet. Open an item and tap Message.',
                  ),
                )
              else
                for (final thread in threads) ...[
                  _ThreadTile(
                    thread: thread,
                    store: store,
                    auth: auth,
                    user: user,
                    center: center,
                  ),
                  const SizedBox(height: 10),
                ],
            ],
          );
        },
      ),
    );
  }

  List<_Thread> _threads() {
    final grouped = <String, List<ChatMessage>>{};
    for (final message in center.messages) {
      grouped.putIfAbsent(message.itemId, () => []).add(message);
    }
    final threads = [
      for (final entry in grouped.entries)
        _Thread(
          itemId: entry.key,
          messages: entry.value,
          unread: center.unreadFor(entry.key),
        ),
    ];
    threads.sort((a, b) => b.latest.id.compareTo(a.latest.id));
    return threads;
  }
}

class _Thread {
  _Thread({
    required this.itemId,
    required this.messages,
    required this.unread,
  });

  final String itemId;
  final List<ChatMessage> messages;
  final int unread;

  ChatMessage get latest => messages.last;
}

class _ThreadTile extends StatelessWidget {
  const _ThreadTile({
    required this.thread,
    required this.store,
    required this.auth,
    required this.user,
    required this.center,
  });

  final _Thread thread;
  final ShareStore store;
  final AuthRepository auth;
  final AppUser user;
  final ChatCenter center;

  @override
  Widget build(BuildContext context) {
    final item = store.findItem(thread.itemId);
    final title = item?.name ?? tr(context, '已下架的物品', 'Removed item');
    final owner = item?.owner ?? '';
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () async {
          await center.markItem(thread.itemId);
          if (!context.mounted) return;
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ChatPage(
                auth: auth,
                itemId: thread.itemId,
                itemName: title,
                ownerName: owner,
                senderName: user.label,
                center: center,
              ),
            ),
          );
          await center.refresh();
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFF0E6B52).withValues(alpha: 0.12),
                child: const Icon(
                  Icons.chat_bubble_outline,
                  color: Color(0xFF0E6B52),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${thread.latest.sender}：${thread.latest.body}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFF5E6A64)),
                    ),
                  ],
                ),
              ),
              if (thread.unread > 0)
                Badge(
                  label: Text('${thread.unread}'),
                  backgroundColor: const Color(0xFF9A4632),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
