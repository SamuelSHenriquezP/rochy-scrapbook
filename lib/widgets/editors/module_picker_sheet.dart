import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/bento_node.dart';
import '../../providers/bento_canvas_provider.dart';
import '../../theme/rochy_theme.dart';

/// Catálogo editorial de módulos disponibles para construir el perfil.
Future<BentoNodeType?> showModulePickerSheet(
  BuildContext context,
  WidgetRef ref,
) {
  final theme = ref.read(activeRochyThemeProvider);
  if (ref.read(bentoCanvasProvider).isActiveNotebookReadOnly) {
    return Future.value(null);
  }
  final aboutHim = ref.read(bentoCanvasProvider).isTalkingAboutHim;

  return showModalBottomSheet<BentoNodeType>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return DraggableScrollableSheet(
        initialChildSize: 0.78,
        minChildSize: 0.5,
        maxChildSize: 0.92,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: theme.canvasBackground,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(30),
              ),
              border: Border.all(color: theme.borderTint),
            ),
            child: Column(
              children: <Widget>[
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.inkSecondary.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 14, 14, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              'Añadir módulo al cuaderno',
                              style: RochyTypography.brandTitle(
                                theme.brandAccent,
                              ).copyWith(fontSize: 23),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            icon: Icon(
                              Icons.close_rounded,
                              color: theme.inkSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        aboutHim
                            ? 'Elige una pieza para retratar lo que le gusta, cómo habla o lo que viven juntos.'
                            : 'Elige una pieza para retratar lo que le gusta, cómo habla o lo que viven juntos.',
                        style: RochyTypography.sansBody(
                          theme.inkSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(18, 6, 18, 28),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.24,
                    ),
                    itemCount: BentoNodeType.values.length,
                    itemBuilder: (context, index) {
                      final type = BentoNodeType.values[index];
                      final meta = _moduleMeta(type, theme);

                      return InkWell(
                        borderRadius: BorderRadius.circular(22),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          Navigator.of(sheetContext).pop(type);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: theme.ivorySurface,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: theme.borderTint),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: const Color(0xFF2D1E16)
                                    .withValues(alpha: 0.05),
                                blurRadius: 12,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: meta.accent.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(11),
                                ),
                                child: Icon(
                                  meta.icon,
                                  size: 18,
                                  color: meta.accent,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                type.displayNameFor(aboutHim: aboutHim),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: RochyTypography.sansTitle(
                                  theme.inkPrimary,
                                  fontSize: 13.5,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                type.shortDescriptionFor(aboutHim: aboutHim),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: RochyTypography.metadata(
                                  theme.inkSecondary,
                                  fontSize: 10.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

({IconData icon, Color accent}) _moduleMeta(
  BentoNodeType type,
  RochyThemeData theme,
) {
  return switch (type) {
    BentoNodeType.travelPassport => (
        icon: Icons.public_rounded,
        accent: theme.sage
      ),
    BentoNodeType.savedChat => (
        icon: Icons.forum_outlined,
        accent: theme.terracotta
      ),
    BentoNodeType.vintageTicket => (
        icon: Icons.receipt_long_rounded,
        accent: theme.espresso
      ),
    BentoNodeType.photoHero => (
        icon: Icons.photo_camera_back_rounded,
        accent: theme.espresso,
      ),
    BentoNodeType.videoMemory => (
        icon: Icons.videocam_rounded,
        accent: theme.terracotta,
      ),
    BentoNodeType.flipDetail => (
        icon: Icons.flip_rounded,
        accent: theme.espresso,
      ),
    BentoNodeType.quote => (
        icon: Icons.format_quote_rounded,
        accent: theme.terracotta,
      ),
    BentoNodeType.audioNote => (
        icon: Icons.graphic_eq_rounded,
        accent: theme.brandAccent,
      ),
    BentoNodeType.checkList => (
        icon: Icons.checklist_rounded,
        accent: theme.charcoal,
      ),
    BentoNodeType.locationPin => (
        icon: Icons.location_on_rounded,
        accent: theme.sage,
      ),
    BentoNodeType.countdown => (
        icon: Icons.calendar_month_rounded,
        accent: theme.terracotta,
      ),
    BentoNodeType.paletteMood => (
        icon: Icons.palette_rounded,
        accent: theme.sage,
      ),
    BentoNodeType.bookMovie => (
        icon: Icons.menu_book_rounded,
        accent: theme.espresso,
      ),
    BentoNodeType.giftWish => (
        icon: Icons.card_giftcard_rounded,
        accent: theme.brandAccent,
      ),
    BentoNodeType.loveLetter => (
        icon: Icons.mail_rounded,
        accent: theme.terracotta,
      ),
    BentoNodeType.habitChips => (
        icon: Icons.auto_awesome_rounded,
        accent: theme.sage,
      ),
    BentoNodeType.photoStrip => (
        icon: Icons.photo_library_rounded,
        accent: theme.espresso,
      ),
    BentoNodeType.moodPulse => (
        icon: Icons.wb_sunny_rounded,
        accent: theme.terracotta,
      ),
    BentoNodeType.cravingRecipe => (
        icon: Icons.restaurant_menu_rounded,
        accent: theme.brandAccent,
      ),
    BentoNodeType.planTicket => (
        icon: Icons.confirmation_number_rounded,
        accent: theme.sage,
      ),
    BentoNodeType.sketchDoodle => (
        icon: Icons.brush_rounded,
        accent: theme.espresso,
      ),
    BentoNodeType.polaroidThread => (
        icon: Icons.photo_size_select_large_rounded,
        accent: theme.terracotta,
      ),
    BentoNodeType.aboutHer => (
        icon: Icons.auto_awesome_mosaic_rounded,
        accent: theme.terracotta,
      ),
    BentoNodeType.wardrobeCloset => (
        icon: Icons.checkroom_rounded,
        accent: theme.brandAccent,
      ),
    BentoNodeType.coupleQuestion => (
        icon: Icons.question_answer_rounded,
        accent: theme.terracotta,
      ),
  };
}
