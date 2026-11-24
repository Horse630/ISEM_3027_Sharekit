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

String districtLabel(BuildContext context, HkDistrict district) {
  return tr(context, district.label, district.en);
}

String regionLabel(BuildContext context, HkRegion region) {
  return tr(context, region.label, region.en);
}

String categoryLabel(BuildContext context, ItemCategory category) {
  return tr(context, category.label, category.en);
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
