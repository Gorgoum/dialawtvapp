import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';

class _Contact {
  const _Contact(this.icon, this.label, this.value, this.uri);

  final IconData icon;
  final String label;
  final String value;
  final Uri uri;
}

class ContactsPage extends StatelessWidget {
  const ContactsPage({super.key});

  List<_Contact> _contacts() {
    final list = <_Contact>[];
    void add(IconData icon, String label, String value, Uri Function() uri) {
      if (value.isNotEmpty) list.add(_Contact(icon, label, value, uri()));
    }

    add(
      Icons.phone,
      'Téléphone',
      AppConfig.phone,
      () => Uri(scheme: 'tel', path: AppConfig.phone),
    );
    add(
      Icons.chat,
      'WhatsApp',
      AppConfig.whatsapp,
      () => Uri.parse('https://wa.me/${AppConfig.whatsapp}'),
    );
    add(
      Icons.email,
      'E-mail',
      AppConfig.email,
      () => Uri(scheme: 'mailto', path: AppConfig.email),
    );
    add(
      Icons.facebook,
      'Facebook',
      AppConfig.facebook,
      () => Uri.parse(AppConfig.facebook),
    );
    add(
      Icons.smart_display,
      'YouTube',
      AppConfig.youtube,
      () => Uri.parse(AppConfig.youtube),
    );
    add(
      Icons.music_note,
      'TikTok',
      AppConfig.tiktok,
      () => Uri.parse(AppConfig.tiktok),
    );
    add(
      Icons.camera_alt,
      'Instagram',
      AppConfig.instagram,
      () => Uri.parse(AppConfig.instagram),
    );
    add(
      Icons.alternate_email,
      'X (Twitter)',
      AppConfig.twitter,
      () => Uri.parse(AppConfig.twitter),
    );
    add(
      Icons.language,
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
    final contacts = _contacts();
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 24),
      children: [
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset('assets/logo_dialaw.jpg', height: 110),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            'Contactez-nous',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: 16),
        for (final c in contacts)
          ListTile(
            leading: CircleAvatar(
              backgroundColor: AppConfig.blue,
              foregroundColor: Colors.white,
              child: Icon(c.icon),
            ),
            title: Text(c.label),
            subtitle: Text(
              c.value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _open(context, c.uri),
          ),
      ],
    );
  }
}
