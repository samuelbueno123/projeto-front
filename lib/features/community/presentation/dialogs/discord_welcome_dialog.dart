import 'package:flutter/material.dart';
import '../../data/community_api.dart';

class DiscordWelcomeDialog extends StatelessWidget {
  const DiscordWelcomeDialog({
    super.key,
    required this.condominiumName,
    required this.membershipId,
    required this.api,
    required this.onExplored,
  });

  final String condominiumName;
  final num membershipId;
  final CommunityApi api;
  final VoidCallback onExplored;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 680),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Column(
            children: [
              // Discord-style top banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF5865F2), Color(0xFF4752C4)], // Discord blurple
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.celebration_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'BEM-VINDO AO CONDOMÍNIO',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              Text(
                                condominiumName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Seu espaço comunitário está pronto! Aqui está um tour pelos principais recursos disponíveis para você:',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              // Discord-style channels list
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _channelItem(
                      context,
                      icon: Icons.campaign_rounded,
                      channelName: 'comunicados-e-avisos',
                      color: const Color(0xFF7E22CE),
                      title: 'Mural de Notícias',
                      description: 'Fique por dentro de manutenções, avisos da administração e assembleias.',
                    ),
                    _channelItem(
                      context,
                      icon: Icons.event_available_rounded,
                      channelName: 'reservas-de-areas',
                      color: const Color(0xFFB45309),
                      title: 'Salão, Churrasqueira e Espaços',
                      description: 'Consulte horários disponíveis, veja fotos das áreas e solicite sua reserva.',
                    ),
                    _channelItem(
                      context,
                      icon: Icons.chat_bubble_rounded,
                      channelName: 'chat-com-portaria',
                      color: const Color(0xFF2563EB),
                      title: 'Portaria em Tempo Real',
                      description: 'Fale diretamente com a guarita pelo aplicativo e receba avisos imediatos.',
                    ),
                    _channelItem(
                      context,
                      icon: Icons.inventory_2_rounded,
                      channelName: 'encomendas-e-lockers',
                      color: const Color(0xFF0F766E),
                      title: 'Recebimento de Pacotes',
                      description: 'Notificação automática na chegada e código PIN para retirada nos armários inteligentes.',
                    ),
                    _channelItem(
                      context,
                      icon: Icons.receipt_long_rounded,
                      channelName: 'boletos-e-taxas',
                      color: const Color(0xFF15803D),
                      title: 'Cota Condominial',
                      description: 'Acesse seu boleto com linha digitável e pague com um toque sem complicação.',
                    ),
                    _channelItem(
                      context,
                      icon: Icons.pets_rounded,
                      channelName: 'pets-e-garagem',
                      color: const Color(0xFFDB2777),
                      title: 'Veículos e Animais',
                      description: 'Cadastre suas placas para agilizar a entrada na portaria e registre seus pets.',
                    ),
                    _channelItem(
                      context,
                      icon: Icons.photo_library_rounded,
                      channelName: 'galeria-do-condominio',
                      color: const Color(0xFF0284C7),
                      title: 'Fotos e Espaços',
                      description: 'Veja imagens de alta qualidade das instalações compartilhadas pelo síndico.',
                    ),
                  ],
                ),
              ),

              // Bottom action button
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  border: Border(top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1))),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF5865F2),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 2,
                    ),
                    onPressed: () async {
                      try {
                        await api.acknowledgeWelcome(membershipId);
                      } catch (_) {}
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                      onExplored();
                    },
                    icon: const Icon(Icons.rocket_launch_rounded, size: 20),
                    label: const Text(
                      'Começar a explorar meu condomínio!',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _channelItem(
    BuildContext context, {
    required IconData icon,
    required String channelName,
    required Color color,
    required String title,
    required String description,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '# $channelName',
                      style: TextStyle(
                        color: color,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    fontSize: 12.5,
                    height: 1.35,
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
