import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../settings.dart';
import '../subscription.dart';
import '../theme.dart';
import '../widgets/brand.dart';
import '../widgets/profile_avatar.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.settings,
    this.subscription,
    this.onOpenSubscription,
  });

  final AppSettings settings;

  /// Absent ou désactivé (serveur non configuré) : section Abonnement masquée.
  final SubscriptionService? subscription;
  final VoidCallback? onOpenSubscription;

  void _editProfile(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProfileEditPage(settings: settings),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.sizeOf(context).width >= Breakpoints.compact
        ? 24.0
        : 16.0;
    final sub = subscription;
    return ListenableBuilder(
      listenable: Listenable.merge([settings, ?sub]),
      builder: (context, _) => ListView(
        padding: EdgeInsets.all(padding),
        children: [
          ContentWidth(
            maxWidth: 720,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ProfileCard(
                  settings: settings,
                  onEdit: () => _editProfile(context),
                ),
                if (sub != null && sub.enabled) ...[
                  const SizedBox(height: 28),
                  const _SectionLabel('ABONNEMENT'),
                  const SizedBox(height: 10),
                  _SubscriptionTile(
                    subscription: sub,
                    onTap: onOpenSubscription,
                  ),
                ],
                const SizedBox(height: 28),
                const _SectionLabel('APPARENCE'),
                const SizedBox(height: 10),
                _ThemePicker(
                  value: settings.themeMode,
                  onChanged: settings.setThemeMode,
                ),
                const SizedBox(height: 28),
                const _SectionLabel('À PROPOS'),
                const SizedBox(height: 10),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(
                          Icons.language,
                          color: context.palette.accent,
                        ),
                        title: const Text('Site Dialaw Actu'),
                        subtitle: Text(AppConfig.newsHost),
                        trailing: const Icon(Icons.north_east, size: 18),
                        onTap: () => launchUrl(
                          Uri.parse(AppConfig.newsUrl),
                          mode: LaunchMode.externalApplication,
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Icon(
                          Icons.lock_outline,
                          color: context.palette.accent,
                        ),
                        title: const Text('Confidentialité'),
                        subtitle: const Text(
                          'Votre profil reste sur cet appareil, il n’est envoyé nulle part.',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: context.palette.textMuted,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.settings, required this.onEdit});

  final AppSettings settings;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final details = [
      settings.phone,
      settings.email,
    ].where((s) => s.isNotEmpty).join(' · ');
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              ProfileAvatar(
                name: settings.name,
                imagePath: settings.avatarPath,
                size: 64,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      settings.name.isNotEmpty
                          ? settings.name
                          : 'Créez votre profil',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      details.isNotEmpty
                          ? details
                          : 'Ajoutez votre nom et votre photo',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: palette.textMuted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                settings.hasProfile ? Icons.edit_outlined : Icons.add,
                color: palette.accent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemePicker extends StatelessWidget {
  const _ThemePicker({required this.value, required this.onChanged});

  final ThemeMode value;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final system = MediaQuery.platformBrightnessOf(context);
    Widget option(ThemeMode mode, String label, IconData icon) {
      final Brightness preview = switch (mode) {
        ThemeMode.light => Brightness.light,
        ThemeMode.dark => Brightness.dark,
        ThemeMode.system => system,
      };
      return Expanded(
        child: _ThemeOption(
          label: label,
          icon: icon,
          palette: preview == Brightness.dark
              ? AppPalette.dark
              : AppPalette.light,
          selected: value == mode,
          onTap: () {
            HapticFeedback.selectionClick();
            onChanged(mode);
          },
        ),
      );
    }

    return Row(
      children: [
        option(ThemeMode.light, 'Clair', Icons.light_mode_outlined),
        const SizedBox(width: 10),
        option(ThemeMode.dark, 'Sombre', Icons.dark_mode_outlined),
        const SizedBox(width: 10),
        option(ThemeMode.system, 'Système', Icons.brightness_auto_outlined),
      ],
    );
  }
}

/// Carte de choix du thème avec un aperçu miniature de l'application.
class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.label,
    required this.icon,
    required this.palette,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final AppPalette palette;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final current = context.palette;
    return Semantics(
      selected: selected,
      button: true,
      label: 'Thème $label',
      child: Material(
        color: current.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: selected ? AppColors.red : current.outline,
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                AspectRatio(aspectRatio: 0.9, child: _preview()),
                const SizedBox(height: 10),
                // Réduit plutôt que tronqué (« Cl… ») avec une grande police.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    children: [
                      Icon(
                        selected ? Icons.check_circle : icon,
                        size: 18,
                        color: selected ? AppColors.red : current.textMuted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        maxLines: 1,
                        style: TextStyle(
                          fontWeight: selected
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _preview() {
    Widget line(double widthFactor, Color color) => FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: Alignment.centerLeft,
      child: Container(
        height: 5,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 5, child: Container(color: Colors.black87)),
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Container(
                    width: 18,
                    height: 6,
                    decoration: BoxDecoration(
                      color: AppColors.red,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  line(0.8, palette.text),
                  line(0.55, palette.textMuted),
                ],
              ),
            ),
          ),
          Container(height: 8, color: palette.surface),
        ],
      ),
    );
  }
}

/// Saisie du profil : photo, nom, téléphone et e-mail.
class ProfileEditPage extends StatefulWidget {
  const ProfileEditPage({super.key, required this.settings});

  final AppSettings settings;

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.settings.name);
  late final _phone = TextEditingController(text: widget.settings.phone);
  late final _email = TextEditingController(text: widget.settings.email);
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final settings = widget.settings;
    final choice = await showModalBottomSheet<Object>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choisir dans la galerie'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Prendre une photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            if (settings.avatarPath != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.red),
                title: const Text(
                  'Supprimer la photo',
                  style: TextStyle(color: AppColors.red),
                ),
                onTap: () => Navigator.pop(context, 'remove'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choice == null) return;
    if (choice == 'remove') {
      await settings.removeAvatar();
      return;
    }

    try {
      final file = await ImagePicker().pickImage(
        source: choice as ImageSource,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.front,
      );
      if (file != null) await settings.setAvatar(file);
    } on PlatformException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Accès refusé. Autorisez l'accès aux photos ou à l'appareil photo dans les réglages.",
          ),
        ),
      );
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    await widget.settings.saveProfile(
      name: _name.text,
      phone: _phone.text,
      email: _email.text,
    );
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(const SnackBar(content: Text('Profil enregistré')));
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Mon profil',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              ContentWidth(
                maxWidth: 520,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: ListenableBuilder(
                        listenable: Listenable.merge([widget.settings, _name]),
                        builder: (context, _) => GestureDetector(
                          onTap: _pickPhoto,
                          child: Stack(
                            children: [
                              ProfileAvatar(
                                name: _name.text,
                                imagePath: widget.settings.avatarPath,
                                size: 112,
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.red,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: palette.background,
                                      width: 3,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.photo_camera,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton(
                        onPressed: _pickPhoto,
                        child: const Text('Changer la photo'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Nom complet',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Téléphone',
                        hintText: '77 000 00 00',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _save(),
                      decoration: const InputDecoration(
                        labelText: 'E-mail',
                        prefixIcon: Icon(Icons.alternate_email),
                      ),
                      validator: (value) {
                        final v = value?.trim() ?? '';
                        if (v.isEmpty) return null;
                        return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)
                            ? null
                            : 'Adresse e-mail invalide';
                      },
                    ),
                    const SizedBox(height: 28),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: const Icon(Icons.check),
                      label: const Text('Enregistrer'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Résumé de l'abonnement, qui ouvre la page de paiement.
class _SubscriptionTile extends StatelessWidget {
  const _SubscriptionTile({required this.subscription, required this.onTap});

  final SubscriptionService subscription;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final days = subscription.daysLeft ?? 0;
    final (
      IconData icon,
      Color color,
      String title,
      String subtitle,
    ) = switch (subscription.info?.status) {
      AccessStatus.active => (
        Icons.verified,
        const Color(0xFF34C759),
        'Abonné',
        days <= 1 ? 'Se termine aujourd’hui' : 'Encore $days jours',
      ),
      AccessStatus.trial => (
        Icons.card_giftcard,
        const Color(0xFFFF9F0A),
        'Essai gratuit',
        days <= 1 ? 'Dernier jour' : 'Encore $days jours offerts',
      ),
      AccessStatus.expired => (
        Icons.lock_clock,
        AppColors.live,
        'Accès expiré',
        'Abonnez-vous dès 1 000 FCFA/mois',
      ),
      null => (
        Icons.sync,
        palette.textMuted,
        'Mon abonnement',
        'Vérification en cours',
      ),
    };
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: color),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
