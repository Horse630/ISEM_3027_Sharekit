import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'catalog_gateway.dart';
import 'models.dart';

class ShareStore extends ChangeNotifier {
  ShareStore() {
    _items = List<ShareItem>.of(seedItems());
  }

  static const community = '九龍塘示範屋苑';

  late List<ShareItem> _items;
  final List<Booking> _bookings = [];
  int _sequence = 240;
  int? requestedTab;
  CatalogGateway? _gateway;
  Timer? _syncTimer;
  Future<void> _writes = Future<void>.value();

  Future<void> get persisted => _writes;

  Future<void> attach(CatalogGateway gateway) async {
    _syncTimer?.cancel();
    _gateway = gateway;
    final snapshot = await gateway.load();
    _items = List<ShareItem>.of(snapshot.items);
    _bookings
      ..clear()
      ..addAll(snapshot.bookings);
    _sequence = snapshot.sequence;
    notifyListeners();
    if (_isPublic(gateway)) {
      _syncTimer = Timer.periodic(const Duration(seconds: 6), (_) {
        _pullPublic();
      });
    }
  }

  bool _isPublic(CatalogGateway gateway) {
    if (gateway is PublicCatalog) return true;
    return gateway is CombinedCatalog && gateway.remote is PublicCatalog;
  }

  Future<void> _pullPublic() async {
    final gateway = _gateway;
    if (gateway == null || !_isPublic(gateway)) return;
    final CatalogGateway remote = gateway is PublicCatalog
        ? gateway
        : (gateway as CombinedCatalog).remote!;
    try {
      final remoteSnapshot = await remote.load();
      final merged = mergeCatalogs(
        remoteSnapshot,
        CatalogSnapshot(
          items: _items,
          bookings: _bookings,
          sequence: _sequence,
        ),
      );
      if (_sameItems(merged)) return;
      _items = List<ShareItem>.of(merged.items);
      _bookings
        ..clear()
        ..addAll(merged.bookings);
      _sequence = merged.sequence;
      notifyListeners();
    } catch (_) {}
  }

  bool _sameItems(CatalogSnapshot snapshot) {
    if (snapshot.items.length != _items.length) return false;
    if (snapshot.bookings.length != _bookings.length) return false;
    for (var index = 0; index < snapshot.items.length; index++) {
      if (snapshot.items[index].id != _items[index].id) return false;
    }
    return snapshot.sequence == _sequence;
  }

  List<ShareItem> get items => List.unmodifiable(_items);
  List<Booking> get bookings => List.unmodifiable(_bookings.reversed);

  ShareItem itemById(String id) => _items.firstWhere((item) => item.id == id);

  Booking bookingById(String id) =>
      _bookings.firstWhere((booking) => booking.id == id);

  void openTab(int index) {
    requestedTab = index;
    notifyListeners();
  }

  List<ShareItem> search({
    required String query,
    ItemCategory? category,
    required bool freeOnly,
    HkDistrict? district,
    String? owner,
    ItemSort sort = ItemSort.nearest,
  }) {
    final needle = query.trim().toLowerCase();
    final results = _items.where((item) {
      final matchesQuery =
          needle.isEmpty ||
          item.name.toLowerCase().contains(needle) ||
          item.summary.toLowerCase().contains(needle) ||
          item.address.toLowerCase().contains(needle) ||
          item.district.label.toLowerCase().contains(needle) ||
          item.category.label.contains(query.trim());
      final matchesCategory = category == null || item.category == category;
      final matchesFree = !freeOnly || item.isFree;
      final matchesDistrict = district == null || item.district == district;
      final matchesOwner = owner == null || item.owner == owner;
      return matchesQuery &&
          matchesCategory &&
          matchesFree &&
          matchesDistrict &&
          matchesOwner;
    }).toList();
    switch (sort) {
      case ItemSort.nearest:
        results.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
      case ItemSort.rating:
        results.sort((a, b) => b.rating.compareTo(a.rating));
      case ItemSort.priceLow:
        results.sort(
          (a, b) => (a.dailyPrice ?? -1).compareTo(b.dailyPrice ?? -1),
        );
    }
    return results;
  }

