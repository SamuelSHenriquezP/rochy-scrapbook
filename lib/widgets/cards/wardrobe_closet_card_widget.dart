import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/bento_node.dart';
import '../../providers/bento_canvas_provider.dart';
import '../../theme/rochy_theme.dart';
import '../editorial_image.dart';
import 'bento_card_shell.dart';

/// Módulo tipo clóset editorial con tallas automáticas por tipo de prenda.
///
/// - En tamaños compactos (`1x1`, `1x2`): muestra un mazo de Polaroids
///   deslizable horizontalmente (`PageView`) con los datos escritos a mano.
/// - En tamaños medianos/grandes (`2x1`, `2x2`, `1x3`, `2x3`, etc.): muestra
///   una barra de clóset con ganchos y Polaroids colgadas como ropa real.
class WardrobeClosetCardWidget extends ConsumerStatefulWidget {
  const WardrobeClosetCardWidget({
    super.key,
    required this.node,
    required this.payload,
    required this.theme,
    required this.relationHighlight,
    this.showPaperGrain = true,
  });

  final BentoNode node;
  final WardrobeClosetPayload payload;
  final RochyThemeData theme;
  final BentoRelationHighlight relationHighlight;
  final bool showPaperGrain;

  @override
  ConsumerState<WardrobeClosetCardWidget> createState() =>
      _WardrobeClosetCardWidgetState();
}

