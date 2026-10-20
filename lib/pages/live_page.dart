import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../config.dart';

/// Lecture du direct HLS. [active] passe à false quand l'utilisateur quitte l'onglet :
/// la lecture est alors mise en pause.
class LivePage extends StatefulWidget {
  const LivePage({super.key, required this.active});

  final bool active;

  @override
  State<LivePage> createState() => _LivePageState();
}

class _LivePageState extends State<LivePage> with WidgetsBindingObserver {
  VideoPlayerController? _video;
  ChewieController? _chewie;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  Future<void> _start() async {
    await _release();
    setState(() {
      _loading = true;
      _error = null;
    });

    final video = VideoPlayerController.networkUrl(
      Uri.parse(AppConfig.liveStreamUrl),
      formatHint: VideoFormat.hls,
    );
    try {
      await video.initialize();
    } catch (_) {
      await video.dispose();
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Le direct est momentanément indisponible.';
      });
      return;
    }
    if (!mounted) {
      await video.dispose();
      return;
    }

    _video = video;
    _chewie = ChewieController(
      videoPlayerController: video,
      autoPlay: widget.active,
      isLive: true,
      allowMuting: true,
      allowPlaybackSpeedChanging: false,
      aspectRatio: video.value.aspectRatio,
      materialProgressColors: ChewieProgressColors(
        playedColor: AppConfig.red,
        handleColor: AppConfig.red,
      ),
      errorBuilder: (context, message) =>
          _ErrorView(message: 'Lecture interrompue.', onRetry: _start),
    );
    if (widget.active) WakelockPlus.enable();
    setState(() => _loading = false);
  }

  Future<void> _release() async {
    final chewie = _chewie;
    final video = _video;
    _chewie = null;
    _video = null;
    chewie?.dispose();
    await video?.dispose();
    WakelockPlus.disable();
  }

  @override
  void didUpdateWidget(LivePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active == widget.active) return;
    if (widget.active) {
      _chewie?.play();
      WakelockPlus.enable();
    } else {
      _chewie?.pause();
      WakelockPlus.disable();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) _chewie?.pause();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget player;
    if (_loading) {
      player = const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    } else if (_error != null) {
      player = _ErrorView(message: _error!, onRetry: _start);
    } else {
      player = Chewie(controller: _chewie!);
    }

    return ListView(
      children: [
        AspectRatio(
          aspectRatio: _video?.value.aspectRatio ?? 16 / 9,
          child: ColoredBox(color: Colors.black, child: player),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppConfig.red,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'EN DIRECT',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    AppConfig.appName,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                "Suivez les programmes de Dialaw TV en direct, partout et à tout moment.",
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _start,
                icon: const Icon(Icons.refresh),
                label: const Text('Recharger le direct'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.signal_wifi_off, color: Colors.white70, size: 40),
          const SizedBox(height: 8),
          Text(message, style: const TextStyle(color: Colors.white)),
          const SizedBox(height: 8),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppConfig.red),
            onPressed: onRetry,
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }
}