  void renameOwner(String from, String to) {
    final next = to.trim();
    if (from.trim().isEmpty || next.isEmpty || from == next) return;
    var changed = false;
    for (var index = 0; index < _items.length; index++) {
      if (_items[index].owner != from) continue;
      _items[index] = _items[index].copyWith(owner: next);
      changed = true;
    }
    if (!changed) return;
    notifyListeners();
    _persist();
  }

  bool rangeAvailable(String itemId, DateTime start, DateTime end) {
    for (final booking in _bookings) {
      if (booking.itemId != itemId || !booking.stage.blocksDates) continue;
      if (rangesOverlap(start, end, booking.start, booking.end)) return false;
    }
    return true;
  }

  Booking? createBooking({
    required String itemId,
    required DateTime start,
    required DateTime end,
    required String note,
  }) {
    final from = dateOnly(start);
    final to = dateOnly(end);
    if (to.isBefore(from) || !rangeAvailable(itemId, from, to)) return null;
    _sequence += 1;
    final item = itemById(itemId);
    final booking = Booking(
      id: 'SK-$_sequence',
      itemId: itemId,
      start: from,
      end: to,
      stage: BookingStage.reserved,
      pickupCode: (_sequence * 37 % 9000 + 1000).toString(),
      note: note.trim().isEmpty ? '在屋苑會所大堂交接' : note.trim(),
      deposit: item.isFree ? DepositStatus.none : DepositStatus.pending,
    );
    _bookings.add(booking);
    notifyListeners();
    _persist();
    return booking;
  }

  void payDeposit(String bookingId) {
    final booking = bookingById(bookingId);
    if (booking.deposit != DepositStatus.pending) return;
    _update(bookingId, (current) => current.copyWith(deposit: DepositStatus.paid));
  }

  void refundDeposit(String bookingId) {
    final booking = bookingById(bookingId);
    if (booking.deposit != DepositStatus.paid) return;
    _update(
      bookingId,
      (current) => current.copyWith(deposit: DepositStatus.refunded),
    );
  }

  void reportIssue(String bookingId, String issue) {
    final text = issue.trim();
    if (text.isEmpty) return;
    _update(bookingId, (current) => current.copyWith(issue: text));
  }

  void markPickedUp(String bookingId) {
    if (bookingById(bookingId).deposit == DepositStatus.pending) return;
    _update(
      bookingId,
      (booking) => booking.copyWith(stage: BookingStage.pickedUp),
    );
  }

  void markReturned(String bookingId, String condition) {
    _update(
      bookingId,
      (booking) => booking.copyWith(
        stage: BookingStage.returned,
        returnCondition: condition,
      ),
    );
  }

  void saveReview(String bookingId, int stars, String comment) {
    final booking = bookingById(bookingId);
    _update(
      bookingId,
      (current) => current.copyWith(
        stage: BookingStage.reviewed,
        stars: stars,
        comment: comment.trim(),
      ),
    );
    final index = _items.indexWhere((item) => item.id == booking.itemId);
    if (index == -1) return;
    final item = _items[index];
    final nextCount = item.reviewCount + 1;
    final nextRating = ((item.rating * item.reviewCount) + stars) / nextCount;
    _items[index] = item.copyWith(
      rating: double.parse(nextRating.toStringAsFixed(1)),
      reviewCount: nextCount,
      handovers: item.handovers + 1,
    );
    notifyListeners();
    _persist();
  }

  void addItem({
    required String name,
    required String owner,
    required ItemCategory category,
    required String condition,
    required String summary,
    required double? dailyPrice,
    required Uint8List photoBytes,
    required String address,
    required HkDistrict district,
    required HandoverMethod handover,
  }) {
    _sequence += 1;
    _items.insert(
      0,
      ShareItem(
        id: 'item-$_sequence',
        name: name.trim(),
        owner: owner,
        category: category,
        condition: condition,
        distanceMeters: 80,
        summary: summary.trim(),
        rating: 0,
        reviewCount: 0,
        handovers: 0,
        dailyPrice: dailyPrice,
        photoBytes: photoBytes,
        address: address.trim(),
        district: district,
        handover: handover,
      ),
    );
    notifyListeners();
    _persist();
  }

