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

/// État de l'abonnement, choix de la formule et paiement avec le lien Wave Business.
/// Le paiement est ensuite validé par un admin de Dialaw TV.
class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({
    super.key,
    required this.subscription,
    this.defaultPhone = '',
  });

  final SubscriptionService subscription;

  /// Numéro du profil, proposé comme numéro Wave.
  final String defaultPhone;

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage>
    with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  late final _phone = TextEditingController(text: widget.defaultPhone);
  Plan _plan = Plan.yearly;
  bool _opening = false;

  /// Un paiement était en attente : on prévient l'utilisateur quand il est validé.
  bool _wasPending = false;

  SubscriptionService get _sub => widget.subscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _wasPending = _sub.info?.paymentPending ?? false;
    _sub.addListener(_onAccessChanged);
    _sub.refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub.removeListener(_onAccessChanged);
    _phone.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Retour depuis Wave ou réouverture : l'admin a peut-être validé entre-temps.
    if (state == AppLifecycleState.resumed) _sub.refresh();
  }

  void _onAccessChanged() {
    final payment = _sub.info?.lastPayment;
    if (payment?.status == PaymentStatus.pending) {
      _wasPending = true;
    } else if (_wasPending && payment?.status == PaymentStatus.succeeded) {
      _wasPending = false;
      _showValidated();
    }
  }

  Future<void> _showValidated() async {
    final until = _sub.info?.paidUntil;
    if (!mounted || until == null) return;
    HapticFeedback.mediumImpact();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.verified, color: Color(0xFF34C759), size: 40),
        title: const Text('Paiement validé'),
        content: Text(
          'Merci ! Votre abonnement est actif jusqu’au '
          '${DateFormat('d MMMM y', 'fr').format(until)}.',
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

  Future<void> _pay() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _opening = true);
    try {
      final url = await _sub.startPayment(_plan, _phone.text);
      final opened = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!opened) {
        throw const SubscriptionException(
          "Impossible d'ouvrir Wave. Vérifiez que l'application Wave est installée.",
        );
      }
    } on SubscriptionException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  /// Même règle que le serveur : mobile sénégalais (70, 75, 76, 77, 78).
  static String? _validatePhone(String? value) {
    final digits = (value ?? '')
        .replaceAll(RegExp(r'\D'), '')
        .replaceFirst(RegExp(r'^(00)?221'), '');
    if (digits.isEmpty) return 'Indiquez le numéro Wave qui va payer';
    return RegExp(r'^7[05678]\d{7}$').hasMatch(digits)
        ? null
        : 'Numéro invalide (ex. : 77 123 45 67)';
  }

  Widget _label(String text) => Text(
    text,
    style: Theme.of(context).textTheme.labelMedium?.copyWith(
      color: context.palette.textMuted,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.2,
    ),
  );

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
          builder: (context, _) => Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                ContentWidth(
                  maxWidth: 560,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _StatusCard(subscription: _sub),
                      if (_sub.info?.lastPayment case final payment?)
                        if (payment.status != PaymentStatus.succeeded) ...[
                          const SizedBox(height: 12),
                          _PaymentNotice(payment: payment),
                        ],
                      const SizedBox(height: 24),
                      _label('1. CHOISIR UNE FORMULE'),
                      const SizedBox(height: 10),
                      for (final plan in Plan.values) ...[
                        _PlanCard(
                          plan: plan,
                          selected: _plan == plan,
                          onTap: () => setState(() => _plan = plan),
                        ),
                        const SizedBox(height: 10),
                      ],
                      const SizedBox(height: 14),
                      _label('2. VOTRE NUMÉRO WAVE'),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Numéro qui va payer',
                          hintText: '77 123 45 67',
                          prefixIcon: Icon(Icons.phone_android),
                          helperText: 'Dialaw TV s’en sert pour retrouver votre paiement.',
                        ),
                        validator: _validatePhone,
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: _waveBlue,
                          foregroundColor: const Color(0xFF0B1F33),
                          minimumSize: const Size(0, 56),
                        ),
                        onPressed: _opening ? null : _pay,
                        child: _opening
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF0B1F33),
                                ),
                              )
                            : Text(
                                'Payer ${formatFcfa(_plan.amount)} avec Wave',
                                textAlign: TextAlign.center,
                              ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Après le paiement dans Wave, Dialaw TV le vérifie et active '
                        'votre abonnement. Les jours payés s’ajoutent à votre période '
                        'en cours : vous ne perdez aucun jour.',
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
      ),
    );
  }
}

/// Paiement en attente de vérification, ou refusé par Dialaw TV.
class _PaymentNotice extends StatelessWidget {
  const _PaymentNotice({required this.payment});

  final LastPayment payment;

  @override
  Widget build(BuildContext context) {
    final pending = payment.status == PaymentStatus.pending;
    final color = pending ? const Color(0xFFFF9F0A) : AppColors.live;
    final when = DateFormat("d MMM 'à' HH:mm", 'fr').format(payment.createdAt);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            pending ? Icons.hourglass_top : Icons.error_outline,
            color: color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              pending
                  ? 'Paiement de ${formatFcfa(payment.amount)} (demandé le $when) en cours '
                        'de vérification par Dialaw TV. Votre abonnement sera activé dès la '
                        'validation.'
                  : 'Paiement de ${formatFcfa(payment.amount)} du $when non retrouvé '
                        'par Dialaw TV. Si vous avez bien payé, contactez-nous sur WhatsApp.',
              style: const TextStyle(height: 1.4),
            ),
          ),
        ],
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
