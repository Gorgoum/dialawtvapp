import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:url_launcher/url_launcher.dart';

import 'config.dart';
import 'coverage.dart';
import 'pages/contacts_page.dart';
import 'pages/coverage_page.dart';
import 'pages/live_page.dart';
import 'pages/news_page.dart';
import 'pages/settings_page.dart';
import 'pages/subscription_page.dart';
import 'settings.dart';
import 'subscription.dart';
import 'theme.dart';
import 'widgets/brand.dart';
import 'widgets/profile_avatar.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr');
  final settings = await AppSettings.load();
  final coverage = await CoverageStore.load();
  final subscription = await SubscriptionService.load();
  // Sans attendre : l'appli s'ouvre avec le dernier état connu, mis à jour ensuite.
  subscription.refresh();
  runApp(
    DialawApp(
      settings: settings,
      coverage: coverage,
      subscription: subscription,
    ),
  );
}

class DialawApp extends StatelessWidget {
  const DialawApp({
    super.key,
    required this.settings,
    required this.coverage,
    required this.subscription,
  });

  final AppSettings settings;
  final CoverageStore coverage;
  final SubscriptionService subscription;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => MaterialApp(
        title: AppConfig.appName,
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        themeMode: settings.themeMode,
        locale: const Locale('fr'),
        supportedLocales: const [Locale('fr')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        // Android permet une police système jusqu'à ×2 : au-delà de ×1,4 la mise
        // en page se dégrade (mots coupés), on plafonne donc l'agrandissement.
        builder: (context, child) => MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.4,
          child: child!,
        ),
        home: HomeShell(
          settings: settings,
          coverage: coverage,
          subscription: subscription,
        ),
      ),
    );
  }
}

class _Destination {
  const _Destination(this.label, this.title, this.icon, this.selectedIcon);

  final String label;
  final String title;
  final IconData icon;
  final IconData selectedIcon;
}

const _destinations = [
  _Destination('Direct', 'En direct', Icons.live_tv_outlined, Icons.live_tv),
  _Destination(
    'Actualités',
    'Actualités',
    Icons.newspaper_outlined,
    Icons.newspaper,
  ),
  _Destination('Contacts', 'Contacts', Icons.forum_outlined, Icons.forum),
  _Destination(
    'Paramètres',
    'Paramètres',
    Icons.settings_outlined,
    Icons.settings,
  ),
];

