import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/bento_node.dart';
import '../../providers/bento_canvas_provider.dart';
import '../../theme/rochy_theme.dart';
import '../editorial_image.dart';
import 'bento_card_shell.dart';

enum _ThreadGeometry {
  singleHorizontalArc,
  twoTierGarland,
  verticalSerpentine,
}

/// Módulo Bento de múltiples mini Polaroids colgadas de un hilo orgánico.
///
/// Tanto la geometría del hilo (horizontal, doble fila o serpentina vertical)
/// como la proporción y forma de cada foto Polaroid (horizontal panorámica,
/// cuadrada clásica o vertical retrato) se adaptan dinámicamente al tamaño y
/// forma actuales del widget Bento.
class PolaroidThreadCardWidget extends ConsumerWidget {
  const PolaroidThreadCardWidget({
    super.key,
    required this.node,
    required this.payload,
    required this.theme,
    required this.relationHighlight,
    this.showPaperGrain = true,
  });

  final BentoNode node;
  final PolaroidThreadPayload payload;
  final RochyThemeData theme;
  final BentoRelationHighlight relationHighlight;
  final bool showPaperGrain;

  Color _threadStrokeColor(bool usesLightInk) {
    return switch (payload.threadStyle) {
      'terracotta' => theme.brandAccent,
      'gold' => const Color(0xFFC59B56),
      'ivory' =>
        usesLightInk ? const Color(0xFFF3ECE2) : const Color(0xFF7D6B5D),
      _ => usesLightInk ? const Color(0xFFD7BE9E) : const Color(0xFF9C7A56),
    };
  }

  Color _pinColor(bool usesLightInk) {
    return switch (payload.threadStyle) {
      'terracotta' => theme.brandAccent,
      'gold' => const Color(0xFFB3863F),
      'ivory' => const Color(0xFFA85338),
      _ => usesLightInk ? const Color(0xFFE7CBB1) : const Color(0xFF6B3D22),
    };
  }

  Color _clothespinColor() {
    return switch (payload.threadStyle) {
      'terracotta' => const Color(0xFFB35F44),
      'gold' => const Color(0xFFB88C4A),
      'ivory' => const Color(0xFF8C7B6E),
      _ => const Color(0xFFB78A5B),
    };
  }

  List<_ResolvedThreadItem> _resolveItems() {
    if (payload.items.isNotEmpty) {
      return <_ResolvedThreadItem>[
        for (var i = 0; i < payload.items.length; i++)
          _ResolvedThreadItem(
            imageUrl: payload.items[i].imageUrl,
            caption: payload.items[i].caption,
            fallbackScene: _sceneForIndex(i),
          ),
      ];
    }
    return const <_ResolvedThreadItem>[
      _ResolvedThreadItem(
        imageUrl: '',
        caption: 'Recuerdo 1',
        fallbackScene: EditorialFallbackScene.cafeSunlit,
      ),
      _ResolvedThreadItem(
        imageUrl: '',
        caption: 'Recuerdo 2',
        fallbackScene: EditorialFallbackScene.handsSunday,
      ),
      _ResolvedThreadItem(
        imageUrl: '',
        caption: 'Recuerdo 3',
        fallbackScene: EditorialFallbackScene.vinylWarm,
      ),
    ];
  }

  EditorialFallbackScene _sceneForIndex(int index) {
    const scenes = EditorialFallbackScene.values;
    return scenes[index % scenes.length];
  }

