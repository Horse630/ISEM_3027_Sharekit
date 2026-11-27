import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_repository.dart';
import 'camera_capture.dart';
import 'models.dart';
import 'store.dart';
import 'text.dart';
import 'widgets.dart';

class UiSettings extends ChangeNotifier {
  double textScale = 1;
  bool english = false;

  static const _key = 'sharekit_text_scale';
  static const _languageKey = 'sharekit_english';

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      textScale = prefs.getDouble(_key) ?? 1;
      english = prefs.getBool(_languageKey) ?? false;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setEnglish(bool value) async {
    english = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_languageKey, value);
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

class _LocationTag extends StatelessWidget {
  const _LocationTag();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF003070),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_on, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(
              tr(context, '地點：HKBU', 'Location: HKBU'),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
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
  var _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.user.displayName);
    _address = TextEditingController(text: widget.user.address);
    _district = widget.user.district;
    _photo = widget.user.photo;
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
        builder: (_) => CameraCapturePage(
          title: tr(context, '拍攝個人相片', 'Take a profile photo'),
        ),
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
      widget.store.renameOwner(previous, user.label, login: user.name);
      widget.onChanged(user);
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              context,
              '已儲存。新上架的物品會用這個地址和地區。',
              'Saved. New listings use this address and district.',
            ),
          ),
        ),
      );
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
    return SafeArea(
      child: ListenableBuilder(
        listenable: widget.store,
        builder: (context, _) {
          final mine = widget.store.items
              .where((item) => item.owner == widget.user.label)
              .length;
          final reviews = widget.store.reviewsForBorrower(widget.user.label, widget.user.name);
          return ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Text(
            tr(context, '設定', 'Settings'),
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          const _LocationTag(),
          const SizedBox(height: 8),
          Text(
            widget.user.hkidUploaded
                ? tr(context, '香港身份證：已上載', 'HKID: uploaded')
                : tr(context, '香港身份證：未上載', 'HKID: not uploaded'),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            tr(
              context,
              '登入名稱 ${widget.user.name} · ${widget.user.verified ? '已驗證' : '尚未驗證'}',
              'Login ${widget.user.name} · ${widget.user.verified ? 'Verified' : 'Not verified'}',
            ),
            style: const TextStyle(color: Color(0xFF5A6A80)),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: const Color(0xFF003070).withValues(alpha: 0.12),
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
                      tr(context, '你上架了 $mine 件物品', 'You listed $mine items'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: _busy ? null : _takePhoto,
                      child: Text(tr(context, '拍攝個人相片', 'Take a profile photo')),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            tr(
              context,
              '個人相片只能用相機拍攝，不能從相簿上載。',
              'Profile photos must be taken with the camera.',
            ),
            style: const TextStyle(color: Color(0xFF5E6A64), height: 1.4),
          ),
          const SizedBox(height: 16),
          Text(tr(context, '物主給我的評價', 'Reviews from owners'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          if (reviews.isEmpty)
            Text(tr(context, '尚未收到評價。', 'No reviews yet.'))
          else
            for (final review in reviews)
              Card(
                child: ListTile(
                  title: Text('${'★' * (review.ownerReviewStars ?? 0)}  ${review.ownerReviewAuthor ?? tr(context, '物主', 'Owner')}'),
                  subtitle: Text('${widget.store.findItem(review.itemId)?.name ?? review.itemId}\n${review.ownerReviewComment}'),
                  isThreeLine: true,
                ),
              ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            decoration: InputDecoration(
              labelText: tr(context, '顯示名稱', 'Display name'),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _address,
            decoration: InputDecoration(
              labelText: tr(context, '聯絡地址', 'Address'),
              hintText: tr(
                context,
                '例如：浸大會堂 / 宿舍 X 座',
                'For example: HKBU Academic Community Hall / Hall X',
              ),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _busy ? null : _pickDistrict,
            icon: const Icon(Icons.map_outlined),
            label: Text(
              tr(
                context,
                '居住地區 · ${_district.label}',
                'Home district · ${_district.en}',
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            tr(context, '語言', 'Language'),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          ListenableBuilder(
            listenable: widget.ui,
            builder: (context, _) {
              return Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('中文'),
                    selected: !widget.ui.english,
                    onSelected: (_) => widget.ui.setEnglish(false),
                  ),
                  ChoiceChip(
                    label: const Text('English'),
                    selected: widget.ui.english,
                    onSelected: (_) => widget.ui.setEnglish(true),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Text(
            tr(context, '介面文字', 'Text size'),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          ListenableBuilder(
            listenable: widget.ui,
            builder: (context, _) {
              return Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: Text(tr(context, '標準', 'Standard')),
                    selected: widget.ui.textScale < 1.1,
                    onSelected: (_) => widget.ui.setTextScale(1),
                  ),
                  ChoiceChip(
                    label: Text(tr(context, '較大', 'Larger')),
                    selected: widget.ui.textScale >= 1.1,
                    onSelected: (_) => widget.ui.setTextScale(1.2),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          const _TermsSection(),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(
              _busy
                  ? tr(context, '請稍候…', 'Please wait…')
                  : tr(context, '儲存資料', 'Save'),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(shown(context, _error!), style: const TextStyle(color: Color(0xFF9A4632))),
          ],
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _busy ? null : widget.onLogout,
            child: Text(tr(context, '登出', 'Log out')),
          ),
        ],
      );
        },
      ),
    );
  }
}

class _TermsSection extends StatelessWidget {
  const _TermsSection();

  @override
  Widget build(BuildContext context) {
    final chinese = '''
1. ShareKit 是香港浸會大學校園借用試點。帳號視作浸大校園使用者。
2. 使用前必須上載香港身份證相片。未上載者不能瀏覽、上架或預約。
3. 物主上架時可自訂按金。借用成立後，按金由平台暫存，不會直接交給物主。物品歸還並確認後，平台才把按金退回借用者。
4. 租金由物主訂定。平台不另收服務費。
5. 借用者須按約定時間取件、使用和歸還，並保持物品狀況。損壞、遺失或逾期由雙方按平台記錄處理。
6. 平台可因虛假資料、未完成身份核對或違規使用而暫停帳號。
7. 這是課堂示範條款，不構成正式法律意見。''';
    final english = '''
1. ShareKit is an HKBU campus borrowing pilot. Accounts are treated as campus users.
2. You must upload an HKID photo before using the app. Without it you cannot browse, list, or book.
3. The owner sets the deposit. The platform holds it and does not pay it to the owner. It is returned to the borrower after the item is returned and confirmed.
4. The owner sets the rent. The platform adds no fee.
5. Borrowers collect, use, and return items on time and keep them in the agreed condition. Damage, loss, or lateness is handled from the platform record.
6. The platform may suspend an account for false details, missing identity checks, or misuse.
7. These terms are for a class demo and are not formal legal advice.''';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr(context, '條款及細則', 'Terms and conditions'),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(tr(context, chinese, english), style: const TextStyle(height: 1.45)),
      ],
    );
  }
}
