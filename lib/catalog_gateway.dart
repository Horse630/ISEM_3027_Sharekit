import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:sqflite/sqflite.dart';

import 'models.dart';

class CatalogSnapshot {
  const CatalogSnapshot({
    required this.items,
    required this.bookings,
    required this.sequence,
  });

  final List<ShareItem> items;
  final List<Booking> bookings;
  final int sequence;
}

abstract class CatalogGateway {
  Future<CatalogSnapshot> load();
  Future<void> save(CatalogSnapshot snapshot);
}

class LocalCatalog implements CatalogGateway {
  LocalCatalog(this._db, {required this.seed});

  final Database _db;
  final List<ShareItem> Function() seed;

  @override
  Future<CatalogSnapshot> load() async {
    final count = Sqflite.firstIntValue(
      await _db.rawQuery('SELECT COUNT(*) FROM items'),
    );
    if (count == 0) {
      final seeded = CatalogSnapshot(items: seed(), bookings: const [], sequence: 240);
      await save(seeded);
      return seeded;
    }
    final itemRows = await _db.query('items', orderBy: 'rowid ASC');
    final bookingRows = await _db.query('bookings', orderBy: 'rowid ASC');
    final meta = await _db.query('catalog_meta', where: 'id = 1', limit: 1);
    final sequence = meta.isEmpty ? 240 : meta.first['sequence'] as int;
    return CatalogSnapshot(
      items: itemRows.map(itemFromRow).toList(),
      bookings: bookingRows.map(bookingFromRow).toList(),
      sequence: sequence,
    );
  }

