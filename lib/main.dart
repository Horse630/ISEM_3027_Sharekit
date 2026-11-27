import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'account_page.dart';
import 'auth_repository.dart';
import 'booking_pages.dart';
import 'catalog_gateway.dart';
import 'chat_center.dart';
import 'chats_page.dart';
import 'explore_page.dart';
import 'hkid_page.dart';
import 'item_pages.dart';
import 'login_page.dart';
import 'opening_page.dart';
import 'models.dart';
import 'store.dart';
import 'text.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(ShareKitApp(store: ShareStore()));
}

class ShareKitApp extends StatefulWidget {
  const ShareKitApp({
    super.key,
    required this.store,
    this.databasePath,
    this.seed,
  });

  final ShareStore store;
  final String? databasePath;
  final List<ShareItem> Function()? seed;

  @override
  State<ShareKitApp> createState() => _ShareKitAppState();
}

class _ShareKitAppState extends State<ShareKitApp> {
  late final AuthRepository _auth = AuthRepository(
    databasePath: widget.databasePath,
  );
  final _ui = UiSettings();
  final _chat = ChatCenter();
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
        await widget.store.attach(remote);
      } else {
        final local = LocalCatalog(
          _auth.database,
          seed: widget.seed ?? seedItems,
        );
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
    _chat.stop();
    _auth.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget home;
    if (_loading) {
      home = const OpeningPage();
    } else if (_error != null) {
      home = Scaffold(
        body: Center(
          child: Text(
            tr(context, '資料庫打不開：$_error', 'The database did not open: $_error'),
          ),
        ),
      );
    } else if (_user == null) {
      home = LoginPage(
        auth: _auth,
        ui: _ui,
        onLoggedIn: (next) => setState(() => _user = next),
      );
    } else if (!_user!.hkidUploaded) {
      home = HkidGatePage(
        user: _user!,
        auth: _auth,
        onSubmitted: (next) => setState(() => _user = next),
        onLogout: _logout,
      );
    } else {
      home = HomeShell(
        store: widget.store,
        user: _user!,
        auth: _auth,
        ui: _ui,
        chat: _chat,
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
        return AppLang(
          english: _ui.english,
          child: MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(_ui.textScale)),
            child: ColoredBox(
              color: const Color(0xFFD5E2F2),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: ColoredBox(
                    color: const Color(0xFFF3F6FB),
                    child: child ?? const SizedBox.shrink(),
                  ),
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
    required this.chat,
    required this.onUserChanged,
    required this.onLogout,
  });

  final ShareStore store;
  final AppUser user;
  final AuthRepository auth;
  final UiSettings ui;
  final ChatCenter chat;
  final ValueChanged<AppUser> onUserChanged;
  final Future<void> Function() onLogout;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  final Map<String, BookingStage> _stages = {};
  final Set<String> _toldPickup = {};
  final Set<String> _toldDeposit = {};
  var _stagesReady = false;

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_syncTab);
    widget.chat.bind(widget.auth, widget.user.label);
    WidgetsBinding.instance.addPostFrameCallback((_) => _notePickups());
  }

  @override
  void didUpdateWidget(HomeShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.label != widget.user.label) {
      widget.chat.bind(widget.auth, widget.user.label);
    }
  }

  @override
  void dispose() {
    widget.store.removeListener(_syncTab);
    widget.chat.stop();
    super.dispose();
  }

  void _syncTab() {
    final next = widget.store.requestedTab;
    if (next != null && mounted) {
      widget.store.requestedTab = null;
      setState(() => _index = next);
    }
    _notePickups();
  }

  void _notePickups() {
    if (!mounted) return;
    final user = widget.user;
    final names = {user.label, user.name}.where((value) => value.trim().isNotEmpty).toSet();
    Booking? reserved;
    Booking? pickup;
    var pickupAsOwner = false;
    Booking? returnedNotice;
    Booking? deposit;
    Booking? reviewed;
    for (final booking in widget.store.bookings) {
      final item = widget.store.findItem(booking.itemId);
      final isOwner = item != null && names.contains(item.owner);
      final isBorrower = widget.store.isBorrower(booking, user.label, user.name);
      if (!isOwner && !isBorrower) {
        _stages[booking.id] = booking.stage;
        continue;
      }
      final previous = _stages[booking.id];
      final changed = _stagesReady && previous != null && previous != booking.stage;
      if (changed && booking.stage == BookingStage.reserved) {
        reserved = booking;
      }
      if (changed &&
          booking.stage == BookingStage.pickedUp &&
          _toldPickup.add(booking.id)) {
        pickup = booking;
        pickupAsOwner = isOwner && !isBorrower;
      }
      if (changed && booking.stage == BookingStage.returned) {
        returnedNotice = booking;
      }
      if (changed &&
          booking.stage == BookingStage.returned &&
          isBorrower &&
          (booking.depositAmount > 0 || booking.deposit == DepositStatus.paid) &&
          _toldDeposit.add(booking.id)) {
        deposit = booking;
      }
      if (changed && booking.stage == BookingStage.reviewed) {
        reviewed = booking;
      }
      _stages[booking.id] = booking.stage;
    }
    if (!_stagesReady) {
      _stagesReady = true;
      return;
    }
    if (reserved != null) {
      final itemName = widget.store.findItem(reserved.itemId)?.name ?? '';
      _popup(
        tr(context, '預約已同意', 'Booking accepted'),
        tr(context, '「$itemName」的預約已同意。', 'The booking for “$itemName” was accepted.'),
      );
    }
    if (returnedNotice != null) {
      final itemName = widget.store.findItem(returnedNotice.itemId)?.name ?? '';
      _popup(
        tr(context, '已歸還', 'Returned'),
        tr(context, '「$itemName」已確認歸還。', '“$itemName” has been returned.'),
      );
    }
    if (reviewed != null) {
      final itemName = widget.store.findItem(reviewed.itemId)?.name ?? '';
      _popup(
        tr(context, '評價已完成', 'Review finished'),
        tr(context, '「$itemName」的評價步驟已完成。', 'The review step for “$itemName” is done.'),
      );
    }
    if (pickup != null) {
      final itemName = widget.store.findItem(pickup.itemId)?.name ?? '';
      final asOwner = pickupAsOwner;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(tr(dialogContext, '已取件', 'Picked up')),
            content: Text(
              asOwner
                  ? tr(dialogContext, '「$itemName」已確認取件。', '“$itemName” has been picked up.')
                  : tr(
                      dialogContext,
                      '「$itemName」已取件。歸還時請向物主出示歸還碼。',
                      '“$itemName” has been picked up. Show the return code when you bring it back.',
                    ),
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(tr(dialogContext, '知道了', 'OK')),
              ),
            ],
          ),
        );
      });
    }
    if (deposit != null) {
      final itemName = widget.store.findItem(deposit.itemId)?.name ?? '';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(tr(dialogContext, '按金將退回', 'Deposit will be returned')),
            content: Text(tr(
              dialogContext,
              '「$itemName」已歸還。按金將於 3 日內退回。',
              '“$itemName” is returned. The deposit will be returned within 3 days.',
            )),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(tr(dialogContext, '知道了', 'OK')),
              ),
            ],
          ),
        );
      });
    }
  }

  void _popup(String title, String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(tr(dialogContext, '知道了', 'OK')),
            ),
          ],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      const ExplorePage(),
      ChatsPage(
        center: widget.chat,
        store: widget.store,
        auth: widget.auth,
        user: widget.user,
      ),
      const BookingsPage(),
      ListItemPage(ownerName: widget.user.label, ui: widget.ui),
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
      onOpenAccount: () => setState(() => _index = 4),
    );

    if (wide) {
      return ChatScope(
        chat: widget.chat,
        child: ListenableBuilder(
          listenable: widget.chat,
          builder: (context, _) => Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: _index,
                  onDestinationSelected: (index) =>
                      setState(() => _index = index),
                  labelType: NavigationRailLabelType.all,
                  backgroundColor: Colors.white,
                  destinations: [
                    NavigationRailDestination(
                      icon: const Icon(Icons.explore_outlined),
                      selectedIcon: const Icon(Icons.explore),
                      label: Text(tr(context, '探索', 'Explore')),
                    ),
                    NavigationRailDestination(
                      icon: _chatIcon(false),
                      selectedIcon: _chatIcon(true),
                      label: Text(tr(context, '聊天', 'Chats')),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.event_note_outlined),
                      selectedIcon: const Icon(Icons.event_note),
                      label: Text(tr(context, '預約', 'Bookings')),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.add_box_outlined),
                      selectedIcon: const Icon(Icons.add_box),
                      label: Text(tr(context, '上架', 'List')),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.settings_outlined),
                      selectedIcon: const Icon(Icons.settings),
                      label: Text(tr(context, '設定', 'Settings')),
                    ),
                  ],
                ),
                const VerticalDivider(width: 1, thickness: 1),
                Expanded(
                  child: Column(
                    children: [
                      accountBar,
                      Expanded(
                        child: _FadeTabs(index: _index, children: pages),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ChatScope(
      chat: widget.chat,
      child: ListenableBuilder(
        listenable: widget.chat,
        builder: (context, _) => Scaffold(
          body: Column(
            children: [
              accountBar,
              Expanded(
                child: _FadeTabs(index: _index, children: pages),
              ),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (index) => setState(() => _index = index),
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.explore_outlined),
                selectedIcon: const Icon(Icons.explore),
                label: tr(context, '探索', 'Explore'),
              ),
              NavigationDestination(
                icon: _chatIcon(false),
                selectedIcon: _chatIcon(true),
                label: tr(context, '聊天', 'Chats'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.event_note_outlined),
                selectedIcon: const Icon(Icons.event_note),
                label: tr(context, '預約', 'Bookings'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.add_box_outlined),
                selectedIcon: const Icon(Icons.add_box),
                label: tr(context, '上架', 'List'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.settings_outlined),
                selectedIcon: const Icon(Icons.settings),
                label: tr(context, '設定', 'Settings'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chatIcon(bool selected) {
    final icon = Icon(selected ? Icons.chat_bubble : Icons.chat_bubble_outline);
    final count = widget.chat.unread;
    if (count <= 0) return icon;
    return Badge(
      label: Text(count > 99 ? '99+' : '$count'),
      backgroundColor: const Color(0xFF9A4632),
      child: icon,
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
              TextButton(
                onPressed: onLogout,
                child: Text(tr(context, '登出', 'Log out')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FadeTabs extends StatelessWidget {
  const _FadeTabs({required this.index, required this.children});

  final int index;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        for (var i = 0; i < children.length; i++)
          Offstage(
            offstage: i != index,
            child: TickerMode(
              enabled: i == index,
              child: _FadeIn(active: i == index, child: children[i]),
            ),
          ),
      ],
    );
  }
}

class _FadeIn extends StatefulWidget {
  const _FadeIn({required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  State<_FadeIn> createState() => _FadeInState();
}

class _FadeInState extends State<_FadeIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
    value: widget.active ? 1 : 0,
  );

  @override
  void didUpdateWidget(_FadeIn oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _controller.forward(from: 0);
    } else if (!widget.active) {
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _controller, child: widget.child);
  }
}

class _SharePageTransitions extends PageTransitionsBuilder {
  const _SharePageTransitions();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero).animate(curved),
        child: child,
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
  const ink = Color(0xFF10233F);
  const paper = Color(0xFFF3F6FB);
  const blue = Color(0xFF003070);
  final scheme = ColorScheme.fromSeed(
    seedColor: blue,
    primary: blue,
    surface: paper,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: paper,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: _SharePageTransitions(),
        TargetPlatform.iOS: _SharePageTransitions(),
        TargetPlatform.macOS: _SharePageTransitions(),
        TargetPlatform.windows: _SharePageTransitions(),
        TargetPlatform.linux: _SharePageTransitions(),
      },
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: paper,
      foregroundColor: ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: blue.withValues(alpha: 0.16),
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
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: blue,
        minimumSize: const Size(64, 52),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: blue,
        foregroundColor: Colors.white,
        minimumSize: const Size(64, 52),
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