const _settingsIndex = 3;

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.settings,
    required this.coverage,
    required this.subscription,
  });

  final AppSettings settings;
  final CoverageStore coverage;
  final SubscriptionService subscription;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _index = 0;
  final _newsKey = GlobalKey<NewsPageState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Retour dans l'appli (après un paiement, ou des jours plus tard) : l'accès est
  // revérifié, l'essai ou l'abonnement ayant pu se terminer entre-temps.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) widget.subscription.refresh();
  }

  void _select(int i) => setState(() => _index = i);

  void _openSubscription() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SubscriptionPage(
          subscription: widget.subscription,
          defaultPhone: widget.settings.phone,
        ),
      ),
    );
  }

  /// Rappel affiché sur le direct pendant l'essai, ou paiement en vérification.
  String? _accessNote() {
    final sub = widget.subscription;
    if (!sub.enabled || sub.info?.status != AccessStatus.trial) return null;
    if (sub.info!.paymentPending) {
      return 'Paiement en cours de vérification par Dialaw TV';
    }
    final days = sub.daysLeft ?? 0;
    return days <= 1
        ? 'Essai gratuit : dernier jour. Abonnez-vous dès 1 000 FCFA/mois'
        : 'Essai gratuit : $days jours restants. Abonnez-vous dès 1 000 FCFA/mois';
  }

  void _openCoverage() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CoverageRequestPage(
          settings: widget.settings,
          store: widget.coverage,
        ),
      ),
    );
  }

  /// Bouton retour Android : historique du site, puis onglet Direct, puis sortie.
  Future<void> _onBack() async {
    if (_index == 1 && (await _newsKey.currentState?.goBack() ?? false)) return;
    if (_index != 0) {
      _select(0);
      return;
    }
    SystemNavigator.pop();
  }

  /// Boutons de la barre du haut : outils du site sur l'onglet Actualités, puis
  /// l'avatar qui mène aux paramètres.
  List<Widget> _actions() {
    return [
      if (_index == 1) ...[
        IconButton(
          tooltip: 'Recharger',
          icon: const Icon(Icons.refresh),
          onPressed: () => _newsKey.currentState?.reload(),
        ),
        IconButton(
          tooltip: 'Ouvrir dans le navigateur',
          icon: const Icon(Icons.open_in_new),
          onPressed: () async {
            final url = await _newsKey.currentState?.currentUrl();
            await launchUrl(
              Uri.parse(url ?? AppConfig.newsUrl),
              mode: LaunchMode.externalApplication,
            );
          },
        ),
      ],
      if (_index != _settingsIndex)
        ListenableBuilder(
          listenable: widget.settings,
          builder: (context, _) => IconButton(
            tooltip: 'Mon profil et paramètres',
            onPressed: () => _select(_settingsIndex),
            icon: ProfileAvatar(
              name: widget.settings.name,
              imagePath: widget.settings.avatarPath,
              size: 32,
            ),
          ),
        ),
      const SizedBox(width: 8),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= Breakpoints.compact;
    // Tablette : titre à droite du rail. Téléphone en paysage : pas de titre,
    // chaque pixel de hauteur compte.
    final showHeader = wide && size.height >= 500;
    final extendedRail = size.width >= 1100;

    // Les clés gardent le même élément (lecteur, WebView) quand on tourne l'écran.
    final pages = Expanded(
      key: const ValueKey('pages'),
      child: Column(
        children: [
          if (showHeader) _WideHeader(_destinations[_index].title, _actions()),
          Expanded(
            key: const ValueKey('stack'),
            // Sans barre du haut, on évite la barre d'état et les boutons système.
            child: SafeArea(
              top: wide && !showHeader,
              left: false,
              bottom: false,
              // IndexedStack garde la page Actualités chargée quand on change d'onglet.
              child: IndexedStack(
                index: _index,
                children: [
                  ListenableBuilder(
                    listenable: widget.subscription,
                    builder: (context, _) => LivePage(
                      active: _index == 0,
                      onOpenNews: () => _select(1),
                      onOpenContacts: () => _select(2),
                      onRequestCoverage: _openCoverage,
                      locked: !widget.subscription.canWatch,
                      paymentPending:
                          widget.subscription.info?.paymentPending ?? false,
                      accessNote: _accessNote(),
                      onSubscribe: _openSubscription,
                    ),
                  ),
                  NewsPage(key: _newsKey),
                  ContactsPage(onRequestCoverage: _openCoverage),
                  SettingsPage(
                    settings: widget.settings,
                    subscription: widget.subscription,
                    onOpenSubscription: _openSubscription,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    final palette = context.palette;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final iconBrightness = dark ? Brightness.light : Brightness.dark;
    // Barres système accordées au thème (l'AppBar le fait seule, pas le rail).
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: iconBrightness,
        statusBarBrightness: dark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: palette.surface,
        systemNavigationBarIconBrightness: iconBrightness,
      ),
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _onBack();
        },
        child: Scaffold(
          appBar: !wide
              ? AppBar(
                  title: const BrandLogo(height: 34),
                  actions: _actions(),
                  bottom: const PreferredSize(
                    preferredSize: Size.fromHeight(1),
                    child: Divider(height: 1),
                  ),
                )
              : null,
          body: Row(
            children: [
              if (wide) ...[
                SafeArea(
                  right: false,
                  child: NavigationRail(
                    selectedIndex: _index,
                    onDestinationSelected: _select,
                    extended: extendedRail,
                    labelType: extendedRail
                        ? NavigationRailLabelType.none
                        : NavigationRailLabelType.all,
                    groupAlignment: -0.9,
                    leading: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: extendedRail
                          ? const BrandLogo(height: 40)
                          : const _RailMark(),
                    ),
                    destinations: [
                      for (final d in _destinations)
                        NavigationRailDestination(
                          icon: Icon(d.icon),
                          selectedIcon: Icon(d.selectedIcon),
                          label: Text(d.label),
                        ),
                    ],
                  ),
                ),
                VerticalDivider(
                  key: ValueKey('rail-divider'),
                  width: 1,
                  color: context.palette.outline,
                ),
              ],
              pages,
            ],
          ),
          bottomNavigationBar: wide
              ? null
              : DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: context.palette.outline),
                    ),
                  ),
                  child: NavigationBar(
                    selectedIndex: _index,
                    onDestinationSelected: _select,
                    destinations: [
                      for (final d in _destinations)
                        NavigationDestination(
                          icon: Icon(d.icon),
                          selectedIcon: Icon(d.selectedIcon),
                          label: d.label,
                        ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

/// Barre de titre de la colonne de contenu, à droite du rail.
class _WideHeader extends StatelessWidget {
  const _WideHeader(this.title, this.actions);

  final String title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.palette.outline)),
      ),
      child: SafeArea(
        left: false,
        bottom: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              const SizedBox(width: 24),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              ...actions,
              const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }
}

/// Monogramme pour le rail étroit, où le logo complet ne tient pas.
class _RailMark extends StatelessWidget {
  const _RailMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.blue, AppColors.red],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Text(
        'DTV',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 15,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
