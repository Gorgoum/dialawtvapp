import 'package:flutter/material.dart';

import '../theme.dart';

/// Logo Dialaw sur cartouche blanc. L'image source est carrée avec beaucoup de marge :
/// on n'affiche que la bande centrale qui contient le texte.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.height = 36});

  final double height;

  @override
  Widget build(BuildContext context) {
    // Liseré pour détacher le cartouche blanc du fond en mode clair.
    final light = Theme.of(context).brightness == Brightness.light;
    return Container(
      height: height,
      width: height * 4,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(height * 0.22),
        border: light ? Border.all(color: context.palette.outline) : null,
      ),
      child: Image.asset(
        'assets/logo_dialaw.jpg',
        fit: BoxFit.cover,
        alignment: const Alignment(0, 0.12),
        filterQuality: FilterQuality.medium,
      ),
    );
  }
}

/// Pastille « EN DIRECT » avec un point qui pulse.
class LiveBadge extends StatefulWidget {
  const LiveBadge({super.key});

  @override
  State<LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<LiveBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.red,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: Tween(begin: 0.35, end: 1.0).animate(_pulse),
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            'EN DIRECT',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 12,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

/// Limite la largeur du contenu sur tablette pour garder des lignes lisibles.
class ContentWidth extends StatelessWidget {
  const ContentWidth({super.key, this.maxWidth = 840, required this.child});

  final double maxWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
