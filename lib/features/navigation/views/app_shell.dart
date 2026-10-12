import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../entries/viewmodels/entries_view_model.dart';
import '../../entries/views/entries_page.dart';
import '../../integrations/health/viewmodels/health_integration_view_model.dart';
import '../../search/views/search_page.dart';
import '../../settings/viewmodels/settings_view_model.dart';
import '../../settings/views/settings_page.dart';
import '../../today/views/today_page.dart';

/// Holds the main pages and switches them with the bottom navigation bar.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _selectedIndex = 0;
  late final AppLifecycleListener _lifecycleListener;

  static const _pages = [
    TodayPage(),
    EntriesPage(),
    SearchPage(),
    SettingsPage(),
  ];

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(onResume: _syncHealth);
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(healthIntegrationViewModelProvider);
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
          if (index == 0) _syncHealth();
          if (index == 1) ref.invalidate(entriesViewModelProvider);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today),
            label: 'Today',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Entries',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search),
            label: 'Search',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  // Refreshes health data when Today is opened or the app returns to view.
  void _syncHealth() {
    final settings = ref.read(settingsViewModelProvider).value;
    if (settings?.healthIntegrationEnabled != true) return;
    ref.read(healthIntegrationViewModelProvider.notifier).syncNow();
  }
}
