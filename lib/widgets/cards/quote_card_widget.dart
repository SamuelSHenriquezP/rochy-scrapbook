import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/bento_node.dart';
import '../../providers/bento_canvas_provider.dart';
import '../../theme/rochy_theme.dart';
import 'bento_card_shell.dart';

/// Tarjeta tipográfica limpia para frases o notas textuales con comillas
/// editoriales translúcidas y lectura completa al tocar.
class QuoteCardWidget extends ConsumerWidget {
  const QuoteCardWidget({
    super.key,
    required this.node,
    required this.payload,
    required this.theme,
    required this.relationHighlight,
    this.showPaperGrain = true,
  });

  final BentoNode node;
  final QuotePayload payload;
  final RochyThemeData theme;
  final BentoRelationHighlight relationHighlight;
  final bool showPaperGrain;

  void _openFullTextDialog(BuildContext context, BentoCanvasState canvas) {
    HapticFeedback.lightImpact();
    final authorLabel = canvas.authorLabelFor(node.authorId);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 32),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.ivorySurface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: theme.borderTint),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (payload.contextLabel.isNotEmpty ||
                    authorLabel.isNotEmpty) ...<Widget>[
                  Row(
                    children: <Widget>[
                      if (payload.contextLabel.isNotEmpty)
                        Expanded(
                          child: Text(
                            payload.contextLabel,
                            style: RochyTypography.metadata(
                              theme.brandAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      if (authorLabel.isNotEmpty)
                        Text(
                          'Por $authorLabel',
                          style: RochyTypography.metadata(
                            theme.inkSecondary,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
                Text(
                  payload.isPlainText
                      ? payload.quoteText
                      : '“${payload.quoteText}”',
                  textAlign: RochyTypography.toFlutterTextAlign(
                    node.textAlign,
                  ),
                  style: RochyTypography.resolveCardTitle(
                    node.fontStyle,
                    theme.inkPrimary,
                    fontSize: 16.5 * node.titleScale,
                    fontWeight:
                        node.isTitleBold ? FontWeight.w600 : FontWeight.w400,
                    fontStyle: payload.isPlainText
                        ? FontStyle.normal
                        : FontStyle.italic,
                  ).copyWith(height: 1.55),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: Text(
                      'Cerrar',
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
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canvas = ref.read(bentoCanvasProvider);
    final bgColor = theme.resolveNodeBackground(node);
    final primaryInk = theme.resolveNodePrimaryInk(node);
    final secondaryInk = theme.resolveNodeSecondaryInk(node);
    final isPlain = payload.isPlainText;
    final displayText =
        isPlain ? payload.quoteText : '“${payload.quoteText}”';

    return BentoCardShell(
      theme: theme,
      node: node,
      backgroundColor: bgColor,
      relationHighlight: relationHighlight,
      showPaperGrain: showPaperGrain,
      padding: const EdgeInsets.fromLTRB(15, 13, 15, 12),
      onTap: () => _openFullTextDialog(context, canvas),
      onLongPress: () =>
          ref.read(bentoCanvasProvider.notifier).toggleNodeFocus(node.id),
      child: Stack(
        children: <Widget>[
          if (!isPlain) ...<Widget>[
            Positioned(
              top: -12,
              left: -2,
              child: IgnorePointer(
                child: Text(
                  '“',
                  style: RochyTypography.cardSerifTitle(
                    primaryInk.withValues(alpha: 0.14),
                    fontSize: 70,
                    height: 1.0,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 6,
              right: 2,
              child: IgnorePointer(
                child: Text(
                  '”',
                  style: RochyTypography.cardSerifTitle(
                    primaryInk.withValues(alpha: 0.12),
                    fontSize: 56,
                    height: 1.0,
                  ),
                ),
              ),
            ),
          ],
          LayoutBuilder(
            builder: (context, constraints) {
              final isStrip = constraints.maxHeight < 110;
              if (isStrip) {
                return Center(
                  child: Text(
                    displayText,
                    textAlign: RochyTypography.toFlutterTextAlign(
                      node.textAlign,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: RochyTypography.resolveCardTitle(
                      node.fontStyle,
                      primaryInk,
                      fontSize: (isPlain ? 13.5 : 14.5) * node.titleScale,
                      fontWeight:
                          node.isTitleBold ? FontWeight.w600 : FontWeight.w400,
                      fontStyle:
                          isPlain ? FontStyle.normal : FontStyle.italic,
                    ),
                  ),
                );
              }

              return Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: isPlain
                    ? CrossAxisAlignment.stretch
                    : CrossAxisAlignment.center,
                children: <Widget>[
                  if (!isPlain) const SizedBox(height: 4),
                  Expanded(
                    child: isPlain
                        ? SingleChildScrollView(
                            primary: false,
                            child: Text(
                              displayText,
                              textAlign: RochyTypography.toFlutterTextAlign(
                                node.textAlign,
                              ),
                              style: RochyTypography.resolveCardTitle(
                                node.fontStyle,
                                primaryInk,
                                fontSize: (constraints.maxHeight > 200
                                        ? 15.0
                                        : 13.8) *
                                    node.titleScale,
                                fontWeight: node.isTitleBold
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                fontStyle: FontStyle.normal,
                              ).copyWith(height: 1.45),
                            ),
                          )
                        : Center(
                            child: Text(
                              displayText,
                              textAlign: RochyTypography.toFlutterTextAlign(
                                node.textAlign,
                              ),
                              maxLines: constraints.maxHeight > 200 ? 6 : 4,
                              overflow: TextOverflow.ellipsis,
                              style: RochyTypography.resolveCardTitle(
                                node.fontStyle,
                                primaryInk,
                                fontSize: (constraints.maxHeight > 200
                                        ? 19.5
                                        : 17.5) *
                                    node.titleScale,
                                fontWeight: node.isTitleBold
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                  ),
                  if (payload.contextLabel.trim().isNotEmpty) ...<Widget>[
                    const SizedBox(height: 6),
                    Align(
                      alignment: isPlain
                          ? Alignment.centerLeft
                          : Alignment.center,
                      child: Text(
                        payload.contextLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: RochyTypography.metadata(
                          secondaryInk.withValues(alpha: 0.85),
                          fontSize: 10.5,
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
