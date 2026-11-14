import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'booking_pages.dart';
import 'explore_page.dart';
import 'item_pages.dart';
import 'store.dart';

void main() {
  runApp(ShareKitApp(store: ShareStore()));
}

class ShareKitApp extends StatelessWidget {
  const ShareKitApp({super.key, required this.store});

  final ShareStore store;

  @override
  Widget build(BuildContext context) {
    return ShareKitScope(
      store: store,
      child: MaterialApp(
        title: 'ShareKit',
        debugShowCheckedModeBanner: false,
        scrollBehavior: const ShareKitScrollBehavior(),
        theme: _theme(),
        builder: (context, child) {
          return ColoredBox(
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
          );
        },
        home: HomeShell(store: store),
      ),
    );
  }
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
  const HomeShell({super.key, required this.store});

  final ShareStore store;

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
    const pages = [ExplorePage(), BookingsPage(), ListItemPage()];
    final wide = MediaQuery.sizeOf(context).width >= 840;

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
              ],
            ),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(child: IndexedStack(index: _index, children: pages)),
          ],
        ),
      );
    }

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
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
        ],
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