  void _update(String bookingId, Booking Function(Booking booking) transform) {
    final index = _bookings.indexWhere((booking) => booking.id == bookingId);
    if (index == -1) return;
    _bookings[index] = transform(_bookings[index]);
    notifyListeners();
    _persist();
  }

  void _persist() {
    final gateway = _gateway;
    if (gateway == null) return;
    final snapshot = CatalogSnapshot(
      items: List<ShareItem>.of(_items),
      bookings: List<Booking>.of(_bookings),
      sequence: _sequence,
    );
    _writes = _writes
        .catchError((Object _) {})
        .then((_) => gateway.save(snapshot));
  }
}

List<ShareItem> seedItems() {
  return const [
    ShareItem(
      id: 'drill',
      name: '充電電鑽套裝',
      owner: '陳先生',
      category: ItemCategory.tool,
      condition: '良好',
      distanceMeters: 180,
      dailyPrice: 40,
      summary: '附兩枚電池、常用鑽咀和充電座。適合裝窗簾桿、層架，用完即還。',
      rating: 4.8,
      reviewCount: 16,
      handovers: 21,
      district: HkDistrict.kowloonCity,
    ),
    ShareItem(
      id: 'cleaner',
      name: '地毯清潔機',
      owner: '林小姐',
      category: ItemCategory.home,
      condition: '良好',
      distanceMeters: 420,
      dailyPrice: 60,
      summary: '適合沙發和地毯深層清潔。機身連短吸管，清潔劑需自備。',
      rating: 4.6,
      reviewCount: 9,
      handovers: 11,
      district: HkDistrict.kowloonCity,
    ),
    ShareItem(
      id: 'camp',
      name: '雙人露營套裝',
      owner: '黃同學',
      category: ItemCategory.outdoor,
      condition: '有使用痕跡',
      distanceMeters: 650,
      dailyPrice: 80,
      summary: '帳幕、防潮墊和兩支頭燈。帳底有正常摺痕，沒有破洞。',
      rating: 4.7,
      reviewCount: 7,
      handovers: 8,
      district: HkDistrict.shaTin,
    ),
    ShareItem(
      id: 'tables',
      name: '摺枱連椅一組',
      owner: '業主會',
      category: ItemCategory.event,
      condition: '良好',
      distanceMeters: 260,
      summary: '一張摺枱加四張摺椅，給樓層聚會或學會活動免費借用。',
      rating: 4.9,
      reviewCount: 22,
      handovers: 30,
      district: HkDistrict.kowloonCity,
    ),
    ShareItem(
      id: 'projector',
      name: '便攜投影機',
      owner: '周先生',
      category: ItemCategory.event,
      condition: '良好',
      distanceMeters: 900,
      dailyPrice: 50,
      summary: '支援 HDMI。適合電影夜和小組匯報，遙控器放在同袋。',
      rating: 4.5,
      reviewCount: 6,
      handovers: 6,
      district: HkDistrict.yauTsimMong,
    ),
    ShareItem(
      id: 'washer',
      name: '高壓清洗機',
      owner: '張太太',
      category: ItemCategory.home,
      condition: '良好',
      distanceMeters: 1100,
      dailyPrice: 45,
      summary: '清洗冷氣機濾網外的露台地板。水管接頭已附，用後請抹乾。',
      rating: 4.4,
      reviewCount: 5,
      handovers: 5,
      district: HkDistrict.kwunTong,
    ),
    ShareItem(
      id: 'cookset',
      name: '登山炊具組',
      owner: '李同學',
      category: ItemCategory.outdoor,
      condition: '良好',
      distanceMeters: 540,
      summary: '鍋、爐頭和兩套餐具。社區內免費借用，煤氣罐請自備。',
      rating: 5,
      reviewCount: 4,
      handovers: 4,
      district: HkDistrict.saiKung,
    ),
    ShareItem(
      id: 'cart',
      name: '摺疊手推車',
      owner: '吳先生',
      category: ItemCategory.tool,
      condition: '有使用痕跡',
      distanceMeters: 300,
      dailyPrice: 25,
      summary: '搬紙箱、飲用水或活動物資。輪子正常，承重約 40 公斤。',
      rating: 4.3,
      reviewCount: 11,
      handovers: 14,
      district: HkDistrict.shamShuiPo,
    ),
  ];
}
