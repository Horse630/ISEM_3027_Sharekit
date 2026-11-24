import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'account_page.dart';
import 'auth_repository.dart';
import 'booking_pages.dart';
import 'catalog_gateway.dart';
import 'explore_page.dart';
import 'item_pages.dart';
import 'login_page.dart';
import 'store.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(ShareKitApp(store: ShareStore()));
}

class ShareKitApp extends StatefulWidget {
  const ShareKitApp({super.key, required this.store, this.databasePath});

  final ShareStore store;
  final String? databasePath;

  @override
  State<ShareKitApp> createState() => _ShareKitAppState();
}

class _ShareKitAppState extends State<ShareKitApp> {
  late final AuthRepository _auth = AuthRepository(
    databasePath: widget.databasePath,
  );
  final _ui = UiSettings();
  AppUser? _user;
  Object? _error;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _ui.addListener(_onUi);
    _ui.load();
    _openSession();
  }

  void _onUi() {
    if (mounted) setState(() {});
  }

  Future<void> _openSession() async {
    try {
      await _auth.open();
      if (widget.databasePath == null) {
        final remote = await PublicCatalog.connect();
        if (remote == null) {
          throw StateError('共用資料庫連不上');
        }
        var snapshot = await remote.load();
        if (snapshot.items.isEmpty) {
          snapshot = CatalogSnapshot(
            items: seedItems(),
            bookings: const [],
            sequence: 240,
          );
          await remote.save(snapshot);
        }
        await widget.store.attach(remote);
      } else {
        final local = LocalCatalog(_auth.database, seed: seedItems);
        await widget.store.attach(local);
      }
      final user = await _auth.currentUser();
      if (!mounted) return;
      setState(() {
        _user = user;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _logout() async {
    await _auth.logout();
    if (!mounted) return;
    setState(() => _user = null);
  }

  @override
  void dispose() {
    _ui.removeListener(_onUi);
    _auth.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget home;
    if (_loading) {
      home = const Scaffold(body: Center(child: Text('正在開啟資料庫…')));
    } else if (_error != null) {
      home = Scaffold(body: Center(child: Text('資料庫打不開：$_error')));
    } else if (_user == null) {
      home = LoginPage(
        auth: _auth,
        onLoggedIn: (next) => setState(() => _user = next),
      );
    } else {
      home = HomeShell(
        store: widget.store,
        user: _user!,
        auth: _auth,
        ui: _ui,
        onUserChanged: (next) => setState(() => _user = next),
        onLogout: _logout,
      );
    }

    final app = MaterialApp(
        title: 'ShareKit',
        debugShowCheckedModeBanner: false,
        scrollBehavior: const ShareKitScrollBehavior(),
        theme: _theme(),
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(_ui.textScale),
            ),
            child: ColoredBox(
            color: const Color(0xFFE4DDD2),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: ColoredBox(
                  color: const Color(0xFFF4F1EB),
                  child: child ?? const SizedBox.shrink(),
                ),
              ),
            ),
          ),
          );
        },
        home: home,
      );
    final signedIn = _user == null
        ? app
        : AccountScope(user: _user!, auth: _auth, child: app);
    return ShareKitScope(store: widget.store, child: signedIn);
  }
}

class AccountScope extends InheritedWidget {
  const AccountScope({
    super.key,
    required this.user,
    required this.auth,
    required super.child,
  });

  final AppUser user;
  final AuthRepository auth;

  static AccountScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AccountScope>();
    assert(scope != null, 'AccountScope 不在樹中');
    return scope!;
  }

  @override
  bool updateShouldNotify(AccountScope oldWidget) =>
      oldWidget.user != user || oldWidget.auth != auth;
}

class ShareKitScope extends InheritedNotifier<ShareStore> {
  const ShareKitScope({
    super.key,
    required ShareStore store,
    required super.child,
  }) : super(notifier: store);

  static const communityName = ShareStore.community;

  static ShareStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ShareKitScope>();
    assert(scope != null, 'ShareKitScope 不在樹中');
    return scope!.notifier!;
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.store,
    required this.user,
    required this.auth,
    required this.ui,
    required this.onUserChanged,
    required this.onLogout,
  });

  final ShareStore store;
  final AppUser user;
  final AuthRepository auth;
  final UiSettings ui;
  final ValueChanged<AppUser> onUserChanged;
  final Future<void> Function() onLogout;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_syncTab);
  }

  @override
  void dispose() {
    widget.store.removeListener(_syncTab);
    super.dispose();
  }

  void _syncTab() {
    final next = widget.store.requestedTab;
    if (next == null || !mounted) return;
    widget.store.requestedTab = null;
    setState(() => _index = next);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      const ExplorePage(),
      const BookingsPage(),
      ListItemPage(ownerName: widget.user.label),
      SettingsPage(
        user: widget.user,
        auth: widget.auth,
        store: widget.store,
        ui: widget.ui,
        onChanged: widget.onUserChanged,
        onLogout: widget.onLogout,
      ),
    ];
    final wide = MediaQuery.sizeOf(context).width >= 840;
    final accountBar = _AccountBar(
      userName: widget.user.label,
      onLogout: widget.onLogout,
      onOpenAccount: () => setState(() => _index = 3),
    );

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: (index) => setState(() => _index = index),
              labelType: NavigationRailLabelType.all,
              backgroundColor: Colors.white,
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.explore_outlined),
                  selectedIcon: Icon(Icons.explore),
                  label: Text('探索'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.event_note_outlined),
                  selectedIcon: Icon(Icons.event_note),
                  label: Text('預約'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.add_box_outlined),
                  selectedIcon: Icon(Icons.add_box),
                  label: Text('上架'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: Text('設定'),
                ),
              ],
            ),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(
              child: Column(
                children: [
                  accountBar,
                  Expanded(child: IndexedStack(index: _index, children: pages)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          accountBar,
          Expanded(child: IndexedStack(index: _index, children: pages)),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: '探索',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_note_outlined),
            selectedIcon: Icon(Icons.event_note),
            label: '預約',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_box_outlined),
            selectedIcon: Icon(Icons.add_box),
            label: '上架',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '設定',
          ),
        ],
      ),
    );
  }
}

class _AccountBar extends StatelessWidget {
  const _AccountBar({
    required this.userName,
    required this.onLogout,
    required this.onOpenAccount,
  });

  final String userName;
  final Future<void> Function() onLogout;
  final VoidCallback onOpenAccount;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              const Icon(Icons.person_outline, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: onOpenAccount,
                    child: Text(
                      userName,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
              TextButton(onPressed: onLogout, child: const Text('登出')),
            ],
          ),
        ),
      ),
    );
  }
}

class ShareKitScrollBehavior extends MaterialScrollBehavior {
  const ShareKitScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.trackpad,
      };
}

ThemeData _theme() {
  const ink = Color(0xFF1B2A24);
  const paper = Color(0xFFF4F1EB);
  const green = Color(0xFF0E6B52);
  final scheme = ColorScheme.fromSeed(
    seedColor: green,
    primary: green,
    surface: paper,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: paper,
    appBarTheme: const AppBarTheme(
      backgroundColor: paper,
      foregroundColor: ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: green.withValues(alpha: 0.16),
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: green,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: ink, height: 1.35),
      bodyLarge: TextStyle(color: ink, height: 1.35),
    ),
  );
}
