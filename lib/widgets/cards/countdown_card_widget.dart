import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/bento_node.dart';
import '../../providers/bento_canvas_provider.dart';
import '../../theme/rochy_theme.dart';
import 'bento_card_shell.dart';

/// Módulo de fecha especial con cálculo automático de días transcurridos o restantes.
class CountdownCardWidget extends ConsumerWidget {
  const CountdownCardWidget({
    super.key,
    required this.node,
    required this.payload,
    required this.theme,
    required this.relationHighlight,
    this.showPaperGrain = true,
  });

  final BentoNode node;
  final CountdownPayload payload;
  final RochyThemeData theme;
  final BentoRelationHighlight relationHighlight;
  final bool showPaperGrain;

  static const _months = <String>[
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(
      payload.targetDate.year,
      payload.targetDate.month,
      payload.targetDate.day,
    );

    final diffDays = payload.countMode == 'until'
        ? target.difference(today).inDays.clamp(0, 99999)
        : today.difference(target).inDays.abs();

    final dateFormatted =
        '${target.day} ${_months[(target.month - 1).clamp(0, 11)]} ${target.year}';

    final bgColor = theme.resolveNodeBackground(node);
    final primaryInk = theme.resolveNodePrimaryInk(node);
    final secondaryInk = theme.resolveNodeSecondaryInk(node);

    return BentoCardShell(
      theme: theme,
      node: node,
      backgroundColor: bgColor,
      relationHighlight: relationHighlight,
      showPaperGrain: showPaperGrain,
      padding: const EdgeInsets.all(15),
      onTap: () {
        HapticFeedback.lightImpact();
        ref.read(bentoCanvasProvider.notifier).toggleNodeFocus(node.id);
      },
      onLongPress: () =>
          ref.read(bentoCanvasProvider.notifier).toggleNodeFocus(node.id),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompactStrip = constraints.maxHeight < 118;
          if (isCompactStrip) {
            return Row(
              children: <Widget>[
                SizedBox(
                  width: constraints.maxWidth * 0.42,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '$diffDays d',
                      style: RochyTypography.cardSerifTitle(
                        primaryInk,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
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
                        ),
                      ),
                      Text(
                        dateFormatted,
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
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    payload.countMode == 'until'
                        ? Icons.hourglass_top_rounded
                        : Icons.calendar_today_rounded,
                    size: 14,
                    color: secondaryInk,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      dateFormatted,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          RochyTypography.metadata(secondaryInk, fontSize: 11),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  '$diffDays días',
                  maxLines: 1,
                  style: RochyTypography.cardSerifTitle(
                    primaryInk,
                    fontSize: constraints.maxHeight > 210 ? 34 : 28,
                    fontWeight: FontWeight.w700,
                    height: 1.05,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                payload.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: RochyTypography.resolveCardTitle(
                  node.fontStyle,
                  primaryInk,
                  fontSize: 14.5 * node.titleScale,
                  fontWeight:
                      node.isTitleBold ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              if (payload.subtitle.isNotEmpty) ...<Widget>[
                const SizedBox(height: 2),
                Text(
                  payload.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: RochyTypography.metadata(secondaryInk, fontSize: 11),
                ),
              ],
              const Spacer(),
            ],
          );
        },
      ),
    );
  }
}
