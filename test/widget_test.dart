import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sharekit/auth_repository.dart';
import 'package:sharekit/catalog_gateway.dart';
import 'package:sharekit/main.dart';
import 'package:sharekit/models.dart';
import 'package:sharekit/store.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  final stamp = DateTime.now().microsecondsSinceEpoch;
  var databaseNumber = 0;

  String nextDatabase() =>
      '${Directory.systemTemp.path}${Platform.pathSeparator}sharekit_${stamp}_${databaseNumber++}.db';

  Future<void> settleDatabase(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> signIn(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField).at(0), 'Isem_3027');
    await tester.enterText(find.byType(TextField).at(1), 'Isem_3027');
    await tester.tap(find.text('登入'));
    await settleDatabase(tester);
  }

  Future<ShareStore> openApp(WidgetTester tester) async {
    final store = ShareStore();
    await tester.pumpWidget(
      ShareKitApp(store: store, databasePath: nextDatabase()),
    );
    await settleDatabase(tester);
    await signIn(tester);
    return store;
  }

  testWidgets('輸入帳號密碼後進入探索頁', (tester) async {
    await tester.pumpWidget(
      ShareKitApp(store: ShareStore(), databasePath: nextDatabase()),
    );
    await settleDatabase(tester);
    expect(find.text('登入'), findsOneWidget);
    expect(find.text('還沒有帳號？註冊'), findsOneWidget);
    await signIn(tester);
    expect(find.text('充電電鑽套裝'), findsOneWidget);
    expect(find.text('Isem_3027'), findsWidgets);
  });

  testWidgets('可以在物品頁跟物主聊天', (tester) async {
    await openApp(tester);
    await tester.tap(find.text('充電電鑽套裝'));
    await tester.pumpAndSettle();
    expect(find.textContaining('九龍塘示範屋苑'), findsOneWidget);
    expect(find.text('交接方式：當面交接'), findsOneWidget);
    await tester.tap(find.text('聯絡物主'));
    await settleDatabase(tester);
    await tester.enterText(find.byType(TextField), '星期六下午可以當面交嗎？');
    await tester.tap(find.text('送出'));
    await settleDatabase(tester);
    expect(find.text('星期六下午可以當面交嗎？'), findsOneWidget);
  });

  testWidgets('上架要填地址並選擇交接方式', (tester) async {
    tester.view.physicalSize = const Size(800, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await openApp(tester);
    await tester.tap(find.text('上架'));
    await tester.pumpAndSettle();
    expect(find.text('你的地址'), findsOneWidget);
    expect(find.text('當面交接'), findsOneWidget);
    expect(find.text('郵寄'), findsOneWidget);
    await tester.tap(find.text('發佈到本社區'));
    await tester.pumpAndSettle();
    expect(find.text('請填寫名稱、地址和簡介。'), findsOneWidget);
  });

  testWidgets('探索頁顯示附近可借物品', (tester) async {
    await openApp(tester);
    expect(find.text('ShareKit'), findsOneWidget);
    expect(find.text('充電電鑽套裝'), findsOneWidget);
  });

  testWidgets('可以按香港十八區篩選，並在設定改名稱', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await openApp(tester);
    await tester.tap(find.text('十八區'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('沙田區'));
    await tester.pumpAndSettle();
    expect(find.text('雙人露營套裝'), findsOneWidget);
    expect(find.text('充電電鑽套裝'), findsNothing);

    await tester.tap(find.text('設定'));
    await tester.pumpAndSettle();
    expect(find.text('顯示名稱'), findsOneWidget);
    expect(find.text('介面文字'), findsOneWidget);
    expect(find.text('聯絡地址'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, '顯示名稱'), '馬仔');
    await tester.tap(find.text('儲存資料'));
    await settleDatabase(tester);
    expect(find.text('馬仔'), findsWidgets);
  });

  testWidgets('可以完成預約、取件、歸還和評價', (tester) async {
    final store = await openApp(tester);
    await tester.tap(find.text('充電電鑽套裝'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('預約這件物品'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('確認預約'));
    await settleDatabase(tester);
    await settleDatabase(tester);
    expect(store.bookings, isNotEmpty);
    expect(find.textContaining('租借申請'), findsOneWidget);
    expect(find.text('確認已借出'), findsNothing);
    expect(find.textContaining('在屋苑會所大堂交接'), findsNothing);
    final booking = store.bookings.first;
    expect(booking.stage, BookingStage.requested);
    expect(booking.note, isEmpty);
    store.acceptBooking(booking.id);
    await tester.pumpAndSettle();
    expect(store.needsOnlinePayment(store.bookingById(booking.id)), isTrue);
    store.payDeposit(booking.id);
    store.markPickedUp(booking.id);
    expect(store.bookingById(booking.id).stage, BookingStage.pickedUp);
    store.markReturned(booking.id, '完好');
    store.saveReview(booking.id, 5, '取件準時，工具齊全。', reviewerLabel: 'Isem_3027', reviewerLogin: 'Isem_3027');
    expect(store.bookingById(booking.id).stage, BookingStage.reviewed);
    expect(store.bookingById(booking.id).comment, '取件準時，工具齊全。');
    await tester.runAsync(() => store.persisted);
  });

  test('重新開啟資料庫仍看得到上架物品和相片', () async {
    final path = nextDatabase();
    final auth = AuthRepository(databasePath: path);
    await auth.open();
    final first = ShareStore();
    await first.attach(LocalCatalog(auth.database, seed: seedItems));
    first.addItem(
      name: '測試梯子',
      owner: 'Isem_3027',
      category: ItemCategory.tool,
      condition: '良好',
      summary: '三級鋁梯',
      dailyPrice: 10,
      photoBytes: Uint8List.fromList([9, 8, 7]),
      address: '九龍塘1座',
      district: HkDistrict.kowloonCity,
      handover: HandoverMethod.mail,
    );
    await first.persisted;
    await auth.close();

    final reopened = AuthRepository(databasePath: path);
    await reopened.open();
    final second = ShareStore();
    await second.attach(LocalCatalog(reopened.database, seed: seedItems));
    final item = second.items.firstWhere((item) => item.name == '測試梯子');
    expect(item.owner, 'Isem_3027');
    expect(item.address, '九龍塘1座');
    expect(item.district, HkDistrict.kowloonCity);
    expect(item.handover, HandoverMethod.mail);
    expect(item.photoBytes, Uint8List.fromList([9, 8, 7]));
    await reopened.close();
  });
}
