import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'bento_interaction_lock.dart';
import 'bento_size_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/bento_node.dart';
import '../providers/bento_canvas_provider.dart';
import '../theme/rochy_theme.dart';
import 'cards/audio_memory_card_widget.dart';
import 'cards/bento_card_shell.dart';
import 'cards/book_movie_card_widget.dart';
import 'cards/checklist_card_widget.dart';
import 'cards/countdown_card_widget.dart';
import 'cards/flip_3d_card_widget.dart';
import 'cards/gift_wish_card_widget.dart';
import 'cards/habit_chips_card_widget.dart';
import 'cards/location_pin_card_widget.dart';
import 'cards/love_letter_card_widget.dart';
import 'cards/palette_mood_card_widget.dart';
import 'cards/photo_hero_card_widget.dart';
import 'cards/quote_card_widget.dart';
import 'cards/video_memory_card_widget.dart';
import 'editors/node_editor_sheet.dart';

/// Constructor polimórfico compartido entre el lienzo principal y la vista
/// previa en vivo del editor de módulos.
Widget buildPolymorphicBentoCard({
  required BentoNode node,
  required RochyThemeData theme,
  required bool showPaperGrain,
  BentoRelationHighlight highlight = BentoRelationHighlight.normal,
}) {
  return switch (node.payload) {
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
  };
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
    if (node.colSpan == 2) {
      return math.max(
          88.0,
          switch (node.rowSpan) {
            1 => colWidth * 0.56,
            2 => colWidth * 1.08,
            3 => colWidth * 1.54,
            4 => colWidth * 1.98,
            _ => colWidth * 2.42,
          });
    }
    return switch (node.type) {
      BentoNodeType.locationPin => switch (node.rowSpan) {
          1 => colWidth * 0.52,
          2 => colWidth * 0.96,
          3 => colWidth * 1.40,
          4 => colWidth * 1.82,
          _ => colWidth * 2.24,
        },
      BentoNodeType.checkList || BentoNodeType.giftWish => switch (
            node.rowSpan) {
          1 => colWidth * 0.66,
          2 => colWidth * 1.06,
          3 => colWidth * 1.48,
          4 => colWidth * 1.90,
          _ => colWidth * 2.32,
        },
      BentoNodeType.quote => switch (node.rowSpan) {
          1 => colWidth * 0.62,
          2 => colWidth * 0.98,
          3 => colWidth * 1.40,
          4 => colWidth * 1.82,
          _ => colWidth * 2.24,
        },
      BentoNodeType.audioNote => switch (node.rowSpan) {
          1 => colWidth * 0.64,
          2 => colWidth * 0.96,
          3 => colWidth * 1.40,
          4 => colWidth * 1.82,
          _ => colWidth * 2.24,
        },
      _ => switch (node.rowSpan) {
          1 => colWidth * 0.60,
          2 => colWidth * 1.00,
          3 => colWidth * 1.48,
          4 => colWidth * 1.94,
          _ => colWidth * 2.40,
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

    // Los hilos de conexión (y el halo de nodos vinculados) solo aparecen al
    // pulsar "Conectar" o "Iluminar conexiones"; nunca al mantener presionada
    // una tarjeta para editar, mover o cambiar su tamaño.
    final showConnections = canvas.isConnectingMode ||
        (selectedId != null && activeWidgetId == null);
    final relatedIds =
        showConnections ? canvas.relatedNodeIds : const <String>{};

    _syncAnimations(
      canvas.isEditMode || activeWidgetId != null,
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
                        index: i,
                        rect: rect,
                        isEditMode: canvas.isEditMode,
                        isActiveWidget: (activeWidgetId == node.id ||
                                _holdPreviewNodeId == node.id) &&
                            _draggingNodeId != node.id,
                        isConnectingMode: canvas.isConnectingMode,
                        isDraggingAny: _draggingNodeId != null ||
                            _holdPreviewNodeId != null,
                        isDraggingThis: isDraggingThis,
                        selectedNodeId: selectedId,
                        jiggleController: _jiggleController,
                        theme: theme,
                        onResizeStarted: () =>
                            setState(() => _resizingNodeId = node.id),
                        onResizeEnded: () {
                          if (mounted) setState(() => _resizingNodeId = null);
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
                        child: buildPolymorphicBentoCard(
                          node: node,
                          theme: theme,
                          showPaperGrain: canvas.showPaperGrain,
                          highlight: _highlightFor(
                            node,
                            selectedId,
                            relatedIds,
                            canvas.isConnectingMode,
                          ),
                        ),
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
              if (menuNode != null &&
                  menuCardRect != null &&
                  _draggingNodeId == null)
                _FloatingWidgetActionList(
                  cardRect: menuCardRect,
                  totalWidth: totalWidth,
                  canvasHeight: canvasHeight,
                  node: menuNode,
                  theme: theme,
                  onChooseSize: () =>
                      showBentoSizePicker(context, menuNode!.id),
                  onClose: () {
                    setState(() => _holdPreviewNodeId = null);
                    ref.read(bentoCanvasProvider.notifier).clearNodeFocus();
                  },
                  onConnect: () => ref
                      .read(bentoCanvasProvider.notifier)
                      .startVisualConnection(menuNode!.id),
                  onFavorite: () {
                    ref
                        .read(bentoCanvasProvider.notifier)
                        .toggleNodeFavorite(menuNode!.id);
                    ref.read(bentoCanvasProvider.notifier).clearNodeFocus();
                  },
                  onEdit: () async {
                    final target = menuNode!;
                    ref.read(bentoCanvasProvider.notifier).clearNodeFocus();
                    await showNodeEditorSheet(
                      context,
                      ref,
                      type: target.type,
                      existingNode: target,
                    );
                  },
                  onDelete: () => _deleteWithUndo(context, menuNode!),
                ),
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
  final _resizeOwner = Object();
  bool _isResizing = false;
  int _resizeStartCol = 1;
  int _resizeStartRow = 1;
  Offset _dragStartGlobal = Offset.zero;
  double _resizeDx = 0;
  double _resizeDy = 0;

  @override
  void dispose() {
    widget.interactionLock.release(_resizeOwner);
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

  void _onResizePanStart(DragStartDetails details) {
    if (!widget.interactionLock.acquire(_resizeOwner)) return;
    _isResizing = true;
    _resizeDx = 0;
    _resizeDy = 0;
    _resizeStartCol = widget.node.colSpan;
    _resizeStartRow = widget.node.rowSpan;
    widget.onResizeStarted();
    HapticFeedback.selectionClick();
  }

  void _onResizePanUpdate(DragUpdateDetails details, BentoNode _) {
    if (!_isResizing) return;
    _resizeDx += details.delta.dx;
    _resizeDy += details.delta.dy;
    final cols = (_resizeStartCol + (_resizeDx / 64).round()).clamp(1, 2);
    final rows = (_resizeStartRow + (_resizeDy / 56).round()).clamp(1, 5);
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
    _isResizing = false;
    widget.interactionLock.release(_resizeOwner);
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

    final showWidgetFrame =
        (widget.isEditMode || widget.isActiveWidget) && !widget.isDraggingThis;
    final jigglePhase = widget.index.isEven ? 1.0 : -1.0;

    // Contenido visual con temblor suave + líneas blancas de tamaño (sin números)
    Widget framedCard = widget.child;
    if (showWidgetFrame) {
      framedCard = AnimatedBuilder(
        animation: widget.jiggleController,
        builder: (context, childWidget) {
          final angle =
              (widget.jiggleController.value - 0.5) * 0.018 * jigglePhase;
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
                  if (widget.isEditMode) {
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
            // Borde derecho (ancho 1 <-> 2 columnas)
            if (showWidgetFrame)
              Positioned(
                key: ValueKey('resize_width_${node.id}'),
                right: 0,
                top: 22,
                bottom: 34,
                width: 30,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragStart: _onResizePanStart,
                  onHorizontalDragEnd: (_) => _endResize(),
                  onHorizontalDragCancel: _endResize,
                  onHorizontalDragUpdate: (d) => _onResizePanUpdate(
                    DragUpdateDetails(
                      globalPosition: d.globalPosition,
                      localPosition: d.localPosition,
                      delta: Offset(d.delta.dx, 0),
                    ),
                    node,
                  ),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    ref.read(bentoCanvasProvider.notifier).resizeNode(
                          node.id,
                          colSpan: node.colSpan == 1 ? 2 : 1,
                        );
                  },
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Container(
                        width: 4.5,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.35),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            // Borde inferior (5 alturas distintas)
            if (showWidgetFrame)
              Positioned(
                key: ValueKey('resize_height_${node.id}'),
                left: 26,
                right: 34,
                bottom: 0,
                height: 30,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragStart: _onResizePanStart,
                  onVerticalDragEnd: (_) => _endResize(),
                  onVerticalDragCancel: _endResize,
                  onVerticalDragUpdate: (d) => _onResizePanUpdate(
                    DragUpdateDetails(
                      globalPosition: d.globalPosition,
                      localPosition: d.localPosition,
                      delta: Offset(0, d.delta.dy),
                    ),
                    node,
                  ),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Container(
                        width: 32,
                        height: 4.5,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.35),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            // Esquina: arrastrar para ajustar o tocar para elegir un tamaño.
            if (showWidgetFrame)
              Positioned(
                key: ValueKey('resize_corner_${node.id}'),
                right: 0,
                bottom: 0,
                width: 44,
                height: 44,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    showBentoSizePicker(context, node.id);
                  },
                  onPanStart: _onResizePanStart,
                  onPanEnd: (_) => _endResize(),
                  onPanCancel: _endResize,
                  onPanUpdate: (d) => _onResizePanUpdate(d, node),
                  child: const SizedBox.expand(),
                ),
              ),
            if (widget.isEditMode)
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

/// Dibuja las clásicas líneas blancas en esquinas estilo widget iOS/Android
/// para indicar redimensionamiento directo sin números.
class _WhiteWidgetResizePainter extends CustomPainter {
  const _WhiteWidgetResizePainter({required this.radius});

  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.30)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round;

    final whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;

    final subtleFrame = Paint()
      ..color = Colors.white.withValues(alpha: 0.72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final r = radius.clamp(10.0, 28.0);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(r)),
      subtleFrame,
    );

    const arm = 16.0;
    final w = size.width;
    final h = size.height;

    final corners = Path()
      // Superior izquierda
      ..moveTo(0, r + arm)
      ..lineTo(0, r)
      ..quadraticBezierTo(0, 0, r, 0)
      ..lineTo(r + arm, 0)
      // Superior derecha
      ..moveTo(w - r - arm, 0)
      ..lineTo(w - r, 0)
      ..quadraticBezierTo(w, 0, w, r)
      ..lineTo(w, r + arm)
      // Inferior derecha (principal para redimensionar)
      ..moveTo(w, h - r - arm)
      ..lineTo(w, h - r)
      ..quadraticBezierTo(w, h, w - r, h)
      ..lineTo(w - r - arm, h)
      // Inferior izquierda
      ..moveTo(r + arm, h)
      ..lineTo(r, h)
      ..quadraticBezierTo(0, h, 0, h - r)
      ..lineTo(0, h - r - arm);

    canvas.drawPath(corners, shadowPaint);
    canvas.drawPath(corners, whitePaint);
  }

  @override
  bool shouldRepaint(covariant _WhiteWidgetResizePainter oldDelegate) {
    return oldDelegate.radius != radius;
  }
}

/// Vertical actions placed inside the visible scroll viewport.
class _FloatingWidgetActionList extends StatelessWidget {
  const _FloatingWidgetActionList({
    required this.cardRect,
    required this.totalWidth,
    required this.canvasHeight,
    required this.node,
    required this.theme,
    required this.onChooseSize,
    required this.onClose,
    required this.onConnect,
    required this.onFavorite,
    required this.onEdit,
    required this.onDelete,
  });

  final Rect cardRect;
  final double totalWidth;
  final double canvasHeight;
  final BentoNode node;
  final RochyThemeData theme;
  final VoidCallback onChooseSize,
      onClose,
      onConnect,
      onFavorite,
      onEdit,
      onDelete;

  @override
  Widget build(BuildContext context) {
    final menuWidth = math.min(184.0, totalWidth - 16);
    const gap = 8.0;
    final opensLeft = cardRect.left > totalWidth - cardRect.right;
    final desiredLeft =
        opensLeft ? cardRect.left - menuWidth - gap : cardRect.right + gap;
    final left =
        desiredLeft.clamp(8.0, math.max(8.0, totalWidth - menuWidth - 8));

    // Convert the scroll viewport into canvas coordinates, including its scroll offset.
    var visibleTop = 0.0;
    var visibleBottom = canvasHeight;
    final stack = context.findAncestorRenderObjectOfType<RenderStack>();
    final viewport = Scrollable.maybeOf(context)?.context.findRenderObject();
    if (stack != null && viewport is RenderBox && viewport.hasSize) {
      final top = stack.globalToLocal(viewport.localToGlobal(Offset.zero)).dy;
      visibleTop = math.max(0, top);
      visibleBottom = math.min(canvasHeight, top + viewport.size.height);
    }
    final menuHeight =
        math.min(280.0, math.max(80.0, visibleBottom - visibleTop - 16));
    final top = cardRect.top.clamp(visibleTop + 8,
        math.max(visibleTop + 8, visibleBottom - menuHeight - 8));
    return Positioned(
      left: left.toDouble(),
      top: top.toDouble(),
      width: menuWidth,
      height: menuHeight,
      child: Material(
        key: ValueKey('bento_action_menu_${node.id}'),
        elevation: 12,
        color: theme.ivorySurface,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(6),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              const SizedBox(width: 8),
              Expanded(
                  child: Text('Tarjeta',
                      style:
                          TextStyle(fontSize: 12, color: theme.inkSecondary))),
              IconButton(
                  tooltip: 'Cerrar menú',
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded, size: 18)),
            ]),
            _ActionListRow(
                icon: Icons.edit_rounded,
                label: 'Editar',
                color: theme.espresso,
                theme: theme,
                onTap: onEdit),
            _ActionListRow(
                icon: Icons.aspect_ratio_rounded,
                label: 'Cambiar tamaño',
                color: theme.brandAccent,
                theme: theme,
                onTap: onChooseSize),
            _ActionListRow(
                icon: node.isFavorite
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                label: node.isFavorite ? 'Quitar favorito' : 'Favorito',
                highlighted: node.isFavorite,
                color: theme.terracotta,
                theme: theme,
                onTap: onFavorite),
            _ActionListRow(
                icon: Icons.hub_rounded,
                label: 'Conectar',
                color: theme.sage,
                theme: theme,
                onTap: onConnect),
            _ActionListRow(
                icon: Icons.delete_outline_rounded,
                label: 'Borrar',
                color: theme.terracotta,
                theme: theme,
                onTap: onDelete),
          ]),
        ),
      ),
    );
  }
}

class _ActionListRow extends StatelessWidget {
  const _ActionListRow({
    required this.icon,
    required this.label,
    required this.color,
    required this.theme,
    required this.onTap,
    this.highlighted = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final RochyThemeData theme;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color:
              highlighted ? color.withValues(alpha: 0.11) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 17, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: RochyTypography.sansTitle(
                  highlighted ? color : theme.inkPrimary,
                  fontSize: 13,
                ),
              ),
            ),
          ],
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
