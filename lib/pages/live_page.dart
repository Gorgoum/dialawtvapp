import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../config.dart';
import '../theme.dart';
import '../widgets/brand.dart';

/// Lecture du direct HLS. [active] passe à false quand l'utilisateur quitte l'onglet :
/// la lecture est alors mise en pause.
class LivePage extends StatefulWidget {
  const LivePage({
    super.key,
    required this.active,
    required this.onOpenNews,
    required this.onOpenContacts,
    required this.onRequestCoverage,
    this.locked = false,
    this.accessNote,
    this.onSubscribe,
    this.paymentPending = false,
  });

  final bool active;
  final VoidCallback onOpenNews;
  final VoidCallback onOpenContacts;
  final VoidCallback onRequestCoverage;

  /// Essai terminé sans abonnement : le flux n'est pas chargé.
  final bool locked;

  /// Ex. « Essai gratuit : 12 jours restants », affiché sous le titre.
  final String? accessNote;
  final VoidCallback? onSubscribe;

  /// Paiement envoyé, en attente de validation par un admin.
  final bool paymentPending;

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
    if (widget.locked) {
      _loading = false;
    } else {
      _start();
    }
  }

  Future<void> _start() async {
    await _release();
    if (!mounted || widget.locked) return;
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
    // L'accès a pu être coupé pendant le chargement.
    if (!mounted || widget.locked) {
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
    if (oldWidget.locked != widget.locked) {
      if (widget.locked) {
        _release();
        setState(() {
          _loading = false;
          _error = null;
        });
      } else {
        _start();
      }
      return;
    }
    if (oldWidget.active == widget.active) return;
    if (widget.active && _chewie != null) {
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        // Téléphone en paysage : le lecteur occupe tout l'écran disponible.
        if (width >= Breakpoints.compact && height < 500) {
          return ColoredBox(
            color: Colors.black,
            child: Center(child: _player()),
          );
        }

        // Tablette en paysage : lecteur à gauche, informations à droite.
        if (width >= Breakpoints.expanded && width > height) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: _player(radius: 16),
                ),
              ),
              SizedBox(
                width: 380,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(0, 24, 24, 24),
                  children: [
                    _details(),
                    const SizedBox(height: 24),
                    _explore(),
                  ],
                ),
              ),
            ],
          );
        }

        // Tablette en portrait : contenu centré, lecteur arrondi.
        if (width >= Breakpoints.compact) {
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              ContentWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _player(radius: 16),
                    const SizedBox(height: 24),
                    _details(),
                    const SizedBox(height: 24),
                    _explore(horizontal: true),
                  ],
                ),
              ),
            ],
          );
        }

        // Téléphone en portrait : lecteur bord à bord.
        return ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            _player(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [_details(), const SizedBox(height: 24), _explore()],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _player({double radius = 0}) {
    final Widget content;
    if (widget.locked) {
      content = _LockedView(
        onSubscribe: widget.onSubscribe,
        pending: widget.paymentPending,
      );
    } else if (_loading) {
      content = const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    } else if (_error != null) {
      content = _ErrorView(message: _error!, onRetry: _start);
    } else {
      content = Chewie(controller: _chewie!);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: AspectRatio(
        aspectRatio: _video?.value.aspectRatio ?? 16 / 9,
        child: ColoredBox(color: Colors.black, child: content),
      ),
    );
  }

  Widget _details() {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const LiveBadge(),
        const SizedBox(height: 12),
        Text(
          AppConfig.appName,
          style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          'Suivez les programmes de Dialaw TV en direct, partout et à tout moment.',
          style: textTheme.bodyMedium?.copyWith(
            color: context.palette.textMuted,
            height: 1.45,
          ),
        ),
        if (widget.accessNote != null) ...[
          const SizedBox(height: 14),
          _AccessNote(text: widget.accessNote!, onTap: widget.onSubscribe),
        ],
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final fullscreen = FilledButton.icon(
              onPressed: _chewie == null
                  ? null
                  : () => _chewie?.enterFullScreen(),
              icon: const Icon(Icons.fullscreen),
              label: const Text('Plein écran', maxLines: 1),
            );
            final reload = OutlinedButton.icon(
              onPressed: widget.locked ? null : _start,
              icon: const Icon(Icons.refresh),
              label: const Text('Recharger', maxLines: 1),
            );
            // Côte à côte s'il y a la place pour le texte, sinon l'un sous l'autre
            // (petit écran ou grande police) pour ne pas couper les mots.
            final needed = MediaQuery.textScalerOf(context).scale(300);
            if (constraints.maxWidth >= needed) {
              return Row(
                children: [
                  Expanded(child: fullscreen),
                  const SizedBox(width: 12),
                  Expanded(child: reload),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [fullscreen, const SizedBox(height: 10), reload],
            );
          },
        ),
      ],
    );
  }

  Widget _explore({bool horizontal = false}) {
    final news = _ShortcutCard(
      icon: Icons.newspaper,
      color: context.palette.accent,
      title: 'Dialaw Actu',
      subtitle: "L'information en temps réel",
      onTap: widget.onOpenNews,
    );
    final contacts = _ShortcutCard(
      icon: Icons.forum,
      color: AppColors.live,
      title: 'Nous suivre',
      subtitle: 'Réseaux sociaux et contacts',
      onTap: widget.onOpenContacts,
    );
    final coverage = _ShortcutCard(
      icon: Icons.videocam,
      color: const Color(0xFFFF9F0A),
      title: 'Demander une couverture',
      subtitle: 'Faites couvrir votre événement',
      onTap: widget.onRequestCoverage,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'EXPLORER',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: context.palette.textMuted,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        coverage,
        const SizedBox(height: 10),
        if (horizontal)
          Row(
            children: [
              Expanded(child: news),
              const SizedBox(width: 12),
              Expanded(child: contacts),
            ],
          )
        else ...[
          news,
          const SizedBox(height: 10),
          contacts,
        ],
      ],
    );
  }
}

class _ShortcutCard extends StatelessWidget {
  const _ShortcutCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.palette.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: context.palette.textMuted),
            ],
          ),
        ),
      ),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }
}

/// Remplace le lecteur quand l'essai est terminé sans abonnement.
class _LockedView extends StatelessWidget {
  const _LockedView({required this.onSubscribe, this.pending = false});

  final VoidCallback? onSubscribe;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    // FittedBox : reste entier dans le cadre 16:9, même petit ou avec une grande police.
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                pending ? Icons.hourglass_top : Icons.lock_outline,
                color: Colors.white,
                size: 36,
              ),
              const SizedBox(height: 10),
              Text(
                pending
                    ? 'Paiement en cours de vérification'
                    : 'Votre mois gratuit est terminé',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                pending
                    ? 'Le direct reviendra dès que Dialaw TV aura validé votre paiement.'
                    : 'Abonnez-vous pour continuer à suivre le direct.',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onSubscribe,
                icon: const Icon(Icons.play_circle_outline),
                label: Text(
                  pending
                      ? 'Voir mon abonnement'
                      : 'S’abonner – dès 1 000 FCFA/mois',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rappel de l'essai en cours, qui mène à la page d'abonnement.
class _AccessNote extends StatelessWidget {
  const _AccessNote({required this.text, required this.onTap});

  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const orange = Color(0xFFFF9F0A);
    return Material(
      color: orange.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.card_giftcard, color: orange, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              // Flèche plutôt qu'un libellé : tient sur petit écran / grande police.
              Icon(Icons.chevron_right, color: context.palette.accent),
            ],
          ),
        ),
      ),
    );
  }
}
