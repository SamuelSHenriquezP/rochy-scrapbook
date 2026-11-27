import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'bento_interaction_lock.dart';
import 'bento_size_picker.dart';
import 'bento_resize_handle.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/bento_node.dart';
import '../providers/bento_canvas_provider.dart';
import '../theme/rochy_theme.dart';
import 'cards/keepsake_card_widget.dart';
import 'cards/about_her_card_widget.dart';
import 'cards/audio_memory_card_widget.dart';
import 'cards/bento_card_shell.dart';
import 'cards/book_movie_card_widget.dart';
import 'cards/checklist_card_widget.dart';
import 'cards/couple_question_card_widget.dart';
import 'cards/countdown_card_widget.dart';
import 'cards/craving_recipe_card_widget.dart';
import 'cards/flip_3d_card_widget.dart';
import 'cards/gift_wish_card_widget.dart';
import 'cards/habit_chips_card_widget.dart';
import 'cards/location_pin_card_widget.dart';
import 'cards/love_letter_card_widget.dart';
import 'cards/mood_pulse_card_widget.dart';
import 'cards/palette_mood_card_widget.dart';
import 'cards/photo_hero_card_widget.dart';
import 'cards/photo_strip_card_widget.dart';
import 'cards/plan_ticket_card_widget.dart';
import 'cards/polaroid_thread_card_widget.dart';
import 'cards/quote_card_widget.dart';
import 'cards/sketch_doodle_card_widget.dart';
import 'cards/video_memory_card_widget.dart';
import 'cards/wardrobe_closet_card_widget.dart';
import 'editors/node_editor_sheet.dart';

/// Constructor polimórfico compartido entre el lienzo principal y la vista
/// previa en vivo del editor de módulos.
Widget buildPolymorphicBentoCard({
  required BentoNode node,
  required RochyThemeData theme,
  required bool showPaperGrain,
  BentoRelationHighlight highlight = BentoRelationHighlight.normal,
}) {
  final card = switch (node.payload) {
    TravelPassportPayload() ||
    SavedChatPayload() ||
    VintageTicketPayload() =>
      KeepsakeCardWidget(
        node: node,
        theme: theme,
        relationHighlight: highlight,
        showPaperGrain: showPaperGrain,
      ),
    final PhotoHeroPayload payload => PhotoHeroCardWidget(
        node: node,
        payload: payload,
        theme: theme,
        relationHighlight: highlight,
        showPaperGrain: showPaperGrain,
      ),
    final VideoMemoryPayload payload => VideoMemoryCardWidget(
        node: node,
        payload: payload,
        theme: theme,
        relationHighlight: highlight,
        showPaperGrain: showPaperGrain,
      ),
    final FlipDetailPayload payload => Flip3DCardWidget(
        node: node,
        payload: payload,
        theme: theme,
        relationHighlight: highlight,
        showPaperGrain: showPaperGrain,
      ),
    final QuotePayload payload => QuoteCardWidget(
        node: node,
        payload: payload,
        theme: theme,
        relationHighlight: highlight,
        showPaperGrain: showPaperGrain,
      ),
    final AudioNotePayload payload => AudioMemoryCardWidget(
        node: node,
        payload: payload,
        theme: theme,
        relationHighlight: highlight,
        showPaperGrain: showPaperGrain,
      ),
    final CheckListPayload payload => CheckListCardWidget(
        node: node,
        payload: payload,
        theme: theme,
        relationHighlight: highlight,
        showPaperGrain: showPaperGrain,
      ),
    final LocationPinPayload payload => LocationPinCardWidget(
        node: node,
        payload: payload,
        theme: theme,
        relationHighlight: highlight,
        showPaperGrain: showPaperGrain,
      ),
    final CountdownPayload payload => CountdownCardWidget(
        node: node,
        payload: payload,
        theme: theme,
        relationHighlight: highlight,
        showPaperGrain: showPaperGrain,
      ),
    final PaletteMoodPayload payload => PaletteMoodCardWidget(
        node: node,
        payload: payload,
        theme: theme,
        relationHighlight: highlight,
        showPaperGrain: showPaperGrain,
      ),
    final BookMoviePayload payload => BookMovieCardWidget(
        node: node,
        payload: payload,
        theme: theme,
        relationHighlight: highlight,
        showPaperGrain: showPaperGrain,
      ),
    final GiftWishPayload payload => GiftWishCardWidget(
        node: node,
        payload: payload,
        theme: theme,
        relationHighlight: highlight,
        showPaperGrain: showPaperGrain,
      ),
    final LoveLetterPayload payload => LoveLetterCardWidget(
        node: node,
        payload: payload,
        theme: theme,
        relationHighlight: highlight,
        showPaperGrain: showPaperGrain,
      ),
    final HabitChipsPayload payload => HabitChipsCardWidget(
        node: node,
        payload: payload,
        theme: theme,
        relationHighlight: highlight,
        showPaperGrain: showPaperGrain,
      ),
    final PhotoStripPayload payload => PhotoStripCardWidget(
        node: node,
        payload: payload,
        theme: theme,
        relationHighlight: highlight,
        showPaperGrain: showPaperGrain,
      ),
    final MoodPulsePayload payload => MoodPulseCardWidget(
        node: node,
        payload: payload,
        theme: theme,
        relationHighlight: highlight,
        showPaperGrain: showPaperGrain,
      ),
    final CravingRecipePayload payload => CravingRecipeCardWidget(
        node: node,
        payload: payload,
        theme: theme,
        relationHighlight: highlight,
        showPaperGrain: showPaperGrain,
      ),
    final PlanTicketPayload payload => PlanTicketCardWidget(
        node: node,
        payload: payload,
        theme: theme,
        relationHighlight: highlight,
        showPaperGrain: showPaperGrain,
      ),
    final SketchDoodlePayload payload => SketchDoodleCardWidget(
        node: node,
        payload: payload,
        theme: theme,
        relationHighlight: highlight,
        showPaperGrain: showPaperGrain,
      ),
    final PolaroidThreadPayload payload => PolaroidThreadCardWidget(
        node: node,
        payload: payload,
        theme: theme,
        relationHighlight: highlight,
        showPaperGrain: showPaperGrain,
      ),
    final AboutHerPayload payload => AboutHerCardWidget(
        node: node,
        payload: payload,
        theme: theme,
        relationHighlight: highlight,
        showPaperGrain: showPaperGrain,
      ),
    final WardrobeClosetPayload payload => WardrobeClosetCardWidget(
        node: node,
        payload: payload,
        theme: theme,
        relationHighlight: highlight,
        showPaperGrain: showPaperGrain,
      ),
    final CoupleQuestionPayload payload => CoupleQuestionCardWidget(
        node: node,
        payload: payload,
        theme: theme,
        relationHighlight: highlight,
        showPaperGrain: showPaperGrain,
      ),
  };
  return LayoutBuilder(builder: (context, constraints) {
    const compactTypes = {
      BentoNodeType.flipDetail,
      BentoNodeType.coupleQuestion,
      BentoNodeType.moodPulse,
      BentoNodeType.photoStrip,
      BentoNodeType.planTicket,
      BentoNodeType.polaroidThread,
      BentoNodeType.sketchDoodle
    };
    if (constraints.maxHeight >= 150 || !compactTypes.contains(node.type)) {
      return card;
    }
    return BentoCardShell(
      node: node,
      theme: theme,
      backgroundColor: theme.resolveNodeBackground(node),
      showPaperGrain: showPaperGrain,
      relationHighlight: highlight,
      padding: const EdgeInsets.all(12),
      onTap: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          showDragHandle: true,
          builder: (context) => SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.72,
              child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Consumer(builder: (context, ref, _) {
                    final current = ref
                            .watch(bentoCanvasProvider)
                            .nodes
                            .where((n) => n.id == node.id)
                            .firstOrNull ??
                        node;
                    return buildPolymorphicBentoCard(
                        node: current.copyWith(colSpan: 2, rowSpan: 4),
                        theme: theme,
                        showPaperGrain: showPaperGrain);
                  })))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
            child: Align(
                alignment: Alignment.centerLeft,
                child: Text(node.displayTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: theme.resolveNodePrimaryInk(node),
                        fontWeight: FontWeight.w600,
                        fontSize: 13)))),
        Text(node.type.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: theme.resolveNodeSecondaryInk(node), fontSize: 10)),
      ]),
    );
  });
}

