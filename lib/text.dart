import 'package:flutter/widgets.dart';

import 'models.dart';

class AppLang extends InheritedWidget {
  const AppLang({super.key, required this.english, required super.child});

  final bool english;

  static bool of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppLang>()?.english ??
        false;
  }

  @override
  bool updateShouldNotify(AppLang oldWidget) => oldWidget.english != english;
}

String tr(BuildContext context, String zh, String en) {
  return AppLang.of(context) ? en : zh;
}

String both(String zh, String en) => '$zh\n$en';

String shown(BuildContext context, String message) {
  if (!AppLang.of(context)) return message;
  return switch (message) {
    '請先驗證電郵或電話。' => 'Verify your email or phone first.',
    '請填名稱、密碼和電郵或電話。' => 'Enter a name, password, and email or phone.',
    '這個名稱已經有人用了。' => 'That name is already taken.',
    '找不到這個帳號。' => 'That account was not found.',
    '驗證碼不對。' => 'That code is wrong.',
    '請填顯示名稱。' => 'Enter a display name.',
    _ => message,
  };
}

String districtLabel(BuildContext context, HkDistrict district) {
  return tr(context, district.label, district.en);
}

String regionLabel(BuildContext context, HkRegion region) {
  return tr(context, region.label, region.en);
}

String categoryLabel(BuildContext context, ItemCategory category) {
  return tr(context, category.label, category.en);
}

String sizeText(BuildContext context, ShareItem item) {
  String number(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
  final parts = <String>[
    if (item.lengthCm != null) tr(context, '長 ${number(item.lengthCm!)}', 'L ${number(item.lengthCm!)}'),
    if (item.widthCm != null) tr(context, '闊 ${number(item.widthCm!)}', 'W ${number(item.widthCm!)}'),
    if (item.heightCm != null) tr(context, '高 ${number(item.heightCm!)}', 'H ${number(item.heightCm!)}'),
  ];
  if (parts.isEmpty) return '';
  return '${parts.join(' × ')} cm';
}

String handoverLabel(BuildContext context, HandoverMethod method) {
  return tr(context, method.label, method.en);
}

String stageLabel(BuildContext context, BookingStage stage) {
  return tr(context, stage.label, stage.en);
}

String depositLabel(BuildContext context, DepositStatus status) {
  return tr(context, status.label, status.en);
}

String sortLabel(BuildContext context, ItemSort sort) {
  return tr(context, sort.label, sort.en);
}

String priceText(BuildContext context, ShareItem item) {
  if (item.isFree) return tr(context, '免費借用', 'Free to borrow');
  final amount = money(item.dailyPrice!);
  return tr(context, '每日 $amount', '$amount / day');
}

String distanceText(BuildContext context, int meters) {
  if (meters >= 1000) {
    final km = (meters / 1000).toStringAsFixed(1);
    return tr(context, '$km 公里', '$km km');
  }
  return tr(context, '$meters 米', '$meters m');
}

String conditionLabel(BuildContext context, String condition) {
  return switch (condition) {
    '全新' => tr(context, '全新', 'New'),
    '良好' => tr(context, '良好', 'Good'),
    '有使用痕跡' => tr(context, '有使用痕跡', 'Used'),
    '完好' => tr(context, '完好', 'Fine'),
    '有輕微使用痕跡' => tr(context, '有輕微使用痕跡', 'Light wear'),
    '需要物主再檢查' => tr(context, '需要物主再檢查', 'Owner should check'),
    _ => condition,
  };
}
