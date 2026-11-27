import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'auth_repository.dart';
import 'catalog_gateway.dart';
import 'text.dart';

class HkidGatePage extends StatefulWidget {
  const HkidGatePage({
    super.key,
    required this.user,
    required this.auth,
    required this.onSubmitted,
    required this.onLogout,
  });

  final AppUser user;
  final AuthRepository auth;
  final ValueChanged<AppUser> onSubmitted;
  final Future<void> Function() onLogout;

  @override
  State<HkidGatePage> createState() => _HkidGatePageState();
}

class _HkidGatePageState extends State<HkidGatePage> {
  Uint8List? _photo;
  var _busy = false;
  String? _error;

  Future<void> _pick() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final bytes = picked?.files.single.bytes;
    if (!mounted || bytes == null) return;
    setState(() {
      _photo = shrinkPhotoBytes(bytes) ?? bytes;
      _error = null;
    });
  }

  Future<void> _submit() async {
    final photo = _photo;
    if (photo == null) {
      setState(() {
        _error = tr(context, '請先上載香港身份證相片。', 'Upload a Hong Kong identity card photo first.');
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final user = await widget.auth.submitHkid(userId: widget.user.id, bytes: photo);
      if (!mounted) return;
      widget.onSubmitted(user);
    } on AuthFailure catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          children: [
            Text(
              'ShareKit',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              tr(context, '上載香港身份證後才能使用', 'Upload your HKID before using ShareKit'),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Text(
              tr(
                context,
                '未上載香港身份證的帳號不能瀏覽、上架或預約。證件只用於核對身份。伺服器只記錄「已上載」，相片留在這部裝置，不會放進公開物品目錄。',
                'Accounts without an HKID photo cannot browse, list, or book. The server only stores that you uploaded it. The photo stays on this device and is not put in the public catalogue.',
              ),
              style: const TextStyle(height: 1.45),
            ),
            const SizedBox(height: 20),
            if (_photo != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.memory(_photo!, height: 180, fit: BoxFit.cover),
              ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _busy ? null : _pick,
              child: Text(tr(context, '上載香港身份證', 'Upload HKID')),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: Text(_busy ? tr(context, '請稍候…', 'Please wait…') : tr(context, '確認並進入', 'Continue')),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(shown(context, _error!), style: TextStyle(color: Colors.red.shade800)),
            ],
            const SizedBox(height: 12),
            TextButton(
              onPressed: _busy ? null : widget.onLogout,
              child: Text(tr(context, '登出', 'Log out')),
            ),
          ],
        ),
      ),
    );
  }
}
