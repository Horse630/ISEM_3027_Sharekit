import 'package:flutter/material.dart';

enum ItemCategory { tool, home, outdoor, event }

extension ItemCategoryX on ItemCategory {
  String get label => switch (this) {
    ItemCategory.tool => '工具',
    ItemCategory.home => '家居',
    ItemCategory.outdoor => '戶外',
    ItemCategory.event => '活動',
  };

  IconData get icon => switch (this) {
    ItemCategory.tool => Icons.handyman_outlined,
    ItemCategory.home => Icons.cleaning_services_outlined,
    ItemCategory.outdoor => Icons.forest_outlined,
    ItemCategory.event => Icons.event_seat_outlined,
  };

  Color get color => switch (this) {
    ItemCategory.tool => const Color(0xFF0E6B52),
    ItemCategory.home => const Color(0xFF8C6239),
    ItemCategory.outdoor => const Color(0xFF1D6A86),
    ItemCategory.event => const Color(0xFF9A4632),
  };
}

enum BookingStage { reserved, pickedUp, returned, reviewed }

extension BookingStageX on BookingStage {
  String get label => switch (this) {
    BookingStage.reserved => '待取件',
    BookingStage.pickedUp => '使用中',
    BookingStage.returned => '待評價',
    BookingStage.reviewed => '已完成',
  };

  bool get blocksDates =>
      this == BookingStage.reserved || this == BookingStage.pickedUp;
}

class ShareItem {
  const ShareItem({
    required this.id,
    required this.name,
    required this.owner,
    required this.category,
    required this.condition,
    required this.distanceMeters,
    required this.summary,
    required this.rating,
    required this.reviewCount,
    required this.handovers,
    this.dailyPrice,
  });

  final String id;
  final String name;
  final String owner;
  final ItemCategory category;
  final String condition;
  final int distanceMeters;
  final String summary;
  final double rating;
  final int reviewCount;
  final int handovers;
  final double? dailyPrice;

  bool get isFree => dailyPrice == null || dailyPrice == 0;

  String get priceLabel => isFree ? '免費借用' : '每日 ${money(dailyPrice!)}';

  ShareItem copyWith({double? rating, int? reviewCount, int? handovers}) {
    return ShareItem(
      id: id,
      name: name,
      owner: owner,
      category: category,
      condition: condition,
      distanceMeters: distanceMeters,
      summary: summary,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      handovers: handovers ?? this.handovers,
      dailyPrice: dailyPrice,
    );
  }
}

class Booking {
  const Booking({
    required this.id,
    required this.itemId,
    required this.start,
    required this.end,
    required this.stage,
    required this.pickupCode,
    required this.note,
    this.returnCondition,
    this.stars,
    this.comment,
  });

  final String id;
  final String itemId;
  final DateTime start;
  final DateTime end;
  final BookingStage stage;
  final String pickupCode;
  final String note;
  final String? returnCondition;
  final int? stars;
  final String? comment;

  int get days => end.difference(start).inDays + 1;

  Booking copyWith({
    BookingStage? stage,
    String? returnCondition,
    int? stars,
    String? comment,
  }) {
    return Booking(
      id: id,
      itemId: itemId,
      start: start,
      end: end,
      stage: stage ?? this.stage,
      pickupCode: pickupCode,
      note: note,
      returnCondition: returnCondition ?? this.returnCondition,
      stars: stars ?? this.stars,
      comment: comment ?? this.comment,
    );
  }
}

class PriceQuote {
  const PriceQuote({
    required this.days,
    required this.rent,
    required this.serviceFee,
    required this.free,
  });

  final int days;
  final double rent;
  final double serviceFee;
  final bool free;

  double get total => rent + serviceFee;
}

DateTime dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

String formatDate(DateTime value) {
  final day = dateOnly(value);
  final m = day.month.toString().padLeft(2, '0');
  final d = day.day.toString().padLeft(2, '0');
  return '${day.year}/$m/$d';
}

String money(double value) {
  if (value == value.roundToDouble()) {
    return 'HK\$${value.toStringAsFixed(0)}';
  }
  return 'HK\$${value.toStringAsFixed(1)}';
}

String formatDistance(int meters) {
  if (meters >= 1000) {
    return '${(meters / 1000).toStringAsFixed(1)} 公里';
  }
  return '$meters 米';
}

PriceQuote quoteFor(ShareItem item, DateTime start, DateTime end) {
  final days = dateOnly(end).difference(dateOnly(start)).inDays + 1;
  if (item.isFree) {
    return PriceQuote(days: days, rent: 0, serviceFee: 0, free: true);
  }
  final rent = item.dailyPrice! * days;
  final fee = (rent * 0.1).roundToDouble();
  return PriceQuote(days: days, rent: rent, serviceFee: fee, free: false);
}

bool rangesOverlap(
  DateTime aStart,
  DateTime aEnd,
  DateTime bStart,
  DateTime bEnd,
) {
  final a1 = dateOnly(aStart);
  final a2 = dateOnly(aEnd);
  final b1 = dateOnly(bStart);
  final b2 = dateOnly(bEnd);
  return !a2.isBefore(b1) && !b2.isBefore(a1);
}
