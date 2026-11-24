import 'dart:io';
import 'dart:typed_data';

import 'package:sharekit/auth_repository.dart';
import 'package:sharekit/catalog_gateway.dart';
import 'package:sharekit/models.dart';
import 'package:sharekit/store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _RealHttp extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      super.createHttpClient(context);
}

void main() {
  HttpOverrides.global = _RealHttp();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  final stamp = DateTime.now().microsecondsSinceEpoch;
  var databaseNumber = 0;

  String nextDatabase() =>
      '${Directory.systemTemp.path}${Platform.pathSeparator}sharekit_catalog_${stamp}_${databaseNumber++}.db';

  test('兩個瀏覽器共用同一份物品資料庫', () async {
    HttpOverrides.global = _RealHttp();
    final server = await Process.start(
      'python',
      ['tool/catalog_server.py'],
      environment: {
        ...Platform.environment,
        'SHAREKIT_CATALOG_PORT': '8791',
        'SHAREKIT_CATALOG_DB': nextDatabase(),
      },
    );
    addTearDown(() => server.kill());
    final origin = 'http://127.0.0.1:8791';
    RemoteCatalog? remote;
    for (var attempt = 0; attempt < 20; attempt++) {
      remote = await RemoteCatalog.connect(origin);
      if (remote != null) break;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    expect(remote, isNotNull);

    final firefoxAuth = AuthRepository(databasePath: nextDatabase());
    await firefoxAuth.open();
    final firefox = ShareStore();
    await firefox.attach(
      CombinedCatalog(
        local: LocalCatalog(firefoxAuth.database, seed: seedItems),
        remote: remote,
      ),
    );
    firefox.addItem(
      name: 'Firefox 上架的露營燈',
      owner: 'Isem_3027',
      category: ItemCategory.outdoor,
      condition: '良好',
      summary: '給另一個瀏覽器看',
      dailyPrice: null,
      photoBytes: Uint8List.fromList([4, 5, 6]),
      address: '九龍塘2座',
      district: HkDistrict.kowloonCity,
      handover: HandoverMethod.faceToFace,
    );
    await firefox.persisted;

    final edgeAuth = AuthRepository(databasePath: nextDatabase());
    await edgeAuth.open();
    final edge = ShareStore();
    await edge.attach(
      CombinedCatalog(
        local: LocalCatalog(edgeAuth.database, seed: seedItems),
        remote: RemoteCatalog(origin),
      ),
    );
    final item = edge.items.firstWhere((entry) => entry.name == 'Firefox 上架的露營燈');
    expect(item.address, '九龍塘2座');
    expect(item.photoBytes, Uint8List.fromList([4, 5, 6]));
    await firefoxAuth.close();
    await edgeAuth.close();
  });
}
