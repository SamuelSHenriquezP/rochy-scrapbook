import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/bento_node.dart';
import '../../providers/bento_canvas_provider.dart';
import '../../theme/rochy_theme.dart';
import 'bento_card_shell.dart';

/// Módulo tipo nube de píldoras para sus manías, gestos y hábitos diarios.
class HabitChipsCardWidget extends ConsumerWidget {
  const HabitChipsCardWidget({
    super.key,
    required this.node,
    required this.payload,
    required this.theme,
    required this.relationHighlight,
    this.showPaperGrain = true,
  });

  final BentoNode node;
  final HabitChipsPayload payload;
  final RochyThemeData theme;
  final BentoRelationHighlight relationHighlight;
  final bool showPaperGrain;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      onLongPress: () =>
          ref.read(bentoCanvasProvider.notifier).toggleNodeFocus(node.id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            payload.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: RochyTypography.resolveCardTitle(
              node.fontStyle,
              primaryInk,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: payload.habits.map((habit) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: primaryInk.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: primaryInk.withValues(alpha: 0.14),
                      ),
                    ),
                    child: Text(
                      habit,
                      style: RochyTypography.sansBody(
                        primaryInk,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          if (payload.footnote.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              payload.footnote,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: RochyTypography.metadata(secondaryInk, fontSize: 10),
            ),
          ],
        ],
      ),
    );
  }
}
