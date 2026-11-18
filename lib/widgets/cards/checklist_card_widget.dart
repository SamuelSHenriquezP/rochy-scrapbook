import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/bento_node.dart';
import '../../providers/bento_canvas_provider.dart';
import '../../theme/rochy_theme.dart';
import 'bento_card_shell.dart';

/// Tarjeta editorial tipo libreta de apuntes ("Detalles que amo") con
/// tipografía manuscrita y viñetas interactivas destacables.
class CheckListCardWidget extends ConsumerWidget {
  const CheckListCardWidget({
    super.key,
    required this.node,
    required this.payload,
    required this.theme,
    required this.relationHighlight,
    this.showPaperGrain = true,
  });

  final BentoNode node;
  final CheckListPayload payload;
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
      padding: const EdgeInsets.fromLTRB(15, 14, 14, 13),
      onLongPress: () =>
          ref.read(bentoCanvasProvider.notifier).toggleNodeFocus(node.id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: switch (node.textAlign) {
                BentoTextAlign.center => Alignment.center,
                BentoTextAlign.right => Alignment.centerRight,
                BentoTextAlign.left => Alignment.centerLeft,
              },
              child: Text(
                payload.title,
                maxLines: 1,
                style: RochyTypography.resolveCardTitle(
                  node.fontStyle,
                  primaryInk,
                  fontSize: 18.5 * node.titleScale,
                  fontWeight:
                      node.isTitleBold ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView(
              primary: false,
              padding: EdgeInsets.zero,
              children: payload.items.map((item) {
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ref
                        .read(bentoCanvasProvider.notifier)
                        .toggleCheckListItem(node.id, item.id);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            width: item.isHighlighted ? 7 : 5,
                            height: item.isHighlighted ? 7 : 5,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: item.isHighlighted
                                  ? theme.terracotta
                                  : primaryInk.withValues(alpha: 0.72),
                            ),
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: RochyTypography.sansBody(
                              item.isHighlighted ? primaryInk : secondaryInk,
                              fontSize: 12.6,
                              fontWeight: item.isHighlighted
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              height: 1.32,
                            ),
                            child: Text(
                              item.text,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          if (payload.footerHint.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Row(
              children: <Widget>[
                Icon(
                  Icons.auto_awesome_rounded,
                  size: 11,
                  color: theme.brandAccent.withValues(alpha: 0.8),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    payload.footerHint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: RochyTypography.metadata(
                      secondaryInk.withValues(alpha: 0.78),
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
