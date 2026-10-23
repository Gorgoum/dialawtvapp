import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../config.dart';
import '../theme.dart';

/// Site dialawactu.com. Les liens vers d'autres domaines s'ouvrent dans le navigateur.
class NewsPage extends StatefulWidget {
  const NewsPage({super.key});

  @override
  State<NewsPage> createState() => NewsPageState();
}

class NewsPageState extends State<NewsPage> {
  late final WebViewController _controller;
  int _progress = 0;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) => setState(() => _progress = p),
          onPageStarted: (_) => setState(() => _failed = false),
          onWebResourceError: (error) {
            if (error.isForMainFrame ?? false) setState(() => _failed = true);
          },
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            if (uri == null || _isInternal(uri)) {
              return NavigationDecision.navigate;
            }
            launchUrl(uri, mode: LaunchMode.externalApplication);
            return NavigationDecision.prevent;
          },
        ),
      )
      ..loadRequest(Uri.parse(AppConfig.newsUrl));
  }

  /// Remonte l'historique du site. Renvoie false s'il n'y a plus de page précédente.
  Future<bool> goBack() async {
    if (!await _controller.canGoBack()) return false;
    await _controller.goBack();
    return true;
  }

  Future<void> reload() => _controller.reload();

  Future<String?> currentUrl() => _controller.currentUrl();

  bool _isInternal(Uri uri) {
    if (uri.scheme != 'http' && uri.scheme != 'https') return false;
    return uri.host == AppConfig.newsHost ||
        uri.host.endsWith('.${AppConfig.newsHost}');
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (_failed)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: context.palette.surface,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.cloud_off,
                      size: 40,
                      color: context.palette.textMuted,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Impossible de charger les actualités',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Vérifiez votre connexion puis réessayez.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.palette.textMuted),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _controller.reload,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Réessayer'),
                  ),
                ],
              ),
            ),
          )
        else
          WebViewWidget(controller: _controller),
        if (_progress < 100 && !_failed)
          LinearProgressIndicator(value: _progress / 100, minHeight: 3),
      ],
    );
  }
}
