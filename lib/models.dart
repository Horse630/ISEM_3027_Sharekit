import 'dart:typed_data';

import 'package:flutter/material.dart';

enum HkRegion { island, kowloon, newTerritories }

extension HkRegionX on HkRegion {
  String get label => switch (this) {
    HkRegion.island => '香港島',
    HkRegion.kowloon => '九龍',
    HkRegion.newTerritories => '新界',
  };

  String get en => switch (this) {
    HkRegion.island => 'Hong Kong Island',
    HkRegion.kowloon => 'Kowloon',
    HkRegion.newTerritories => 'New Territories',
  };
}

enum HkDistrict {
  centralWestern('中西區', HkRegion.island),
  wanChai('灣仔區', HkRegion.island),
  eastern('東區', HkRegion.island),
  southern('南區', HkRegion.island),
  yauTsimMong('油尖旺區', HkRegion.kowloon),
  shamShuiPo('深水埗區', HkRegion.kowloon),
  kowloonCity('九龍城區', HkRegion.kowloon),
  wongTaiSin('黃大仙區', HkRegion.kowloon),
  kwunTong('觀塘區', HkRegion.kowloon),
  kwaiTsing('葵青區', HkRegion.newTerritories),
  tsuenWan('荃灣區', HkRegion.newTerritories),
  tuenMun('屯門區', HkRegion.newTerritories),
  yuenLong('元朗區', HkRegion.newTerritories),
  north('北區', HkRegion.newTerritories),
  taiPo('大埔區', HkRegion.newTerritories),
  shaTin('沙田區', HkRegion.newTerritories),
  saiKung('西貢區', HkRegion.newTerritories),
  islands('離島區', HkRegion.newTerritories);

  const HkDistrict(this.label, this.region);

  final String label;
  final HkRegion region;

  static HkDistrict byName(String? name) {
    for (final district in values) {
      if (district.name == name || district.label == name) return district;
    }
    return HkDistrict.kowloonCity;
  }

  String get en => switch (this) {
    HkDistrict.centralWestern => 'Central & Western',
    HkDistrict.wanChai => 'Wan Chai',
    HkDistrict.eastern => 'Eastern',
    HkDistrict.southern => 'Southern',
    HkDistrict.yauTsimMong => 'Yau Tsim Mong',
    HkDistrict.shamShuiPo => 'Sham Shui Po',
    HkDistrict.kowloonCity => 'Kowloon City',
    HkDistrict.wongTaiSin => 'Wong Tai Sin',
    HkDistrict.kwunTong => 'Kwun Tong',
    HkDistrict.kwaiTsing => 'Kwai Tsing',
    HkDistrict.tsuenWan => 'Tsuen Wan',
    HkDistrict.tuenMun => 'Tuen Mun',
    HkDistrict.yuenLong => 'Yuen Long',
    HkDistrict.north => 'North',
    HkDistrict.taiPo => 'Tai Po',
    HkDistrict.shaTin => 'Sha Tin',
    HkDistrict.saiKung => 'Sai Kung',
    HkDistrict.islands => 'Islands',
  };
}

class DistrictFilter {
  const DistrictFilter(this.district);

  final HkDistrict? district;
}

enum ItemSort { nearest, rating, priceLow }

extension ItemSortX on ItemSort {
  String get label => switch (this) {
    ItemSort.nearest => '最近',
    ItemSort.rating => '評價',
    ItemSort.priceLow => '租金',
  };

  String get en => switch (this) {
    ItemSort.nearest => 'Nearest',
    ItemSort.rating => 'Rating',
    ItemSort.priceLow => 'Price',
  };
}

enum ItemCategory { tool, home, outdoor, event }

extension ItemCategoryX on ItemCategory {
  String get label => switch (this) {
    ItemCategory.tool => '工具',
    ItemCategory.home => '家居',
    ItemCategory.outdoor => '戶外',
    ItemCategory.event => '活動',
  };

