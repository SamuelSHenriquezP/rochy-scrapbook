import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// One pointer owns moving or resizing across the entire canvas.
class BentoInteractionLock {
  Object? _owner;

  bool acquire(Object owner) {
    if (_owner != null) return false;
    _owner = owner;
    return true;
  }

  void release(Object owner) {
    if (identical(_owner, owner)) _owner = null;
  }
}

/// Reject additional pointers before Flutter creates another drag avatar.
class ExclusiveBentoDraggable<T extends Object> extends LongPressDraggable<T> {
  const ExclusiveBentoDraggable({
    super.key,
    required this.interactionLock,
    required super.child,
    required super.feedback,
    super.childWhenDragging,
    super.data,
    super.onDragStarted,
    super.onDragUpdate,
    super.onDragEnd,
  }) : super(
          delay: const Duration(milliseconds: 260),
          maxSimultaneousDrags: 1,
          hapticFeedbackOnStart: false,
        );

  final BentoInteractionLock interactionLock;

  @override
  DelayedMultiDragGestureRecognizer createRecognizer(
      GestureMultiDragStartCallback onStart) {
    final owner = Object();
    return super.createRecognizer((position) {
      if (!interactionLock.acquire(owner)) return null;
      final drag = onStart(position);
      if (drag == null) {
        interactionLock.release(owner);
        return null;
      }
      return _OwnedDrag(drag, () => interactionLock.release(owner));
    });
  }
}

class _OwnedDrag extends Drag {
  _OwnedDrag(this.delegate, this.release);

  final Drag delegate;
  final VoidCallback release;

  @override
  void update(DragUpdateDetails details) => delegate.update(details);

  @override
  void end(DragEndDetails details) {
    try {
      delegate.end(details);
    } finally {
      release();
    }
  }

  @override
  void cancel() {
    try {
      delegate.cancel();
    } finally {
      release();
    }
  }
}
