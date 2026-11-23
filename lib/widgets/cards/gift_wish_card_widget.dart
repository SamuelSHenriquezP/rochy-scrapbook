import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/bento_node.dart';
import '../../providers/bento_canvas_provider.dart';
import '../../theme/rochy_theme.dart';
import 'bento_card_shell.dart';

/// Módulo táctil para ideas de regalo, flores o planes soñados juntos.
class GiftWishCardWidget extends ConsumerWidget {
  const GiftWishCardWidget({
    super.key,
    required this.node,
    required this.payload,
    required this.theme,
    required this.relationHighlight,
    this.showPaperGrain = true,
  });

  final BentoNode node;
  final GiftWishPayload payload;
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
          if (payload.title.isNotEmpty) ...<Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.card_giftcard_rounded, size: 16, color: primaryInk),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    payload.title,
                    maxLines: 2,
                    softWrap: true,
                    overflow: TextOverflow.ellipsis,
                    style: RochyTypography.resolveCardTitle(
                      node.fontStyle,
                      primaryInk,
                      fontSize: 16 * node.titleScale,
                      fontWeight:
                          node.isTitleBold ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          Expanded(
            child: ListView(
              primary: false,
              padding: EdgeInsets.zero,
              children: payload.items.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ref
                        .read(bentoCanvasProvider.notifier)
                        .toggleGiftWishItem(
                          node.id,
                          item.id,
                          index: index,
                        );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: <Widget>[
                        Icon(
                          item.isHighlighted
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          size: 15,
                          color: item.isHighlighted
                              ? (theme.nodeUsesLightInk(node)
                                  ? const Color(0xFFF3C69F)
                                  : theme.terracotta)
                              : secondaryInk,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item.text,
                            maxLines: 2,
                            softWrap: true,
                            overflow: TextOverflow.ellipsis,
                            style: RochyTypography.sansBody(
                              item.isHighlighted ? secondaryInk : primaryInk,
                              fontSize: 12.2,
                            ).copyWith(
                              decoration: item.isHighlighted
                                  ? TextDecoration.lineThrough
                                  : null,
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
        ],
      ),
    );
  }
}
