import 'package:flutter/material.dart';
import '../design_system/saas_design_system.dart';
import 'saas_dashboard_widgets.dart';

/// Immutable representation of the active condominium subscription and
/// feature flags resolved with Fail-Closed semantics.
class SubscriptionAccessState {
  const SubscriptionAccessState({
    required this.hasLoaded,
    required this.accessAllowed,
    required this.enabledFeatures,
    this.status,
    this.planName,
    this.planCode,
    this.billingPlanId,
    this.billingCycle,
    this.endAt,
  });

  const SubscriptionAccessState.empty()
      : hasLoaded = false,
        accessAllowed = false,
        enabledFeatures = const {},
        status = null,
        planName = null,
        planCode = null,
        billingPlanId = null,
        billingCycle = null,
        endAt = null;

  final bool hasLoaded;
  final bool accessAllowed;
  final Set<String> enabledFeatures;
  final String? status;
  final String? planName;
  final String? planCode;
  final num? billingPlanId;
  final String? billingCycle;
  final String? endAt;

  /// Builds Fail-Closed subscription access state from `/condominiums/{id}` and
  /// `/condominiums/{id}/subscription`.
  factory SubscriptionAccessState.fromMaps({
    Map<String, dynamic>? condominium,
    Map<String, dynamic>? subscription,
  }) {
    if (condominium == null && subscription == null) {
      return const SubscriptionAccessState.empty();
    }

    final rawStatus = (subscription?['status'] ??
            condominium?['subscriptionStatus'])
        ?.toString()
        .trim()
        .toUpperCase();

    final rawFeatures = subscription?['enabledFeatures'] ??
        condominium?['features'];

    final features = <String>{};
    if (rawFeatures is Iterable) {
      for (final item in rawFeatures) {
        final code = item?.toString().trim().toUpperCase();
        if (code != null && code.isNotEmpty) {
          features.add(code);
        }
      }
    }

    final explicitlyDenied = subscription?['accessAllowed'] == false ||
        rawStatus == 'SUSPENDED' ||
        rawStatus == 'CANCELLED';

    final allowed = !explicitlyDenied && features.isNotEmpty;

    return SubscriptionAccessState(
      hasLoaded: true,
      accessAllowed: allowed,
      enabledFeatures: allowed ? features : const {},
      status: rawStatus,
      planName: (subscription?['billingPlanName'] ?? condominium?['planName'])
          ?.toString(),
      planCode: (subscription?['billingPlanCode'] ?? condominium?['planCode'])
          ?.toString(),
      billingPlanId: (subscription?['billingPlanId'] ??
              condominium?['billingPlanId']) as num?,
      billingCycle: subscription?['billingCycle']?.toString(),
      endAt: subscription?['endAt']?.toString(),
    );
  }

  /// Fail-Closed check: returns true only when subscription state is loaded,
  /// operational status allows access, and [featureCode] is explicitly enabled.
  bool hasFeature(String featureCode) {
    if (!hasLoaded || !accessAllowed) return false;
    return enabledFeatures.contains(featureCode.trim().toUpperCase());
  }

  bool get isSuspendedOrCancelled =>
      status == 'SUSPENDED' || status == 'CANCELLED';

  bool get isPastDue => status == 'PAST_DUE';

  bool get isTrial => status == 'TRIAL';

  String get displayStatusLabel => switch (status) {
        'ACTIVE' => 'Ativa',
        'TRIAL' => 'Período de Avaliação',
        'PAST_DUE' => 'Pendência Financeira',
        'SUSPENDED' => 'Assinatura Suspensa',
        'CANCELLED' => 'Assinatura Cancelada',
        _ => 'Sem assinatura',
      };
}

/// Alert banner rendered when a condominium subscription is in TRIAL, PAST_DUE,
/// SUSPENDED, or CANCELLED status.
class SubscriptionStatusBanner extends StatelessWidget {
  const SubscriptionStatusBanner({
    super.key,
    required this.access,
    this.onManagePlan,
  });

  final SubscriptionAccessState access;
  final VoidCallback? onManagePlan;

  @override
  Widget build(BuildContext context) {
    if (!access.hasLoaded) return const SizedBox.shrink();
    final isSuspended = access.isSuspendedOrCancelled;
    final isPastDue = access.isPastDue;
    final isTrial = access.isTrial;
    if (!isSuspended && !isPastDue && !isTrial && access.accessAllowed) {
      return const SizedBox.shrink();
    }

    final Color accent;
    final IconData icon;
    final String title;
    final String subtitle;

    if (isSuspended || !access.accessAllowed) {
      accent = SaaSColors.error;
      icon = Icons.lock_outline_rounded;
      title = '${access.displayStatusLabel} — Acesso aos módulos bloqueado';
      subtitle = onManagePlan != null
          ? 'Regularize ou selecione um plano ativo para reabilitar os módulos operacionais.'
          : 'Este condomínio está temporariamente com acesso restrito. Procure a administração.';
    } else if (isPastDue) {
      accent = SaaSColors.warning;
      icon = Icons.warning_amber_rounded;
      title = 'Assinatura com fatura pendente (${access.planName ?? 'Plano'})';
      subtitle = 'Regularize a assinatura para evitar a suspensão automática dos módulos.';
    } else {
      accent = SaaSColors.primary;
      icon = Icons.hourglass_top_rounded;
      title = 'Período de avaliação (${access.planName ?? 'Plano'})';
      subtitle = 'Aproveite os recursos contratados ou escolha um ciclo definitivo.';
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, color: accent, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.78),
                  ),
                ),
              ],
            ),
          ),
          if (onManagePlan != null) ...[
            const SizedBox(width: 10),
            FilledButton.icon(
              onPressed: onManagePlan,
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
              ),
              icon: const Icon(Icons.workspace_premium_outlined, size: 16),
              label: const Text('Gerenciar Plano'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Standardized Fail-Closed placeholder displayed when a feature/tab is not
/// included in the active plan or the subscription is suspended.
class FeatureLockedPlaceholder extends StatelessWidget {
  const FeatureLockedPlaceholder({
    super.key,
    required this.featureLabel,
    this.planName,
    this.isSuspended = false,
    this.onManagePlan,
  });

  final String featureLabel;
  final String? planName;
  final bool isSuspended;
  final VoidCallback? onManagePlan;

  @override
  Widget build(BuildContext context) {
    final color = isSuspended ? SaaSColors.error : SaaSColors.warning;
    return Center(
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: SaaSGlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: color.withValues(alpha: 0.14),
                  child: Icon(Icons.lock_outline_rounded, color: color, size: 24),
                ),
                const SizedBox(height: 10),
                Text(
                  isSuspended
                      ? '$featureLabel bloqueado por assinatura inativa'
                      : '$featureLabel não incluído no plano atual',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isSuspended
                      ? 'A assinatura do condomínio está suspensa ou cancelada.'
                      : 'O plano ${planName ?? 'atual'} não habilita este módulo operacional.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.72),
                  ),
                ),
                if (onManagePlan != null) ...[
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: onManagePlan,
                    icon: const Icon(Icons.upgrade_rounded, size: 17),
                    label: const Text('Atualizar Plano do Condomínio'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
