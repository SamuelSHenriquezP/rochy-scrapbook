import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
/// arrastre fluido tipo widget, marcos blancos de tamaño sin números y arco Pinterest.
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
      return switch (node.rowSpan) {
        1 => colWidth * 0.56,
        2 => colWidth * 1.08,
        3 => colWidth * 1.54,
        4 => colWidth * 1.98,
        _ => colWidth * 2.42,
      };
    }
    return switch (node.type) {
      BentoNodeType.locationPin => switch (node.rowSpan) {
          1 => colWidth * 0.52,
          2 => colWidth * 0.96,
          3 => colWidth * 1.40,
          4 => colWidth * 1.82,
          _ => colWidth * 2.24,
        },
      BentoNodeType.checkList || BentoNodeType.giftWish => switch (node.rowSpan) {
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
    final totalHeight = math.max(120.0, maxBottom > 0 ? maxBottom - _gap : 120.0);
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
    final showConnections =
        canvas.isConnectingMode || (selectedId != null && activeWidgetId == null);
    final relatedIds = showConnections ? canvas.relatedNodeIds : const <String>{};

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
            _draggingNodeId != null ? null : (_holdPreviewNodeId ?? activeWidgetId);

        BentoNode? menuNode;
        if (effectiveMenuNodeId != null) {
          for (final n in widget.nodes) {
            if (n.id == effectiveMenuNodeId) {
              menuNode = n;
              break;
            }
          }
        }
        final menuCardRect =
            effectiveMenuNodeId != null ? layout.rects[effectiveMenuNodeId] : null;
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
                        node: node,
                        index: i,
                        rect: rect,
                        isEditMode: canvas.isEditMode,
                        isActiveWidget:
                            (activeWidgetId == node.id ||
                                _holdPreviewNodeId == node.id) &&
                            _draggingNodeId != node.id,
                        isConnectingMode: canvas.isConnectingMode,
                        isDraggingAny: _draggingNodeId != null,
                        isDraggingThis: isDraggingThis,
                        selectedNodeId: selectedId,
                        jiggleController: _jiggleController,
                        theme: theme,
                        onHoldStarted: () {
                          setState(() {
                            _holdPreviewNodeId = node.id;
                          });
                        },
                        onMoveStarted: () {
                          // Limpiar el foco activo sin desmontar el Draggable (ver _immediateDragInFlight)
                          ref.read(bentoCanvasProvider.notifier).clearNodeFocus();
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
                  onResizeStep: (colDelta, rowDelta) {
                    final n = menuNode!;
                    final nextCol = (n.colSpan + colDelta).clamp(1, 2);
                    final nextRow = (n.rowSpan + rowDelta).clamp(1, 5);
                    ref.read(bentoCanvasProvider.notifier).resizeNode(
                          n.id,
                          colSpan: nextCol,
                          rowSpan: nextRow,
                        );
                  },
                  onToggleCols: () {
                    final n = menuNode!;
                    ref.read(bentoCanvasProvider.notifier).resizeNode(
                          n.id,
                          colSpan: n.colSpan == 1 ? 2 : 1,
                        );
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
  bool _immediateDragInFlight = false;
  bool _longPressInFlight = false;
  Offset _dragStartGlobal = Offset.zero;
  double _resizeDx = 0;
  double _resizeDy = 0;

  @override
  void dispose() {
    _isMovingNotifier.dispose();
    super.dispose();
  }

  Widget _buildDraggableFeedback(BentoNode node) {
    return Material(
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
    _resizeDx = 0;
    _resizeDy = 0;
    HapticFeedback.selectionClick();
  }

  void _onResizePanUpdate(DragUpdateDetails details, BentoNode node) {
    _resizeDx += details.delta.dx;
    _resizeDy += details.delta.dy;

    var nextCol = node.colSpan;
    var nextRow = node.rowSpan;
    var changed = false;

    if (_resizeDx > 44 && nextCol < 2) {
      nextCol = 2;
      _resizeDx = 0;
      changed = true;
    } else if (_resizeDx < -44 && nextCol > 1) {
      nextCol = 1;
      _resizeDx = 0;
      changed = true;
    }

    if (_resizeDy > 30 && nextRow < 5) {
      nextRow++;
      _resizeDy = 0;
      changed = true;
    } else if (_resizeDy < -30 && nextRow > 1) {
      nextRow--;
      _resizeDy = 0;
      changed = true;
    }

    if (changed) {
      HapticFeedback.selectionClick();
      ref
          .read(bentoCanvasProvider.notifier)
          .resizeNode(node.id, colSpan: nextCol, rowSpan: nextRow);
    }
  }

  @override
  Widget build(BuildContext context) {
    final node = widget.node;

    // 1. Modo de conexión visual (desde el arco estilo Pinterest)
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
    final useImmediateDraggable = !_longPressInFlight &&
        (widget.isEditMode || widget.isActiveWidget || _immediateDragInFlight);
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

    final allowedDrags =
        (widget.isDraggingAny && !widget.isDraggingThis) ? 0 : 1;

    // Mantener el mismo Draggable durante todo el arrastre (sin desmontarlo cuando cambie isActiveWidget)
    // y limitar maxSimultaneousDrags a 1 para impedir que con dos dedos se divida en dos copias.
    final Widget interactiveChild = useImmediateDraggable
        ? Draggable<String>(
            key: ValueKey<String>('drag_${node.id}'),
            data: node.id,
            maxSimultaneousDrags: allowedDrags,
            onDragStarted: () {
              HapticFeedback.mediumImpact();
              _immediateDragInFlight = true;
              _isMovingNotifier.value = true;
              widget.onMoveStarted();
            },
            onDragEnd: (_) {
              _immediateDragInFlight = false;
              _isMovingNotifier.value = false;
              widget.onDragEnded();
            },
            onDraggableCanceled: (_, __) {
              _immediateDragInFlight = false;
              _isMovingNotifier.value = false;
              widget.onDragEnded();
            },
            feedback: _buildDraggableFeedback(node),
            childWhenDragging: _buildGhostPlaceholder(node),
            child: widget.isDraggingThis
                ? _buildGhostPlaceholder(node)
                : framedCard,
          )
        : Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (e) => _dragStartGlobal = e.position,
            child: LongPressDraggable<String>(
              key: ValueKey<String>('lp_drag_${node.id}'),
              data: node.id,
              maxSimultaneousDrags: allowedDrags,
              delay: const Duration(milliseconds: 260),
              onDragStarted: () {
                HapticFeedback.mediumImpact();
                _longPressInFlight = true;
                _isMovingNotifier.value = false;
                widget.onHoldStarted();
              },
              onDragUpdate: (details) {
                if (!_isMovingNotifier.value &&
                    (details.globalPosition - _dragStartGlobal).distance >
                        18.0) {
                  _isMovingNotifier.value = true;
                  HapticFeedback.selectionClick();
                  widget.onMoveStarted();
                }
              },
              onDragEnd: (details) {
                final didMove = _isMovingNotifier.value;
                _longPressInFlight = false;
                _isMovingNotifier.value = false;
                widget.onDragEnded();
                if (!didMove) {
                  ref.read(bentoCanvasProvider.notifier).activateWidget(node.id);
                }
              },
              onDraggableCanceled: (_, __) {
                final didMove = _isMovingNotifier.value;
                _longPressInFlight = false;
                _isMovingNotifier.value = false;
                widget.onDragEnded();
                if (!didMove) {
                  ref.read(bentoCanvasProvider.notifier).activateWidget(node.id);
                }
              },
              feedback: ValueListenableBuilder<bool>(
                valueListenable: _isMovingNotifier,
                builder: (context, isMoving, _) {
                  return isMoving
                      ? _buildDraggableFeedback(node)
                      : const SizedBox.shrink();
                },
              ),
              childWhenDragging: ValueListenableBuilder<bool>(
                valueListenable: _isMovingNotifier,
                builder: (context, isMoving, _) {
                  if (isMoving) return _buildGhostPlaceholder(node);
                  return Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      widget.child,
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: _WhiteWidgetResizePainter(
                              radius: node.borderRadius,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
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
        if (!showWidgetFrame) return interactiveChild;

        // Manijas de tamaño FUERA del Draggable y estrictamente dentro de la tarjeta
        // para que ni el scroll ni el arrastre roben el gesto al cambiar el tamaño.
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            interactiveChild,
            // Borde derecho (ancho 1 <-> 2 columnas)
            Positioned(
              right: 0,
              top: 22,
              bottom: 34,
              width: 30,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: _onResizePanStart,
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
            Positioned(
              left: 26,
              right: 34,
              bottom: 0,
              height: 30,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragStart: _onResizePanStart,
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
            // Esquina inferior derecha blanca (diagonal o toque para cambiar tamaño)
            Positioned(
              right: 0,
              bottom: 0,
              width: 44,
              height: 44,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  HapticFeedback.lightImpact();
                  ref
                      .read(bentoCanvasProvider.notifier)
                      .cycleNodeSize(node.id);
                },
                onPanStart: _onResizePanStart,
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

/// Lista contextual flotante que sale automáticamente del lado con espacio
/// libre (izquierda o derecha) sin chocar nunca con los bordes de la pantalla.
class _FloatingWidgetActionList extends StatelessWidget {
  const _FloatingWidgetActionList({
    required this.cardRect,
    required this.totalWidth,
    required this.canvasHeight,
    required this.node,
    required this.theme,
    required this.onResizeStep,
    required this.onToggleCols,
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
  final void Function(int colDelta, int rowDelta) onResizeStep;
  final VoidCallback onToggleCols;
  final VoidCallback onConnect;
  final VoidCallback onFavorite;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    const menuWidth = 172.0;
    const menuHeight = 236.0;
    const gap = 10.0;

    final spaceLeft = cardRect.left;
    final spaceRight = totalWidth - cardRect.right;

    // Elegir el lado donde cabe completa sin chocar con la pantalla.
    late final double leftPos;
    late final bool opensFromLeft;
    if (spaceLeft >= menuWidth + gap && spaceLeft >= spaceRight) {
      leftPos = cardRect.left - menuWidth - gap;
      opensFromLeft = true;
    } else if (spaceRight >= menuWidth + gap) {
      leftPos = cardRect.right + gap;
      opensFromLeft = false;
    } else if (spaceLeft >= spaceRight) {
      leftPos = (cardRect.left - menuWidth - gap)
          .clamp(8.0, (totalWidth - menuWidth - 8.0).clamp(8.0, totalWidth));
      opensFromLeft = true;
    } else {
      leftPos = (cardRect.right + gap)
          .clamp(8.0, (totalWidth - menuWidth - 8.0).clamp(8.0, totalWidth));
      opensFromLeft = false;
    }

    final maxTop = math.max(8.0, canvasHeight - menuHeight - 8.0);
    final topPos = cardRect.top.clamp(8.0, maxTop);

    return Positioned(
      left: leftPos,
      top: topPos,
      width: menuWidth,
      child: TweenAnimationBuilder<double>(
        key: ValueKey<String>('menu_${node.id}'),
        tween: Tween<double>(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        builder: (context, t, child) {
          final slideOffset = (opensFromLeft ? 14.0 : -14.0) * (1.0 - t);
          return Opacity(
            opacity: t.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(slideOffset, 0),
              child: Transform.scale(
                alignment: opensFromLeft
                    ? Alignment.topRight
                    : Alignment.topLeft,
                scale: 0.90 + 0.10 * t,
                child: child,
              ),
            ),
          );
        },
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
            decoration: BoxDecoration(
              color: theme.ivorySurface.withValues(alpha: 0.98),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: theme.borderTint, width: 1.1),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _ActionListRow(
                  icon: Icons.edit_rounded,
                  label: 'Editar',
                  color: theme.espresso,
                  theme: theme,
                  onTap: onEdit,
                ),
                _ActionListRow(
                  icon: node.isFavorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  label: node.isFavorite ? 'Quitar ♥' : 'Favorito',
                  color: theme.terracotta,
                  highlighted: node.isFavorite,
                  theme: theme,
                  onTap: onFavorite,
                ),
                _ActionListRow(
                  icon: Icons.hub_rounded,
                  label: 'Conectar',
                  color: theme.sage,
                  theme: theme,
                  onTap: onConnect,
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        Icons.aspect_ratio_rounded,
                        size: 16,
                        color: theme.inkSecondary,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          'Tamaño',
                          style: RochyTypography.sansTitle(
                            theme.inkPrimary,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                      _TinyResizeChip(
                        icon: Icons.remove_rounded,
                        enabled: node.rowSpan > 1,
                        theme: theme,
                        onTap: () => onResizeStep(0, -1),
                      ),
                      const SizedBox(width: 4),
                      _TinyResizeChip(
                        icon: Icons.add_rounded,
                        enabled: node.rowSpan < 5,
                        theme: theme,
                        onTap: () => onResizeStep(0, 1),
                      ),
                      const SizedBox(width: 4),
                      _TinyResizeChip(
                        icon: Icons.swap_horiz_rounded,
                        enabled: true,
                        theme: theme,
                        accent: node.colSpan == 2,
                        onTap: onToggleCols,
                      ),
                    ],
                  ),
                ),
                Divider(height: 6, color: theme.borderTint),
                _ActionListRow(
                  icon: Icons.delete_outline_rounded,
                  label: 'Borrar',
                  color: theme.terracotta,
                  theme: theme,
                  onTap: onDelete,
                ),
              ],
            ),
          ),
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: highlighted ? color.withValues(alpha: 0.11) : Colors.transparent,
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

class _TinyResizeChip extends StatelessWidget {
  const _TinyResizeChip({
    required this.icon,
    required this.enabled,
    required this.theme,
    required this.onTap,
    this.accent = false,
  });

  final IconData icon;
  final bool enabled;
  final RochyThemeData theme;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled
          ? () {
              HapticFeedback.selectionClick();
              onTap();
            }
          : null,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: accent
              ? theme.brandAccent
              : theme.sandSurface.withValues(alpha: enabled ? 0.95 : 0.45),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: accent ? theme.brandAccent : theme.borderTint,
          ),
        ),
        child: Icon(
          icon,
          size: 14,
          color: accent
              ? Colors.white
              : (enabled
                  ? theme.inkPrimary
                  : theme.inkSecondary.withValues(alpha: 0.4)),
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
