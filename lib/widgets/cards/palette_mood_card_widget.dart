import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/bento_node.dart';
import '../../providers/bento_canvas_provider.dart';
import '../../theme/rochy_theme.dart';
import 'bento_card_shell.dart';

/// Módulo sensorial con su paleta de colores favorita, aroma y palabras clave.
class PaletteMoodCardWidget extends ConsumerWidget {
  const PaletteMoodCardWidget({
    super.key,
    required this.node,
    required this.payload,
    required this.theme,
    required this.relationHighlight,
    this.showPaperGrain = true,
  });

  final BentoNode node;
  final PaletteMoodPayload payload;
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isTallVertical = constraints.maxHeight > 205;
          final isStrip = constraints.maxHeight < 118;

          if (isStrip) {
            return Row(
              children: <Widget>[
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
                          fontSize: 15 * node.titleScale,
                        ),
                      ),
                      if (payload.scentNote.isNotEmpty)
                        Text(
                          payload.scentNote,
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
                const SizedBox(width: 8),
                Row(
                  children: payload.swatchHexes.take(4).map((hex) {
                    return Container(
                      width: 18,
                      height: 36,
                      margin: const EdgeInsets.only(left: 4),
                      decoration: BoxDecoration(
                        color: Color(hex),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: primaryInk.withValues(alpha: 0.16),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                payload.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: RochyTypography.resolveCardTitle(
                  node.fontStyle,
                  primaryInk,
                  fontSize: 16.5 * node.titleScale,
                  fontWeight:
                      node.isTitleBold ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
              const SizedBox(height: 10),
              if (isTallVertical)
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: payload.swatchHexes.take(5).map((hex) {
                      return Expanded(
                        child: Container(
                          margin: const EdgeInsets.only(right: 5),
                          decoration: BoxDecoration(
                            color: Color(hex),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: primaryInk.withValues(alpha: 0.16),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                )
              else
                Row(
                  children: payload.swatchHexes.take(5).map((hex) {
                    return Expanded(
                      child: Container(
                        height: 28,
                        margin: const EdgeInsets.only(right: 5),
                        decoration: BoxDecoration(
                          color: Color(hex),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: primaryInk.withValues(alpha: 0.16),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              if (!isTallVertical) const Spacer() else const SizedBox(height: 10),
              if (payload.scentNote.isNotEmpty)
                Row(
                  children: <Widget>[
                    Icon(Icons.spa_rounded, size: 13, color: secondaryInk),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        payload.scentNote,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: RochyTypography.sansBody(
                          secondaryInk,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              if (payload.moodWords.isNotEmpty) ...<Widget>[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 5,
                  runSpacing: 4,
                  children: payload.moodWords.take(4).map((word) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: primaryInk.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        word,
                        style: RochyTypography.metadata(
                          primaryInk,
                          fontSize: 10.5,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
