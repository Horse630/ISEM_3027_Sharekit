import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sharekit/main.dart';
import 'package:sharekit/store.dart';

void main() {
  testWidgets('探索頁顯示附近可借物品', (tester) async {
    await tester.pumpWidget(ShareKitApp(store: ShareStore()));
    expect(find.text('ShareKit'), findsOneWidget);
    expect(find.text('充電電鑽套裝'), findsOneWidget);
  });

  testWidgets('可以完成預約、取件、歸還和評價', (tester) async {
    await tester.pumpWidget(ShareKitApp(store: ShareStore()));
    await tester.tap(find.text('充電電鑽套裝'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('預約這件物品'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('確認預約'));
    await tester.pumpAndSettle();

    expect(find.text('待取件'), findsWidgets);
    await tester.tap(find.text('確認已取件'));
    await tester.pumpAndSettle();
    expect(find.text('使用中'), findsWidgets);

    await tester.tap(find.text('確認歸還'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('完成歸還'));
    await tester.pumpAndSettle();
    expect(find.text('待評價'), findsWidgets);

    await tester.tap(find.text('撰寫評價'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '取件準時，工具齊全。');
    await tester.tap(find.text('送出評價'));
    await tester.pumpAndSettle();
    expect(find.text('已完成'), findsWidgets);
    expect(find.text('取件準時，工具齊全。'), findsOneWidget);
  });
}