/// Lienzo Bento animado de 2 columnas con reflow y colapso suave ([AnimatedPositioned]),
/// arrastre fluido tipo widget, marcos blancos de tamaño sin números y menú vertical y tamaños seleccionables.
class StaggeredBentoGrid extends ConsumerStatefulWidget {
  const StaggeredBentoGrid({
    super.key,
    required this.nodes,
  });

  final List<BentoNode> nodes;

  @override
  ConsumerState<StaggeredBentoGrid> createState() => _StaggeredBentoGridState();
}

class _StaggeredBentoGridState extends ConsumerState<StaggeredBentoGrid>
    with TickerProviderStateMixin {
  static const double _gap = 13.0;

  late final AnimationController _entranceController;
  late final AnimationController _threadPulseController;
  late final AnimationController _jiggleController;

  final _interactionLock = BentoInteractionLock();
  String? _resizingNodeId;
  String? _draggingNodeId;
  String? _holdPreviewNodeId;
  DateTime _lastReorderAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    )..forward();
    _threadPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    );
    _jiggleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _threadPulseController.dispose();
    _jiggleController.dispose();
    super.dispose();
  }

  void _syncAnimations(bool shouldJiggle, bool hasThreads) {
    if (shouldJiggle && !_jiggleController.isAnimating) {
      _jiggleController.repeat(reverse: true);
    } else if (!shouldJiggle && _jiggleController.isAnimating) {
      _jiggleController.stop();
      _jiggleController.value = 0.5;
    }

    if (hasThreads && !_threadPulseController.isAnimating) {
      _threadPulseController.repeat(reverse: true);
    } else if (!hasThreads && _threadPulseController.isAnimating) {
      _threadPulseController.stop();
    }
  }

  double _tileHeight(BentoNode node, double colWidth) {
    final extraRows = math.max(0, node.rowSpan - 5);
    final extraHeight = extraRows * (colWidth * 0.44);
    if (node.colSpan == 2) {
      return math.max(
          88.0,
          switch (node.rowSpan) {
            1 => colWidth * 0.56,
            2 => colWidth * 1.08,
            3 => colWidth * 1.54,
            4 => colWidth * 1.98,
            _ => colWidth * 2.42 + extraHeight,
          });
    }
    return switch (node.type) {
      BentoNodeType.locationPin => switch (node.rowSpan) {
          1 => colWidth * 0.52,
          2 => colWidth * 0.96,
          3 => colWidth * 1.40,
          4 => colWidth * 1.82,
          _ => colWidth * 2.24 + extraHeight,
        },
      BentoNodeType.checkList || BentoNodeType.giftWish => switch (
            node.rowSpan) {
          1 => colWidth * 0.66,
          2 => colWidth * 1.06,
          3 => colWidth * 1.48,
          4 => colWidth * 1.90,
          _ => colWidth * 2.32 + extraHeight,
        },
      BentoNodeType.quote => switch (node.rowSpan) {
          1 => colWidth * 0.62,
          2 => colWidth * 0.98,
          3 => colWidth * 1.40,
          4 => colWidth * 1.82,
          _ => colWidth * 2.24 + extraHeight,
        },
      BentoNodeType.audioNote => switch (node.rowSpan) {
          1 => colWidth * 0.64,
          2 => colWidth * 0.96,
          3 => colWidth * 1.40,
          4 => colWidth * 1.82,
          _ => colWidth * 2.24 + extraHeight,
        },
      _ => switch (node.rowSpan) {
          1 => colWidth * 0.60,
          2 => colWidth * 1.00,
          3 => colWidth * 1.48,
          4 => colWidth * 1.94,
          _ => colWidth * 2.40 + extraHeight,
        },
    };
  }

  ({Map<String, Rect> rects, double totalHeight}) _computeLayout(
    List<BentoNode> nodes,
    double totalWidth,
  ) {
    final colWidth = ((totalWidth - _gap) / 2.0).clamp(110.0, 600.0);
    final colY = <double>[0.0, 0.0];
    final rects = <String, Rect>{};

    for (final node in nodes) {
      final h = _tileHeight(node, colWidth);
      if (node.colSpan == 2) {
        final top = math.max(colY[0], colY[1]);
        rects[node.id] = Rect.fromLTWH(0.0, top, totalWidth, h);
        colY[0] = top + h + _gap;
        colY[1] = top + h + _gap;
      } else {
        final col = colY[0] <= colY[1] ? 0 : 1;
        final left = col == 0 ? 0.0 : (colWidth + _gap);
        final top = colY[col];
        rects[node.id] = Rect.fromLTWH(left, top, colWidth, h);
        colY[col] = top + h + _gap;
      }
    }

    final maxBottom = math.max(colY[0], colY[1]);
    final totalHeight =
        math.max(120.0, maxBottom > 0 ? maxBottom - _gap : 120.0);
    return (rects: rects, totalHeight: totalHeight);
  }

  BentoRelationHighlight _highlightFor(
    BentoNode node,
    String? selectedNodeId,
    Set<String> relatedIds,
    bool isConnectingMode,
  ) {
    if (!isConnectingMode && selectedNodeId == null) {
      return BentoRelationHighlight.normal;
    }
    if (node.id == selectedNodeId) return BentoRelationHighlight.selected;
    if (relatedIds.contains(node.id)) return BentoRelationHighlight.linked;
    return isConnectingMode
        ? BentoRelationHighlight.dimmed
        : BentoRelationHighlight.normal;
  }

  void _handleHoverReorder(String draggedId, String targetId) {
    if (draggedId == targetId) return;
    final now = DateTime.now();
    if (now.difference(_lastReorderAt).inMilliseconds < 180) return;
    _lastReorderAt = now;
    HapticFeedback.selectionClick();
    ref.read(bentoCanvasProvider.notifier).reorderNode(draggedId, targetId);
  }

  Future<void> _openPartnerReplyDialog(
    BuildContext context,
    BentoNode node,
    BentoCanvasState canvas,
    RochyThemeData theme,
  ) async {
    final ctrl = TextEditingController(text: node.partnerReplyText);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: theme.ivorySurface,
        title: Text(
          'Nota de ${canvas.viewerDisplayName}',
          style: RochyTypography.cardSerifTitle(theme.inkPrimary, fontSize: 19),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Deja una notita manuscrita o reacción debajo de "${node.displayTitle}":',
              style: RochyTypography.sansBody(
                theme.inkSecondary,
                fontSize: 12.5,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: ctrl,
              maxLines: 3,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Ej. Ese día fui demasiado feliz ♥',
                filled: true,
                fillColor: theme.canvasBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
        actions: <Widget>[
          if (node.partnerReplyText.trim().isNotEmpty)
            TextButton(
              onPressed: () {
                ref.read(bentoCanvasProvider.notifier).savePartnerReply(
                      node.id,
                      '',
                    );
                Navigator.of(dialogContext).pop();
              },
              child: Text(
                'Quitar',
                style: TextStyle(color: theme.terracotta),
              ),
            ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: theme.brandAccent,
              foregroundColor: const Color(0xFFFAF7F2),
            ),
            onPressed: () {
              ref.read(bentoCanvasProvider.notifier).savePartnerReply(
                    node.id,
                    ctrl.text,
                  );
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Guardar nota'),
          ),
        ],
      ),
    );
    ctrl.dispose();
  }

  void _deleteWithUndo(BuildContext context, BentoNode node) {
    final notifier = ref.read(bentoCanvasProvider.notifier);
    final removed = notifier.deleteNode(node.id);
    if (removed == null) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.clearSnackBars();
    messenger?.showSnackBar(
      SnackBar(
        content: Text('Eliminado: ${removed.node.displayTitle}'),
        action: SnackBarAction(
          label: 'Deshacer',
          onPressed: () {
            notifier.restoreDeletedNode(removed.node, removed.index);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canvas = ref.watch(bentoCanvasProvider);
    final theme = ref.watch(activeRochyThemeProvider);
    final selectedId = canvas.selectedNodeId;
    final activeWidgetId = canvas.activeWidgetId;
    final hasValidActiveWidget = activeWidgetId != null &&
        widget.nodes.any((n) => n.id == activeWidgetId);

    // Los hilos de conexión (y el halo de nodos vinculados) solo aparecen al
    // pulsar "Conectar" o "Iluminar conexiones"; nunca al mantener presionada
    // una tarjeta para editar, mover o cambiar su tamaño.
    final showConnections = canvas.isConnectingMode ||
        (selectedId != null && activeWidgetId == null);
    final relatedIds =
        showConnections ? canvas.relatedNodeIds : const <String>{};

    _syncAnimations(
      canvas.isEditMode || hasValidActiveWidget,
      showConnections && selectedId != null && relatedIds.isNotEmpty,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final layout = _computeLayout(widget.nodes, totalWidth);

        final originCenter = showConnections && selectedId != null
            ? layout.rects[selectedId]?.center
            : null;
        final linkedCenters = <Offset>[
          for (final id in relatedIds)
            if (layout.rects[id] != null) layout.rects[id]!.center,
        ];

        final effectiveMenuNodeId =
            (_draggingNodeId != null || _resizingNodeId != null)
                ? null
                : (_holdPreviewNodeId ?? activeWidgetId);

        BentoNode? menuNode;
        if (effectiveMenuNodeId != null) {
          for (final n in widget.nodes) {
            if (n.id == effectiveMenuNodeId) {
              menuNode = n;
              break;
            }
          }
        }
        final menuCardRect = effectiveMenuNodeId != null
            ? layout.rects[effectiveMenuNodeId]
            : null;
        final canvasHeight = math.max(
          layout.totalHeight,
          menuCardRect != null ? menuCardRect.top + 252.0 : 0.0,
        );

        return AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          height: canvasHeight,
          width: totalWidth,
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              for (var i = 0; i < widget.nodes.length; i++)
                () {
                  final node = widget.nodes[i];
                  final rect = layout.rects[node.id]!;
                  final isDraggingThis = _draggingNodeId == node.id;
                  final isLockedSurprise =
                      canvas.isHiddenSurpriseForViewer(node);
                  final authorLabel = canvas.authorLabelFor(node.authorId);
                  final hasPartnerReply = !isLockedSurprise &&
                      node.partnerReplyText.trim().isNotEmpty;
                  final replyAuthorName =
                      canvas.authorLabelFor(node.partnerReplyAuthor);

                  Widget cardVisual = isLockedSurprise
                      ? _LockedSurpriseCard(
                          node: node,
                          authorLabel: authorLabel.isNotEmpty
                              ? authorLabel
                              : 'tu pareja',
                          theme: theme,
                          showPaperGrain: canvas.showPaperGrain,
                          highlight: _highlightFor(
                            node,
                            selectedId,
                            relatedIds,
                            canvas.isConnectingMode,
                          ),
                          onTap: () {
                            HapticFeedback.lightImpact();
                            final who = authorLabel.isNotEmpty
                                ? authorLabel
                                : 'tu pareja';
                            final days = node.daysUntilSurpriseUnlock;
                            final msg = days != null && days > 0
                                ? '⏳ Sorpresa de $who · Se abre sola en ${days == 1 ? '1 día' : '$days días'}'
                                : '🎁 Sorpresa sellada de $who · Se revelará cuando te la entregue';
                            final messenger =
                                ScaffoldMessenger.maybeOf(context);
                            messenger?.clearSnackBars();
                            messenger?.showSnackBar(
                              SnackBar(content: Text(msg)),
                            );
                          },
                        )
                      : buildPolymorphicBentoCard(
                          node: node,
                          theme: theme,
                          showPaperGrain: canvas.showPaperGrain,
                          highlight: _highlightFor(
                            node,
                            selectedId,
                            relatedIds,
                            canvas.isConnectingMode,
                          ),
                        );

                  if (hasPartnerReply) {
                    cardVisual = Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        cardVisual,
                        Positioned(
                          left: 8,
                          right: 8,
                          bottom: 8,
                          child: Align(
                            alignment: Alignment.bottomLeft,
                            child: _PartnerReplyPill(
                              authorName: replyAuthorName,
                              replyText: node.partnerReplyText.trim(),
                              theme: theme,
                              onTap: () => _openPartnerReplyDialog(
                                context,
                                node,
                                canvas,
                                theme,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }

                  return AnimatedPositioned(
                    key: ValueKey<String>('bento_pos_${node.id}'),
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    left: rect.left,
                    top: rect.top,
                    width: rect.width,
                    height: rect.height,
                    child: _StaggeredSpringEntrance(
                      controller: _entranceController,
                      index: i,
                      totalCount: widget.nodes.length,
                      child: _BentoWidgetSlot(
                        key: ValueKey('bento_slot_${node.id}'),
                        interactionLock: _interactionLock,
                        node: node,
                        isLockedSurprise: isLockedSurprise,
                        index: i,
                        rect: rect,
                        isEditMode: canvas.isEditMode,
                        isActiveWidget: (activeWidgetId == node.id ||
                                _holdPreviewNodeId == node.id) &&
                            _draggingNodeId != node.id,
                        isConnectingMode: canvas.isConnectingMode,
                        isDraggingAny: _draggingNodeId != null,
                        isDraggingThis: isDraggingThis,
                        selectedNodeId: selectedId,
                        jiggleController: _jiggleController,
                        theme: theme,
                        onResizeStarted: () =>
                            setState(() => _resizingNodeId = node.id),
                        onResizeEnded: () {
                          if (mounted && _resizingNodeId == node.id) {
                            setState(() => _resizingNodeId = null);
                          }
                        },
                        onHoldStarted: () {
                          setState(() {
                            _holdPreviewNodeId = node.id;
                          });
                        },
                        onMoveStarted: () {
                          // Limpiar el foco activo sin desmontar el Draggable (ver _immediateDragInFlight)
                          ref
                              .read(bentoCanvasProvider.notifier)
                              .clearNodeFocus();
                          setState(() {
                            _holdPreviewNodeId = null;
                            _draggingNodeId = node.id;
                          });
                        },
                        onDragEnded: () {
                          if (mounted) {
                            setState(() {
                              _holdPreviewNodeId = null;
                              _draggingNodeId = null;
                            });
                          }
                        },
                        onHoverTarget: (draggedId) =>
                            _handleHoverReorder(draggedId, node.id),
                        onDelete: () => _deleteWithUndo(context, node),
                        child: cardVisual,
                      ),
                    ),
                  );
                }(),

              // Hilos luminosos del Memory Graph cuando un nodo está enfocado
              if (originCenter != null && linkedCenters.isNotEmpty)
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _threadPulseController,
                      builder: (context, _) {
                        return CustomPaint(
                          painter: _MemoryGraphThreadsPainter(
                            origin: originCenter,
                            targets: linkedCenters,
                            color: theme.haloColor,
                            pulse: _threadPulseController.value,
                          ),
                        );
                      },
                    ),
                  ),
                ),

              // Lista contextual flotante que sale del lado libre sin chocar con la pantalla
              if (!canvas.isActiveNotebookReadOnly &&
                  menuNode != null &&
                  menuCardRect != null &&
                  _draggingNodeId == null)
                () {
                  final target = menuNode!;
                  final menuLocked = canvas.isHiddenSurpriseForViewer(target);
                  return _FloatingWidgetActionList(
                    cardRect: menuCardRect,
                    totalWidth: totalWidth,
                    canvasHeight: canvasHeight,
                    node: target,
                    authorLabel: canvas.authorLabelFor(target.authorId),
                    isLockedSurprise: menuLocked,
                    theme: theme,
                    onChooseSize: () => showBentoSizePicker(context, target.id),
                    onConnect: () => ref
                        .read(bentoCanvasProvider.notifier)
                        .startVisualConnection(target.id),
                    onFavorite: () {
                      ref
                          .read(bentoCanvasProvider.notifier)
                          .toggleNodeFavorite(target.id);
                      ref.read(bentoCanvasProvider.notifier).clearNodeFocus();
                    },
                    onPartnerReply: menuLocked
                        ? null
                        : () {
                            ref
                                .read(bentoCanvasProvider.notifier)
                                .clearNodeFocus();
                            _openPartnerReplyDialog(
                              context,
                              target,
                              canvas,
                              theme,
                            );
                          },
                    onToggleSurprise: menuLocked
                        ? null
                        : () {
                            ref
                                .read(bentoCanvasProvider.notifier)
                                .toggleNodeSurprise(target.id);
                            ref
                                .read(bentoCanvasProvider.notifier)
                                .clearNodeFocus();
                          },
                    onEdit: menuLocked
                        ? null
                        : () async {
                            ref
                                .read(bentoCanvasProvider.notifier)
                                .clearNodeFocus();
                            await showNodeEditorSheet(
                              context,
                              ref,
                              type: target.type,
                              existingNode: target,
                            );
                          },
                    onDelete: menuLocked
                        ? null
                        : () => _deleteWithUndo(context, target),
                  );
                }(),
            ],
          ),
        );
      },
    );
  }
}

