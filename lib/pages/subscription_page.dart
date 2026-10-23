import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../subscription.dart';
import '../theme.dart';
import '../widgets/brand.dart';

/// Couleur de Wave, pour que le bouton de paiement soit reconnu d'un coup d'œil.
const _waveBlue = Color(0xFF1DC8F2);

String formatFcfa(int amount) =>
    '${NumberFormat.decimalPattern('fr').format(amount)} FCFA';

/// État de l'abonnement, choix de la formule et paiement avec Wave.
class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({super.key, required this.subscription});

  final SubscriptionService subscription;

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage>
    with WidgetsBindingObserver {
  Plan _plan = Plan.yearly;
  bool _opening = false;

  /// Après l'ouverture de Wave : on surveille l'arrivée du paiement.
  Timer? _poll;
  DateTime? _paidUntilBefore;

  SubscriptionService get _sub => widget.subscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sub.refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Retour depuis Wave : vérifier tout de suite.
    if (state == AppLifecycleState.resumed && _poll != null) _check();
  }

  Future<void> _pay() async {
    setState(() => _opening = true);
    try {
      final url = await _sub.startCheckout(_plan);
      _paidUntilBefore = _sub.info?.paidUntil;
      final opened = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!opened) {
        throw const SubscriptionException("Impossible d'ouvrir Wave.");
      }
      // Wave confirme au serveur en quelques secondes : on vérifie pendant 3 minutes.
      _poll?.cancel();
      var ticks = 0;
      _poll = Timer.periodic(const Duration(seconds: 5), (timer) {
        if (++ticks > 36) {
          // Paiement abandonné : on rend la main sans bloquer le bouton.
          timer.cancel();
          if (mounted) setState(() => _poll = null);
          return;
        }
        _check();
      });
    } on SubscriptionException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _check() async {
    if (!await _sub.refresh() || !mounted) return;
    final paidUntil = _sub.info?.paidUntil;
    final before = _paidUntilBefore;
    if (paidUntil != null && (before == null || paidUntil.isAfter(before))) {
      _poll?.cancel();
      _poll = null;
      HapticFeedback.mediumImpact();
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.verified, color: Color(0xFF34C759), size: 40),
          title: const Text('Paiement reçu'),
          content: Text(
            'Merci ! Votre abonnement est actif jusqu’au '
            '${DateFormat('d MMMM y', 'fr').format(paidUntil)}.',
            textAlign: TextAlign.center,
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Regarder le direct'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context);
    }
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Mon abonnement',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: _sub,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              ContentWidth(
                maxWidth: 560,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _StatusCard(subscription: _sub),
                    const SizedBox(height: 24),
                    Text(
                      'CHOISIR UNE FORMULE',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: palette.textMuted,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    for (final plan in Plan.values) ...[
                      _PlanCard(
                        plan: plan,
                        selected: _plan == plan,
                        onTap: () => setState(() => _plan = plan),
                      ),
                      const SizedBox(height: 10),
                    ],
                    const SizedBox(height: 10),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: _waveBlue,
                        foregroundColor: const Color(0xFF0B1F33),
                        minimumSize: const Size(0, 56),
                      ),
                      onPressed: _opening || _poll != null ? null : _pay,
                      child: _opening || _poll != null
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF0B1F33),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Flexible(
                                  child: Text(
                                    _poll != null
                                        ? 'En attente du paiement…'
                                        : 'Ouverture de Wave…',
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              'Payer ${formatFcfa(_plan.amount)} avec Wave',
                              textAlign: TextAlign.center,
                            ),
                    ),
                    if (_poll != null)
                      TextButton(
                        onPressed: () {
                          _poll?.cancel();
                          setState(() => _poll = null);
                        },
                        child: const Text('Annuler l’attente'),
                      ),
                    const SizedBox(height: 12),
                    Text(
                      'Paiement sécurisé par Wave. Les jours payés s’ajoutent à votre '
                      'période en cours : vous ne perdez aucun jour.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: palette.textMuted,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _DeviceIdTile(deviceId: _sub.deviceId),
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

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.subscription});

  final SubscriptionService subscription;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final info = subscription.info;
    final days = subscription.daysLeft ?? 0;
    String date(DateTime d) => DateFormat('d MMMM y', 'fr').format(d);

    final (
      IconData icon,
      Color color,
      String title,
      String text,
    ) = switch (info?.status) {
      AccessStatus.active => (
        Icons.verified,
        const Color(0xFF34C759),
        'Abonné',
        'Accès au direct jusqu’au ${date(info!.accessUntil!)}.',
      ),
      AccessStatus.trial => (
        Icons.card_giftcard,
        const Color(0xFFFF9F0A),
        'Essai gratuit',
        days <= 1
            ? 'Votre essai se termine aujourd’hui.'
            : 'Encore $days jours offerts, jusqu’au ${date(info!.accessUntil!)}.',
      ),
      AccessStatus.expired => (
        Icons.lock_clock,
        AppColors.live,
        'Accès expiré',
        'Abonnez-vous pour retrouver le direct.',
      ),
      null => (
        Icons.sync,
        palette.textMuted,
        'Vérification…',
        subscription.loading ? 'Connexion au serveur en cours.' : 'Connexion impossible pour le moment. Vérifiez votre connexion Internet.',
      ),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    text,
                    style: TextStyle(color: palette.textMuted, height: 1.35),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.selected,
    required this.onTap,
  });

  final Plan plan;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    // Annuel : 12 mois pour le prix de 10.
    final saving = Plan.monthly.amount * 12 - Plan.yearly.amount;
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
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: selected ? AppColors.red : palette.outline,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            plan.label,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          if (plan == Plan.yearly)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF34C759),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${formatFcfa(saving)} d’économie',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Prix sous le nom (et non à droite) : il reste lisible
                      // sur petit écran et avec une grande police.
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: formatFcfa(plan.amount),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                              ),
                            ),
                            TextSpan(
                              text: ' ${plan.period}',
                              style: TextStyle(color: palette.textMuted),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        plan == Plan.yearly
                            ? '12 mois pour le prix de 10'
                            : 'Sans engagement, à renouveler chaque mois',
                        style: TextStyle(
                          color: palette.textMuted,
                          fontSize: 13,
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
}

/// Identifiant à communiquer à Dialaw TV (changement de téléphone, réclamation).
class _DeviceIdTile extends StatelessWidget {
  const _DeviceIdTile({required this.deviceId});

  final String deviceId;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Card(
      child: ListTile(
        leading: Icon(Icons.badge_outlined, color: palette.textMuted),
        title: const Text('Identifiant de l’appareil'),
        subtitle: Text(
          '$deviceId\nÀ communiquer à Dialaw TV en cas de problème ou de changement de téléphone.',
          style: TextStyle(color: palette.textMuted, fontSize: 12),
        ),
        isThreeLine: true,
        trailing: IconButton(
          tooltip: 'Copier',
          icon: const Icon(Icons.copy),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: deviceId));
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Identifiant copié')));
          },
        ),
      ),
    );
  }
}
