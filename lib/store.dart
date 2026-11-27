import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'catalog_gateway.dart';
import 'models.dart';

class ShareStore extends ChangeNotifier {
  ShareStore() {
    _items = List<ShareItem>.of(seedItems());
  }

  static const community = '香港浸會大學';

  late List<ShareItem> _items;
  final List<Booking> _bookings = [];
  int _sequence = 240;
  int? requestedTab;
  bool focusMine = false;
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
    if (snapshot.sequence != _sequence) return false;
    for (var index = 0; index < snapshot.items.length; index++) {
      if (snapshot.items[index].id != _items[index].id) return false;
    }
    final current = {for (final booking in _bookings) booking.id: booking};
    for (final next in snapshot.bookings) {
      final booking = current[next.id];
      if (booking == null ||
          booking.stage != next.stage ||
          booking.deposit != next.deposit ||
          booking.borrower != next.borrower ||
          booking.borrowerAccount != next.borrowerAccount ||
          booking.stars != next.stars ||
          booking.comment != next.comment ||
          booking.ownerReviewStars != next.ownerReviewStars ||
          booking.ownerReviewComment != next.ownerReviewComment ||
          booking.ownerReviewAuthor != next.ownerReviewAuthor ||
          booking.returnCode != next.returnCode ||
          booking.returnedAt != next.returnedAt) {
        return false;
      }
    }
    return true;
  }

  List<ShareItem> get items => List.unmodifiable(_items);

  void replaceItems(List<ShareItem> items) {
    _items = List<ShareItem>.of(items);
    notifyListeners();
  }
  List<Booking> get bookings => List.unmodifiable(_bookings.reversed);

  ShareItem itemById(String id) => _items.firstWhere((item) => item.id == id);

  void removeItem(String id) {
    final index = _items.indexWhere((item) => item.id == id);
    if (index == -1) return;
    _items.removeAt(index);
    notifyListeners();
    _persist();
  }

  ShareItem? findItem(String id) {
    for (final item in _items) {
      if (item.id == id) return item;
    }
    return null;
  }

  bool seesBooking(Booking booking, String name, String login) {
    final names = {name, login};
    if (isBorrower(booking, name, login)) {
      return true;
    }
    final item = findItem(booking.itemId);
    return item != null && names.contains(item.owner);
  }

  bool isBorrower(Booking booking, String label, String login) =>
      booking.borrowerAccount.isNotEmpty
      ? booking.borrowerAccount == login
      : booking.borrower.isNotEmpty &&
            (booking.borrower == label || booking.borrower == login);

  List<Booking> reviewsAbout(String name) {
    final person = name.trim();
    if (person.isEmpty) return const [];
    return bookings.where((booking) {
      final item = findItem(booking.itemId);
      final aboutBorrower = (booking.borrower == person || booking.borrowerAccount == person) &&
          (booking.ownerReviewComment ?? '').trim().isNotEmpty;
      final aboutOwner = item != null &&
          item.owner == person &&
          (booking.comment ?? '').trim().isNotEmpty;
      return aboutBorrower || aboutOwner;
    }).toList();
  }

  List<Booking> reviewsForBorrower(String label, String login) => bookings
      .where(
        (booking) =>
            isBorrower(booking, label, login) &&
            (booking.ownerReviewComment ?? '').trim().isNotEmpty,
      )
      .toList();

  DateTime nextOpenDay(String itemId) {
    var day = dateOnly(DateTime.now()).add(const Duration(days: 1));
    final last = dateOnly(DateTime.now()).add(const Duration(days: 90));
    while (!day.isAfter(last)) {
      if (rangeAvailable(itemId, day, day)) return day;
      day = day.add(const Duration(days: 1));
    }
    return dateOnly(DateTime.now()).add(const Duration(days: 1));
  }

  Booking bookingById(String id) =>
      _bookings.firstWhere((booking) => booking.id == id);

  void openTab(int index) {
    requestedTab = index;
    notifyListeners();
  }

  void showMyListings() {
    focusMine = true;
    openTab(0);
  }

  bool takeFocusMine() {
    if (!focusMine) return false;
    focusMine = false;
    return true;
  }

  List<ShareItem> search({
    required String query,
    Set<ItemCategory> categories = const {},
    required bool freeOnly,
    HkDistrict? district,
    String? owner,
    SortField field = SortField.nearest,
    SortDir direction = SortDir.lowToHigh,
  }) {
    final needle = query.trim().toLowerCase();
    final results = _items.where((item) {
      final matchesQuery = needle.isEmpty || _matchesSearch(item, needle);
      final matchesCategory = categories.isEmpty || categories.contains(item.category);
      final matchesFree = !freeOnly || item.isFree;
      final matchesDistrict = district == null || item.district == district;
      final matchesOwner = owner == null || item.owner == owner;
      return matchesQuery &&
          matchesCategory &&
          matchesFree &&
          matchesDistrict &&
          matchesOwner;
    }).toList();
    int compare(ShareItem a, ShareItem b) {
      final high = direction == SortDir.highToLow;
      switch (field) {
        case SortField.nearest:
          final order = a.distanceMeters.compareTo(b.distanceMeters);
          return high ? -order : order;
        case SortField.rating:
          final order = a.rating.compareTo(b.rating);
          return high ? -order : order;
        case SortField.price:
          final order = (a.dailyPrice ?? 0).compareTo(b.dailyPrice ?? 0);
          return high ? -order : order;
      }
    }
    results.sort(compare);
    return results;
  }

  bool _matchesSearch(ShareItem item, String needle) {
    bool has(String value) => value.toLowerCase().contains(needle);
    return has(item.name) ||
        has(item.summary) ||
        has(item.owner) ||
        has(item.address) ||
        has(item.district.label) ||
        has(item.district.en) ||
        has(item.category.label) ||
        has(item.category.en);
  }

  void renameOwner(String from, String to, {String login = ''}) {
    final next = to.trim();
    if (from.trim().isEmpty || next.isEmpty || from == next) return;
    var changed = false;
    for (var index = 0; index < _items.length; index++) {
      if (_items[index].owner != from) continue;
      _items[index] = _items[index].copyWith(owner: next);
      changed = true;
    }
    for (var index = 0; index < _bookings.length; index++) {
      final booking = _bookings[index];
      if (booking.borrower == from &&
          (booking.borrowerAccount.isEmpty ||
              booking.borrowerAccount == login)) {
        _bookings[index] = booking.copyWith(borrower: next);
        changed = true;
      }
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
    required String borrower,
    String borrowerAccount = '',
    required PayMethod payMethod,
    bool useAgreed = false,
    double? agreedDaily,
    double agreedDeposit = 0,
  }) {
    final from = dateOnly(start);
    final to = dateOnly(end);
    if (to.isBefore(from) || !rangeAvailable(itemId, from, to)) return null;
    final item = findItem(itemId);
    if (item == null) return null;
    if (borrower == item.owner) return null;
    _sequence += 1;
    final daily = useAgreed ? agreedDaily : item.dailyPrice;
    final depositFee = useAgreed ? agreedDeposit : item.depositAmount;
    final free = daily == null || daily == 0;
    final holdsDeposit = depositFee > 0;
    final rentOnline = payMethod == PayMethod.online && !free;
    final booking = Booking(
      id: 'SK-$_sequence',
      itemId: itemId,
      start: from,
      end: to,
      stage: BookingStage.requested,
      pickupCode: (_sequence * 37 % 9000 + 1000).toString(),
      note: note.trim(),
      payMethod: payMethod,
      deposit: holdsDeposit || rentOnline
          ? DepositStatus.pending
          : DepositStatus.none,
      depositAmount: depositFee,
      offeredPrice: useAgreed,
      offeredDaily: useAgreed ? daily : null,
      borrower: borrower,
      borrowerAccount: borrowerAccount,
    );
    _bookings.add(booking);
    notifyListeners();
    _persist();
    return booking;
  }

  void acceptBooking(String bookingId) {
    final booking = bookingById(bookingId);
    if (booking.stage != BookingStage.requested) return;
    _update(
      bookingId,
      (current) => current.copyWith(stage: BookingStage.reserved),
    );
  }

  void rejectBooking(String bookingId, String reason) {
    final booking = bookingById(bookingId);
    if (booking.stage != BookingStage.requested) return;
    _update(
      bookingId,
      (current) =>
          current.copyWith(stage: BookingStage.rejected, issue: reason.trim()),
    );
  }

  bool needsOnlinePayment(Booking booking) {
    if (booking.deposit != DepositStatus.pending ||
        booking.stage != BookingStage.reserved) {
      return false;
    }
    if (booking.depositAmount > 0) return true;
    if (booking.offeredPrice) {
      return booking.payMethod == PayMethod.online && (booking.offeredDaily ?? 0) > 0;
    }
    final item = findItem(booking.itemId);
    if (item == null || item.isFree) return false;
    return booking.payMethod == PayMethod.online;
  }

  bool codeReady(Booking booking) {
    if (booking.stage == BookingStage.requested ||
        booking.stage == BookingStage.rejected) {
      return false;
    }
    return !needsOnlinePayment(booking);
  }

  void payDeposit(String bookingId) {
    final booking = bookingById(bookingId);
    if (booking.deposit != DepositStatus.pending) return;
    _update(
      bookingId,
      (current) => current.copyWith(deposit: DepositStatus.paid),
    );
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
    final current = bookingById(bookingId);
    if (current.deposit == DepositStatus.pending) return;
    final returnCode = current.returnCode.isEmpty
        ? ((_sequence * 53) % 9000 + 1000).toString()
        : current.returnCode;
    _update(
      bookingId,
      (booking) => booking.copyWith(
        stage: BookingStage.pickedUp,
        returnCode: returnCode,
      ),
    );
  }

  void markReturned(String bookingId, String condition, {Uint8List? photo}) {
    _update(
      bookingId,
      (booking) => booking.copyWith(
        stage: BookingStage.returned,
        returnCondition: condition,
        returnedAt: DateTime.now(),
        returnPhoto: photo == null ? null : (shrinkPhotoBytes(photo) ?? photo),
      ),
    );
  }

  bool saveReview(
    String bookingId,
    int stars,
    String comment, {
    required String reviewerLabel,
    required String reviewerLogin,
  }) {
    final booking = bookingById(bookingId);
    final itemIndex = _items.indexWhere((item) => item.id == booking.itemId);
    final text = comment.trim();
    if (itemIndex == -1 ||
        stars < 1 ||
        stars > 5 ||
        text.isEmpty ||
        (booking.stage != BookingStage.returned &&
            booking.stage != BookingStage.reviewed)) {
      return false;
    }
    final item = _items[itemIndex];
    final isOwner = item.owner == reviewerLabel || item.owner == reviewerLogin;
    final borrower = isBorrower(booking, reviewerLabel, reviewerLogin);
    if (borrower && (booking.comment ?? '').trim().isEmpty) {
      final nextCount = item.reviewCount + 1;
      final nextRating = ((item.rating * item.reviewCount) + stars) / nextCount;
      _items[itemIndex] = item.copyWith(
        rating: double.parse(nextRating.toStringAsFixed(1)),
        reviewCount: nextCount,
        handovers: item.handovers + 1,
      );
      _update(
        bookingId,
        (current) => current.copyWith(
          stage: BookingStage.reviewed,
          stars: stars,
          comment: text,
        ),
      );
      return true;
    }
    if (!isOwner ||
        booking.borrower.isEmpty ||
        (booking.ownerReviewComment ?? '').trim().isNotEmpty) {
      return false;
    }
    _update(
      bookingId,
      (current) => current.copyWith(
        stage: BookingStage.reviewed,
        ownerReviewStars: stars,
        ownerReviewComment: text,
        ownerReviewAuthor: reviewerLabel,
      ),
    );
    return true;
  }

  void addItem({
    required String name,
    required String owner,
    required ItemCategory category,
    required String condition,
    required String summary,
    required double? dailyPrice,
    required double depositAmount,
    double? lengthCm,
    double? widthCm,
    double? heightCm,
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
        depositAmount: depositAmount,
        lengthCm: lengthCm,
        widthCm: widthCm,
        heightCm: heightCm,
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

/// Production catalog starts empty; real listings come from users / remote DB.
List<ShareItem> seedItems() => const [];