/// Slot individual con arrastre fluido sin desmontar el Draggable, líneas blancas
/// de redimensionamiento y respuesta táctil inmediata.
class _BentoWidgetSlot extends ConsumerStatefulWidget {
  const _BentoWidgetSlot({
    super.key,
    required this.interactionLock,
    required this.onResizeStarted,
    required this.onResizeEnded,
    required this.node,
    this.isLockedSurprise = false,
    required this.index,
    required this.rect,
    required this.isEditMode,
    required this.isActiveWidget,
    required this.isConnectingMode,
    required this.isDraggingAny,
    required this.isDraggingThis,
    required this.selectedNodeId,
    required this.jiggleController,
    required this.theme,
    required this.onHoldStarted,
    required this.onMoveStarted,
    required this.onDragEnded,
    required this.onHoverTarget,
    required this.onDelete,
    required this.child,
  });

  final BentoInteractionLock interactionLock;
  final VoidCallback onResizeStarted;
  final VoidCallback onResizeEnded;
  final BentoNode node;
  final bool isLockedSurprise;
  final int index;
  final Rect rect;
  final bool isEditMode;
  final bool isActiveWidget;
  final bool isConnectingMode;
  final bool isDraggingAny;
  final bool isDraggingThis;
  final String? selectedNodeId;
  final AnimationController jiggleController;
  final RochyThemeData theme;
  final VoidCallback onHoldStarted;
  final VoidCallback onMoveStarted;
  final VoidCallback onDragEnded;
  final ValueChanged<String> onHoverTarget;
  final VoidCallback onDelete;
  final Widget child;

