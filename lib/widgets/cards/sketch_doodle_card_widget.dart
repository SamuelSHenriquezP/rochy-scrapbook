import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/bento_node.dart';
import '../../providers/bento_canvas_provider.dart';
import '../../theme/rochy_theme.dart';
import '../rochy_sketch_pad.dart';
import 'bento_card_shell.dart';

/// Tarjeta para mostrar un dibujo, garabato o firma hecha con el dedo.
class SketchDoodleCardWidget extends ConsumerWidget {
  const SketchDoodleCardWidget({
    super.key,
    required this.node,
    required this.payload,
    required this.theme,
    required this.relationHighlight,
    this.showPaperGrain = true,
  });

  final BentoNode node;
  final SketchDoodlePayload payload;
  final RochyThemeData theme;
  final BentoRelationHighlight relationHighlight;
  final bool showPaperGrain;

  void _openSketchViewer(BuildContext context, Color bgColor, Color primaryInk) {
    HapticFeedback.lightImpact();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: theme.borderTint),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              AspectRatio(
                aspectRatio: 1.15,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: CustomPaint(
                    painter: SketchStrokesPainter(
                      strokes: payload.strokes,
                      baseStrokeScale: 1.25,
                    ),
                  ),
                ),
              ),
              if (payload.title.isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  payload.title,
                  style: RochyTypography.resolveCardTitle(
                    node.fontStyle,
                    primaryInk,
                    fontSize: 18,
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(
                    'Cerrar',
                    style: RochyTypography.sansTitle(
                      primaryInk,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
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
      padding: const EdgeInsets.all(12),
      onTap: payload.strokes.isEmpty
          ? null
          : () => _openSketchViewer(context, bgColor, primaryInk),
      onLongPress: () =>
          ref.read(bentoCanvasProvider.notifier).toggleNodeFocus(node.id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: payload.strokes.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          Icons.brush_rounded,
                          size: 24,
                          color: secondaryInk.withValues(alpha: 0.7),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Toca editar para dibujar',
                          textAlign: TextAlign.center,
                          style: RochyTypography.metadata(
                            secondaryInk,
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  )
                : CustomPaint(
                    painter: SketchStrokesPainter(
                      strokes: payload.strokes,
                      baseStrokeScale: 0.85,
                    ),
                  ),
          ),
          if (payload.title.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              payload.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: RochyTypography.toFlutterTextAlign(node.textAlign),
              style: RochyTypography.resolveCardTitle(
                node.fontStyle,
                primaryInk,
                fontSize: 14.5 * node.titleScale,
                fontWeight:
                    node.isTitleBold ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
