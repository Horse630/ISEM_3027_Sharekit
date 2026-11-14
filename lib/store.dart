import 'package:flutter/foundation.dart';

import 'models.dart';

class ShareStore extends ChangeNotifier {
  ShareStore() {
    _items = List<ShareItem>.of(_seedItems());
  }

  static const community = '九龍塘示範屋苑';

  late List<ShareItem> _items;
  final List<Booking> _bookings = [];
  int _sequence = 240;
  int? requestedTab;

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
  }) {
    final needle = query.trim().toLowerCase();
    return _items.where((item) {
      final matchesQuery =
          needle.isEmpty ||
          item.name.toLowerCase().contains(needle) ||
          item.summary.toLowerCase().contains(needle) ||
          item.category.label.contains(query.trim());
      final matchesCategory = category == null || item.category == category;
      final matchesFree = !freeOnly || item.isFree;
      return matchesQuery && matchesCategory && matchesFree;
    }).toList();
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
    final booking = Booking(
      id: 'SK-$_sequence',
      itemId: itemId,
      start: from,
      end: to,
      stage: BookingStage.reserved,
      pickupCode: (_sequence * 37 % 9000 + 1000).toString(),
      note: note.trim().isEmpty ? '在屋苑會所大堂交接' : note.trim(),
    );
    _bookings.add(booking);
    notifyListeners();
    return booking;
  }

  void markPickedUp(String bookingId) {
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
  }

  void addItem({
    required String name,
    required ItemCategory category,
    required String condition,
    required String summary,
    required double? dailyPrice,
  }) {
    _sequence += 1;
    _items.insert(
      0,
      ShareItem(
        id: 'item-$_sequence',
        name: name.trim(),
        owner: '我',
        category: category,
        condition: condition,
        distanceMeters: 80,
        summary: summary.trim(),
        rating: 0,
        reviewCount: 0,
        handovers: 0,
        dailyPrice: dailyPrice,
      ),
    );
    notifyListeners();
  }

  void _update(String bookingId, Booking Function(Booking booking) transform) {
    final index = _bookings.indexWhere((booking) => booking.id == bookingId);
    if (index == -1) return;
    _bookings[index] = transform(_bookings[index]);
    notifyListeners();
  }
}

List<ShareItem> _seedItems() {
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
    ),
  ];
}