  @override
  ConsumerState<_BentoWidgetSlot> createState() => _BentoWidgetSlotState();
}

class _BentoWidgetSlotState extends ConsumerState<_BentoWidgetSlot> {
  final ValueNotifier<bool> _isMovingNotifier = ValueNotifier<bool>(false);
  bool _isResizing = false;
  int _resizeStartCol = 1;
  int _resizeStartRow = 1;
  Offset _dragStartGlobal = Offset.zero;

  @override
  void dispose() {
    _isMovingNotifier.dispose();
    super.dispose();
  }

  Widget _buildDraggableFeedback(BentoNode node) {
    return Material(
      key: ValueKey('drag_feedback_${node.id}'),
      color: Colors.transparent,
      child: Transform.scale(
        scale: 1.04,
        child: SizedBox(
          width: widget.rect.width,
          height: widget.rect.height,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(node.borderRadius),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }

  Widget _buildGhostPlaceholder(BentoNode node) {
    return Container(
      decoration: BoxDecoration(
        color: widget.theme.brandAccent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(node.borderRadius),
        border: Border.all(
          color: widget.theme.brandAccent.withValues(alpha: 0.40),
          width: 1.6,
        ),
      ),
    );
  }

  void _startResize() {
    setState(() => _isResizing = true);
    _resizeStartCol = widget.node.colSpan;
    _resizeStartRow = widget.node.rowSpan;
    widget.onResizeStarted();
    HapticFeedback.selectionClick();
  }

  void _updateResize(Offset displacement) {
    if (!_isResizing) return;
    final cols = (_resizeStartCol + (displacement.dx / 64).round()).clamp(1, 2);
    final rows =
        (_resizeStartRow + (displacement.dy / 56).round()).clamp(1, 20);
    final current = ref
        .read(bentoCanvasProvider)
        .nodes
        .where((n) => n.id == widget.node.id)
        .firstOrNull;
    if (current == null ||
        (current.colSpan == cols && current.rowSpan == rows)) {
      return;
    }
    HapticFeedback.selectionClick();
    ref.read(bentoCanvasProvider.notifier).resizeNode(
          current.id,
          colSpan: cols,
          rowSpan: rows,
        );
  }

  void _endResize() {
    if (!_isResizing) return;
    if (mounted) {
      setState(() => _isResizing = false);
    } else {
      _isResizing = false;
    }
    widget.onResizeEnded();
  }

  @override
  Widget build(BuildContext context) {
    final node = widget.node;

    // Modo de conexión visual desde la lista contextual.
    if (widget.isConnectingMode) {
      final isOrigin = widget.selectedNodeId == node.id;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          if (isOrigin) {
            ref.read(bentoCanvasProvider.notifier).stopVisualConnection();
          } else {
            ref.read(bentoCanvasProvider.notifier).toggleVisualLink(node.id);
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            IgnorePointer(child: widget.child),
            if (!isOrigin)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: widget.theme.ivorySurface.withValues(alpha: 0.94),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: widget.theme.brandAccent.withValues(alpha: 0.65),
                    ),
                  ),
                  child: Icon(
                    Icons.link_rounded,
                    size: 14,
                    color: widget.theme.brandAccent,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    if (ref.watch(bentoCanvasProvider).isActiveNotebookReadOnly) {
      return widget.child;
    }

    final showWidgetFrame =
        (widget.isEditMode || widget.isActiveWidget) && !widget.isDraggingThis;
    final jigglePhase = widget.index.isEven ? 1.0 : -1.0;

    // Contenido visual con temblor suave + líneas blancas de tamaño (sin números)
    Widget framedCard = widget.child;
    if (showWidgetFrame) {
      framedCard = AnimatedBuilder(
        animation: widget.jiggleController,
        builder: (context, childWidget) {
          final angle = _isResizing
              ? 0.0
              : (widget.jiggleController.value - 0.5) * 0.018 * jigglePhase;
          return Transform.rotate(angle: angle, child: childWidget);
        },
        child: Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: <Widget>[
            IgnorePointer(child: widget.child),
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (widget.isEditMode && !widget.isLockedSurprise) {
                    HapticFeedback.selectionClick();
                    showNodeEditorSheet(
                      context,
                      ref,
                      type: node.type,
                      existingNode: node,
                    );
                  } else {
                    ref.read(bentoCanvasProvider.notifier).clearNodeFocus();
                  }
                },
                child: CustomPaint(
                  painter: _WhiteWidgetResizePainter(
                    radius: node.borderRadius,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Keep the same recognizer and parent Stack for the entire gesture.
    // Removing a Draggable while its avatar is alive creates duplicate copies.
    final interactiveChild = Listener(
      onPointerDown: (event) {
        if (!_isMovingNotifier.value) _dragStartGlobal = event.position;
      },
      child: ExclusiveBentoDraggable<String>(
        key: ValueKey('drag_${node.id}'),
        interactionLock: widget.interactionLock,
        data: node.id,
        onDragStarted: () {
          HapticFeedback.mediumImpact();
          _isMovingNotifier.value = false;
          widget.onHoldStarted();
        },
        onDragUpdate: (details) {
          if (!_isMovingNotifier.value &&
              (details.globalPosition - _dragStartGlobal).distance > 18) {
            _isMovingNotifier.value = true;
            widget.onMoveStarted();
          }
        },
        onDragEnd: (_) {
          final moved = _isMovingNotifier.value;
          _isMovingNotifier.value = false;
          widget.onDragEnded();
          if (!moved) {
            ref.read(bentoCanvasProvider.notifier).activateWidget(node.id);
          }
        },
        feedback: ValueListenableBuilder<bool>(
          valueListenable: _isMovingNotifier,
          builder: (_, moving, __) =>
              moving ? _buildDraggableFeedback(node) : const SizedBox.shrink(),
        ),
        childWhenDragging: ValueListenableBuilder<bool>(
          valueListenable: _isMovingNotifier,
          builder: (_, moving, __) => moving
              ? _buildGhostPlaceholder(node)
              : IgnorePointer(child: framedCard),
        ),
        child: framedCard,
      ),
    );

    return DragTarget<String>(
      onWillAcceptWithDetails: (details) {
        if (details.data != node.id && widget.isDraggingAny) {
          widget.onHoverTarget(details.data);
          return true;
        }
        return details.data != node.id;
      },
      onAcceptWithDetails: (details) {
        if (widget.isDraggingAny) {
          widget.onHoverTarget(details.data);
        }
      },
      builder: (context, candidateData, rejectedData) {
        // Manijas de tamaño FUERA del Draggable y estrictamente dentro de la tarjeta
        // para que ni el scroll ni el arrastre roben el gesto al cambiar el tamaño.
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            interactiveChild,
            // Generous hit areas claim the pointer immediately and stay outside
            // the card Draggable. The corner owns the bottom-right overlap.
            if (showWidgetFrame && widget.rect.height > 80)
              Positioned(
                key: ValueKey('resize_width_${node.id}'),
                right: 0,
                top: 16,
                bottom: 64,
                width: 44,
                child: BentoResizeHandle(
                  interactionLock: widget.interactionLock,
                  onStart: _startResize,
                  onUpdate: (offset) => _updateResize(Offset(offset.dx, 0)),
                  onEnd: _endResize,
                  label: 'Arrastra el borde para cambiar el ancho',
                  cursor: SystemMouseCursors.resizeLeftRight,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    ref.read(bentoCanvasProvider.notifier).resizeNode(
                          node.id,
                          colSpan: node.colSpan == 1 ? 2 : 1,
                        );
                  },
                  builder: (_, __) => const SizedBox.expand(),
                ),
              ),
            if (showWidgetFrame)
              Positioned(
                key: ValueKey('resize_height_${node.id}'),
                left: node.colSpan == 2 ? 70 : 22,
                right: 64,
                bottom: 0,
                height: 44,
                child: BentoResizeHandle(
                  interactionLock: widget.interactionLock,
                  onStart: _startResize,
                  onUpdate: (offset) => _updateResize(Offset(0, offset.dy)),
                  onEnd: _endResize,
                  label: 'Arrastra el borde para cambiar la altura',
                  cursor: SystemMouseCursors.resizeUpDown,
                  builder: (_, __) => const SizedBox.expand(),
                ),
              ),
            if (showWidgetFrame)
              Positioned(
                key: ValueKey('resize_corner_${node.id}'),
                right: 0,
                bottom: 0,
                width: 64,
                height: math.min(64.0, widget.rect.height),
                child: BentoResizeHandle(
                  interactionLock: widget.interactionLock,
                  onStart: _startResize,
                  onUpdate: _updateResize,
                  onEnd: _endResize,
                  label:
                      'Cambiar tama?o: arrastra la esquina o toca para elegir',
                  cursor: SystemMouseCursors.resizeUpLeftDownRight,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    showBentoSizePicker(context, node.id);
                  },
                  builder: (_, grabbed) => Align(
                    alignment: Alignment.bottomRight,
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 90),
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: grabbed
                              ? widget.theme.brandAccent
                              : widget.theme.ivorySurface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 7,
                              offset: const Offset(0, 2),
                            )
                          ],
                        ),
                        child: Icon(Icons.open_in_full_rounded,
                            size: 18,
                            color: grabbed
                                ? Colors.white
                                : widget.theme.brandAccent),
                      ),
                    ),
                  ),
                ),
              ),
            if (widget.isEditMode && !widget.isLockedSurprise)
              Positioned(
                top: 6,
                left: 6,
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    widget.onDelete();
                  },
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: widget.theme.charcoal,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.remove_rounded,
                      size: 15,
                      color: Color(0xFFFAF7F2),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Dibuja un contorno fino limpio y una única curva blanca en la esquina
/// inferior derecha para indicar redimensionamiento directo sin líneas dobles.
class _WhiteWidgetResizePainter extends CustomPainter {
  const _WhiteWidgetResizePainter({required this.radius});

  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final subtleFrame = Paint()
      ..color = Colors.white.withValues(alpha: 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;

    final r = radius.clamp(10.0, 28.0);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(r)),
      subtleFrame,
    );

    final softShadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.2
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);

    final whiteArcPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;

    const arm = 18.0;
    final w = size.width;
    final h = size.height;

    final cornerArc = Path()
      ..moveTo(w, h - r - arm)
      ..lineTo(w, h - r)
      ..quadraticBezierTo(w, h, w - r, h)
      ..lineTo(w - r - arm, h);

    canvas.drawPath(cornerArc, softShadowPaint);
    canvas.drawPath(cornerArc, whiteArcPaint);
  }

  @override
  bool shouldRepaint(covariant _WhiteWidgetResizePainter oldDelegate) {
    return oldDelegate.radius != radius;
  }
}

/// Menú vertical compacto de iconos sueltos que se ubica en el lado libre
/// sin tapar bordes de la pantalla ni las guías de cambio de tamaño.
class _FloatingWidgetActionList extends StatelessWidget {
  const _FloatingWidgetActionList({
    required this.cardRect,
    required this.totalWidth,
    required this.canvasHeight,
    required this.node,
    this.authorLabel = '',
    required this.isLockedSurprise,
    required this.theme,
    required this.onChooseSize,
    required this.onConnect,
    required this.onFavorite,
    this.onPartnerReply,
    this.onToggleSurprise,
    this.onEdit,
    this.onDelete,
  });

