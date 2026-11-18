import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/bento_node.dart';
import '../providers/bento_canvas_provider.dart';
import '../theme/rochy_theme.dart';
import '../widgets/editorial_image.dart';

/// Visor expansivo de la historia al pulsar un [PhotoHeroCardWidget].
///
/// Muestra la fotografía en alta resolución con transición Hero, la crónica íntima
/// y las tarjetas conectadas dentro del Memory Graph.
class StoryDetailView extends ConsumerWidget {
  const StoryDetailView({
    super.key,
    required this.nodeId,
  });

  final String nodeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canvas = ref.watch(bentoCanvasProvider);
    final theme = ref.watch(activeRochyThemeProvider);

    final node = canvas.nodes.firstWhere(
      (n) => n.id == nodeId,
      orElse: () => canvas.nodes.first,
    );
    final payload = node.payload;
    if (payload is! PhotoHeroPayload) {
      return const SizedBox.shrink();
    }

    final linkedNodes = canvas.nodes
        .where((candidate) => node.linkedNodeIds.contains(candidate.id))
        .toList();

    return Scaffold(
      backgroundColor: theme.canvasBackground,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: <Widget>[
          SliverAppBar(
            expandedHeight: 360,
            pinned: true,
            stretch: true,
            backgroundColor: theme.canvasBackground,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).pop();
                },
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFF281D18).withValues(alpha: 0.45),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.35),
                    ),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Color(0xFFFAF7F2),
                    size: 18,
                  ),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const <StretchMode>[
                StretchMode.zoomBackground,
                StretchMode.fadeTitle,
              ],
              background: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  Hero(
                    tag: 'hero_photo_${node.id}',
                    child: EditorialImage(
                      imageUrl: payload.imageUrl,
                      fallbackScene: EditorialFallbackScene.cafeSunlit,
                      alignment: const Alignment(0, -0.2),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const <double>[0.45, 1.0],
                        colors: <Color>[
                          Colors.transparent,
                          theme.canvasBackground,
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 4, 22, 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(
                        Icons.location_on_rounded,
                        size: 15,
                        color: theme.brandAccent,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        payload.locationLabel,
                        style: RochyTypography.metadata(
                          theme.brandAccent,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '·  ${payload.dateLabel}',
                        style: RochyTypography.metadata(
                          theme.inkSecondary,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    payload.title,
                    style: RochyTypography.cardSerifTitle(
                      theme.inkPrimary,
                      fontSize: 30,
                      fontWeight: FontWeight.w600,
                      height: 1.15,
                    ),
                  ),
                  if (payload.photographerNote.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      payload.photographerNote,
                      style: RochyTypography.editorialQuote(
                        theme.inkSecondary,
                        fontSize: 15,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: theme.ivorySurface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: theme.borderTint),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: const Color(0xFF2D1E16).withValues(alpha: 0.06),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Text(
                      payload.storyBody,
                      style: RochyTypography.sansBody(
                        theme.inkPrimary,
                        fontSize: 15,
                        height: 1.65,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: node.tags.map((tag) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: theme.sandSurface,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '#$tag',
                          style: RochyTypography.metadata(
                            theme.inkSecondary,
                            fontSize: 12,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  if (linkedNodes.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 28),
                    Text(
                      'Conectado en su cuaderno',
                      style: RochyTypography.cardSerifTitle(
                        theme.inkPrimary,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...linkedNodes.map((linked) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () {
                            HapticFeedback.selectionClick();
                            ref
                                .read(bentoCanvasProvider.notifier)
                                .toggleNodeFocus(linked.id);
                            Navigator.of(context).pop();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: theme.cardSurface(linked.colorTheme),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: theme.borderTint),
                            ),
                            child: Row(
                              children: <Widget>[
                                Icon(
                                  Icons.hub_rounded,
                                  size: 18,
                                  color: theme.cardPrimaryText(linked.colorTheme),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    linked.displayTitle,
                                    style: RochyTypography.sansTitle(
                                      theme.cardPrimaryText(linked.colorTheme),
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.north_east_rounded,
                                  size: 16,
                                  color:
                                      theme.cardSecondaryText(linked.colorTheme),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
