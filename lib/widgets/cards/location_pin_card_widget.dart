import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/bento_node.dart';
import '../../providers/bento_canvas_provider.dart';
import '../../theme/rochy_theme.dart';
import '../editorial_image.dart';
import 'bento_card_shell.dart';

/// Tarjeta de ubicación significativa en dos variantes editoriales:
/// - [LocationPinStyle.constellationPill]: píldora verde salvia con estrellas
///   de cuatro puntas y subtítulo del rincón compartido.
/// - [LocationPinStyle.polaroid]: marco Polaroid levemente inclinado con foto
///   y pie manuscrito.
class LocationPinCardWidget extends ConsumerWidget {
  const LocationPinCardWidget({
    super.key,
    required this.node,
    required this.payload,
    required this.theme,
    required this.relationHighlight,
    this.showPaperGrain = true,
  });

  final BentoNode node;
  final LocationPinPayload payload;
  final RochyThemeData theme;
  final BentoRelationHighlight relationHighlight;
  final bool showPaperGrain;

  void _openLocationSheet(BuildContext context, WidgetRef ref) {
    HapticFeedback.lightImpact();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 22),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: theme.ivorySurface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: theme.borderTint),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: theme.sage.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.location_on_rounded,
                      size: 18,
                      color: theme.sage,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          payload.placeName,
                          style: RochyTypography.cardSerifTitle(
                            theme.inkPrimary,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          payload.coordinatesLabel,
                          style: RochyTypography.metadata(
                            theme.inkSecondary,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                payload.memoryNote.isNotEmpty
                    ? payload.memoryNote
                    : payload.caption,
                style: RochyTypography.sansBody(
                  theme.inkPrimary,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  TextButton.icon(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      ref
                          .read(bentoCanvasProvider.notifier)
                          .toggleNodeFocus(node.id);
                    },
                    icon: Icon(
                      Icons.hub_rounded,
                      size: 16,
                      color: theme.brandAccent,
                    ),
                    label: Text(
                      'Iluminar conexiones',
                      style: RochyTypography.sansTitle(
                        theme.brandAccent,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const Spacer(),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.brandAccent,
                      foregroundColor: const Color(0xFFFAF7F2),
                      shape: const StadiumBorder(),
                    ),
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      ref
                          .read(bentoCanvasProvider.notifier)
                          .focusNodeOnMap(node.id);
                    },
                    child: const Text('Ver en Mapa'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (payload.style) {
      LocationPinStyle.constellationPill => _buildConstellationPill(
          context,
          ref,
        ),
      LocationPinStyle.polaroid => _buildPolaroidPin(
          context,
          ref,
        ),
    };
  }

  Widget _buildConstellationPill(BuildContext context, WidgetRef ref) {
    final bgColor = theme.resolveNodeBackground(node);
    final primaryInk = theme.resolveNodePrimaryInk(node);
    final secondaryInk = theme.resolveNodeSecondaryInk(node);

    return BentoCardShell(
      theme: theme,
      node: node,
      backgroundColor: bgColor,
      relationHighlight: relationHighlight,
      showPaperGrain: showPaperGrain,
      borderRadius: node.borderRadius,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      onTap: () => _openLocationSheet(context, ref),
      onLongPress: () =>
          ref.read(bentoCanvasProvider.notifier).toggleNodeFocus(node.id),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List<Widget>.generate(
              payload.starCount.clamp(1, 5),
              (index) => _FourPointStar(
                size: 18,
                color: primaryInk.withValues(alpha: 0.92),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                Icons.location_on_rounded,
                size: 11,
                color: secondaryInk,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  payload.placeName,
                  maxLines: 2,
                  softWrap: true,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: RochyTypography.metadata(
                    secondaryInk,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPolaroidPin(BuildContext context, WidgetRef ref) {
    final isDimmed = relationHighlight == BentoRelationHighlight.dimmed;
    final isHighlighted = relationHighlight == BentoRelationHighlight.selected ||
        relationHighlight == BentoRelationHighlight.linked;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 280),
      opacity: isDimmed ? 0.35 : 1.0,
      child: Transform.rotate(
        angle: payload.tiltAngle,
        child: GestureDetector(
          onTap: () => _openLocationSheet(context, ref),
          onLongPress: () {
            HapticFeedback.mediumImpact();
            ref.read(bentoCanvasProvider.notifier).toggleNodeFocus(node.id);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            padding: const EdgeInsets.fromLTRB(9, 9, 9, 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFDFBF7),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isHighlighted
                    ? theme.haloColor
                    : const Color(0xFFE7DFD5),
                width: isHighlighted ? 1.8 : 1.0,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: const Color(0xFF2D1E16).withValues(alpha: 0.11),
                  blurRadius: 16,
                  offset: const Offset(2, 8),
                ),
                if (isHighlighted)
                  BoxShadow(
                    color: theme.haloColor.withValues(alpha: 0.36),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: EditorialImage(
                      imageUrl: payload.imageUrl,
                      fallbackScene: EditorialFallbackScene.handsSunday,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  payload.caption,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: RochyTypography.handwrittenTitle(
                    const Color(0xFF2E221D),
                    fontSize: 17.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Estrella editorial de cuatro puntas dibujada con precisión vectorial.
class _FourPointStar extends StatelessWidget {
  const _FourPointStar({
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _FourPointStarPainter(color: color),
    );
  }
}

class _FourPointStarPainter extends CustomPainter {
  const _FourPointStarPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;

    final path = Path()
      ..moveTo(cx, 0)
      ..quadraticBezierTo(cx, cy, w, cy)
      ..quadraticBezierTo(cx, cy, cx, h)
      ..quadraticBezierTo(cx, cy, 0, cy)
      ..quadraticBezierTo(cx, cy, cx, 0)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _FourPointStarPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
