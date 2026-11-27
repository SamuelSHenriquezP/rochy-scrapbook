import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/bento_node.dart';
import '../../providers/bento_canvas_provider.dart';
import '../../theme/rochy_theme.dart';
import 'bento_card_shell.dart';

/// Tarjeta estilo boleto / cupón de promesa o cita juntos, con sello interactivo
/// de cumplimiento y enlace opcional directo al mapa real.
class PlanTicketCardWidget extends ConsumerWidget {
  const PlanTicketCardWidget({
    super.key,
    required this.node,
    required this.payload,
    required this.theme,
    required this.relationHighlight,
    this.showPaperGrain = true,
  });

  final BentoNode node;
  final PlanTicketPayload payload;
  final RochyThemeData theme;
  final BentoRelationHighlight relationHighlight;
  final bool showPaperGrain;

  void _openPlanSheet(BuildContext context, WidgetRef ref) {
    HapticFeedback.lightImpact();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 22),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: theme.ivorySurface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: theme.borderTint),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
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
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: (payload.isRedeemed ? theme.sage : theme.terracotta)
                        .withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    payload.isRedeemed
                        ? Icons.verified_rounded
                        : Icons.confirmation_number_rounded,
                    size: 18,
                    color: payload.isRedeemed ? theme.sage : theme.terracotta,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        payload.title,
                        style: RochyTypography.cardSerifTitle(
                          theme.inkPrimary,
                          fontSize: 18.5,
                        ),
                      ),
                      if (payload.whenLabel.isNotEmpty ||
                          payload.placeLabel.isNotEmpty)
                        Text(
                          <String>[
                            if (payload.whenLabel.isNotEmpty) payload.whenLabel,
                            if (payload.placeLabel.isNotEmpty)
                              payload.placeLabel,
                          ].join(' · '),
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
            if (payload.promiseNote.isNotEmpty) ...<Widget>[
              const SizedBox(height: 14),
              Text(
                payload.promiseNote,
                style: RochyTypography.sansBody(
                  theme.inkPrimary,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor:
                        payload.isRedeemed ? theme.sage : theme.brandAccent,
                    side: BorderSide(
                      color:
                          (payload.isRedeemed ? theme.sage : theme.brandAccent)
                              .withValues(alpha: 0.45),
                    ),
                    shape: const StadiumBorder(),
                  ),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    ref
                        .read(bentoCanvasProvider.notifier)
                        .togglePlanRedeemed(node.id);
                    Navigator.of(sheetContext).pop();
                  },
                  icon: Icon(
                    payload.isRedeemed
                        ? Icons.replay_rounded
                        : Icons.check_rounded,
                    size: 16,
                  ),
                  label: Text(
                    payload.isRedeemed ? 'Marcar pendiente' : 'Marcar cumplido',
                  ),
                ),
                const Spacer(),
                if (node.mapCoordinates != null)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.brandAccent,
                      foregroundColor: const Color(0xFFFAF7F2),
                      shape: const StadiumBorder(),
                    ),
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      ref
                          .read(bentoCanvasProvider.notifier)
                          .focusNodeOnMap(node.id);
                    },
                    icon: const Icon(Icons.location_on_rounded, size: 16),
                    label: const Text('Ver en Mapa'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bgColor = theme.resolveNodeBackground(node);
    final primaryInk = theme.resolveNodePrimaryInk(node);
    final secondaryInk = theme.resolveNodeSecondaryInk(node);
    final redeemed = payload.isRedeemed;
    final stampColor = redeemed
        ? (theme.nodeUsesLightInk(node) ? const Color(0xFFCDE3C6) : theme.sage)
        : (theme.nodeUsesLightInk(node)
            ? const Color(0xFFF3C69F)
            : theme.terracotta);

    return BentoCardShell(
      theme: theme,
      node: node,
      backgroundColor: bgColor,
      relationHighlight: relationHighlight,
      showPaperGrain: showPaperGrain,
      padding: const EdgeInsets.all(14),
      onTap: () => _openPlanSheet(context, ref),
      onLongPress: () =>
          ref.read(bentoCanvasProvider.notifier).toggleNodeFocus(node.id),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxHeight < 120;

          if (isCompact) {
            return Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        payload.title,
                        maxLines: 2,
                        softWrap: true,
                        overflow: TextOverflow.ellipsis,
                        style: RochyTypography.resolveCardTitle(
                          node.fontStyle,
                          primaryInk,
                          fontSize: 14.5 * node.titleScale,
                          fontWeight: node.isTitleBold
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ).copyWith(
                          decoration:
                              redeemed ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      if (payload.whenLabel.isNotEmpty ||
                          payload.placeLabel.isNotEmpty)
                        Text(
                          <String>[
                            if (payload.whenLabel.isNotEmpty) payload.whenLabel,
                            if (payload.placeLabel.isNotEmpty)
                              payload.placeLabel,
                          ].join(' · '),
                          maxLines: 2,
                          softWrap: true,
                          overflow: TextOverflow.ellipsis,
                          style: RochyTypography.metadata(
                            secondaryInk,
                            fontSize: 10.5,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _RedeemedPill(
                  redeemed: redeemed,
                  color: stampColor,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ref
                        .read(bentoCanvasProvider.notifier)
                        .togglePlanRedeemed(node.id);
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
                  Icon(
                    Icons.confirmation_number_rounded,
                    size: 16,
                    color: secondaryInk,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                      child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: _RedeemedPill(
                            redeemed: redeemed,
                            color: stampColor,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              ref
                                  .read(bentoCanvasProvider.notifier)
                                  .togglePlanRedeemed(node.id);
                            },
                          ))),
                ],
              ),
              const SizedBox(height: 8),
              CustomPaint(
                size: const Size(double.infinity, 2),
                painter: _TicketDashPainter(
                  color: primaryInk.withValues(alpha: 0.22),
                ),
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
                ).copyWith(
                  decoration: redeemed ? TextDecoration.lineThrough : null,
                ),
              ),
              if (payload.promiseNote.isNotEmpty) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  payload.promiseNote,
                  maxLines: constraints.maxHeight > 205 ? 3 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: RochyTypography.sansBody(
                    secondaryInk,
                    fontSize: 11.8,
                    height: 1.28,
                  ),
                ),
              ],
              const Spacer(),
              if (payload.whenLabel.isNotEmpty || payload.placeLabel.isNotEmpty)
                Row(
                  children: <Widget>[
                    if (payload.placeLabel.isNotEmpty) ...<Widget>[
                      Icon(
                        Icons.location_on_rounded,
                        size: 12,
                        color: secondaryInk,
                      ),
                      const SizedBox(width: 3),
                    ],
                    Expanded(
                      child: Text(
                        <String>[
                          if (payload.placeLabel.isNotEmpty) payload.placeLabel,
                          if (payload.whenLabel.isNotEmpty) payload.whenLabel,
                        ].join(' · '),
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
            ],
          );
        },
      ),
    );
  }
}

class _RedeemedPill extends StatelessWidget {
  const _RedeemedPill({
    required this.redeemed,
    required this.color,
    required this.onTap,
  });

  final bool redeemed;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: redeemed ? 0.22 : 0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.65)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              redeemed ? Icons.check_circle_rounded : Icons.schedule_rounded,
              size: 12,
              color: color,
            ),
            const SizedBox(width: 4),
            Text(
              redeemed ? 'Cumplido' : 'Pendiente',
              style: RochyTypography.metadata(
                color,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TicketDashPainter extends CustomPainter {
  const _TicketDashPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    const dash = 5.0;
    const gap = 4.0;
    for (var x = 0.0; x < size.width; x += dash + gap) {
      canvas.drawLine(
        Offset(x, size.height / 2),
        Offset((x + dash).clamp(0.0, size.width), size.height / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TicketDashPainter oldDelegate) =>
      oldDelegate.color != color;
}