  _ThreadLayoutPlan _computeLayout({
    required double stageW,
    required double stageH,
    required int count,
  }) {
    final aspect = stageW / math.max(1.0, stageH);

    // 1) Decidir geometría del hilo y forma de las Polaroids según el widget.
    final _ThreadGeometry geometry;
    final double targetPhotoRatio;

    if (aspect >= 1.38) {
      if (count >= 4 && stageH >= 158) {
        geometry = _ThreadGeometry.twoTierGarland;
        targetPhotoRatio = aspect >= 1.7 ? 1.18 : 1.06;
      } else {
        geometry = _ThreadGeometry.singleHorizontalArc;
        // Widget apaisado -> fotos apaisadas / panorámicas.
        targetPhotoRatio = aspect >= 1.7 ? 1.32 : 1.18;
      }
    } else if (aspect <= 0.78) {
      geometry = _ThreadGeometry.verticalSerpentine;
      // Widget vertical alto -> polaroids verticales retrato.
      targetPhotoRatio = aspect <= 0.56 ? 0.68 : 0.78;
    } else {
      // Widget cuadrado / equilibrado.
      if (count >= 4 && stageH >= 152) {
        geometry = _ThreadGeometry.twoTierGarland;
        targetPhotoRatio = 0.98;
      } else {
        geometry = _ThreadGeometry.singleHorizontalArc;
        targetPhotoRatio = aspect >= 1.05 ? 1.04 : 0.94;
      }
    }

    // 2) Calcular dimensiones de marco y anclajes manteniendo márgenes seguros.
    final anchors = <Offset>[];
    final rotations = <double>[];
    final stringSegments = <List<Offset>>[];

    late double frameW;
    late double frameH;
    late double borderPad;
    late double chinPad;
    late bool showMiniCaption;

    void finalizeFrameSize(double maxSlotW, double maxSlotH) {
      final candidateW = maxSlotW.clamp(34.0, 128.0);
      borderPad = (candidateW * 0.08).clamp(2.5, 5.5);
      final prelimInnerW = candidateW - borderPad * 2;
      final prelimInnerH = prelimInnerW / targetPhotoRatio;
      showMiniCaption = prelimInnerH >= 36 && candidateW >= 52;
      chinPad = showMiniCaption
          ? (candidateW * 0.24).clamp(11.0, 20.0)
          : (candidateW * 0.14).clamp(6.0, 12.0);
      final prelimH = prelimInnerH + borderPad + chinPad;

      if (prelimH > maxSlotH && maxSlotH > 20) {
        final scale = maxSlotH / prelimH;
        frameW = candidateW * scale;
        borderPad = (frameW * 0.08).clamp(2.2, 5.0);
        final innerW = frameW - borderPad * 2;
        final innerH = innerW / targetPhotoRatio;
        showMiniCaption = innerH >= 32 && frameW >= 48;
        chinPad = showMiniCaption
            ? (frameW * 0.24).clamp(10.0, 18.0)
            : (frameW * 0.14).clamp(5.0, 11.0);
        frameH = innerH + borderPad + chinPad;
      } else {
        frameW = candidateW;
        frameH = prelimH;
      }
    }

    const tiltPattern = <double>[-0.075, 0.06, -0.05, 0.08, -0.065, 0.05];

    switch (geometry) {
      case _ThreadGeometry.singleHorizontalArc:
        final overlapBoost = count >= 4 ? 1.08 : 0.94;
        final slotW = ((stageW - 14) / count) * overlapBoost;
        final maxSlotH = stageH - 18;
        finalizeFrameSize(slotW, maxSlotH);

        final usableW = math.max(20.0, stageW - frameW - 10);
        final leftPin = Offset(4, math.min(stageH * 0.16, 14));
        final rightPin = Offset(stageW - 4, math.min(stageH * 0.18, 16));
        final sag = math.min(18.0, stageH * 0.14);

        final curveSamples = <Offset>[leftPin];
        for (var i = 0; i < count; i++) {
          final t = count == 1 ? 0.5 : (i + 0.5) / count;
          final cx = (count == 1)
              ? stageW * 0.5
              : (frameW * 0.5 + 5) + usableW * (i / math.max(1, count - 1));
          // Curva catenaria suave.
          final arcY =
              leftPin.dy + (rightPin.dy - leftPin.dy) * t + math.sin(t * math.pi) * sag;
          final clampedPinY = math.max(
            4.0,
            math.min(arcY, stageH - frameH - 5),
          );
          anchors.add(Offset(cx, clampedPinY));
          rotations.add(tiltPattern[i % tiltPattern.length]);
          curveSamples.add(Offset(cx, clampedPinY));
        }
        curveSamples.add(rightPin);
        stringSegments.add(curveSamples);
        break;

      case _ThreadGeometry.twoTierGarland:
        final topCount = (count / 2).ceil();
        final bottomCount = count - topCount;
        final maxCols = math.max(topCount, bottomCount);

        final slotW = ((stageW - 14) / maxCols) * (maxCols >= 3 ? 1.04 : 0.92);
        final tierH = stageH * 0.46;
        finalizeFrameSize(slotW, tierH - 10);

        // Fila 1 (arriba)
        const topPinL = Offset(4, 10);
        final topPinR = Offset(stageW - 4, 12);
        final topSag = math.min(13.0, tierH * 0.12);
        final usableTopW = math.max(18.0, stageW - frameW - 10);
        final topPts = <Offset>[topPinL];

        for (var i = 0; i < topCount; i++) {
          final t = topCount == 1 ? 0.5 : i / math.max(1, topCount - 1);
          final cx = topCount == 1
              ? stageW * 0.5
              : (frameW * 0.5 + 5) + usableTopW * t;
          final y = topPinL.dy +
              (topPinR.dy - topPinL.dy) * t +
              math.sin(t * math.pi) * topSag;
          final safeY = math.max(4.0, math.min(y, tierH - frameH - 2));
          anchors.add(Offset(cx, safeY));
          rotations.add(tiltPattern[i % tiltPattern.length]);
          topPts.add(Offset(cx, safeY));
        }
        topPts.add(topPinR);

        // Fila 2 (abajo) conectada en un único hilo continuo por la derecha
        if (bottomCount > 0) {
          final botStartY = stageH * 0.50;
          final botPinL = Offset(4, botStartY);
          final botPinR = Offset(stageW - 4, botStartY + 2);
          final botSag = math.min(13.0, tierH * 0.12);
          final usableBotW = math.max(18.0, stageW - frameW - 10);
          final botPts = <Offset>[botPinL];

          for (var j = 0; j < bottomCount; j++) {
            final t = bottomCount == 1 ? 0.5 : j / math.max(1, bottomCount - 1);
            final cx = bottomCount == 1
                ? stageW * 0.5
                : (frameW * 0.5 + 5) + usableBotW * t;
            final y = botPinL.dy +
                (botPinR.dy - botPinL.dy) * t +
                math.sin(t * math.pi) * botSag;
            final safeY = math.max(
              botStartY - 4.0,
              math.min(y, stageH - frameH - 4),
            );
            anchors.add(Offset(cx, safeY));
            rotations.add(tiltPattern[(topCount + j) % tiltPattern.length]);
            botPts.add(Offset(cx, safeY));
          }
          botPts.add(botPinR);
          stringSegments.add(<Offset>[...topPts, ...botPts.reversed]);
        } else {
          stringSegments.add(topPts);
        }
        break;

      case _ThreadGeometry.verticalSerpentine:
        // En módulos verticales altos zigzagueamos las fotos para mantener tamaño legible.
        final staggeredCols = count >= 3 && stageW >= 110;
        final slotW = staggeredCols ? stageW * 0.58 : stageW * 0.72;
        final effectiveRows = staggeredCols ? (count * 0.80) : count.toDouble();
        final slotH = (stageH - 18) / math.max(1.0, effectiveRows);
        finalizeFrameSize(slotW, slotH - 6);

        const minY = 9.0;
        final maxPinY = math.max(minY + 4, stageH - frameH - 6);
        final topAnchor = Offset(stageW * 0.30, 3);
        final bottomAnchor = Offset(
          count.isOdd ? stageW * 0.72 : stageW * 0.28,
          stageH - 3,
        );
        final pts = <Offset>[topAnchor];

        for (var i = 0; i < count; i++) {
          final frac = count == 1 ? 0.45 : i / (count - 1);
          final py = minY + (maxPinY - minY) * frac;
          final leftSide = i.isEven;
          final marginX = frameW * 0.5 + 4;
          final px = staggeredCols
              ? (leftSide
                  ? math.max(marginX, stageW * 0.33)
                  : math.min(stageW - marginX, stageW * 0.67))
              : (leftSide ? stageW * 0.44 : stageW * 0.56);

          anchors.add(Offset(px, py));
          rotations.add(leftSide ? -0.065 : 0.065);
          pts.add(Offset(px, py));
        }
        pts.add(bottomAnchor);
        stringSegments.add(pts);
        break;
    }

    return _ThreadLayoutPlan(
      geometry: geometry,
      photoAspectRatio: targetPhotoRatio,
      frameW: frameW,
      frameH: frameH,
      borderPad: borderPad,
      chinPad: chinPad,
      showMiniCaption: showMiniCaption,
      anchors: anchors,
      rotations: rotations,
      stringSegments: stringSegments,
    );
  }