  @override
  Future<void> save(CatalogSnapshot snapshot) async {
    await _db.transaction((txn) async {
      await txn.delete('items');
      await txn.delete('bookings');
      for (final item in snapshot.items) {
        await txn.insert('items', itemToRow(item));
      }
      for (final booking in snapshot.bookings) {
        await txn.insert('bookings', bookingToRow(booking));
      }
      await txn.insert('catalog_meta', {
        'id': 1,
        'sequence': snapshot.sequence,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }
}

class RemoteCatalog implements CatalogGateway {
  RemoteCatalog(this.origin);

  static const defaultOrigin = 'http://127.0.0.1:8780';

  final String origin;

  static Future<RemoteCatalog?> connect([
    String origin = defaultOrigin,
  ]) async {
    try {
      final response = await http
          .get(Uri.parse('$origin/api/health'))
          .timeout(const Duration(seconds: 2));
      if (response.statusCode != 200) return null;
      return RemoteCatalog(origin);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<CatalogSnapshot> load() async {
    final response = await http
        .get(Uri.parse('$origin/api/catalog'))
        .timeout(const Duration(seconds: 5));
    if (response.statusCode != 200) {
      throw StateError('共用資料庫讀取失敗');
    }
    return snapshotFromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  @override
  Future<void> save(CatalogSnapshot snapshot) async {
    final response = await http
        .put(
          Uri.parse('$origin/api/catalog'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode(snapshotToJson(snapshot)),
        )
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      throw StateError('共用資料庫寫入失敗');
    }
  }
}

class PublicCatalog implements CatalogGateway {
  static const documentUrl =
      'https://isem-3027-sharekit.onrender.com/api/catalog';

  static Future<PublicCatalog?> connect() async {
    try {
      final response = await http
          .get(Uri.parse(documentUrl))
          .timeout(const Duration(seconds: 75));
      if (response.statusCode != 200) return null;
      return PublicCatalog();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<CatalogSnapshot> load() async {
    final response = await http
        .get(Uri.parse(documentUrl))
        .timeout(const Duration(seconds: 75));
    if (response.statusCode != 200) {
      throw StateError('共用資料庫讀取失敗');
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    json.remove('_id');
    return snapshotFromJson(json);
  }

  @override
  Future<void> save(CatalogSnapshot snapshot) async {
    var response = await _put(_shrinkSnapshot(snapshot));
    if (response.statusCode == 413) {
      response = await _put(_withoutPhotos(snapshot));
    }
    if (response.statusCode != 200) {
      throw StateError('共用資料庫寫入失敗');
    }
  }

  Future<http.Response> _put(CatalogSnapshot snapshot) {
    return http
        .put(
          Uri.parse(documentUrl),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode(snapshotToJson(snapshot)),
        )
        .timeout(const Duration(seconds: 75));
  }
}

class CombinedCatalog implements CatalogGateway {
  CombinedCatalog({required this.local, this.remote});

  final LocalCatalog local;
  final CatalogGateway? remote;

  @override
  Future<CatalogSnapshot> load() async {
    final localSnapshot = await local.load();
    final remoteCatalog = remote;
    if (remoteCatalog == null) return localSnapshot;
    final remoteSnapshot = await remoteCatalog.load();
    final merged = mergeCatalogs(remoteSnapshot, localSnapshot);
    await remoteCatalog.save(merged);
    await local.save(merged);
    return merged;
  }

  @override
  Future<void> save(CatalogSnapshot snapshot) async {
    await local.save(snapshot);
    final remoteCatalog = remote;
    if (remoteCatalog == null) return;
    await remoteCatalog.save(snapshot);
  }
}

CatalogSnapshot mergeCatalogs(CatalogSnapshot remote, CatalogSnapshot local) {
  final items = [...remote.items];
  final itemIds = items.map((item) => item.id).toSet();
  for (final item in local.items) {
    if (itemIds.add(item.id)) items.add(item);
  }
  final bookings = [...remote.bookings];
  final bookingIds = bookings.map((booking) => booking.id).toSet();
  for (final booking in local.bookings) {
    if (bookingIds.add(booking.id)) bookings.add(booking);
  }
  return CatalogSnapshot(
    items: items,
    bookings: bookings,
    sequence: math.max(remote.sequence, local.sequence),
  );
}

Map<String, Object?> itemToRow(ShareItem item) {
  return {
    'id': item.id,
    'name': item.name,
    'owner': item.owner,
    'category': item.category.name,
    'condition': item.condition,
    'distance_meters': item.distanceMeters,
    'summary': item.summary,
    'rating': item.rating,
    'review_count': item.reviewCount,
    'handovers': item.handovers,
    'daily_price': item.dailyPrice,
    'deposit_amount': item.depositAmount,
    'length_cm': item.lengthCm,
    'width_cm': item.widthCm,
    'height_cm': item.heightCm,
    'photo': item.photoBytes,
    'address': item.address,
    'district': item.district.name,
    'handover': item.handover.name,
  };
}

ShareItem itemFromRow(Map<String, Object?> row) {
  return ShareItem(
    id: row['id'] as String,
    name: row['name'] as String,
    owner: row['owner'] as String,
    category: ItemCategoryX.parse(row['category'] as String?),
    condition: row['condition'] as String,
    distanceMeters: row['distance_meters'] as int,
    summary: row['summary'] as String,
    rating: (row['rating'] as num).toDouble(),
    reviewCount: row['review_count'] as int,
    handovers: row['handovers'] as int,
    dailyPrice: (row['daily_price'] as num?)?.toDouble(),
    depositAmount: (row['deposit_amount'] as num?)?.toDouble() ?? 0,
    lengthCm: (row['length_cm'] as num?)?.toDouble(),
    widthCm: (row['width_cm'] as num?)?.toDouble(),
    heightCm: (row['height_cm'] as num?)?.toDouble(),
    photoBytes: _bytes(row['photo']),
    address: row['address'] as String,
    district: _districtOf(row),
    handover: HandoverMethod.values.byName(row['handover'] as String),
  );
}

HkDistrict _districtOf(Map<String, Object?> row) {
  final saved = row['district'];
  if (saved is String && saved.isNotEmpty) return HkDistrict.byName(saved);
  return switch (row['id']) {
    'camp' => HkDistrict.shaTin,
    'projector' => HkDistrict.yauTsimMong,
    'washer' => HkDistrict.kwunTong,
    'cookset' => HkDistrict.saiKung,
    'cart' => HkDistrict.shamShuiPo,
    _ => HkDistrict.kowloonCity,
  };
}

Map<String, Object?> bookingToRow(Booking booking) {
  return {
    'id': booking.id,
    'item_id': booking.itemId,
    'start_date': _date(booking.start),
    'end_date': _date(booking.end),
    'stage': booking.stage.name,
    'pickup_code': booking.pickupCode,
    'note': booking.note,
    'pay_method': booking.payMethod.name,
    'deposit': booking.deposit.name,
    'deposit_amount': booking.depositAmount,
    'offered_price': booking.offeredPrice ? 1 : 0,
    'offered_daily': booking.offeredDaily,
    'borrower': booking.borrower,
    'borrower_account': booking.borrowerAccount,
    'owner_review_stars': booking.ownerReviewStars,
    'owner_review_comment': booking.ownerReviewComment,
    'owner_review_author': booking.ownerReviewAuthor,
    'return_condition': booking.returnCondition,
    'return_code': booking.returnCode,
    'returned_at': booking.returnedAt?.toIso8601String(),
    'return_photo': booking.returnPhoto,
    'stars': booking.stars,
    'comment': booking.comment,
    'issue': booking.issue,
  };
}

Booking bookingFromRow(Map<String, Object?> row) {
  return Booking(
    id: row['id'] as String,
    itemId: row['item_id'] as String,
    start: DateTime.parse(row['start_date'] as String),
    end: DateTime.parse(row['end_date'] as String),
    stage: BookingStage.values.byName(row['stage'] as String),
    pickupCode: row['pickup_code'] as String,
    note: row['note'] as String,
    payMethod: PayMethod.values.byName((row['pay_method'] as String?) ?? 'online'),
    deposit: DepositStatus.values.byName(row['deposit'] as String),
    depositAmount: (row['deposit_amount'] as num?)?.toDouble() ?? 0,
    offeredPrice: row['offered_price'] == 1 || row['offered_price'] == true,
    offeredDaily: (row['offered_daily'] as num?)?.toDouble(),
    borrower: (row['borrower'] as String?) ?? '',
    borrowerAccount: (row['borrower_account'] as String?) ?? '',
    ownerReviewStars: row['owner_review_stars'] as int?,
    ownerReviewComment: row['owner_review_comment'] as String?,
    ownerReviewAuthor: row['owner_review_author'] as String?,
    returnCondition: row['return_condition'] as String?,
    returnCode: (row['return_code'] as String?) ?? '',
    returnedAt: DateTime.tryParse((row['returned_at'] as String?) ?? ''),
    returnPhoto: _bytes(row['return_photo']),
    stars: row['stars'] as int?,
    comment: row['comment'] as String?,
    issue: row['issue'] as String?,
  );
}

Map<String, Object?> snapshotToJson(CatalogSnapshot snapshot) {
  return {
    'sequence': snapshot.sequence,
    'items': snapshot.items.map(_itemJson).toList(),
    'bookings': snapshot.bookings.map(_bookingJson).toList(),
  };
}

CatalogSnapshot snapshotFromJson(Map<String, dynamic> json) {
  final items = (json['items'] as List<dynamic>? ?? const [])
      .map((row) => itemFromRow(Map<String, Object?>.from(row as Map)))
      .toList();
  final bookings = (json['bookings'] as List<dynamic>? ?? const [])
      .map((row) => bookingFromRow(_bookingRow(Map<String, Object?>.from(row as Map))))
      .toList();
  return CatalogSnapshot(
    items: items,
    bookings: bookings,
    sequence: json['sequence'] as int? ?? 240,
  );
}

Map<String, Object?> _itemJson(ShareItem item) {
  final row = itemToRow(item);
  final photo = item.photoBytes;
  row['photo'] = photo == null ? null : base64Encode(photo);
  return row;
}

Map<String, Object?> _bookingJson(Booking booking) {
  final row = bookingToRow(booking);
  final photo = booking.returnPhoto;
  row['return_photo'] = photo == null ? null : base64Encode(photo);
  return row;
}

Map<String, Object?> _bookingRow(Map<String, Object?> json) => json;

Uint8List? _bytes(Object? value) {
  if (value == null) return null;
  if (value is Uint8List) return value;
  if (value is List) return Uint8List.fromList(value.cast<int>());
  if (value is String && value.isEmpty) return null;
  if (value is String) return base64Decode(value);
  return null;
}

CatalogSnapshot _shrinkSnapshot(CatalogSnapshot snapshot) {
  return CatalogSnapshot(
    items: [
      for (final item in snapshot.items)
        _withPhoto(item, _shrinkPhoto(item.photoBytes)),
    ],
    bookings: snapshot.bookings,
    sequence: snapshot.sequence,
  );
}

CatalogSnapshot _withoutPhotos(CatalogSnapshot snapshot) {
  return CatalogSnapshot(
    items: [for (final item in snapshot.items) _withPhoto(item, null)],
    bookings: snapshot.bookings,
    sequence: snapshot.sequence,
  );
}

ShareItem _withPhoto(ShareItem item, Uint8List? photo) {
  return ShareItem(
    id: item.id,
    name: item.name,
    owner: item.owner,
    category: item.category,
    condition: item.condition,
    distanceMeters: item.distanceMeters,
    summary: item.summary,
    rating: item.rating,
    reviewCount: item.reviewCount,
    handovers: item.handovers,
    dailyPrice: item.dailyPrice,
    depositAmount: item.depositAmount,
    lengthCm: item.lengthCm,
    widthCm: item.widthCm,
    heightCm: item.heightCm,
    photoBytes: photo,
    address: item.address,
    district: item.district,
    handover: item.handover,
  );
}

Uint8List? shrinkPhotoBytes(Uint8List? bytes) => _shrinkPhoto(bytes);

Uint8List? _shrinkPhoto(Uint8List? bytes) {
  if (bytes == null || bytes.length < 80000) return bytes;
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return bytes.length > 300000 ? null : bytes;
  final resized = decoded.width > 480
      ? img.copyResize(decoded, width: 480)
      : decoded;
  final jpg = Uint8List.fromList(img.encodeJpg(resized, quality: 42));
  return jpg.length < bytes.length ? jpg : bytes;
}

String _date(DateTime value) {
  final day = dateOnly(value);
  final month = day.month.toString().padLeft(2, '0');
  final date = day.day.toString().padLeft(2, '0');
  return '${day.year}-$month-$date';
}
