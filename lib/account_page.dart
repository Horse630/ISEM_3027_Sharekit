import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'auth_repository.dart';
import 'camera_capture.dart';
import 'store.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({
    super.key,
    required this.user,
    required this.auth,
    required this.onChanged,
  });

  final AppUser user;
  final AuthRepository auth;
  final ValueChanged<AppUser> onChanged;

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  late final TextEditingController _name;
  Uint8List? _photo;
  late bool _joined;
  var _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.user.displayName);
    _photo = widget.user.photo;
    _joined = widget.user.communityJoined;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    final bytes = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        builder: (_) => const CameraCapturePage(title: '拍攝個人相片'),
      ),
    );
    if (!mounted || bytes == null) return;
    setState(() => _photo = bytes);
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final user = await widget.auth.updateProfile(
        userId: widget.user.id,
        displayName: _name.text,
        photo: _photo,
      );
      if (!mounted) return;
      widget.onChanged(user);
      Navigator.of(context).pop();
    } on AuthFailure catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.message;
      });
    }
  }

  Future<void> _join() async {
    setState(() => _busy = true);
    try {
      final user = await widget.auth.joinCommunity(widget.user.id);
      if (!mounted) return;
      widget.onChanged(user);
      setState(() {
        _joined = true;
        _busy = false;
      });
    } finally {
      if (mounted && _busy) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final joined = _joined;
    return Scaffold(
      appBar: AppBar(title: const Text('帳戶')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Text('登入名稱 ${widget.user.name}'),
          const SizedBox(height: 4),
          Text(
            widget.user.verified
                ? '聯絡方式已驗證：${widget.user.contact}'
                : '聯絡方式尚未驗證',
            style: const TextStyle(color: Color(0xFF5E6A64)),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: '顯示名稱'),
          ),
          const SizedBox(height: 12),
          const Text(
            '個人相片只能用相機拍攝，不能從相簿上載。',
            style: TextStyle(color: Color(0xFF5E6A64), height: 1.4),
          ),
          const SizedBox(height: 8),
          if (_photo != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.memory(_photo!, height: 160, width: double.infinity, fit: BoxFit.cover),
            ),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: _busy ? null : _takePhoto, child: const Text('拍攝個人相片')),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(_busy ? '請稍候…' : '儲存資料'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Color(0xFF9A4632))),
          ],
          const SizedBox(height: 20),
          Text(
            joined ? '已加入${ShareStore.community}' : '加入社區後，附近的人可以看到你上架的物品。',
            style: const TextStyle(height: 1.4),
          ),
          const SizedBox(height: 8),
          if (!joined)
            FilledButton(
              onPressed: _busy ? null : _join,
              child: Text('加入${ShareStore.community}'),
            ),
        ],
      ),
    );
  }
}
