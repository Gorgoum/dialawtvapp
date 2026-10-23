import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../theme.dart';
import '../widgets/brand.dart';

class _Contact {
  const _Contact(this.icon, this.color, this.label, this.value, this.uri);

  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final Uri uri;
}

class ContactsPage extends StatelessWidget {
  const ContactsPage({super.key, required this.onRequestCoverage});

  final VoidCallback onRequestCoverage;

  /// Valeur lisible sous chaque contact : numéro groupé, @compte ou domaine,
  /// plutôt que l'adresse brute.
  static String _display(String value) {
    // +221772197773 → +221 77 219 77 73
    final sn = RegExp(r'^\+221(\d{2})(\d{3})(\d{2})(\d{2})$').firstMatch(value);
    if (sn != null) return '+221 ${sn[1]} ${sn[2]} ${sn[3]} ${sn[4]}';

    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return value;
    final host = uri.host.replaceFirst('www.', '');
    final path = uri.path.replaceAll(RegExp(r'/+$'), '');
    if (path.startsWith('/@')) return path.substring(1); // TikTok, YouTube
    // Page Facebook sans nom d'utilisateur : l'identifiant n'a pas de sens.
    if (path == '/profile.php') return AppConfig.appName;
    return '$host$path';
  }

  List<_Contact> _contacts(BuildContext context) {
    final list = <_Contact>[];
    void add(
      IconData icon,
      Color color,
      String label,
      String value,
      Uri Function() uri,
    ) {
      if (value.isNotEmpty) {
        list.add(_Contact(icon, color, label, _display(value), uri()));
      }
    }

    add(
      Icons.phone,
      const Color(0xFF34C759),
      'Téléphone',
      AppConfig.phone,
      () => Uri(scheme: 'tel', path: AppConfig.phone),
    );
    add(
      Icons.chat,
      const Color(0xFF25D366),
      'WhatsApp',
      AppConfig.whatsapp.isEmpty ? '' : '+${AppConfig.whatsapp}',
      () => Uri.parse('https://wa.me/${AppConfig.whatsapp}'),
    );
    add(
      Icons.email,
      const Color(0xFFFFB020),
      'E-mail',
      AppConfig.email,
      () => Uri(scheme: 'mailto', path: AppConfig.email),
    );
    add(
      Icons.facebook,
      const Color(0xFF1877F2),
      'Facebook',
      AppConfig.facebook,
      () => Uri.parse(AppConfig.facebook),
    );
    add(
      Icons.smart_display,
      const Color(0xFFFF0033),
      'YouTube',
      AppConfig.youtube,
      () => Uri.parse(AppConfig.youtube),
    );
    add(
      Icons.music_note,
      const Color(0xFF25F4EE),
      'TikTok',
      AppConfig.tiktok,
      () => Uri.parse(AppConfig.tiktok),
    );
    add(
      Icons.camera_alt,
      const Color(0xFFE1306C),
      'Instagram',
      AppConfig.instagram,
      () => Uri.parse(AppConfig.instagram),
    );
    add(
      Icons.alternate_email,
      context.palette.text,
      'X (Twitter)',
      AppConfig.twitter,
      () => Uri.parse(AppConfig.twitter),
    );
    add(
      Icons.language,
      context.palette.accent,
      'Site web',
      AppConfig.newsUrl,
      () => Uri.parse(AppConfig.newsUrl),
    );
    return list;
  }

  Future<void> _open(BuildContext context, Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Impossible d'ouvrir ce lien.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final contacts = _contacts(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final padding = width >= Breakpoints.compact ? 24.0 : 16.0;
        final columns = width >= 1000
            ? 3
            : width >= Breakpoints.compact
            ? 2
            : 1;

        return ListView(
          padding: EdgeInsets.all(padding),
          children: [
            ContentWidth(
              maxWidth: 1000,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _Hero(),
                  const SizedBox(height: 16),
                  _CoverageCta(onTap: onRequestCoverage),
                  const SizedBox(height: 28),
                  Text(
                    'NOUS JOINDRE',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: context.palette.textMuted,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  LayoutBuilder(
                    builder: (context, inner) {
                      const gap = 12.0;
                      final itemWidth =
                          (inner.maxWidth - gap * (columns - 1)) / columns;
                      return Wrap(
                        spacing: gap,
                        runSpacing: gap,
                        children: [
                          for (final c in contacts)
                            SizedBox(
                              width: itemWidth,
                              child: _ContactCard(
                                contact: c,
                                onTap: () => _open(context, c.uri),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                  Center(
                    child: Text(
                      '© Dialaw TV',
                      style: TextStyle(
                        color: context.palette.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.blue, Color(0xFF1A0A6B), Color(0xFF5A0A2A)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BrandLogo(height: 44),
          const SizedBox(height: 20),
          Text(
            'Restons connectés',
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Une info, une remarque, un partenariat ? '
            "L'équipe de Dialaw TV vous répond.",
            style: textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.8),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({required this.contact, required this.onTap});

  final _Contact contact;
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
                  color: contact.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(contact.icon, color: contact.color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.label,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      contact.value,
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
              Icon(
                Icons.north_east,
                size: 18,
                color: context.palette.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Encart d'appel à demander la couverture d'un événement.
class _CoverageCta extends StatelessWidget {
  const _CoverageCta({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.red.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.videocam, color: AppColors.live),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Demander une couverture',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'En direct ou en reportage : Dialaw TV couvre votre événement.',
                      style: TextStyle(color: palette.textMuted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward, color: palette.accent),
            ],
          ),
        ),
      ),
    );
  }
}
