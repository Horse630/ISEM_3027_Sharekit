import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'catalog_gateway.dart';

import 'auth_repository.dart';
import 'chat_page.dart';
import 'hkid_page.dart';
import 'camera_capture.dart';
import 'models.dart';
import 'store.dart';
import 'text.dart';
import 'widgets.dart';

class UiSettings extends ChangeNotifier {
  double textScale = 1;
  bool english = false;
  String handoverPlace = '';

  static const _key = 'sharekit_text_scale';
  static const _languageKey = 'sharekit_english';
  static const _handoverKey = 'sharekit_handover_place';

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      textScale = prefs.getDouble(_key) ?? 1;
      english = prefs.getBool(_languageKey) ?? false;
      handoverPlace = prefs.getString(_handoverKey) ?? '';
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

  Future<void> setHandoverPlace(String value) async {
    handoverPlace = value.trim();
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_handoverKey, handoverPlace);
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
  late final TextEditingController _handover;
  late HkDistrict _district;
  Uint8List? _photo;
  var _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.user.displayName);
    _address = TextEditingController(text: widget.user.address);
    _handover = TextEditingController(text: widget.ui.handoverPlace);
    _district = widget.user.district;
    _photo = widget.user.photo;
    widget.ui.addListener(_syncHandover);
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

  void _syncHandover() {
    if (_handover.text.isEmpty && widget.ui.handoverPlace.isNotEmpty) {
      _handover.text = widget.ui.handoverPlace;
    }
  }

  @override
  void dispose() {
    widget.ui.removeListener(_syncHandover);
    _name.dispose();
    _address.dispose();
    _handover.dispose();
    super.dispose();
  }

  Future<void> _uploadPhoto() async {
    final picked = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    final bytes = picked?.files.single.bytes;
    if (!mounted || bytes == null) return;
    setState(() => _photo = shrinkPhotoBytes(bytes) ?? bytes);
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
      await widget.ui.setHandoverPlace(_handover.text);
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

  Future<void> _changePassword() async {
    final current = TextEditingController();
    final next = TextEditingController();
    final again = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr(dialogContext, '修改密碼', 'Change password')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: current, obscureText: true, decoration: InputDecoration(labelText: tr(dialogContext, '現有密碼', 'Current password'))),
            const SizedBox(height: 8),
            TextField(controller: next, obscureText: true, decoration: InputDecoration(labelText: tr(dialogContext, '新密碼', 'New password'))),
            const SizedBox(height: 8),
            TextField(controller: again, obscureText: true, decoration: InputDecoration(labelText: tr(dialogContext, '再輸入新密碼', 'Confirm new password'))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(tr(dialogContext, '取消', 'Cancel'))),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(tr(dialogContext, '更新', 'Update'))),
        ],
      ),
    );
    if (saved != true || !mounted) return;
    if (next.text != again.text) {
      setState(() => _error = tr(context, '兩次新密碼不相同。', 'The new passwords do not match.'));
      return;
    }
    try {
      await widget.auth.changePassword(
        userId: widget.user.id,
        currentPassword: current.text,
        nextPassword: next.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(context, '密碼已更新。', 'Password updated.'))));
    } on AuthFailure catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    }
  }

  Future<void> _reuploadHkid() async {
    final picked = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    final bytes = picked?.files.single.bytes;
    if (!mounted || bytes == null) return;
    try {
      final user = await widget.auth.submitHkid(
        userId: widget.user.id,
        bytes: shrinkPhotoBytes(bytes) ?? bytes,
      );
      if (!mounted) return;
      await showHkidVerifyDialog(context);
      if (!mounted) return;
      widget.onChanged(user);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(context, '身份證已更新。相片只留在這部裝置。', 'HKID updated. The photo stays on this device.'))),
      );
    } on AuthFailure catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    }
  }

  void _contactUs() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatPage(
          auth: widget.auth,
          itemId: supportItemId(widget.user.name),
          itemName: supportServiceName,
          ownerName: supportServiceName,
          senderName: widget.user.label,
          clientName: widget.user.label,
          store: widget.store,
        ),
      ),
    );
  }

  void _showDeposits() {
    final user = widget.user;
    final rows = widget.store.bookings.where((booking) {
      final item = widget.store.findItem(booking.itemId);
      final owner = item != null && (item.owner == user.label || item.owner == user.name);
      return owner || widget.store.isBorrower(booking, user.label, user.name);
    }).toList();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr(dialogContext, '按金狀態', 'Deposit status')),
        content: SizedBox(
          width: 360,
          child: rows.isEmpty
              ? Text(tr(dialogContext, '暫時沒有按金紀錄。', 'No deposits yet.'))
              : ListView(
                  shrinkWrap: true,
                  children: [
                    for (final booking in rows)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(widget.store.findItem(booking.itemId)?.name ?? booking.id),
                        subtitle: Text(
                          booking.depositAmount <= 0
                              ? depositLabel(dialogContext, booking.deposit)
                              : '${money(booking.depositAmount)} · ${depositLabel(dialogContext, booking.deposit)}',
                        ),
                      ),
                  ],
                ),
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(dialogContext), child: Text(tr(dialogContext, '關閉', 'Close'))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListenableBuilder(
        listenable: widget.store,
        builder: (context, _) {
          final mine = widget.store.items.where((item) => item.owner == widget.user.label).length;
          final reviews = widget.store.reviewsForBorrower(widget.user.label, widget.user.name);
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  children: [
                    Text(tr(context, '設定', 'Settings'), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 12),
                    _AccountCard(
                      name: widget.user.label,
                      login: widget.user.name,
                      verified: widget.user.verified,
                      hkid: widget.user.hkidUploaded,
                      listed: mine,
                      photo: _photo,
                      busy: _busy,
                      onPhoto: _takePhoto,
                      onUpload: _uploadPhoto,
                    ),
                    const SizedBox(height: 12),
                    Text(tr(context, '物主給我的評價', 'Reviews from owners'), style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    if (reviews.isEmpty)
                      Text(tr(context, '尚未收到評價。', 'No reviews yet.'))
                    else
                      for (final review in reviews)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('${'★' * (review.ownerReviewStars ?? 0)}  ${review.ownerReviewAuthor ?? tr(context, '物主', 'Owner')}'),
                          subtitle: Text('${widget.store.findItem(review.itemId)?.name ?? review.itemId}\n${review.ownerReviewComment}'),
                          isThreeLine: true,
                        ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _Shortcut(label: tr(context, '我的上架', 'My listings'), icon: Icons.inventory_2_outlined, onTap: widget.store.showMyListings),
                        _Shortcut(label: tr(context, '借用紀錄', 'Borrowing history'), icon: Icons.event_note_outlined, onTap: () => widget.store.openTab(2)),
                        _Shortcut(label: tr(context, '按金狀態', 'Deposit status'), icon: Icons.account_balance_wallet_outlined, onTap: _showDeposits),
                        _Shortcut(label: tr(context, '聯絡我們', 'Contact us'), icon: Icons.support_agent, onTap: _contactUs),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _Group(
                      title: tr(context, '個人資料', 'Profile'),
                      children: [
                        TextField(controller: _name, decoration: InputDecoration(labelText: tr(context, '顯示名稱', 'Display name'))),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _address,
                          decoration: InputDecoration(
                            labelText: tr(context, '聯絡地址', 'Address'),
                            hintText: tr(context, '例如：浸大會堂 / 宿舍 X 座', 'For example: HKBU Academic Community Hall / Hall X'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _handover,
                          decoration: InputDecoration(
                            labelText: tr(context, '預設交接地點', 'Default handover place'),
                            helperText: tr(context, '上架時會自動填入地址欄。', 'New listings fill the address with this.'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _busy ? null : _pickDistrict,
                          icon: const Icon(Icons.map_outlined),
                          label: Text(tr(context, '居住地區 · ${_district.label}', 'Home district · ${_district.en}')),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(onPressed: _busy ? null : _changePassword, child: Text(tr(context, '修改密碼', 'Change password'))),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(onPressed: _busy ? null : _reuploadHkid, child: Text(tr(context, '重新上載香港身份證', 'Upload HKID again'))),
                        ),
                        Text(
                          tr(context, '證件相片只留在這部裝置，不會放進公開物品目錄。', 'The identity photo stays on this device and is not put in the public catalogue.'),
                          style: const TextStyle(color: Color(0xFF5A6A80), height: 1.4),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _Group(
                      title: tr(context, '偏好', 'Preferences'),
                      children: [
                        Text(tr(context, '語言', 'Language'), style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        ListenableBuilder(
                          listenable: widget.ui,
                          builder: (context, _) => Wrap(
                            spacing: 8,
                            children: [
                              ChoiceChip(label: const Text('中文'), selected: !widget.ui.english, onSelected: (_) => widget.ui.setEnglish(false)),
                              ChoiceChip(label: const Text('English'), selected: widget.ui.english, onSelected: (_) => widget.ui.setEnglish(true)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(tr(context, '介面文字', 'Text size'), style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        ListenableBuilder(
                          listenable: widget.ui,
                          builder: (context, _) => Wrap(
                            spacing: 8,
                            children: [
                              ChoiceChip(label: Text(tr(context, '標準', 'Standard')), selected: widget.ui.textScale < 1.1, onSelected: (_) => widget.ui.setTextScale(1)),
                              ChoiceChip(label: Text(tr(context, '較大', 'Larger')), selected: widget.ui.textScale >= 1.1, onSelected: (_) => widget.ui.setTextScale(1.2)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const _TermsSection(),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_error != null) ...[
                      Text(shown(context, _error!), style: const TextStyle(color: Color(0xFF9A4632))),
                      const SizedBox(height: 8),
                    ],
                    FilledButton(
                      onPressed: _busy ? null : _save,
                      child: Text(_busy ? tr(context, '請稍候…', 'Please wait…') : tr(context, '儲存資料', 'Save')),
                    ),
                    TextButton(
                      onPressed: _busy ? null : widget.onLogout,
                      child: Text(tr(context, '登出', 'Log out')),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.name,
    required this.login,
    required this.verified,
    required this.hkid,
    required this.listed,
    required this.photo,
    required this.busy,
    required this.onPhoto,
    required this.onUpload,
  });

  final String name;
  final String login;
  final bool verified;
  final bool hkid;
  final int listed;
  final Uint8List? photo;
  final bool busy;
  final VoidCallback onPhoto;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: const Color(0xFF003070).withValues(alpha: 0.12),
            backgroundImage: photo == null ? null : MemoryImage(photo!),
            child: photo == null ? const Icon(Icons.person_outline, size: 32) : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                const _LocationTag(),
                const SizedBox(height: 8),
                Text(
                  hkid ? tr(context, '香港身份證：已上載', 'HKID: uploaded') : tr(context, '香港身份證：未上載', 'HKID: not uploaded'),
                ),
                const SizedBox(height: 4),
                Text(tr(context, '你上架了 $listed 件物品', 'You listed $listed items')),
                const SizedBox(height: 4),
                Text(
                  tr(context, '登入 $login · ${verified ? '已驗證' : '尚未驗證'}', 'Login $login · ${verified ? 'Verified' : 'Not verified'}'),
                  style: const TextStyle(color: Color(0xFF5A6A80), fontSize: 13),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: busy ? null : onPhoto,
                      child: Text(tr(context, '拍攝個人相片', 'Take a profile photo')),
                    ),
                    OutlinedButton(
                      onPressed: busy ? null : onUpload,
                      child: Text(tr(context, '上載相片', 'Upload a photo')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({required this.label, required this.icon, required this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onTap,
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
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        title: Text(
          tr(context, '條款及細則', 'Terms and conditions'),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Text(tr(context, chinese, english), style: const TextStyle(height: 1.45)),
        ],
      ),
    );
  }
}
