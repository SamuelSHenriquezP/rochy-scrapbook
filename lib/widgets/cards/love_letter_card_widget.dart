import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/bento_node.dart';
import '../../providers/bento_canvas_provider.dart';
import '../../theme/rochy_theme.dart';
import 'bento_card_shell.dart';

/// Tarjeta sobre sellado con lacre que despliega una carta íntima al pulsar.
class LoveLetterCardWidget extends ConsumerWidget {
  const LoveLetterCardWidget({
    super.key,
    required this.node,
    required this.payload,
    required this.theme,
    required this.relationHighlight,
    this.showPaperGrain = true,
  });

  final BentoNode node;
  final LoveLetterPayload payload;
  final RochyThemeData theme;
  final BentoRelationHighlight relationHighlight;
  final bool showPaperGrain;

  void _openLetterModal(BuildContext context) {
    HapticFeedback.lightImpact();
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 22, vertical: 32),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.ivorySurface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: theme.borderTint),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 30,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: theme.terracotta,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.favorite_rounded,
                          size: 16,
                          color: Color(0xFFFAF7F2),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          payload.title,
                          style: RochyTypography.cardSerifTitle(
                            theme.inkPrimary,
                            fontSize: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    payload.letterBody,
                    style: RochyTypography.sansBody(
                      theme.inkPrimary,
                      fontSize: 14.5,
                      height: 1.68,
                    ),
                  ),
                  if (payload.signature.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 18),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        payload.signature,
                        style: RochyTypography.handwrittenTitle(
                          theme.brandAccent,
                          fontSize: 26,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: Text(
                        'Cerrar carta',
                        style: RochyTypography.sansTitle(
                          theme.brandAccent,
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
      },
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
      padding: const EdgeInsets.all(15),
      onTap: () => _openLetterModal(context),
      onLongPress: () =>
          ref.read(bentoCanvasProvider.notifier).toggleNodeFocus(node.id),
      child: LayoutBuilder(builder: (context, constraints) {
        final compact = constraints.maxHeight < 110;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: theme.terracotta,
                    shape: BoxShape.circle,
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: theme.terracotta.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.mail_rounded,
                    size: 14,
                    color: Color(0xFFFAF7F2),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Toca para abrir',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: RochyTypography.metadata(secondaryInk, fontSize: 10),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              payload.title,
              maxLines: compact ? 1 : 2,
              overflow: TextOverflow.ellipsis,
              style: RochyTypography.resolveCardTitle(
                node.fontStyle,
                primaryInk,
                fontSize: 16.5,
              ),
            ),
            if (!compact) ...[
              const SizedBox(height: 4),
              Text(
                payload.previewLine,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: RochyTypography.editorialQuote(
                  secondaryInk,
                  fontSize: 12.5,
                ),
              ),
            ],
          ],
        );
      }),
    );
  }
}
