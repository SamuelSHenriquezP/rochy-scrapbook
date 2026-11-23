import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'bento_interaction_lock.dart';

/// Own the pointer immediately, before scrolling or card dragging can claim it.
/// Global displacement stays stable while the card and handle reflow.
class BentoResizeHandle extends StatefulWidget {
  const BentoResizeHandle({
    super.key,
    required this.interactionLock,
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
    required this.builder,
    required this.label,
    required this.cursor,
    this.onTap,
  });

  final BentoInteractionLock interactionLock;
  final VoidCallback onStart;
  final ValueChanged<Offset> onUpdate;
  final VoidCallback onEnd;
  final VoidCallback? onTap;
  final Widget Function(BuildContext context, bool grabbed) builder;
  final String label;
  final MouseCursor cursor;

  @override
  State<BentoResizeHandle> createState() => _BentoResizeHandleState();
}

class _BentoResizeHandleState extends State<BentoResizeHandle> {
  final _owner = Object();
  int? _pointer;
  Offset _origin = Offset.zero;
  bool _moved = false;

  void _start(PointerDownEvent event) {
    if (!mounted || _pointer != null || !widget.interactionLock.acquire(_owner)) {
      return;
    }
    _origin = event.position;
    _moved = false;
    setState(() => _pointer = event.pointer);
    widget.onStart();
  }

  void _update(PointerMoveEvent event) {
    if (!mounted || event.pointer != _pointer) return;
    final displacement = event.position - _origin;
    if (displacement.distance > 8) _moved = true;
    widget.onUpdate(displacement);
  }

  void _finish(int pointer, {bool cancelled = false}) {
    if (!mounted || pointer != _pointer) return;
    final tapped = !cancelled && !_moved;
    setState(() => _pointer = null);
    widget.interactionLock.release(_owner);
    widget.onEnd();
    if (tapped) widget.onTap?.call();
  }

  @override
  void dispose() {
    widget.interactionLock.release(_owner);
    if (_pointer != null) {
      final onEnd = widget.onEnd;
      _pointer = null;
      WidgetsBinding.instance.addPostFrameCallback((_) => onEnd());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
        label: widget.label,
        button: widget.onTap != null,
        onTap: widget.onTap,
        child: MouseRegion(
          cursor: widget.cursor,
          child: RawGestureDetector(
            behavior: HitTestBehavior.opaque,
            gestures: <Type, GestureRecognizerFactory>{
              EagerGestureRecognizer:
                  GestureRecognizerFactoryWithHandlers<EagerGestureRecognizer>(
                EagerGestureRecognizer.new,
                (_) {},
              ),
            },
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: _start,
              onPointerMove: _update,
              onPointerUp: (event) => _finish(event.pointer),
              onPointerCancel: (event) =>
                  _finish(event.pointer, cancelled: true),
              child: widget.builder(context, _pointer != null),
            ),
          ),
        ),
      );
}
