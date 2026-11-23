import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/bento_node.dart';
import '../../providers/bento_canvas_provider.dart';
import '../../theme/rochy_theme.dart';
import '../editorial_image.dart';
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

  IconData get _kindIcon => switch (payload.kind) {
        'movie' => Icons.local_movies_rounded,
        'series' => Icons.live_tv_rounded,
        _ => Icons.menu_book_rounded,
      };

  String get _kindLabel => switch (payload.kind) {
        'movie' => 'Película',
        'series' => 'Serie',
        _ => 'Libro',
      };

  void _openBookMovieDialog(BuildContext context) {
    HapticFeedback.lightImpact();
    final hasImage = payload.imageUrl.trim().isNotEmpty;
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
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: theme.brandAccent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            _kindIcon,
                            size: 14,
                            color: theme.brandAccent,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _kindLabel,
                            style: RochyTypography.metadata(
                              theme.brandAccent,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List<Widget>.generate(
                        5,
                        (i) => Icon(
                          i < payload.rating.clamp(1, 5)
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          size: 17,
                          color: theme.terracotta,
                        ),
                      ),
                    ),
                  ],
                ),
                if (hasImage) ...<Widget>[
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: SizedBox(
                      width: double.infinity,
                      height: 185,
                      child: EditorialImage(
                        imageUrl: payload.imageUrl,
                        fallbackScene: EditorialFallbackScene.cinemaReel,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  payload.title,
                  style: RochyTypography.cardSerifTitle(
                    theme.inkPrimary,
                    fontSize: 22,
                  ),
                ),
                if (payload.creator.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    payload.creator,
                    style: RochyTypography.metadata(
                      theme.inkSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
                if (payload.personalNote.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 14),
                  Text(
                    payload.personalNote,
                    style: RochyTypography.sansBody(
                      theme.inkPrimary,
                      fontSize: 14.5,
                      height: 1.55,
                    ),
                  ),
                ],
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
      ),
    );
  }

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
      onTap: () => _openBookMovieDialog(context),
      onLongPress: () =>
          ref.read(bentoCanvasProvider.notifier).toggleNodeFocus(node.id),
      child: LayoutBuilder(builder: (context, constraints) {
        final compact = constraints.maxHeight < 130;
        final isWide = constraints.maxWidth > constraints.maxHeight * 1.15;
        final hasImage = payload.imageUrl.trim().isNotEmpty;
        final starColor = theme.nodeUsesLightInk(node)
            ? const Color(0xFFF3C69F)
            : theme.terracotta;

        Widget buildHeaderRow() {
          return Row(
            children: <Widget>[
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 6 : 8,
                  vertical: compact ? 4 : 5,
                ),
                decoration: BoxDecoration(
                  color: primaryInk.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(_kindIcon, size: compact ? 13 : 14, color: primaryInk),
                    if (!compact) ...<Widget>[
                      const SizedBox(width: 4),
                      Text(
                        _kindLabel,
                        style: RochyTypography.metadata(
                          primaryInk,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List<Widget>.generate(
                      payload.rating.clamp(1, 5),
                      (_) => Icon(
                        Icons.star_rounded,
                        size: compact ? 12 : 13.5,
                        color: starColor,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        Widget buildCoverFrame({required double radius}) {
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: primaryInk.withValues(alpha: 0.12),
                width: 0.8,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.16),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: EditorialImage(
                imageUrl: payload.imageUrl,
                fallbackScene: EditorialFallbackScene.cinemaReel,
              ),
            ),
          );
        }

        Widget buildMetaBlock({bool showNote = true}) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                payload.title,
                maxLines: compact ? 1 : 2,
                softWrap: true,
                overflow: TextOverflow.ellipsis,
                style: RochyTypography.resolveCardTitle(
                  node.fontStyle,
                  primaryInk,
                  fontSize: (compact ? 14.5 : 16.5) * node.titleScale,
                  fontWeight:
                      node.isTitleBold ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              if (payload.creator.isNotEmpty &&
                  constraints.maxHeight >= 70) ...<Widget>[
                const SizedBox(height: 2),
                Text(
                  payload.creator,
                  maxLines: compact ? 1 : 2,
                  softWrap: true,
                  overflow: TextOverflow.ellipsis,
                  style: RochyTypography.metadata(secondaryInk, fontSize: 11),
                ),
              ],
              if (showNote && !compact && payload.personalNote.isNotEmpty) ...<Widget>[
                const SizedBox(height: 5),
                Text(
                  payload.personalNote,
                  maxLines: 2,
                  softWrap: true,
                  overflow: TextOverflow.ellipsis,
                  style: RochyTypography.sansBody(
                    secondaryInk,
                    fontSize: 11.5,
                    height: 1.28,
                  ),
                ),
              ],
            ],
          );
        }

        // 1) Formato ancho horizontal (2x1 / 2x2 apaisado) con portada a la izquierda
        if (isWide && hasImage) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              AspectRatio(
                aspectRatio: 0.72,
                child: buildCoverFrame(radius: 14),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    buildHeaderRow(),
                    const Spacer(),
                    buildMetaBlock(),
                  ],
                ),
              ),
            ],
          );
        }

        // 2) Formato compacto (1x1)
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              buildHeaderRow(),
              const Spacer(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  if (hasImage) ...<Widget>[
                    SizedBox(
                      width: 34,
                      height: 46,
                      child: buildCoverFrame(radius: 8),
                    ),
                    const SizedBox(width: 9),
                  ],
                  Expanded(child: buildMetaBlock(showNote: false)),
                ],
              ),
            ],
          );
        }

        // 3) Formato vertical / cuadrado editorial (1x2, 1x3, 2x2)
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            buildHeaderRow(),
            if (hasImage) ...<Widget>[
              const SizedBox(height: 10),
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 0.74,
                    child: buildCoverFrame(radius: 14),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ] else ...<Widget>[
              const Spacer(),
              Container(
                width: 28,
                height: 2,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: starColor.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
            buildMetaBlock(),
          ],
        );
      }),
    );
  }
}
