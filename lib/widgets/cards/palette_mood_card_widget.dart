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
          final isTiny = constraints.maxHeight < 102;
          final isTallGrid = constraints.maxHeight > constraints.maxWidth * 1.12 &&
              payload.swatchHexes.length >= 4;
          final swatches = payload.swatchHexes.take(5).toList();

          Widget swatchBox(int hex, {double radius = 13}) {
            return Container(
              decoration: BoxDecoration(
                color: Color(hex),
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(
                  color: primaryInk.withValues(alpha: 0.14),
                  width: 0.9,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            );
          }

          Widget buildSwatchGrid() {
            if (swatches.isEmpty) return const SizedBox.shrink();
            if (isTallGrid) {
              final topRow = swatches.take(2).toList();
              final botRow = swatches.skip(2).take(3).toList();
              return Column(
                children: <Widget>[
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        for (var i = 0; i < topRow.length; i++) ...<Widget>[
                          if (i > 0) const SizedBox(width: 7),
                          Expanded(child: swatchBox(topRow[i], radius: 14)),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 7),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        for (var i = 0; i < botRow.length; i++) ...<Widget>[
                          if (i > 0) const SizedBox(width: 7),
                          Expanded(child: swatchBox(botRow[i], radius: 14)),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (var i = 0; i < swatches.length; i++) ...<Widget>[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: swatchBox(
                      swatches[i],
                      radius: isTiny ? 9 : 13,
                    ),
                  ),
                ],
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (payload.title.isNotEmpty) ...<Widget>[
                Text(
                  payload.title,
                  textAlign:
                      RochyTypography.toFlutterTextAlign(node.textAlign),
                  maxLines: isTiny ? 1 : 2,
                  softWrap: true,
                  overflow: TextOverflow.ellipsis,
                  style: RochyTypography.resolveCardTitle(
                    node.fontStyle,
                    primaryInk,
                    fontSize: (isTiny ? 14.5 : 16.5) * node.titleScale,
                    fontWeight:
                        node.isTitleBold ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                SizedBox(height: isTiny ? 7 : 10),
              ],
              Expanded(child: buildSwatchGrid()),
              if (!isTiny && payload.scentNote.isNotEmpty) ...<Widget>[
                const SizedBox(height: 9),
                Row(
                  children: <Widget>[
                    Icon(Icons.spa_rounded, size: 13, color: secondaryInk),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        payload.scentNote,
                        maxLines: 2,
                        softWrap: true,
                        overflow: TextOverflow.ellipsis,
                        style: RochyTypography.sansBody(
                          secondaryInk,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (!isTiny && payload.moodWords.isNotEmpty) ...<Widget>[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 5,
                  runSpacing: 4,
                  children: payload.moodWords.map((word) {
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