  final Rect cardRect;
  final double totalWidth;
  final double canvasHeight;
  final BentoNode node;
  final String authorLabel;
  final bool isLockedSurprise;
  final RochyThemeData theme;
  final VoidCallback onChooseSize, onConnect, onFavorite;
  final VoidCallback? onPartnerReply, onToggleSurprise, onEdit, onDelete;

  @override
  Widget build(BuildContext context) {
    const menuWidth = 44.0;
    const desiredHeight = 340.0;
    const leftGap = 12.0;
    const rightGap = 14.0;

    final spaceLeft = cardRect.left;
    final spaceRight = totalWidth - cardRect.right;

    // 1) Si cabe a la izquierda (tarjetas columna derecha), colocar a la izquierda:
    //    totalmente opuesto a la esquina inferior derecha de cambio de tamaño.
    // 2) Si cabe a la derecha (tarjetas columna izquierda), colocar a la derecha con
    //    14px de aire libre.
    // 3) Si ocupa ancho completo (2 columnas), colocar en el borde superior izquierdo
    //    interno, despejando por completo las manijas derecha, inferior y esquina.
    late final double left;
    late final bool opensFromLeft;
    if (spaceLeft >= menuWidth + leftGap) {
      left = (cardRect.left - menuWidth - leftGap)
          .clamp(6.0, math.max(6.0, totalWidth - menuWidth - 6));
      opensFromLeft = true;
    } else if (spaceRight >= menuWidth + rightGap) {
      left = (cardRect.right + rightGap)
          .clamp(6.0, math.max(6.0, totalWidth - menuWidth - 6));
      opensFromLeft = false;
    } else {
      left = (cardRect.left + 10.0)
          .clamp(6.0, math.max(6.0, totalWidth - menuWidth - 6));
      opensFromLeft = false;
    }

    // Convertir el viewport visible del scroll a coordenadas locales del lienzo.
    var visibleTop = 0.0;
    var visibleBottom = canvasHeight;
    final stack = context.findAncestorRenderObjectOfType<RenderStack>();
    final viewport = Scrollable.maybeOf(context)?.context.findRenderObject();
    if (stack != null && viewport is RenderBox && viewport.hasSize) {
      final topOffset =
          stack.globalToLocal(viewport.localToGlobal(Offset.zero)).dy;
      visibleTop = math.max(0.0, topOffset);
      visibleBottom = math.min(canvasHeight, topOffset + viewport.size.height);
    }

    final maxHeight = math.min(
        desiredHeight, math.max(96.0, visibleBottom - visibleTop - 16));
    final top = cardRect.top.clamp(
      visibleTop + 8.0,
      math.max(visibleTop + 8.0, visibleBottom - maxHeight - 8.0),
    );

    return Positioned(
      left: left,
      top: top.toDouble(),
      width: menuWidth,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: TweenAnimationBuilder<double>(
          key: ValueKey<String>('bento_action_anim_${node.id}'),
          tween: Tween<double>(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          builder: (context, t, child) {
            final dx = (opensFromLeft ? 10.0 : -10.0) * (1.0 - t);
            return Opacity(
              opacity: t.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(dx, 0),
                child: Transform.scale(
                  scale: 0.90 + 0.10 * t,
                  alignment:
                      opensFromLeft ? Alignment.topRight : Alignment.topLeft,
                  child: child,
                ),
              ),
            );
          },
          child: SingleChildScrollView(
            clipBehavior: Clip.none,
            padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
            child: Column(
              key: ValueKey('bento_action_menu_${node.id}'),
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (authorLabel.isNotEmpty) ...<Widget>[
                  Tooltip(
                    message: 'Creado por $authorLabel',
                    child: Container(
                      width: 36,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.ivorySurface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: theme.borderTint),
                      ),
                      child: Text(
                        authorLabel,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: RochyTypography.metadata(
                          theme.inkSecondary,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                if (onEdit != null) ...<Widget>[
                  _VerticalIconAction(
                    icon: Icons.edit_rounded,
                    tooltip: 'Editar',
                    color: theme.espresso,
                    theme: theme,
                    onTap: onEdit!,
                  ),
                  const SizedBox(height: 8),
                ],
                _VerticalIconAction(
                  icon: Icons.aspect_ratio_rounded,
                  tooltip: 'Cambiar tamaño',
                  color: theme.brandAccent,
                  theme: theme,
                  onTap: onChooseSize,
                ),
                const SizedBox(height: 8),
                if (onToggleSurprise != null) ...<Widget>[
                  _VerticalIconAction(
                    icon: Icons.card_giftcard_rounded,
                    tooltip: node.isSurprise
                        ? 'Revelar sorpresa'
                        : 'Ocultar como sorpresa',
                    color: theme.terracotta,
                    theme: theme,
                    highlighted: node.isSurprise,
                    onTap: onToggleSurprise!,
                  ),
                  const SizedBox(height: 8),
                ],
                if (onPartnerReply != null) ...<Widget>[
                  _VerticalIconAction(
                    icon: Icons.chat_bubble_outline_rounded,
                    tooltip: 'Nota de pareja',
                    color: theme.brandAccent,
                    theme: theme,
                    highlighted: node.partnerReplyText.trim().isNotEmpty,
                    onTap: onPartnerReply!,
                  ),
                  const SizedBox(height: 8),
                ],
                _VerticalIconAction(
                  icon: node.isFavorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  tooltip: node.isFavorite ? 'Quitar de favoritos' : 'Favorito',
                  color: theme.terracotta,
                  theme: theme,
                  highlighted: node.isFavorite,
                  onTap: onFavorite,
                ),
                const SizedBox(height: 8),
                _VerticalIconAction(
                  icon: Icons.hub_rounded,
                  tooltip: 'Conectar',
                  color: theme.sage,
                  theme: theme,
                  onTap: onConnect,
                ),
                if (onDelete != null) ...<Widget>[
                  const SizedBox(height: 8),
                  _VerticalIconAction(
                    icon: Icons.delete_outline_rounded,
                    tooltip: 'Borrar',
                    color: theme.terracotta,
                    theme: theme,
                    onTap: onDelete!,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VerticalIconAction extends StatelessWidget {
  const _VerticalIconAction({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.theme,
    required this.onTap,
    this.highlighted = false,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final RochyThemeData theme;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        elevation: 6,
        shadowColor: Colors.black.withValues(alpha: 0.20),
        color: highlighted ? color : theme.ivorySurface.withValues(alpha: 0.96),
        shape: CircleBorder(
          side: BorderSide(
            color: highlighted
                ? Colors.white.withValues(alpha: 0.7)
                : theme.borderTint,
            width: 1.1,
          ),
        ),
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(
              icon,
              size: 19,
              color: highlighted ? const Color(0xFFFAF7F2) : color,
            ),
          ),
        ),
      ),
    );
  }
}

/// Dibuja hilos curvos orgánicos conectando el nodo enfocado con sus nodos vinculados.
class _MemoryGraphThreadsPainter extends CustomPainter {
  const _MemoryGraphThreadsPainter({
    required this.origin,
    required this.targets,
    required this.color,
    required this.pulse,
  });

  final Offset origin;
  final List<Offset> targets;
  final Color color;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.24 + 0.14 * pulse)
      ..strokeWidth = 5.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final linePaint = Paint()
      ..color = color.withValues(alpha: 0.88)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final dotPaint = Paint()
      ..color = const Color(0xFFFAF7F2)
      ..style = PaintingStyle.fill;

    final dotBorderPaint = Paint()
      ..color = color
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;

    for (final target in targets) {
      final mid = Offset(
        (origin.dx + target.dx) / 2,
        (origin.dy + target.dy) / 2 - 22,
      );
      final path = Path()
        ..moveTo(origin.dx, origin.dy)
        ..quadraticBezierTo(mid.dx, mid.dy, target.dx, target.dy);

      canvas.drawPath(path, glowPaint);
      canvas.drawPath(path, linePaint);

      canvas.drawCircle(target, 5.0 + pulse * 1.1, dotPaint);
      canvas.drawCircle(target, 5.0 + pulse * 1.1, dotBorderPaint);
    }

    canvas.drawCircle(origin, 6.2 + pulse * 1.3, dotPaint);
    canvas.drawCircle(origin, 6.2 + pulse * 1.3, dotBorderPaint);
  }

  @override
  bool shouldRepaint(covariant _MemoryGraphThreadsPainter oldDelegate) {
    return oldDelegate.origin != origin ||
        oldDelegate.targets != targets ||
        oldDelegate.pulse != pulse ||
        oldDelegate.color != color;
  }
}

class _StaggeredSpringEntrance extends StatelessWidget {
  const _StaggeredSpringEntrance({
    required this.controller,
    required this.index,
    required this.totalCount,
    required this.child,
  });

  final Animation<double> controller;
  final int index;
  final int totalCount;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final step = totalCount <= 1 ? 0.0 : (0.45 / (totalCount - 1));
    final start = (index * step).clamp(0.0, 0.50);
    final end = (start + 0.50).clamp(0.0, 1.0);

    final curved = CurvedAnimation(
      parent: controller,
      curve: Interval(start, end, curve: Curves.easeOutBack),
    );

    return AnimatedBuilder(
      animation: curved,
      builder: (context, childWidget) {
        final t = curved.value;
        final opacity = t.clamp(0.0, 1.0);
        final translateY = 34.0 * (1.0 - t);
        final scale = 0.94 + 0.06 * t;

        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, translateY),
            child: Transform.scale(
              scale: scale,
              child: childWidget,
            ),
          ),
        );
      },
      child: child,
    );
  }
}

class _PartnerReplyPill extends StatelessWidget {
  const _PartnerReplyPill({
    required this.authorName,
    required this.replyText,
    required this.theme,
    required this.onTap,
  });

  final String authorName;
  final String replyText;
  final RochyThemeData theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = authorName.isNotEmpty ? '$authorName: $replyText' : replyText;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 230),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
        decoration: BoxDecoration(
          color: theme.ivorySurface.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: theme.terracotta.withValues(alpha: 0.35),
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.chat_bubble_rounded,
              size: 10,
              color: theme.terracotta,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: RochyTypography.handwrittenTitle(
                  theme.inkPrimary,
                  fontSize: 13.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LockedSurpriseCard extends StatelessWidget {
  const _LockedSurpriseCard({
    required this.node,
    required this.authorLabel,
    required this.theme,
    required this.showPaperGrain,
    required this.highlight,
    required this.onTap,
  });

  final BentoNode node;
  final String authorLabel;
  final RochyThemeData theme;
  final bool showPaperGrain;
  final BentoRelationHighlight highlight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = Color.lerp(
      theme.cardSurface(BentoColorTheme.sand),
      theme.terracotta,
      0.14,
    )!;
    return BentoCardShell(
      theme: theme,
      node: node,
      backgroundColor: bg,
      relationHighlight: highlight,
      showPaperGrain: showPaperGrain,
      onTap: onTap,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxHeight < 130;
          return Stack(
            fit: StackFit.expand,
            children: <Widget>[
              // Cinta vertical sutil de paquete regalo
              Align(
                alignment: Alignment.center,
                child: Container(
                  width: compact ? 18 : 24,
                  color: theme.terracotta.withValues(alpha: 0.10),
                ),
              ),
              Align(
                alignment: Alignment.center,
                child: Container(
                  height: compact ? 16 : 22,
                  color: theme.terracotta.withValues(alpha: 0.10),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(compact ? 10 : 14),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Container(
                      width: compact ? 34 : 44,
                      height: compact ? 34 : 44,
                      decoration: BoxDecoration(
                        color: theme.terracotta.withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.terracotta.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Icon(
                        Icons.card_giftcard_rounded,
                        size: compact ? 18 : 22,
                        color: theme.terracotta,
                      ),
                    ),
                    SizedBox(height: compact ? 6 : 10),
                    Text(
                      'Sorpresa de $authorLabel',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: RochyTypography.cardSerifTitle(
                        theme.inkPrimary,
                        fontSize: compact ? 13.5 : 15.5,
                      ),
                    ),
                    if (!compact) ...<Widget>[
                      const SizedBox(height: 4),
                      if (node.daysUntilSurpriseUnlock != null &&
                          node.daysUntilSurpriseUnlock! > 0)
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: theme.terracotta.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '⏳ Se abre en ${node.daysUntilSurpriseUnlock == 1 ? '1 día' : '${node.daysUntilSurpriseUnlock} días'}',
                            style: RochyTypography.metadata(
                              theme.terracotta,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                      else
                        Text(
                          'Sellada hasta el momento especial',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: RochyTypography.metadata(
                            theme.inkSecondary,
                            fontSize: 10.8,
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
