import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/bento_node.dart';
import '../../providers/bento_canvas_provider.dart';
import '../../theme/rochy_theme.dart';
import '../editorial_image.dart';
import 'bento_card_shell.dart';

/// Módulo para guardar bebidas, recetas, antojos o pedidos exactos favoritos.
class CravingRecipeCardWidget extends ConsumerWidget {
  const CravingRecipeCardWidget({
    super.key,
    required this.node,
    required this.payload,
    required this.theme,
    required this.relationHighlight,
    this.showPaperGrain = true,
  });

  final BentoNode node;
  final CravingRecipePayload payload;
  final RochyThemeData theme;
  final BentoRelationHighlight relationHighlight;
  final bool showPaperGrain;

  static ({IconData icon, String label}) resolveCategory(String cat) {
    return switch (cat) {
      'food' => (icon: Icons.restaurant_rounded, label: 'Plato'),
      'dessert' => (icon: Icons.bakery_dining_rounded, label: 'Postre'),
      'place' => (icon: Icons.storefront_rounded, label: 'Café / Sitio'),
      _ => (icon: Icons.local_cafe_rounded, label: 'Bebida'),
    };
  }

  void _openDetailDialog(
    BuildContext context,
    ({IconData icon, String label}) cat,
  ) {
    HapticFeedback.lightImpact();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 32),
        child: Container(
          padding: const EdgeInsets.all(22),
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
                if (payload.imageUrl.trim().isNotEmpty) ...<Widget>[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: SizedBox(
                      height: 165,
                      width: double.infinity,
                      child: EditorialImage(
                        imageUrl: payload.imageUrl,
                        fallbackScene: EditorialFallbackScene.cafeSunlit,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: theme.brandAccent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(cat.icon, size: 14, color: theme.brandAccent),
                          const SizedBox(width: 5),
                          Text(
                            cat.label,
                            style: RochyTypography.metadata(
                              theme.brandAccent,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  payload.title,
                  style: RochyTypography.cardSerifTitle(
                    theme.inkPrimary,
                    fontSize: 21,
                  ),
                ),
                if (payload.details.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 12),
                  for (final line in payload.details)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: theme.terracotta,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              line,
                              style: RochyTypography.sansBody(
                                theme.inkPrimary,
                                fontSize: 13.5,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
                if (payload.placeNote.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 10),
                  Text(
                    payload.placeNote,
                    style: RochyTypography.metadata(
                      theme.inkSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
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
    final cat = resolveCategory(payload.category);

    return BentoCardShell(
      theme: theme,
      node: node,
      backgroundColor: bgColor,
      relationHighlight: relationHighlight,
      showPaperGrain: showPaperGrain,
      padding: const EdgeInsets.all(14),
      onTap: () => _openDetailDialog(context, cat),
      onLongPress: () =>
          ref.read(bentoCanvasProvider.notifier).toggleNodeFocus(node.id),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxHeight < 120;
          final hasPhoto = payload.imageUrl.trim().isNotEmpty;

          if (isCompact) {
            return Row(
              children: <Widget>[
                if (hasPhoto)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: EditorialImage(
                        imageUrl: payload.imageUrl,
                        fallbackScene: EditorialFallbackScene.cafeSunlit,
                      ),
                    ),
                  )
                else
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: primaryInk.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(cat.icon, size: 18, color: primaryInk),
                  ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        payload.title,
                        maxLines: 2,
                        softWrap: true,
                        overflow: TextOverflow.ellipsis,
                        style: RochyTypography.resolveCardTitle(
                          node.fontStyle,
                          primaryInk,
                          fontSize: 14.5 * node.titleScale,
                          fontWeight: node.isTitleBold
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                      if (payload.details.isNotEmpty)
                        Text(
                          payload.details.join(' · '),
                          maxLines: 2,
                          softWrap: true,
                          overflow: TextOverflow.ellipsis,
                          style: RochyTypography.metadata(
                            secondaryInk,
                            fontSize: 10.5,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: primaryInk.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(cat.icon, size: 15, color: primaryInk),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      cat.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: RochyTypography.metadata(
                        secondaryInk,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (hasPhoto)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: SizedBox(
                        width: 32,
                        height: 32,
                        child: EditorialImage(
                          imageUrl: payload.imageUrl,
                          fallbackScene: EditorialFallbackScene.cafeSunlit,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                payload.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: RochyTypography.toFlutterTextAlign(node.textAlign),
                style: RochyTypography.resolveCardTitle(
                  node.fontStyle,
                  primaryInk,
                  fontSize: 16 * node.titleScale,
                  fontWeight:
                      node.isTitleBold ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: ListView(
                  primary: false,
                  padding: EdgeInsets.zero,
                  children: payload.details.map((line) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: theme.terracotta,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              line,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: RochyTypography.sansBody(
                                secondaryInk,
                                fontSize: 11.8,
                                height: 1.28,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              if (payload.placeNote.isNotEmpty) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  payload.placeNote,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: RochyTypography.metadata(secondaryInk, fontSize: 10),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