  String get en => switch (this) {
    ItemCategory.tool => 'Tools',
    ItemCategory.home => 'Home',
    ItemCategory.outdoor => 'Outdoor',
    ItemCategory.event => 'Events',
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

enum PayMethod { online, face }

extension PayMethodX on PayMethod {
  String get label => switch (this) {
    PayMethod.online => '線上付款',
    PayMethod.face => '當面付款',
  };

  String get en => switch (this) {
    PayMethod.online => 'Pay online',
    PayMethod.face => 'Pay in person',
  };
}

enum BookingStage { requested, rejected, reserved, pickedUp, returned, reviewed }

enum HandoverMethod { faceToFace, mail }

extension HandoverMethodX on HandoverMethod {
  String get label => switch (this) {
    HandoverMethod.faceToFace => '當面交接',
    HandoverMethod.mail => '郵寄',
  };

  String get en => switch (this) {
    HandoverMethod.faceToFace => 'In person',
    HandoverMethod.mail => 'Post',
  };
}

enum DepositStatus { none, pending, paid, refunded }

extension DepositStatusX on DepositStatus {
  String get label => switch (this) {
    DepositStatus.none => '無需按金',
    DepositStatus.pending => '按金待付',
    DepositStatus.paid => '按金已付',
    DepositStatus.refunded => '按金已退',
  };

  String get en => switch (this) {
    DepositStatus.none => 'No deposit',
    DepositStatus.pending => 'Deposit due',
    DepositStatus.paid => 'Deposit paid',
    DepositStatus.refunded => 'Deposit refunded',
  };
}

extension BookingStageX on BookingStage {
  String get label => switch (this) {
    BookingStage.requested => '待物主確認',
    BookingStage.rejected => '已拒絕',
    BookingStage.reserved => '待交接',
    BookingStage.pickedUp => '使用中',
    BookingStage.returned => '已歸還',
    BookingStage.reviewed => '已完成',
  };

  String get en => switch (this) {
    BookingStage.requested => 'Waiting for the owner',
    BookingStage.rejected => 'Rejected',
    BookingStage.reserved => 'Ready to hand over',
    BookingStage.pickedUp => 'In use',
    BookingStage.returned => 'Returned',
    BookingStage.reviewed => 'Done',
  };

  int get trackStep => switch (this) {
    BookingStage.requested || BookingStage.rejected || BookingStage.reserved => 0,
    BookingStage.pickedUp => 1,
    BookingStage.returned => 2,
    BookingStage.reviewed => 3,
  };

  bool get blocksDates =>
      this == BookingStage.requested ||
      this == BookingStage.reserved ||
      this == BookingStage.pickedUp;
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
    this.photoBytes,
    this.address = '九龍塘示範屋苑',
    this.district = HkDistrict.kowloonCity,
    this.handover = HandoverMethod.faceToFace,
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
  final Uint8List? photoBytes;
  final String address;
  final HkDistrict district;
  final HandoverMethod handover;

  bool get isFree => dailyPrice == null || dailyPrice == 0;

  String get priceLabel => isFree ? '免費借用' : '每日 ${money(dailyPrice!)}';

  ShareItem copyWith({
    double? rating,
    int? reviewCount,
    int? handovers,
    String? owner,
    HkDistrict? district,
  }) {
    return ShareItem(
      id: id,
      name: name,
      owner: owner ?? this.owner,
      category: category,
      condition: condition,
      distanceMeters: distanceMeters,
      summary: summary,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      handovers: handovers ?? this.handovers,
      dailyPrice: dailyPrice,
      photoBytes: photoBytes,
      address: address,
      district: district ?? this.district,
      handover: handover,
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
    this.payMethod = PayMethod.online,
    this.deposit = DepositStatus.none,
    this.borrower = '',
    this.returnCondition,
    this.stars,
    this.comment,
    this.issue,
  });

  final String id;
  final String itemId;
  final DateTime start;
  final DateTime end;
  final BookingStage stage;
  final String pickupCode;
  final String note;
  final PayMethod payMethod;
  final DepositStatus deposit;
  final String borrower;
  final String? returnCondition;
  final int? stars;
  final String? comment;
  final String? issue;

  int get days => end.difference(start).inDays + 1;

  Booking copyWith({
    BookingStage? stage,
    DepositStatus? deposit,
    PayMethod? payMethod,
    String? returnCondition,
    int? stars,
    String? comment,
    String? issue,
    String? borrower,
  }) {
    return Booking(
      id: id,
      itemId: itemId,
      start: start,
      end: end,
      stage: stage ?? this.stage,
      pickupCode: pickupCode,
      note: note,
      payMethod: payMethod ?? this.payMethod,
      deposit: deposit ?? this.deposit,
      borrower: borrower ?? this.borrower,
      returnCondition: returnCondition ?? this.returnCondition,
      stars: stars ?? this.stars,
      comment: comment ?? this.comment,
      issue: issue ?? this.issue,
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
  return PriceQuote(days: days, rent: rent, serviceFee: 0, free: false);
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
