import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/bento_node.dart';
import '../../providers/bento_canvas_provider.dart';
import '../../theme/rochy_theme.dart';
import 'bento_card_shell.dart';

/// Tarjeta sensorial de estado de ánimo / clima del día con medidor táctil
/// interactivo de batería o energía emocional (1..5).
class MoodPulseCardWidget extends ConsumerWidget {
  const MoodPulseCardWidget({
    super.key,
    required this.node,
    required this.payload,
    required this.theme,
    required this.relationHighlight,
    this.showPaperGrain = true,
  });

  final BentoNode node;
  final MoodPulsePayload payload;
  final RochyThemeData theme;
  final BentoRelationHighlight relationHighlight;
  final bool showPaperGrain;

  static ({IconData icon, String label}) resolveMood(
    String key, {
    bool aboutHim = false,
  }) {
    return switch (key) {
      'serene' => (
          icon: Icons.spa_rounded,
          label: aboutHim ? 'Sereno' : 'Serena',
        ),
      'nostalgic' => (
          icon: Icons.nights_stay_rounded,
          label: aboutHim ? 'Nostálgico' : 'Nostálgica',
        ),
      'rainy' => (icon: Icons.water_drop_rounded, label: 'Días grises'),
      'sparkling' => (icon: Icons.auto_awesome_rounded, label: 'Radiante'),
      'cozy' => (
          icon: Icons.local_cafe_rounded,
          label: aboutHim ? 'Acogedor' : 'Acogedora',
        ),
      _ => (
          icon: Icons.wb_sunny_rounded,
          label: aboutHim ? 'Soleado' : 'Soleada',
        ),
    };
  }

  void _openMoodDialog(
    BuildContext context,
    ({IconData icon, String label}) mood,
  ) {
    HapticFeedback.lightImpact();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.ivorySurface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: theme.borderTint),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.brandAccent.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(mood.icon, size: 20, color: theme.brandAccent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          mood.label,
                          style: RochyTypography.metadata(
                            theme.brandAccent,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (payload.dateLabel.isNotEmpty)
                          Text(
                            payload.dateLabel,
                            style: RochyTypography.metadata(
                              theme.inkSecondary,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                payload.title,
                style: RochyTypography.cardSerifTitle(
                  theme.inkPrimary,
                  fontSize: 20,
                ),
              ),
              if (payload.note.isNotEmpty) ...<Widget>[
                const SizedBox(height: 10),
                Text(
                  payload.note,
                  style: RochyTypography.sansBody(
                    theme.inkSecondary,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  Text(
                    'Energía:',
                    style: RochyTypography.metadata(
                      theme.inkSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  for (var i = 0; i < 5; i++)
                    Container(
                      width: 18,
                      height: 8,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: i < payload.energyLevel
                            ? theme.brandAccent
                            : theme.borderTint,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(
                    'Cerrar',
                    style: RochyTypography.sansTitle(
                      theme.brandAccent,
                      fontSize: 13,
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bgColor = theme.resolveNodeBackground(node);
    final primaryInk = theme.resolveNodePrimaryInk(node);
    final secondaryInk = theme.resolveNodeSecondaryInk(node);
    final aboutHim = ref.watch(
      bentoCanvasProvider.select((s) {
        if (s.activeNotebookId == kRochyNotebookId) return false;
        if (s.activeNotebookId == kSamuelNotebookId) return true;
        if (node.authorId.isNotEmpty) return node.authorId == 'rochy';
        return s.isTalkingAboutHim;
      }),
    );
    final mood = resolveMood(payload.moodKey, aboutHim: aboutHim);
    final energy = payload.energyLevel.clamp(1, 5);
    final accentBar =
        theme.nodeUsesLightInk(node) ? const Color(0xFFF3C69F) : theme.terracotta;

    return BentoCardShell(
      theme: theme,
      node: node,
      backgroundColor: bgColor,
      relationHighlight: relationHighlight,
      showPaperGrain: showPaperGrain,
      padding: const EdgeInsets.all(14),
      onTap: () => _openMoodDialog(context, mood),
      onLongPress: () =>
          ref.read(bentoCanvasProvider.notifier).toggleNodeFocus(node.id),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxHeight < 120;

          if (isCompact) {
            return Row(
              children: <Widget>[
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: primaryInk.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(mood.icon, size: 18, color: primaryInk),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        payload.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: RochyTypography.resolveCardTitle(
                          node.fontStyle,
                          primaryInk,
                          fontSize: 14 * node.titleScale,
                          fontWeight: node.isTitleBold
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        mood.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: RochyTypography.metadata(
                          secondaryInk,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                _EnergyTapBar(
                  energy: energy,
                  activeColor: accentBar,
                  inactiveColor: primaryInk.withValues(alpha: 0.18),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ref
                        .read(bentoCanvasProvider.notifier)
                        .cycleMoodEnergy(node.id);
                  },
                ),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: primaryInk.withValues(alpha: 0.11),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(mood.icon, size: 14, color: primaryInk),
                        const SizedBox(width: 5),
                        Text(
                          mood.label,
                          style: RochyTypography.metadata(
                            primaryInk,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (payload.dateLabel.isNotEmpty)
                    Flexible(
                      child: Text(
                        payload.dateLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: RochyTypography.metadata(
                          secondaryInk,
                          fontSize: 10.5,
                        ),
                      ),
                    ),
                ],
              ),
              const Spacer(),
              Text(
                payload.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: RochyTypography.toFlutterTextAlign(node.textAlign),
                style: RochyTypography.resolveCardTitle(
                  node.fontStyle,
                  primaryInk,
                  fontSize: 16 * node.titleScale,
                  fontWeight:
                      node.isTitleBold ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              if (payload.note.isNotEmpty) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  payload.note,
                  maxLines: constraints.maxHeight > 205 ? 4 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: RochyTypography.sansBody(
                    secondaryInk,
                    fontSize: 12,
                    height: 1.32,
                  ),
                ),
              ],
              const Spacer(),
              Row(
                children: <Widget>[
                  Text(
                    'Energía',
                    style: RochyTypography.metadata(
                      secondaryInk,
                      fontSize: 10.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _EnergyTapBar(
                      energy: energy,
                      activeColor: accentBar,
                      inactiveColor: primaryInk.withValues(alpha: 0.18),
                      expanded: true,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        ref
                            .read(bentoCanvasProvider.notifier)
                            .cycleMoodEnergy(node.id);
                      },
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EnergyTapBar extends StatelessWidget {
  const _EnergyTapBar({
    required this.energy,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
    this.expanded = false,
  });

  final int energy;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final bars = List<Widget>.generate(5, (i) {
      final filled = i < energy;
      final pill = AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 7,
        width: expanded ? null : 10,
        margin: EdgeInsets.only(right: i < 4 ? 3 : 0),
        decoration: BoxDecoration(
          color: filled ? activeColor : inactiveColor,
          borderRadius: BorderRadius.circular(999),
        ),
      );
      return expanded ? Expanded(child: pill) : pill;
    });

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
          children: bars,
        ),
      ),
    );
  }
}
