import 'package:flutter/material.dart';

import 'auth_repository.dart';
import 'chat_center.dart';
import 'chat_page.dart';
import 'store.dart';
import 'text.dart';

String _preview(BuildContext context, ChatMessage message) {
  if (message.body.isEmpty) return tr(context, '相片', 'Photo');
  final text = message.body
      .split('\n')
      .where((line) => !line.startsWith('#offer '))
      .join(' ');
  final shown = text
      .replaceAll(legacySupportServiceName, supportServiceName)
      .replaceAll('列表上的原價不會改變。', '')
      .replaceAll(' The listed price stays the same.', '');
  return shown.isEmpty ? tr(context, '相片', 'Photo') : shown;
}

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
          final unread = threads.fold<int>(0, (sum, thread) => sum + thread.unread);
          if (center.unread != unread) {
            WidgetsBinding.instance.addPostFrameCallback((_) => center.publishUnread(unread));
          }
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
                    '還沒有對話。只有你和物主聊過的才會出現在這裡。',
                    'No chats yet. Only conversations between you and an owner are listed.',
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
    final threads = <_Thread>[];
    for (final entry in grouped.entries) {
      if (entry.key == supportItemId(user.name) || entry.key == supportItemId(user.label)) {
        threads.add(_Thread(
          itemId: entry.key,
          client: user.label,
          asOwner: false,
          support: true,
          messages: entry.value,
          unread: center.unreadForThread(entry.key, user.label, entry.value),
        ));
        continue;
      }
      final owner = store.findItem(entry.key)?.owner ?? '';
      final iAmOwner = owner == user.label || owner == user.name;
      final clients = <String>{
        for (final message in entry.value)
          if (message.sender.isNotEmpty && message.sender != owner) message.sender,
      };
      if (iAmOwner) {
        for (final client in clients) {
          final messages = conversationOf(messages: entry.value, owner: owner, client: client);
          if (messages.isEmpty) continue;
          threads.add(_Thread(
            itemId: entry.key,
            client: client,
            asOwner: true,
            messages: messages,
            unread: center.unreadForThread(entry.key, client, messages),
          ));
        }
      } else if (clients.contains(user.label) || clients.contains(user.name)) {
        final client = clients.contains(user.label) ? user.label : user.name;
        final messages = conversationOf(messages: entry.value, owner: owner, client: client);
        if (messages.isEmpty) continue;
        threads.add(_Thread(
          itemId: entry.key,
          client: client,
          asOwner: false,
          messages: messages,
          unread: center.unreadForThread(entry.key, client, messages),
        ));
      }
    }
    threads.sort((a, b) => b.latest.id.compareTo(a.latest.id));
    return threads;
  }
}

class _Thread {
  _Thread({
    required this.itemId,
    required this.client,
    required this.asOwner,
    this.support = false,
    required this.messages,
    required this.unread,
  });

  final String itemId;
  final String client;
  final bool asOwner;
  final bool support;
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
    final owner = item?.owner ?? '';
    final title = thread.support
        ? supportServiceName
        : thread.asOwner
            ? thread.client
            : (item?.name ?? tr(context, '已下架的物品', 'Removed item'));
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () async {
          await center.markThread(
            thread.itemId,
            thread.client,
            ids: thread.messages.map((message) => message.id),
          );
          if (!context.mounted) return;
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ChatPage(
                auth: auth,
                itemId: thread.itemId,
                itemName: item?.name ?? title,
                ownerName: thread.support ? supportServiceName : owner,
                senderName: user.label,
                clientName: thread.client,
                center: center,
                store: store,
              ),
            ),
          );
          await center.refresh();
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              PersonAvatar(
                auth: auth,
                name: thread.support ? supportServiceName : (thread.asOwner ? thread.client : owner),
                appIcon: thread.support,
                onTap: thread.support
                    ? null
                    : () => showPersonReviews(
                          context,
                          store,
                          thread.asOwner ? thread.client : owner,
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
                      '${supportSenderLabel(thread.latest.sender)}：${_preview(context, thread.latest)}',
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
