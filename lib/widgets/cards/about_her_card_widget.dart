import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/bento_node.dart';
import '../../providers/bento_canvas_provider.dart';
import '../../theme/rochy_theme.dart';
import 'bento_card_shell.dart';

/// Tarjeta editorial de rasgos y afirmaciones ("Ella es…", "Ella tiene…", "Ella ama…").
class AboutHerCardWidget extends ConsumerWidget {
  const AboutHerCardWidget({
    super.key,
    required this.node,
    required this.payload,
    required this.theme,
    required this.relationHighlight,
    this.showPaperGrain = true,
  });

  final BentoNode node;
  final AboutHerPayload payload;
  final RochyThemeData theme;
  final BentoRelationHighlight relationHighlight;
  final bool showPaperGrain;

  void _openFullModal(BuildContext context) {
    HapticFeedback.lightImpact();
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
                if (payload.title.isNotEmpty) ...<Widget>[
                  Text(
                    payload.title,
                    style: RochyTypography.resolveCardTitle(
                      node.fontStyle,
                      theme.inkPrimary,
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                for (final entry in payload.entries)
                  if (entry.prefix.trim().isNotEmpty ||
                      entry.detail.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: RichText(
                        text: TextSpan(
                          children: <InlineSpan>[
                            if (entry.prefix.trim().isNotEmpty)
                              TextSpan(
                                text: '${entry.prefix.trim()} ',
                                style: RochyTypography.cardSerifTitle(
                                  theme.brandAccent,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            TextSpan(
                              text: entry.detail.trim(),
                              style: RochyTypography.sansBody(
                                theme.inkPrimary,
                                fontSize: 14.5,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                const SizedBox(height: 10),
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
    final bgColor = theme.resolveNodeBackground(node);
    final primaryInk = theme.resolveNodePrimaryInk(node);
    final secondaryInk = theme.resolveNodeSecondaryInk(node);
    final usesLight = theme.nodeUsesLightInk(node);
    final accentColor =
        usesLight ? const Color(0xFFF3C69F) : theme.brandAccent;
    final aboutHim = ref.watch(
      bentoCanvasProvider.select((s) => s.isTalkingAboutHim),
    );

    final visibleEntries = payload.entries
        .where((e) => e.prefix.trim().isNotEmpty || e.detail.trim().isNotEmpty)
        .toList();

    return BentoCardShell(
      theme: theme,
      node: node,
      backgroundColor: bgColor,
      relationHighlight: relationHighlight,
      showPaperGrain: showPaperGrain,
      padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
      onTap: () => _openFullModal(context),
      onLongPress: () =>
          ref.read(bentoCanvasProvider.notifier).toggleNodeFocus(node.id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (payload.title.isNotEmpty) ...<Widget>[
            Text(
              payload.title,
              textAlign: RochyTypography.toFlutterTextAlign(node.textAlign),
              maxLines: 2,
              softWrap: true,
              overflow: TextOverflow.ellipsis,
              style: RochyTypography.resolveCardTitle(
                node.fontStyle,
                primaryInk,
                fontSize: 17 * node.titleScale,
                fontWeight:
                    node.isTitleBold ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Expanded(
            child: visibleEntries.isEmpty
                ? Center(
                    child: Text(
                      'Toca Editar para añadir frases sobre ${aboutHim ? 'él' : 'ella'}',
                      textAlign: TextAlign.center,
                      style: RochyTypography.metadata(
                        secondaryInk.withValues(alpha: 0.72),
                        fontSize: 11.5,
                      ),
                    ),
                  )
                : ListView.separated(
                    primary: false,
                    padding: EdgeInsets.zero,
                    itemCount: visibleEntries.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 7),
                    itemBuilder: (_, index) {
                      final entry = visibleEntries[index];
                      final prefix = entry.prefix.trim();
                      final detail = entry.detail.trim();
                      return RichText(
                        textAlign:
                            RochyTypography.toFlutterTextAlign(node.textAlign),
                        text: TextSpan(
                          children: <InlineSpan>[
                            if (prefix.isNotEmpty)
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: Container(
                                  margin: const EdgeInsets.only(right: 6),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: accentColor.withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    prefix,
                                    style: RochyTypography.metadata(
                                      accentColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            if (detail.isNotEmpty)
                              TextSpan(
                                text: detail,
                                style: RochyTypography.sansBody(
                                  primaryInk,
                                  fontSize: 12.8,
                                  height: 1.32,
                                ),
                              ),
                          ],
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
