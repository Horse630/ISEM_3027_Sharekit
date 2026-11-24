import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_repository.dart';
import 'camera_capture.dart';
import 'models.dart';
import 'store.dart';
import 'widgets.dart';

class UiSettings extends ChangeNotifier {
  double textScale = 1;

  static const _key = 'sharekit_text_scale';

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      textScale = prefs.getDouble(_key) ?? 1;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setTextScale(double value) async {
    textScale = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_key, value);
    } catch (_) {}
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.user,
    required this.auth,
    required this.store,
    required this.ui,
    required this.onChanged,
    required this.onLogout,
  });

  final AppUser user;
  final AuthRepository auth;
  final ShareStore store;
  final UiSettings ui;
  final ValueChanged<AppUser> onChanged;
  final Future<void> Function() onLogout;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _name;
  late final TextEditingController _address;
  late HkDistrict _district;
  Uint8List? _photo;
  late bool _joined;
  var _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.user.displayName);
    _address = TextEditingController(text: widget.user.address);
    _district = widget.user.district;
    _photo = widget.user.photo;
    _joined = widget.user.communityJoined;
    widget.ui.load();
  }

  @override
  void didUpdateWidget(SettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.id != widget.user.id) {
      _name.text = widget.user.displayName;
      _address.text = widget.user.address;
      _district = widget.user.district;
      _photo = widget.user.photo;
      _joined = widget.user.communityJoined;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
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

  Future<void> _pickDistrict() async {
    final picked = await showHkDistrictSheet(
      context,
      includeAll: false,
      selected: _district,
    );
    if (!mounted || picked?.district == null) return;
    setState(() => _district = picked!.district!);
  }

  Future<void> _save() async {
    final previous = widget.user.label;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final user = await widget.auth.updateProfile(
        userId: widget.user.id,
        displayName: _name.text,
        photo: _photo,
        address: _address.text,
        district: _district,
      );
      if (!mounted) return;
      widget.store.renameOwner(previous, user.label);
      widget.onChanged(user);
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已儲存。新上架的物品會用這個地址和地區。')),
      );
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
    return SafeArea(
      child: ListenableBuilder(
        listenable: widget.store,
        builder: (context, _) {
          final mine = widget.store.items
              .where((item) => item.owner == widget.user.label)
              .length;
          return ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          const Text(
            '設定',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            '登入名稱 ${widget.user.name} · ${widget.user.verified ? '已驗證' : '尚未驗證'}',
            style: const TextStyle(color: Color(0xFF5E6A64)),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: const Color(0xFF0E6B52).withValues(alpha: 0.12),
                backgroundImage: _photo == null ? null : MemoryImage(_photo!),
                child: _photo == null
                    ? const Icon(Icons.person_outline, size: 32)
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '你上架了 $mine 件物品',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: _busy ? null : _takePhoto,
                      child: const Text('拍攝個人相片'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '個人相片只能用相機拍攝，不能從相簿上載。',
            style: TextStyle(color: Color(0xFF5E6A64), height: 1.4),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: '顯示名稱'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _address,
            decoration: const InputDecoration(
              labelText: '聯絡地址',
              hintText: '例如：九龍塘XX座X樓',
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _busy ? null : _pickDistrict,
            icon: const Icon(Icons.map_outlined),
            label: Text('居住地區 · ${_district.label}'),
          ),
          const SizedBox(height: 16),
          const Text('介面文字', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          ListenableBuilder(
            listenable: widget.ui,
            builder: (context, _) {
              return Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('標準'),
                    selected: widget.ui.textScale < 1.1,
                    onSelected: (_) => widget.ui.setTextScale(1),
                  ),
                  ChoiceChip(
                    label: const Text('較大'),
                    selected: widget.ui.textScale >= 1.1,
                    onSelected: (_) => widget.ui.setTextScale(1.2),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
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
            _joined
                ? '已加入${ShareStore.community}'
                : '加入社區後，附近的人可以看到你上架的物品。',
            style: const TextStyle(height: 1.4),
          ),
          const SizedBox(height: 8),
          if (!_joined)
            FilledButton(
              onPressed: _busy ? null : _join,
              child: Text('加入${ShareStore.community}'),
            ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _busy ? null : widget.onLogout,
            child: const Text('登出'),
          ),
        ],
      );
        },
      ),
    );
  }
}
