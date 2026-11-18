import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/bento_node.dart';
import '../../providers/bento_canvas_provider.dart';
import '../../theme/rochy_theme.dart';
import 'bento_card_shell.dart';

/// Módulo editorial para su libro, película o serie favorita.
class BookMovieCardWidget extends ConsumerWidget {
  const BookMovieCardWidget({
    super.key,
    required this.node,
    required this.payload,
    required this.theme,
    required this.relationHighlight,
    this.showPaperGrain = true,
  });

  final BentoNode node;
  final BookMoviePayload payload;
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
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: primaryInk.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  payload.kind == 'movie'
                      ? Icons.local_movies_rounded
                      : Icons.menu_book_rounded,
                  size: 16,
                  color: primaryInk,
                ),
              ),
              const Spacer(),
              Row(
                children: List<Widget>.generate(
                  payload.rating.clamp(1, 5),
                  (_) => Icon(
                    Icons.star_rounded,
                    size: 13,
                    color: theme.usesLightInk(node.colorTheme)
                        ? const Color(0xFFF3C69F)
                        : theme.terracotta,
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
            style: RochyTypography.resolveCardTitle(
              node.fontStyle,
              primaryInk,
              fontSize: 16,
            ),
          ),
          if (payload.creator.isNotEmpty) ...<Widget>[
            const SizedBox(height: 2),
            Text(
              payload.creator,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: RochyTypography.metadata(secondaryInk, fontSize: 11),
            ),
          ],
          if (payload.personalNote.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              payload.personalNote,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: RochyTypography.sansBody(
                secondaryInk,
                fontSize: 11.5,
                height: 1.28,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