  void _openGalleryModal(
    BuildContext context,
    List<_ResolvedThreadItem> items,
    double photoAspectRatio,
  ) {
    HapticFeedback.lightImpact();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PolaroidThreadModal(
        title: payload.title.isNotEmpty ? payload.title : 'Hilo de polaroids',
        note: payload.note,
        items: items,
        threadColor: _threadStrokeColor(false),
        photoAspectRatio: photoAspectRatio,
        theme: theme,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usesLightInk = theme.nodeUsesLightInk(node);
    final primaryInk = theme.resolveNodePrimaryInk(node);
    final secondaryInk = theme.resolveNodeSecondaryInk(node);
    final items = _resolveItems();
    final hasTitle = payload.title.trim().isNotEmpty;
    final gridShape = node.colSpan / math.max(1, node.rowSpan);
    var latestPhotoRatio =
        gridShape >= 1.4 ? 1.24 : (gridShape <= 0.65 ? 0.76 : 1.0);

    return BentoCardShell(
      theme: theme,
      node: node,
      backgroundColor: theme.resolveNodeBackground(node),
      relationHighlight: relationHighlight,
      showPaperGrain: showPaperGrain,
      padding: const EdgeInsets.fromLTRB(9, 8, 9, 8),
      onTap: () => _openGalleryModal(context, items, latestPhotoRatio),
      onLongPress: () =>
          ref.read(bentoCanvasProvider.notifier).toggleNodeFocus(node.id),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalW =
              constraints.maxWidth.isFinite ? constraints.maxWidth : 220.0;
          final totalH = constraints.hasBoundedHeight
              ? constraints.maxHeight
              : math.max(
                  168.0,
                  totalW * (node.rowSpan / math.max(1, node.colSpan)) * 0.72,
                );
          final compactTitle = totalH < 120;
          final headerH = hasTitle ? (compactTitle ? 18.0 : 23.0) : 0.0;
          final stageH =
              math.max(48.0, totalH - headerH - (hasTitle ? 4.0 : 0.0));

          final plan = _computeLayout(
            stageW: totalW,
            stageH: stageH,
            count: items.length,
          );
          latestPhotoRatio = plan.photoAspectRatio.clamp(0.72, 1.32);

          final stringColor = _threadStrokeColor(usesLightInk);
          final pinColor = _pinColor(usesLightInk);
          final clipColor = _clothespinColor();

          return SizedBox(
            width: totalW,
            height: totalH,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (hasTitle)
                  SizedBox(
                    height: headerH,
                    child: Row(
                      children: <Widget>[
                        Icon(
                          Icons.photo_size_select_large_rounded,
                          size: compactTitle ? 12 : 13.5,
                          color: pinColor,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            payload.title.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: RochyTypography.resolveCardTitle(
                              node.fontStyle,
                              primaryInk,
                              fontSize: compactTitle ? 12.5 : 14.5,
                              fontWeight: node.isTitleBold
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                        if (payload.items.isEmpty)
                          Text(
                            'Ejemplo',
                            style: RochyTypography.metadata(
                              secondaryInk.withValues(alpha: 0.72),
                              fontSize: 9.5,
                            ),
                          ),
                      ],
                    ),
                  ),
                if (hasTitle) const SizedBox(height: 4),
                SizedBox(
                  width: totalW,
                  height: stageH,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: <Widget>[
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _PolaroidThreadPainter(
                            segments: plan.stringSegments,
                            strokeColor: stringColor,
                            pinColor: pinColor,
                            verticalMode: plan.geometry ==
                                _ThreadGeometry.verticalSerpentine,
                          ),
                        ),
                      ),
                      for (var i = 0; i < items.length; i++)
                        Positioned(
                          left: plan.anchors[i].dx - plan.frameW * 0.5,
                          top: plan.anchors[i].dy - 2.0,
                          width: plan.frameW,
                          height: plan.frameH + 6,
                          child: Transform.rotate(
                            angle: plan.rotations[i],
                            alignment: Alignment.topCenter,
                            child: _MiniThreadedPolaroid(
                              item: items[i],
                              frameW: plan.frameW,
                              frameH: plan.frameH,
                              borderPad: plan.borderPad,
                              chinPad: plan.chinPad,
                              showCaption: plan.showMiniCaption &&
                                  items[i].caption.trim().isNotEmpty,
                              clothespinColor: clipColor,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ResolvedThreadItem {
  const _ResolvedThreadItem({
    required this.imageUrl,
    required this.caption,
    required this.fallbackScene,
  });

  final String imageUrl;
  final String caption;
  final EditorialFallbackScene fallbackScene;
}

class _ThreadLayoutPlan {
  const _ThreadLayoutPlan({
    required this.geometry,
    required this.photoAspectRatio,
    required this.frameW,
    required this.frameH,
    required this.borderPad,
    required this.chinPad,
    required this.showMiniCaption,
    required this.anchors,
    required this.rotations,
    required this.stringSegments,
  });

  final _ThreadGeometry geometry;
  final double photoAspectRatio;
  final double frameW;
  final double frameH;
  final double borderPad;
  final double chinPad;
  final bool showMiniCaption;
  final List<Offset> anchors;
  final List<double> rotations;
  final List<List<Offset>> stringSegments;
}

class _PolaroidThreadPainter extends CustomPainter {
  const _PolaroidThreadPainter({
    required this.segments,
    required this.strokeColor,
    required this.pinColor,
    required this.verticalMode,
  });

  final List<List<Offset>> segments;
  final Color strokeColor;
  final Color pinColor;
  final bool verticalMode;

  @override
  void paint(Canvas canvas, Size size) {
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.14)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final threadPaint = Paint()
      ..color = strokeColor
      ..strokeWidth = 1.85
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final pinShadow = Paint()..color = Colors.black.withValues(alpha: 0.22);
    final pinFill = Paint()..color = pinColor;
    final pinHighlight = Paint()
      ..color = Colors.white.withValues(alpha: 0.45);

    for (final pts in segments) {
      if (pts.length < 2) continue;

      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      final pinPoints = <Offset>[pts.first, pts.last];
      for (var i = 0; i < pts.length - 1; i++) {
        final p0 = pts[i];
        final p1 = pts[i + 1];
        if (verticalMode) {
          final midY = (p0.dy + p1.dy) * 0.5;
          path.cubicTo(p0.dx, midY, p1.dx, midY, p1.dx, p1.dy);
        } else if ((p0.dx - p1.dx).abs() < 6 && (p1.dy - p0.dy) > 14) {
          // Curva lateral suave que une la fila superior con la fila inferior.
          path.quadraticBezierTo(
            math.min(size.width - 0.5, p0.dx + 5.5),
            (p0.dy + p1.dy) * 0.5,
            p1.dx,
            p1.dy,
          );
          pinPoints.add(p0);
          pinPoints.add(p1);
        } else {
          final midX = (p0.dx + p1.dx) * 0.5;
          const dip = 2.6;
          final ctrlY = math.max(p0.dy, p1.dy) + dip;
          path.quadraticBezierTo(midX, ctrlY, p1.dx, p1.dy);
        }
      }

      canvas.save();
      canvas.translate(0, 1.5);
      canvas.drawPath(path, shadowPaint);
      canvas.restore();

      canvas.drawPath(path, threadPaint);

      // Pines en los extremos y giros del hilo
      for (final endPin in pinPoints) {
        canvas.drawCircle(endPin + const Offset(0, 1), 3.4, pinShadow);
        canvas.drawCircle(endPin, 3.2, pinFill);
        canvas.drawCircle(endPin + const Offset(-0.8, -0.8), 1.1, pinHighlight);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PolaroidThreadPainter oldDelegate) {
    if (oldDelegate.strokeColor != strokeColor ||
        oldDelegate.pinColor != pinColor ||
        oldDelegate.verticalMode != verticalMode ||
        oldDelegate.segments.length != segments.length) {
      return true;
    }
    for (var i = 0; i < segments.length; i++) {
      final a = segments[i];
      final b = oldDelegate.segments[i];
      if (a.length != b.length) return true;
      for (var j = 0; j < a.length; j++) {
        if (a[j] != b[j]) return true;
      }
    }
    return false;
  }
}

class _MiniThreadedPolaroid extends StatelessWidget {
  const _MiniThreadedPolaroid({
    required this.item,
    required this.frameW,
    required this.frameH,
    required this.borderPad,
    required this.chinPad,
    required this.showCaption,
    required this.clothespinColor,
  });

  final _ResolvedThreadItem item;
  final double frameW;
  final double frameH;
  final double borderPad;
  final double chinPad;
  final bool showCaption;
  final Color clothespinColor;

  @override
  Widget build(BuildContext context) {
    final pinW = (frameW * 0.14).clamp(6.0, 9.0);
    final pinH = (frameW * 0.16).clamp(8.0, 12.0);

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: <Widget>[
        // Papel Polaroid
        Positioned(
          top: 4,
          left: 0,
          right: 0,
          height: frameH,
          child: Container(
            padding: EdgeInsets.fromLTRB(
              borderPad,
              borderPad,
              borderPad,
              chinPad,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFFCF9F4),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: Colors.black.withValues(alpha: 0.08),
                width: 0.7,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 7,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: EditorialImage(
                imageUrl: item.imageUrl,
                fallbackScene: item.fallbackScene,
              ),
            ),
          ),
        ),
        if (showCaption)
          Positioned(
            bottom: math.max(1.5, chinPad * 0.15 + 2),
            left: borderPad + 1,
            right: borderPad + 1,
            child: Text(
              item.caption.trim(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: RochyTypography.handwrittenTitle(
                const Color(0xFF3E2D24),
                fontSize: (frameW * 0.13).clamp(8.5, 11.5),
              ),
            ),
          ),
        // Mini pinza de madera sujetando la Polaroid al hilo
        Positioned(
          top: -1,
          child: Container(
            width: pinW,
            height: pinH,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: <Color>[
                  clothespinColor,
                  Color.lerp(clothespinColor, Colors.white, 0.25)!,
                  clothespinColor,
                ],
              ),
              borderRadius: BorderRadius.circular(2),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 2.5,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: pinW * 0.7,
                height: 1.3,
                color: const Color(0xFF3D2A1E).withValues(alpha: 0.45),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PolaroidThreadModal extends StatelessWidget {
  const _PolaroidThreadModal({
    required this.title,
    required this.note,
    required this.items,
    required this.threadColor,
    required this.photoAspectRatio,
    required this.theme,
  });

  final String title;
  final String note;
  final List<_ResolvedThreadItem> items;
  final Color threadColor;
  final double photoAspectRatio;
  final RochyThemeData theme;

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.sizeOf(context).height;
    final safeRatio = photoAspectRatio.clamp(0.72, 1.32);
    const maxCardW = 224.0;
    final maxPhotoH = math.max(120.0, screenH * 0.52 - 96.0);
    final photoH = math.min((maxCardW - 24.0) / safeRatio, maxPhotoH);
    final cardW = (photoH * safeRatio + 24.0).clamp(164.0, 232.0);
    final listHeight = photoH + 132.0;

    return Container(
      constraints: BoxConstraints(maxHeight: screenH * 0.86),
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
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 8),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: RochyTypography.cardSerifTitle(
                          theme.inkPrimary,
                          fontSize: 22,
                        ),
                      ),
                      if (note.trim().isNotEmpty) ...<Widget>[
                        const SizedBox(height: 4),
                        Text(
                          note.trim(),
                          style: RochyTypography.sansBody(
                            theme.inkSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Container(
            height: 2,
            margin: const EdgeInsets.symmetric(horizontal: 22, vertical: 6),
            color: threadColor.withValues(alpha: 0.65),
          ),
          SizedBox(
            height: listHeight,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(22, 10, 22, 26),
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (context, index) {
                final item = items[index];
                final tilt = index.isEven ? -0.02 : 0.02;
                return Align(
                  alignment: Alignment.topCenter,
                  child: Transform.rotate(
                    angle: tilt,
                    child: Container(
                      width: cardW,
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFCF9F4),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.14),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          SizedBox(
                            width: cardW - 24.0,
                            height: photoH,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: EditorialImage(
                                imageUrl: item.imageUrl,
                                fallbackScene: item.fallbackScene,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            item.caption.trim().isNotEmpty
                                ? item.caption.trim()
                                : 'Recuerdo ${index + 1}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: RochyTypography.handwrittenTitle(
                              const Color(0xFF3A2B24),
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