class _WardrobeClosetCardWidgetState
    extends ConsumerState<WardrobeClosetCardWidget> {
  final PageController _deckController = PageController();
  int _deckIndex = 0;

  @override
  void dispose() {
    _deckController.dispose();
    super.dispose();
  }

  String _categoryLabel(String cat) => switch (cat) {
        'likes' => 'Le gusta',
        'gift' => 'Regalo',
        _ => 'Lo usa',
      };

  Color _categoryColor(String cat) => switch (cat) {
        'likes' => widget.theme.terracotta,
        'gift' => widget.theme.brandAccent,
        _ => widget.theme.sage,
      };

  IconData _garmentIcon(String garmentType) => switch (garmentType) {
        'bottom' => Icons.straighten_rounded,
        'shoes' => Icons.ice_skating_rounded,
        'accessory' => Icons.diamond_outlined,
        'outfit' => Icons.checkroom_rounded,
        _ => Icons.dry_cleaning_rounded,
      };

  void _openClosetModal() {
    HapticFeedback.lightImpact();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _WardrobeClosetModal(
        nodeId: widget.node.id,
        theme: widget.theme,
      ),
    );
  }

  Widget _buildPolaroidCard({
    required WardrobeItem item,
    required int index,
    required bool hanging,
    required bool compact,
    required bool hideGiftSecret,
    double tilt = 0.0,
  }) {
    final resolvedSize = widget.payload.resolveSizeFor(item);
    final catColor =
        hideGiftSecret ? widget.theme.terracotta : _categoryColor(item.category);
    final catLabel =
        hideGiftSecret ? 'Sorpresa' : _categoryLabel(item.category);
    final captionLine = hideGiftSecret
        ? '🎁 Sorpresa guardada'
        : <String>[
            item.name.trim(),
            if (resolvedSize.isNotEmpty) 'Talla $resolvedSize',
          ].where((s) => s.isNotEmpty).join(' · ');

    final Widget polaroid = Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFCF9F4),
        borderRadius: BorderRadius.circular(compact ? 8 : 10),
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.08),
          width: 0.7,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: hanging ? 10 : 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        compact ? 5 : 6,
        compact ? 5 : 6,
        compact ? 5 : 6,
        compact ? 6 : 8,
      ),
      child: Column(
        children: <Widget>[
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: !hideGiftSecret && item.imageUrl.trim().isNotEmpty
                      ? EditorialImage(
                          imageUrl: item.imageUrl,
                          fallbackScene: EditorialFallbackScene.cafeSunlit,
                        )
                      : Container(
                          color: catColor.withValues(alpha: 0.14),
                          child: Center(
                            child: Icon(
                              hideGiftSecret
                                  ? Icons.card_giftcard_rounded
                                  : _garmentIcon(item.garmentType),
                              size: compact ? 22 : 28,
                              color: catColor,
                            ),
                          ),
                        ),
                ),
                Positioned(
                  top: 4,
                  left: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: catColor.withValues(alpha: 0.90),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      catLabel,
                      style: RochyTypography.metadata(
                        Colors.white,
                        fontSize: compact ? 8.5 : 9.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                if (item.category == 'gift' && item.gifted)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Color(0xFF4F7A52),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        size: 10,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: compact ? 3 : 5),
          Text(
            captionLine.isNotEmpty ? captionLine : 'Prenda ${index + 1}',
            maxLines: compact ? 1 : 2,
            softWrap: true,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: RochyTypography.handwrittenTitle(
              const Color(0xFF3A2B24),
              fontSize: compact ? 12.5 : 14.0,
            ),
          ),
        ],
      ),
    );

    if (!hanging) return polaroid;

    return Transform.rotate(
      angle: tilt,
      alignment: Alignment.topCenter,
      child: Column(
        children: <Widget>[
          // Gancho colgador sobre la barra del clóset
          Icon(
            Icons.checkroom_rounded,
            size: compact ? 15 : 18,
            color: const Color(0xFF8C6B4F),
          ),
          Expanded(child: polaroid),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.theme.resolveNodeBackground(widget.node);
    final primaryInk = widget.theme.resolveNodePrimaryInk(widget.node);
    final secondaryInk = widget.theme.resolveNodeSecondaryInk(widget.node);
    final usesLight = widget.theme.nodeUsesLightInk(widget.node);
    final rodColor =
        usesLight ? const Color(0xFFD7BE9E) : const Color(0xFF8C6B4F);

    final items = widget.payload.items;
    final hasTitle = widget.payload.title.trim().isNotEmpty;
    final isRochyViewing = ref.watch(
      bentoCanvasProvider.select((s) {
        final owner = widget.node.authorId.isNotEmpty
            ? widget.node.authorId
            : (s.activeNotebookId == kSamuelNotebookId ? 'rochy' : 'samuel');
        return owner != s.viewerAuthor;
      }),
    );

    return BentoCardShell(
      theme: widget.theme,
      node: widget.node,
      backgroundColor: bgColor,
      relationHighlight: widget.relationHighlight,
      showPaperGrain: widget.showPaperGrain,
      padding: const EdgeInsets.fromLTRB(11, 10, 11, 10),
      onTap: _openClosetModal,
      onLongPress: () => ref
          .read(bentoCanvasProvider.notifier)
          .toggleNodeFocus(widget.node.id),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.hasBoundedHeight ? constraints.maxHeight : 180.0;
          final isClosetRack = w >= 205 || h >= 185;
          final isCompact = h < 125;

          final sizeSummary = widget.payload.effectiveSizeEntries
              .where((e) => e.size.trim().isNotEmpty)
              .take(3)
              .map((e) => e.size.trim())
              .join(' · ');

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (hasTitle || (sizeSummary.isNotEmpty && w >= 190))
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: <Widget>[
                      if (hasTitle)
                        Expanded(
                          child: Text(
                            widget.payload.title.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: RochyTypography.resolveCardTitle(
                              widget.node.fontStyle,
                              primaryInk,
                              fontSize: (isCompact ? 13.5 : 15.5) *
                                  widget.node.titleScale,
                              fontWeight: widget.node.isTitleBold
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        )
                      else
                        const Spacer(),
                      if (sizeSummary.isNotEmpty && w >= 190)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: primaryInk.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            sizeSummary,
                            style: RochyTypography.metadata(
                              secondaryInk,
                              fontSize: 9.8,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              Expanded(
                child: items.isEmpty
                    ? Center(
                        child: Text(
                          'Toca Editar para colgar outfits y sus tallas',
                          textAlign: TextAlign.center,
                          style: RochyTypography.metadata(
                            secondaryInk.withValues(alpha: 0.72),
                            fontSize: 11.5,
                          ),
                        ),
                      )
                    : isClosetRack
                        ? _buildClosetRack(
                            items: items,
                            width: w,
                            height: h,
                            rodColor: rodColor,
                            isRochyViewing: isRochyViewing,
                          )
                        : _buildSwipeDeck(
                            items: items,
                            primaryInk: primaryInk,
                            compact: isCompact,
                            isRochyViewing: isRochyViewing,
                          ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSwipeDeck({
    required List<WardrobeItem> items,
    required Color primaryInk,
    required bool compact,
    required bool isRochyViewing,
  }) {
    final safeIdx = _deckIndex.clamp(0, math.max(0, items.length - 1));
    return Column(
      children: <Widget>[
        Expanded(
          child: PageView.builder(
            controller: _deckController,
            itemCount: items.length,
            onPageChanged: (idx) => setState(() => _deckIndex = idx),
            itemBuilder: (_, idx) {
              final it = items[idx];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                child: _buildPolaroidCard(
                  item: it,
                  index: idx,
                  hanging: false,
                  compact: compact,
                  hideGiftSecret:
                      isRochyViewing && it.category == 'gift' && !it.gifted,
                ),
              );
            },
          ),
        ),
        if (items.length > 1) ...<Widget>[
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List<Widget>.generate(math.min(items.length, 6), (i) {
              final active = i == safeIdx;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: active ? 12 : 5,
                height: 5,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: primaryInk.withValues(alpha: active ? 0.85 : 0.25),
                  borderRadius: BorderRadius.circular(999),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }

  Widget _buildClosetRack({
    required List<WardrobeItem> items,
    required double width,
    required double height,
    required Color rodColor,
    required bool isRochyViewing,
  }) {
    final twoTiers = height >= 265 && items.length >= 4;
    const tilts = <double>[-0.035, 0.03, -0.025, 0.035];

    Widget buildRodRow(List<WardrobeItem> rowItems, int startIndex) {
      final cardW = width >= 260 ? 108.0 : 94.0;
      return Stack(
        children: <Widget>[
          // Barra del clóset arriba
          Positioned(
            top: 4,
            left: 2,
            right: 2,
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                color: rodColor.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(top: 1, left: 4, right: 4),
            itemCount: rowItems.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, idx) {
              final it = rowItems[idx];
              return SizedBox(
                width: cardW,
                child: _buildPolaroidCard(
                  item: it,
                  index: startIndex + idx,
                  hanging: true,
                  compact: twoTiers || height < 145,
                  hideGiftSecret:
                      isRochyViewing && it.category == 'gift' && !it.gifted,
                  tilt: tilts[(startIndex + idx) % tilts.length],
                ),
              );
            },
          ),
        ],
      );
    }

    if (twoTiers) {
      final half = (items.length / 2).ceil();
      return Column(
        children: <Widget>[
          Expanded(child: buildRodRow(items.take(half).toList(), 0)),
          const SizedBox(height: 8),
          Expanded(child: buildRodRow(items.skip(half).toList(), half)),
        ],
      );
    }

    return buildRodRow(items, 0);
  }
}

class _WardrobeClosetModal extends ConsumerStatefulWidget {
  const _WardrobeClosetModal({
    required this.nodeId,
    required this.theme,
  });

  final String nodeId;
  final RochyThemeData theme;

  @override
  ConsumerState<_WardrobeClosetModal> createState() =>
      _WardrobeClosetModalState();
}

class _WardrobeClosetModalState extends ConsumerState<_WardrobeClosetModal> {
  String _filter = 'all';

  String _garmentLabel(String type) => switch (type) {
        'top' => 'Arriba',
        'bottom' => 'Abajo',
        'shoes' => 'Calzado',
        'accessory' => 'Accesorio',
        'outfit' => 'Conjunto',
        _ => type,
      };

  ({String label, Color bg, Color fg}) _categoryBadge(
    WardrobeItem item,
    RochyThemeData theme,
  ) {
    if (item.category == 'gift' && item.gifted) {
      return (
        label: 'Regalado ✓',
        bg: const Color(0xFF4F7A52),
        fg: Colors.white,
      );
    }
    return switch (item.category) {
      'uses' => (
          label: 'Lo usa',
          bg: const Color(0xFF3A2B24).withValues(alpha: 0.76),
          fg: Colors.white,
        ),
      'likes' => (
          label: 'Le gusta',
          bg: theme.brandAccent.withValues(alpha: 0.90),
          fg: Colors.white,
        ),
      'gift' => (
          label: 'Idea regalo',
          bg: const Color(0xFFB36A43).withValues(alpha: 0.92),
          fg: Colors.white,
        ),
      _ => (
          label: item.category,
          bg: const Color(0xFF3A2B24).withValues(alpha: 0.76),
          fg: Colors.white,
        ),
    };
  }

  void _selectFilter(String key) {
    if (_filter == key) return;
    HapticFeedback.selectionClick();
    setState(() => _filter = key);
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final nodes = ref.watch(bentoCanvasProvider).nodes;
    final idx = nodes.indexWhere((n) => n.id == widget.nodeId);
    if (idx < 0) return const SizedBox.shrink();
    final payload = nodes[idx].payload;
    if (payload is! WardrobeClosetPayload) return const SizedBox.shrink();

    final isRochyViewing = ref.watch(
      bentoCanvasProvider.select((s) {
        final targetNode = nodes[idx];
        final owner = targetNode.authorId.isNotEmpty
            ? targetNode.authorId
            : (s.activeNotebookId == kSamuelNotebookId ? 'rochy' : 'samuel');
        return owner != s.viewerAuthor;
      }),
    );
    final sizeEntries = <(String label, String val)>[
      for (final e in payload.effectiveSizeEntries)
        if (e.typeName.trim().isNotEmpty && e.size.trim().isNotEmpty)
          (e.typeName.trim(), e.size.trim()),
    ];

    final indexed = <(int originalIdx, WardrobeItem item)>[
      for (var i = 0; i < payload.items.length; i++)
        if (_filter == 'all' || payload.items[i].category == _filter)
          (i, payload.items[i]),
    ];

    int countFor(String key) => key == 'all'
        ? payload.items.length
        : payload.items.where((it) => it.category == key).length;

    final screenH = MediaQuery.sizeOf(context).height;
    return Container(
      constraints: BoxConstraints(maxHeight: screenH * 0.88),
      decoration: BoxDecoration(
        color: theme.canvasBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: theme.borderTint,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 14, 16, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Icon(
                            Icons.checkroom_rounded,
                            size: 13,
                            color: theme.brandAccent,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'CLÓSET & TALLAS',
                            style: RochyTypography.metadata(
                              theme.brandAccent,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ).copyWith(letterSpacing: 1.1),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        payload.title.trim().isNotEmpty
                            ? payload.title.trim()
                            : 'Su Clóset & Tallas',
                        style: RochyTypography.cardSerifTitle(
                          theme.inkPrimary,
                          fontSize: 23,
                        ),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: theme.ivorySurface,
                      shape: BoxShape.circle,
                      border: Border.all(color: theme.borderTint),
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: theme.inkPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (sizeEntries.isNotEmpty)
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 22),
                itemCount: sizeEntries.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final s = sizeEntries[i];
                  return Container(
                    padding: const EdgeInsets.fromLTRB(10, 4, 6, 4),
                    decoration: BoxDecoration(
                      color: theme.ivorySurface,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: theme.borderTint),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          s.$1,
                          style: RochyTypography.metadata(
                            theme.inkSecondary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.brandAccent.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            s.$2,
                            style: RochyTypography.metadata(
                              theme.brandAccent,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Row(
              children: <({String key, String label})>[
                (key: 'all', label: 'Todos'),
                (key: 'uses', label: 'Lo usa'),
                (key: 'likes', label: 'Le gustan'),
                (key: 'gift', label: 'Regalo'),
              ].map((tab) {
                final selected = _filter == tab.key;
                final count = countFor(tab.key);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => _selectFilter(tab.key),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color:
                            selected ? theme.brandAccent : theme.ivorySurface,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: selected
                              ? theme.brandAccent
                              : theme.borderTint,
                        ),
                        boxShadow: selected
                            ? <BoxShadow>[
                                BoxShadow(
                                  color: theme.brandAccent
                                      .withValues(alpha: 0.28),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : const <BoxShadow>[],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            tab.label,
                            style: RochyTypography.metadata(
                              selected ? Colors.white : theme.inkPrimary,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (count > 0) ...<Widget>[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: selected
                                    ? Colors.white.withValues(alpha: 0.22)
                                    : theme.borderTint.withValues(alpha: 0.55),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '$count',
                                style: RochyTypography.metadata(
                                  selected ? Colors.white : theme.inkSecondary,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          Flexible(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.96, end: 1.0).animate(anim),
                  child: child,
                ),
              ),
              child: indexed.isEmpty
                  ? Padding(
                      key: ValueKey<String>('empty_$_filter'),
                      padding: const EdgeInsets.fromLTRB(28, 36, 28, 44),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: theme.brandAccent.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.checkroom_rounded,
                              size: 26,
                              color: theme.brandAccent,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No hay prendas en esta categoría todavía.',
                            textAlign: TextAlign.center,
                            style: RochyTypography.sansBody(
                              theme.inkSecondary,
                              fontSize: 13.5,
                            ),
                          ),
                        ],
                      ),
                    )
                  : _PolaroidDeckCarousel(
                      key: ValueKey<String>(
                        'deck_${_filter}_${indexed.length}',
                      ),
                      itemCount: indexed.length,
                      theme: theme,
                      itemBuilder: (i) {
                        final origIdx = indexed[i].$1;
                        final item = indexed[i].$2;
                        final size = payload.resolveSizeFor(item);
                        return _buildPolaroidItem(
                          theme: theme,
                          item: item,
                          origIdx: origIdx,
                          size: size,
                          isRochyViewing: isRochyViewing,
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPolaroidItem({
    required RochyThemeData theme,
    required WardrobeItem item,
    required int origIdx,
    required String size,
    required bool isRochyViewing,
  }) {
    final hideGiftSecret =
        isRochyViewing && item.category == 'gift' && !item.gifted;
    final badge = _categoryBadge(item, theme);
    final garmentText = _garmentLabel(item.garmentType);
    final hasImage = !hideGiftSecret && item.imageUrl.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 10),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: <Widget>[
          Container(
            width: 244,
            padding: const EdgeInsets.fromLTRB(13, 15, 13, 15),
            decoration: BoxDecoration(
              color: const Color(0xFFFCF9F4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFE9DFD3),
                width: 1,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: const Color(0xFF2B1E17).withValues(alpha: 0.14),
                  blurRadius: 22,
                  offset: const Offset(0, 12),
                ),
                BoxShadow(
                  color: const Color(0xFF2B1E17).withValues(alpha: 0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: <Widget>[
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        if (hideGiftSecret)
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: <Color>[
                                  theme.terracotta.withValues(alpha: 0.16),
                                  const Color(0xFFF3E4DA),
                                ],
                              ),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Container(
                                    width: 64,
                                    height: 64,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.80),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: theme.terracotta
                                            .withValues(alpha: 0.28),
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.card_giftcard_rounded,
                                      size: 30,
                                      color: theme.terracotta,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    'Sorpresa sellada',
                                    style: RochyTypography.metadata(
                                      const Color(0xFF7B675C),
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else if (hasImage)
                          EditorialImage(
                            imageUrl: item.imageUrl,
                            fallbackScene: EditorialFallbackScene.cafeSunlit,
                          )
                        else
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: <Color>[
                                  theme.brandAccent.withValues(alpha: 0.12),
                                  const Color(0xFFF3E9DE),
                                ],
                              ),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.72),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: theme.brandAccent
                                            .withValues(alpha: 0.22),
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.checkroom_rounded,
                                      size: 30,
                                      color: theme.brandAccent,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    garmentText.isNotEmpty
                                        ? garmentText
                                        : 'Prenda',
                                    style: RochyTypography.metadata(
                                      const Color(0xFF7B675C),
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3.5,
                            ),
                            decoration: BoxDecoration(
                              color: badge.bg,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              badge.label,
                              style: RochyTypography.metadata(
                                badge.fg,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        if (!hideGiftSecret && size.isNotEmpty)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3.5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFCF9F4)
                                    .withValues(alpha: 0.92),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: theme.borderTint,
                                ),
                              ),
                              child: Text(
                                'Talla $size',
                                style: RochyTypography.metadata(
                                  const Color(0xFF3A2B24),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                if (hideGiftSecret) ...<Widget>[
                  Text(
                    '🎁 Sorpresa guardada',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: RochyTypography.handwrittenTitle(
                      const Color(0xFF3A2B24),
                      fontSize: 18.5,
                    ),
                  ),
                  Text(
                    'Se revelará cuando te la entregue',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: RochyTypography.metadata(
                      const Color(0xFF7B675C),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ] else ...<Widget>[
                  Text(
                    item.name.trim().isNotEmpty
                        ? item.name.trim()
                        : (garmentText.isNotEmpty ? garmentText : 'Prenda'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: RochyTypography.handwrittenTitle(
                      const Color(0xFF3A2B24),
                      fontSize: 18.5,
                    ),
                  ),
                  Text(
                    <String>[
                      garmentText,
                      if (size.isNotEmpty) 'Talla $size',
                    ].where((s) => s.isNotEmpty).join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: RochyTypography.metadata(
                      const Color(0xFF7B675C),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (item.note.trim().isNotEmpty) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(
                      item.note.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: RochyTypography.sansBody(
                        const Color(0xFF5D4C42),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                  if (item.category == 'gift') ...<Widget>[
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        ref
                            .read(bentoCanvasProvider.notifier)
                            .toggleWardrobeGifted(
                              widget.nodeId,
                              origIdx,
                            );
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: item.gifted
                              ? const Color(0xFF4F7A52)
                              : theme.brandAccent.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          item.gifted ? 'Ya se lo di ✓' : 'Marcar como regalado',
                          style: RochyTypography.metadata(
                            item.gifted ? Colors.white : theme.brandAccent,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
          // Cinta washi superior decorativa
          Positioned(
            top: -7,
            child: Transform.rotate(
              angle: origIdx.isEven ? -0.04 : 0.05,
              child: Container(
                width: 58,
                height: 16,
                decoration: BoxDecoration(
                  color: theme.brandAccent.withValues(alpha: 0.24),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.45),
                    width: 0.6,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PolaroidDeckCarousel extends StatefulWidget {
  const _PolaroidDeckCarousel({
    super.key,
    required this.itemCount,
    required this.theme,
    required this.itemBuilder,
  });

  final int itemCount;
  final RochyThemeData theme;
  final Widget Function(int index) itemBuilder;

  @override
  State<_PolaroidDeckCarousel> createState() => _PolaroidDeckCarouselState();
}

class _PolaroidDeckCarouselState extends State<_PolaroidDeckCarousel> {
  late final PageController _controller = PageController(viewportFraction: 0.72);
  int _activePage = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          height: 348,
          child: PageView.builder(
            controller: _controller,
            clipBehavior: Clip.none,
            itemCount: widget.itemCount,
            onPageChanged: (page) {
              HapticFeedback.selectionClick();
              setState(() => _activePage = page);
            },
            itemBuilder: (_, i) {
              return AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  double page = _activePage.toDouble();
                  if (_controller.hasClients &&
                      _controller.positions.length == 1 &&
                      _controller.position.hasContentDimensions) {
                    page = _controller.page ?? page;
                  }
                  final delta = page - i;
                  final dist = delta.abs();
                  final scale = (1.0 - dist * 0.13).clamp(0.84, 1.0);
                  final opacity = (1.0 - dist * 0.28).clamp(0.62, 1.0);
                  final baseTilt = i.isEven ? -0.016 : 0.016;
                  final rotY = (delta * 0.18).clamp(-0.35, 0.35);
                  final rotZ = (delta * 0.04).clamp(-0.07, 0.07) + baseTilt;

                  return Center(
                    child: Opacity(
                      opacity: opacity,
                      child: Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.0012)
                          ..rotateY(rotY)
                          ..rotateZ(rotZ),
                        child: Transform.scale(
                          scale: scale,
                          child: child,
                        ),
                      ),
                    ),
                  );
                },
                child: widget.itemBuilder(i),
              );
            },
          ),
        ),
        if (widget.itemCount > 1) ...<Widget>[
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List<Widget>.generate(
              math.min(widget.itemCount, 8),
              (i) {
                final safeActive = _activePage.clamp(0, widget.itemCount - 1);
                final active = i == safeActive;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  width: active ? 20 : 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: active
                        ? widget.theme.brandAccent
                        : widget.theme.inkSecondary.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(999),
                  ),
                );
              },
            ),
          ),
        ],
        const SizedBox(height: 18),
      ],
    );
  }
}
