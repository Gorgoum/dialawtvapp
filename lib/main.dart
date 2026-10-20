import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'config.dart';
import 'pages/contacts_page.dart';
import 'pages/live_page.dart';
import 'pages/news_page.dart';

void main() {
  runApp(const DialawApp());
}

class DialawApp extends StatelessWidget {
  const DialawApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppConfig.blue,
          primary: AppConfig.blue,
          secondary: AppConfig.red,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppConfig.blue,
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
      ),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  final _newsKey = GlobalKey<NewsPageState>();

  static const _titles = ['En direct', 'Actualités', 'Contacts'];

  /// Bouton retour Android : historique du site, puis onglet Direct, puis sortie.
  Future<void> _onBack() async {
    if (_index == 1 && (await _newsKey.currentState?.goBack() ?? false)) return;
    if (_index != 0) {
      setState(() => _index = 0);
      return;
    }
    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset('assets/logo_dialaw.jpg', height: 32),
              ),
              const SizedBox(width: 10),
              Text(_titles[_index]),
            ],
          ),
        ),
        // IndexedStack garde la page Actualités chargée quand on change d'onglet.
        body: IndexedStack(
          index: _index,
          children: [
            LivePage(active: _index == 0),
            NewsPage(key: _newsKey),
            const ContactsPage(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          indicatorColor: AppConfig.red.withValues(alpha: 0.15),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.live_tv_outlined),
              selectedIcon: Icon(Icons.live_tv, color: AppConfig.red),
              label: 'Direct',
            ),
            NavigationDestination(
              icon: Icon(Icons.newspaper_outlined),
              selectedIcon: Icon(Icons.newspaper, color: AppConfig.red),
              label: 'Actualités',
            ),
            NavigationDestination(
              icon: Icon(Icons.contact_phone_outlined),
              selectedIcon: Icon(Icons.contact_phone, color: AppConfig.red),
              label: 'Contacts',
            ),
          ],
        ),
      ),
    );
  }
}
