import 'package:fin_pay/design_system/design_system.dart';
import 'package:fin_pay/routes/app_routes.dart';
import 'package:fin_pay/screens/auth/widgets/secure_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Notifies a tab that it was re-selected while already current, so it can
/// scroll back to the top. Read it with [AppShell.reselectOf].
class TabReselect extends ChangeNotifier {
  int _index = -1;
  int _count = 0;

  /// The tab that was last re-selected.
  int get index => _index;

  /// How many re-selections have happened (changes on every one).
  int get count => _count;

  void fire(int index) {
    _index = index;
    _count++;
    notifyListeners();
  }
}

class _ReselectScope extends InheritedNotifier<TabReselect> {
  const _ReselectScope({required super.notifier, required super.child});
}

/// The visible branch index, as an inherited dependency so tabs rebuild
/// (and get `didChangeDependencies`) when the selection changes.
class _ShellScope extends InheritedWidget {
  const _ShellScope({required this.index, required super.child});

  final int index;

  @override
  bool updateShouldNotify(_ShellScope oldWidget) => oldWidget.index != index;
}

/// The four-tab shell: an `IndexedStack` of branches (state survives tab
/// switches), the NeoPOP bottom bar, and the Android back rule (back on a
/// non-home tab returns to home; back on home leaves the app).
///
/// Home and Cards show balances and card details, so `FLAG_SECURE` is on
/// while one of them is the visible tab.
class AppShell extends StatefulWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  /// Tab index of the home branch.
  static const int homeIndex = 0;

  /// Tabs whose content must not appear in screenshots or recents.
  static const Set<int> protectedTabs = {0, 2};

  /// The destinations, in [AppRoutes.tabs] order.
  static const List<FpBottomNavItem> items = [
    FpBottomNavItem(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
      label: 'Home',
    ),
    FpBottomNavItem(
      icon: Icons.bar_chart_outlined,
      selectedIcon: Icons.bar_chart,
      label: 'Stats',
    ),
    FpBottomNavItem(
      icon: Icons.credit_card_outlined,
      selectedIcon: Icons.credit_card,
      label: 'Cards',
    ),
    FpBottomNavItem(
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
      label: 'Profile',
    ),
  ];

  /// The re-selection notifier for the enclosing shell, or null outside it.
  static TabReselect? reselectOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ReselectScope>()?.notifier;

  /// Whether the branch at [index] is the visible tab (outside a shell
  /// everything counts as visible). Registers a dependency, so the caller
  /// rebuilds when the selection changes.
  static bool isVisibleTab(BuildContext context, int index) {
    final scope = context.dependOnInheritedWidgetOfExactType<_ShellScope>();
    return scope == null || scope.index == index;
  }

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final TabReselect _reselect = TabReselect();

  @override
  void dispose() {
    _reselect.dispose();
    super.dispose();
  }

  int get _index => widget.navigationShell.currentIndex;

  void _goHome() => widget.navigationShell.goBranch(
    AppShell.homeIndex,
    initialLocation: true,
  );

  @override
  Widget build(BuildContext context) {
    final c = context.fp.colors;
    final index = _index;
    return _ShellScope(
      index: index,
      child: _ReselectScope(
        notifier: _reselect,
        child: SecureScreen(
          active: AppShell.protectedTabs.contains(index),
          child: PopScope(
            canPop: index == AppShell.homeIndex,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) _goHome();
            },
            child: Scaffold(
              backgroundColor: c.background,
              body: widget.navigationShell,
              bottomNavigationBar: FpBottomNav(
                items: AppShell.items,
                currentIndex: index,
                onSelected: (i) => widget.navigationShell.goBranch(i),
                onReselected: (i) {
                  widget.navigationShell.goBranch(i, initialLocation: true);
                  _reselect.fire(i);
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
