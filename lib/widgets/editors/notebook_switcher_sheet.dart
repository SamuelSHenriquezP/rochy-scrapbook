import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/bento_canvas_provider.dart';
import '../../theme/rochy_theme.dart';

/// Selector multi-cuaderno para cambiar de persona o crear un nuevo perfil.
Future<void> showNotebookSwitcherSheet(
  BuildContext context,
  WidgetRef ref,
) async {
  final theme = ref.read(activeRochyThemeProvider);

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return Consumer(
        builder: (context, innerRef, _) {
          final canvas = innerRef.watch(bentoCanvasProvider);
          final activeTheme = innerRef.watch(activeRochyThemeProvider);

          return Container(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 26),
            decoration: BoxDecoration(
              color: activeTheme.canvasBackground,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(30),
              ),
              border: Border.all(color: activeTheme.borderTint),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: activeTheme.inkSecondary.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Tus cuadernos',
                  style: RochyTypography.brandTitle(activeTheme.brandAccent)
                      .copyWith(fontSize: 23),
                ),
                const SizedBox(height: 4),
                Text(
                  'Guarda perfiles independientes para cada persona especial.',
                  style: RochyTypography.sansBody(
                    activeTheme.inkSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                ...canvas.notebooks.map((book) {
                  final isCurrent = book.entity.id == canvas.activeNotebookId;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        innerRef
                            .read(bentoCanvasProvider.notifier)
                            .switchNotebook(book.entity.id);
                        Navigator.of(sheetContext).pop();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: activeTheme.ivorySurface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isCurrent
                                ? activeTheme.brandAccent
                                : activeTheme.borderTint,
                            width: isCurrent ? 1.8 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: <Widget>[
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: activeTheme.brandAccent
                                  .withValues(alpha: 0.16),
                              child: Text(
                                book.entity.name.isNotEmpty
                                    ? book.entity.name.substring(0, 1)
                                    : 'R',
                                style: RochyTypography.cardSerifTitle(
                                  activeTheme.brandAccent,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    book.entity.name,
                                    style: RochyTypography.cardSerifTitle(
                                      activeTheme.inkPrimary,
                                      fontSize: 17,
                                    ),
                                  ),
                                  Text(
                                    '${book.nodes.length} módulos',
                                    style: RochyTypography.metadata(
                                      activeTheme.inkSecondary,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (canvas.notebooks.length > 1 && !isCurrent)
                              IconButton(
                                icon: Icon(
                                  Icons.delete_outline_rounded,
                                  size: 18,
                                  color: activeTheme.inkSecondary,
                                ),
                                onPressed: () {
                                  innerRef
                                      .read(bentoCanvasProvider.notifier)
                                      .deleteNotebook(book.entity.id);
                                },
                              ),
                            if (isCurrent)
                              Icon(
                                Icons.check_circle_rounded,
                                color: activeTheme.brandAccent,
                                size: 20,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: activeTheme.brandAccent,
                      foregroundColor: const Color(0xFFFAF7F2),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: const StadiumBorder(),
                    ),
                    onPressed: () async {
                      Navigator.of(sheetContext).pop();
                      await _showCreateNotebookDialog(context, ref, theme);
                    },
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Crear nuevo cuaderno'),
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

Future<void> _showCreateNotebookDialog(
  BuildContext context,
  WidgetRef ref,
  RochyThemeData theme,
) async {
  final nameCtrl = TextEditingController();
  final subtitleCtrl = TextEditingController();
  var startBlank = true;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: theme.ivorySurface,
            title: Text(
              'Nuevo cuaderno',
              style: RochyTypography.cardSerifTitle(
                theme.inkPrimary,
                fontSize: 20,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre de la persona',
                    hintText: 'Ej. Camila, Mamá, Mejores Amigos…',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: subtitleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Subtítulo (opcional)',
                    hintText: 'Ej. Pequeñas cosas que amo',
                  ),
                ),
                const SizedBox(height: 10),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Empezar lienzo en blanco'),
                  value: startBlank,
                  onChanged: (v) => setDialogState(() => startBlank = v),
                ),
              ],
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: theme.brandAccent,
                ),
                onPressed: () {
                  ref.read(bentoCanvasProvider.notifier).createNotebook(
                        name: nameCtrl.text,
                        subtitle: subtitleCtrl.text,
                        startBlank: startBlank,
                      );
                  Navigator.of(dialogContext).pop();
                },
                child: const Text('Crear'),
              ),
            ],
          );
        },
      );
    },
  );
  nameCtrl.dispose();
  subtitleCtrl.dispose();
}
