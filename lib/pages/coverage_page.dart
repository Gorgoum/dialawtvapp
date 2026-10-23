import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../config.dart';
import '../coverage.dart';
import '../settings.dart';
import '../theme.dart';
import '../widgets/brand.dart';

/// Formulaire de demande de couverture. La demande part sur le WhatsApp de la
/// rédaction, qui confirme ensuite directement à l'utilisateur.
class CoverageRequestPage extends StatefulWidget {
  const CoverageRequestPage({
    super.key,
    required this.settings,
    required this.store,
  });

  final AppSettings settings;
  final CoverageStore store;

  @override
  State<CoverageRequestPage> createState() => _CoverageRequestPageState();
}

class _CoverageRequestPageState extends State<CoverageRequestPage> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _date = TextEditingController();
  final _place = TextEditingController();
  late final _requester = TextEditingController(text: widget.settings.name);
  late final _phone = TextEditingController(text: widget.settings.phone);
  final _details = TextEditingController();
  bool _live = true;
  String? _category;
  DateTime? _when;
  bool _sending = false;

  // Après une première tentative d'envoi, les erreurs se mettent à jour pendant la saisie.
  bool _submitted = false;

  @override
  void dispose() {
    _title.dispose();
    _date.dispose();
    _place.dispose();
    _requester.dispose();
    _phone.dispose();
    _details.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = _when ?? now.add(const Duration(days: 1));
    final day = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
      helpText: "Date de l'événement",
    );
    if (day == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_when ?? DateTime(0, 1, 1, 10)),
      helpText: 'Heure de début',
    );
    if (time == null) return;
    setState(() {
      _when = DateTime(day.year, day.month, day.day, time.hour, time.minute);
      _date.text = formatCoverageDateShort(_when!);
    });
  }

  Future<void> _submit() async {
    if (!_submitted) setState(() => _submitted = true);
    if (!_formKey.currentState!.validate()) return;
    if (!coverageContactConfigured) {
      _snack(
        "Le contact de la rédaction n'est pas encore configuré. Réessayez plus tard.",
      );
      return;
    }
    setState(() => _sending = true);
    final request = CoverageRequest(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      live: _live,
      title: _title.text.trim(),
      category: _category!,
      date: _when!,
      place: _place.text.trim(),
      requester: _requester.text.trim(),
      phone: _phone.text.trim(),
      details: _details.text.trim(),
      sentAt: DateTime.now(),
    );
    final opened = await sendCoverageRequest(request);
    if (!mounted) return;
    setState(() => _sending = false);
    if (!opened) {
      _snack(
        AppConfig.whatsapp.isNotEmpty
            ? "Impossible d'ouvrir WhatsApp. Vérifiez qu'il est installé."
            : "Impossible d'ouvrir la messagerie.",
      );
      return;
    }
    await widget.store.add(request);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => const _SentDialog(),
    );
    if (mounted) Navigator.pop(context);
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String? _required(String? value) =>
      (value?.trim().isEmpty ?? true) ? 'Champ obligatoire' : null;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final viaWhatsapp =
        AppConfig.whatsapp.isNotEmpty || !coverageContactConfigured;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Couverture',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: 'Mes demandes',
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => MyCoverageRequestsPage(store: widget.store),
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          autovalidateMode: _submitted
              ? AutovalidateMode.onUserInteraction
              : AutovalidateMode.disabled,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              ContentWidth(
                maxWidth: 640,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Vous organisez un événement ? Décrivez-le ci-dessous : '
                      'la demande est envoyée à la rédaction de Dialaw TV, '
                      'qui vous confirmera la couverture par WhatsApp.',
                      style: TextStyle(color: palette.textMuted, height: 1.45),
                    ),
                    const SizedBox(height: 20),
                    const _Label('Type de couverture'),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _TypeCard(
                            icon: Icons.sensors,
                            title: 'En direct',
                            subtitle: 'Diffusée en direct sur Dialaw TV',
                            selected: _live,
                            onTap: () => setState(() => _live = true),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _TypeCard(
                            icon: Icons.videocam_outlined,
                            title: 'Simple',
                            subtitle: 'Reportage diffusé après l’événement',
                            selected: !_live,
                            onTap: () => setState(() => _live = false),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const _Label("L'événement"),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _title,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.next,
                      maxLength: 120,
                      decoration: const InputDecoration(
                        labelText: "Nom de l'événement *",
                        hintText: 'Ex. : Conférence de presse annuelle',
                        prefixIcon: Icon(Icons.event_outlined),
                        counterText: '',
                      ),
                      validator: _required,
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: _category,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Catégorie *',
                        prefixIcon: Icon(Icons.category_outlined),
                      ),
                      items: [
                        for (final c in coverageCategories)
                          DropdownMenuItem(value: c, child: Text(c)),
                      ],
                      onChanged: (v) => setState(() => _category = v),
                      validator: (v) =>
                          v == null ? 'Choisissez une catégorie' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _date,
                      readOnly: true,
                      onTap: _pickDate,
                      decoration: const InputDecoration(
                        labelText: 'Date et heure *',
                        prefixIcon: Icon(Icons.calendar_month_outlined),
                        suffixIcon: Icon(Icons.arrow_drop_down),
                      ),
                      validator: (_) {
                        if (_when == null) {
                          return 'Choisissez la date et l’heure';
                        }
                        if (_when!.isBefore(DateTime.now())) {
                          return 'La date est déjà passée';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _place,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Lieu *',
                        hintText: 'Ville, quartier, salle…',
                        prefixIcon: Icon(Icons.place_outlined),
                      ),
                      validator: _required,
                    ),
                    const SizedBox(height: 24),
                    const _Label('Vos coordonnées'),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _requester,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Nom ou organisation *',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: _required,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Téléphone (WhatsApp) *',
                        hintText: '77 000 00 00',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      validator: (v) {
                        final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
                        if (digits.isEmpty) return 'Champ obligatoire';
                        if (digits.length < 9) return 'Numéro trop court';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _details,
                      textCapitalization: TextCapitalization.sentences,
                      minLines: 3,
                      maxLines: 6,
                      maxLength: 500,
                      decoration: const InputDecoration(
                        labelText: 'Détails (facultatif)',
                        hintText: 'Programme, durée, personnalités attendues, besoins particuliers…',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _sending ? null : _submit,
                      icon: Icon(
                        viaWhatsapp ? Icons.send : Icons.email_outlined,
                      ),
                      label: Text(
                        viaWhatsapp
                            ? 'Envoyer sur WhatsApp'
                            : 'Envoyer par e-mail',
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '* Champs obligatoires',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: palette.textMuted, fontSize: 12),
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

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: context.palette.textMuted,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _TypeCard extends StatelessWidget {
  const _TypeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected
            ? AppColors.red.withValues(alpha: 0.08)
            : palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: selected ? AppColors.red : palette.outline,
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      icon,
                      color: selected ? AppColors.live : palette.textMuted,
                    ),
                    const Spacer(),
                    Icon(
                      selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      size: 20,
                      color: selected ? AppColors.red : palette.outline,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: palette.textMuted,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SentDialog extends StatelessWidget {
  const _SentDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(
        Icons.mark_chat_read_outlined,
        color: AppColors.live,
        size: 36,
      ),
      title: const Text('Demande préparée'),
      content: Text(
        AppConfig.whatsapp.isNotEmpty
            ? 'Si ce n’est pas déjà fait, appuyez sur « Envoyer » dans WhatsApp. '
                  'La rédaction de Dialaw TV vous confirmera la couverture par WhatsApp.'
            : 'Si ce n’est pas déjà fait, envoyez l’e-mail préparé. '
                  'La rédaction de Dialaw TV vous répondra pour confirmer la couverture.',
        textAlign: TextAlign.center,
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Compris'),
        ),
      ],
    );
  }
}

/// Historique des demandes envoyées depuis ce téléphone.
class MyCoverageRequestsPage extends StatelessWidget {
  const MyCoverageRequestsPage({super.key, required this.store});

  final CoverageStore store;

  Future<void> _delete(BuildContext context, CoverageRequest request) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer cette demande ?'),
        content: const Text(
          'Elle sera retirée de cette liste uniquement : si elle a déjà été '
          'envoyée, la rédaction l’a reçue.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok ?? false) await store.remove(request.id);
  }

  Future<void> _resend(BuildContext context, CoverageRequest request) async {
    if (!await sendCoverageRequest(request) && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Impossible d'ouvrir WhatsApp.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Mes demandes',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final requests = store.requests;
          if (requests.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.inbox_outlined,
                      size: 56,
                      color: palette.textMuted,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Aucune demande pour le moment',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Vos demandes de couverture apparaîtront ici.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: palette.textMuted),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) => ContentWidth(
              maxWidth: 640,
              child: _RequestCard(
                request: requests[i],
                onResend: () => _resend(context, requests[i]),
                onDelete: () => _delete(context, requests[i]),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.onResend,
    required this.onDelete,
  });

  final CoverageRequest request;
  final VoidCallback onResend;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final badgeColor = request.live ? AppColors.red : palette.accent;
    final sent = DateFormat("d MMM y 'à' HH:mm", 'fr').format(request.sentAt);
    Widget info(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: palette.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: palette.textMuted, fontSize: 13),
            ),
          ),
        ],
      ),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
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
                    color: badgeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    request.live ? 'DIRECT' : 'SIMPLE',
                    style: TextStyle(
                      color: badgeColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    request.category,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: palette.textMuted, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              request.title,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            info(
              Icons.calendar_month_outlined,
              formatCoverageDate(request.date),
            ),
            info(Icons.place_outlined, request.place),
            info(
              Icons.schedule_send_outlined,
              'Envoyée le $sent · confirmation par WhatsApp',
            ),
            const SizedBox(height: 4),
            // Wrap : les boutons passent à la ligne avec une grande police.
            Wrap(
              alignment: WrapAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Supprimer'),
                  style: TextButton.styleFrom(
                    foregroundColor: palette.textMuted,
                  ),
                ),
                TextButton.icon(
                  onPressed: onResend,
                  icon: const Icon(Icons.send, size: 18),
                  label: const Text('Renvoyer'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
