import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/bento_node.dart';
import '../../providers/bento_canvas_provider.dart';
import '../../theme/rochy_theme.dart';
import 'couple_sync_sheet.dart';

/// Selector multi-cuaderno libre para cambiar entre libros, ajustar su privacidad
/// (Privado, Compartido o Solo vista) o crear libros nuevos vacíos.
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
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.84,
            ),
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 26),
            decoration: BoxDecoration(
              color: activeTheme.canvasBackground,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(30),
              ),
              border: Border.all(color: activeTheme.borderTint),
            ),
            child: SingleChildScrollView(
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
                    'Elige si cada libro es Privado, Compartido o Solo vista para tu pareja.',
                    style: RochyTypography.sansBody(
                      activeTheme.inkSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...canvas.visibleNotebooks.map((book) {
                    final isCurrent = book.entity.id == canvas.activeNotebookId;
                    final mode = book.entity.sharingMode;
                    final modeAccent = switch (mode) {
                      NotebookSharingMode.privateOnly =>
                        activeTheme.inkSecondary,
                      NotebookSharingMode.sharedEdit => activeTheme.terracotta,
                      NotebookSharingMode.sharedViewOnly => activeTheme.sage,
                    };
                    final modeIcon = switch (mode) {
                      NotebookSharingMode.privateOnly =>
                        Icons.lock_outline_rounded,
                      NotebookSharingMode.sharedEdit => Icons.favorite_rounded,
                      NotebookSharingMode.sharedViewOnly =>
                        Icons.visibility_outlined,
                    };

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
                                backgroundColor:
                                    modeAccent.withValues(alpha: 0.14),
                                child: mode == NotebookSharingMode.sharedEdit
                                    ? Icon(
                                        Icons.favorite_rounded,
                                        color: activeTheme.terracotta,
                                        size: 20,
                                      )
                                    : Text(
                                        book.entity.name.isNotEmpty
                                            ? book.entity.name
                                                .substring(0, 1)
                                                .toUpperCase()
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
                                    Row(
                                      children: <Widget>[
                                        Flexible(
                                          child: Text(
                                            book.entity.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style:
                                                RochyTypography.cardSerifTitle(
                                              activeTheme.inkPrimary,
                                              fontSize: 17,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 7,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: modeAccent.withValues(
                                              alpha: 0.13,
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(999),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: <Widget>[
                                              Icon(
                                                modeIcon,
                                                size: 10,
                                                color: modeAccent,
                                              ),
                                              const SizedBox(width: 3),
                                              Text(
                                                mode.label,
                                                style: RochyTypography.metadata(
                                                  modeAccent,
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      book.nodes.isEmpty
                                          ? 'Vacío · listo para llenar'
                                          : '${book.nodes.length} módulos',
                                      style: RochyTypography.metadata(
                                        activeTheme.inkSecondary,
                                        fontSize: 11.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (book.entity.canManageFor(canvas.viewerAuthor))
                                PopupMenuButton<NotebookSharingMode>(
                                  tooltip: 'Cambiar privacidad',
                                  icon: Icon(
                                    Icons.more_vert_rounded,
                                    size: 18,
                                    color: activeTheme.inkSecondary,
                                  ),
                                  color: activeTheme.ivorySurface,
                                  onSelected: (nextMode) {
                                    HapticFeedback.selectionClick();
                                    innerRef
                                        .read(bentoCanvasProvider.notifier)
                                        .setNotebookSharingMode(
                                          book.entity.id,
                                          nextMode,
                                        );
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                      value: NotebookSharingMode.privateOnly,
                                      child: Text('🔒 Privado (solo yo)'),
                                    ),
                                    PopupMenuItem(
                                      value: NotebookSharingMode.sharedEdit,
                                      child:
                                          Text('♥ Compartido (ambos editan)'),
                                    ),
                                    PopupMenuItem(
                                      value: NotebookSharingMode.sharedViewOnly,
                                      child: Text(
                                        '👁 Solo vista (mi pareja solo ve)',
                                      ),
                                    ),
                                  ],
                                ),
                              if (canvas.notebooks.length > 1 &&
                                  book.entity.canManageFor(canvas.viewerAuthor))
                                IconButton(
                                  tooltip: 'Eliminar cuaderno',
                                  icon: Icon(
                                    Icons.delete_outline_rounded,
                                    size: 18,
                                    color: activeTheme.terracotta,
                                  ),
                                  onPressed: () async {
                                    final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (dialogContext) => AlertDialog(
                                        backgroundColor:
                                            activeTheme.ivorySurface,
                                        title: Text(
                                          '¿Eliminar "${book.entity.name}"?',
                                          style: RochyTypography.cardSerifTitle(
                                            activeTheme.inkPrimary,
                                            fontSize: 19,
                                          ),
                                        ),
                                        content: Text(
                                          'Se borrará este cuaderno y sus tarjetas.',
                                          style: RochyTypography.sansBody(
                                            activeTheme.inkSecondary,
                                            fontSize: 12.5,
                                          ),
                                        ),
                                        actions: <Widget>[
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(dialogContext)
                                                    .pop(false),
                                            child: const Text('Cancelar'),
                                          ),
                                          FilledButton(
                                            style: FilledButton.styleFrom(
                                              backgroundColor:
                                                  activeTheme.terracotta,
                                              foregroundColor:
                                                  const Color(0xFFFAF7F2),
                                            ),
                                            onPressed: () =>
                                                Navigator.of(dialogContext)
                                                    .pop(true),
                                            child: const Text('Eliminar'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirmed == true) {
                                      HapticFeedback.mediumImpact();
                                      innerRef
                                          .read(bentoCanvasProvider.notifier)
                                          .deleteNotebook(book.entity.id);
                                    }
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
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: activeTheme.brandAccent,
                        side: BorderSide(
                          color:
                              activeTheme.brandAccent.withValues(alpha: 0.45),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: const StadiumBorder(),
                      ),
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        showCoupleSyncSheet(context, ref);
                      },
                      icon: const Icon(Icons.sync_rounded, size: 17),
                      label: Text(
                        '${canvas.partnerAName} y ${canvas.partnerBName} · Sincronizar y Drive',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
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
  var sharingMode = NotebookSharingMode.privateOnly;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          final hintDesc = switch (sharingMode) {
            NotebookSharingMode.privateOnly =>
              'Solo se guarda en tu teléfono; tu pareja no lo verá en la nube.',
            NotebookSharingMode.sharedEdit =>
              'Ambos pueden verlo, agregar recuerdos, sorpresas y responder preguntas.',
            NotebookSharingMode.sharedViewOnly =>
              'Tu pareja podrá verlo y leerlo en su teléfono, pero solo tú podrás editarlo.',
          };

          return AlertDialog(
            backgroundColor: theme.ivorySurface,
            title: Text(
              'Nuevo cuaderno',
              style: RochyTypography.cardSerifTitle(
                theme.inkPrimary,
                fontSize: 20,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Nombre del cuaderno',
                      hintText: sharingMode == NotebookSharingMode.sharedEdit
                          ? 'Ej. Nosotros, Nuestros viajes…'
                          : 'Ej. Rochy, Sam, Diario, Ideas…',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: subtitleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Subtítulo (opcional)',
                      hintText: 'Ej. Pequeñas cosas que amamos',
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Privacidad del cuaderno',
                    style: RochyTypography.metadata(
                      theme.inkSecondary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _BookModeChoice(
                          label: 'Privado',
                          icon: Icons.lock_outline_rounded,
                          selected:
                              sharingMode == NotebookSharingMode.privateOnly,
                          accent: theme.espresso,
                          theme: theme,
                          onTap: () => setDialogState(
                            () => sharingMode = NotebookSharingMode.privateOnly,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _BookModeChoice(
                          label: 'Compartido',
                          icon: Icons.favorite_rounded,
                          selected:
                              sharingMode == NotebookSharingMode.sharedEdit,
                          accent: theme.terracotta,
                          theme: theme,
                          onTap: () => setDialogState(
                            () => sharingMode = NotebookSharingMode.sharedEdit,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _BookModeChoice(
                          label: 'Solo vista',
                          icon: Icons.visibility_outlined,
                          selected:
                              sharingMode == NotebookSharingMode.sharedViewOnly,
                          accent: theme.sage,
                          theme: theme,
                          onTap: () => setDialogState(
                            () => sharingMode =
                                NotebookSharingMode.sharedViewOnly,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '$hintDesc Empieza completamente vacío.',
                    style: RochyTypography.metadata(
                      theme.inkSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: sharingMode == NotebookSharingMode.sharedEdit
                      ? theme.terracotta
                      : theme.brandAccent,
                  foregroundColor: const Color(0xFFFAF7F2),
                ),
                onPressed: () {
                  final notifier = ref.read(bentoCanvasProvider.notifier);
                  final bookTitle = nameCtrl.text.trim();
                  notifier.createNotebook(
                    name: bookTitle,
                    subtitle: subtitleCtrl.text,
                    sharingMode: sharingMode,
                  );
                  Navigator.of(dialogContext).pop();
                  if (sharingMode != NotebookSharingMode.privateOnly &&
                      context.mounted) {
                    notifier.syncNowWithFirebase(silent: true);
                    _showQuickInviteDialog(
                      context,
                      ref,
                      theme,
                      bookName: bookTitle.isEmpty ? 'Nosotros' : bookTitle,
                    );
                  }
                },
                child: const Text('Crear vacío'),
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

Future<void> _showQuickInviteDialog(
  BuildContext context,
  WidgetRef ref,
  RochyThemeData theme, {
  required String bookName,
}) async {
  final canvas = ref.read(bentoCanvasProvider);
  final code = canvas.cloudConfig.coupleRoomId.trim().toUpperCase();
  final partner = canvas.otherPartnerDisplayName;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: theme.ivorySurface,
      title: Text(
        'Invitar a $partner',
        style: RochyTypography.cardSerifTitle(theme.inkPrimary, fontSize: 19),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '"$bookName" ya está listo. Comparte este código para que $partner se una:',
            style: RochyTypography.sansBody(theme.inkSecondary, fontSize: 12.5),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: theme.canvasBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.borderTint),
            ),
            child: SelectableText(
              code,
              textAlign: TextAlign.center,
              style: RochyTypography.cardSerifTitle(
                theme.terracotta,
                fontSize: 17,
              ),
            ),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Ahora no'),
        ),
        OutlinedButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: code));
            if (dialogContext.mounted) Navigator.of(dialogContext).pop();
            if (context.mounted) {
              ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                SnackBar(content: Text('Código copiado: $code')),
              );
            }
          },
          icon: const Icon(Icons.copy_rounded, size: 15),
          label: const Text('Copiar'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: theme.terracotta,
            foregroundColor: const Color(0xFFFAF7F2),
          ),
          onPressed: () async {
            Navigator.of(dialogContext).pop();
            final msg = '♥ Únete a nuestro cuaderno "$bookName" en Rochy\n'
                'Código: $code';
            await SharePlus.instance.share(
              ShareParams(text: msg, subject: 'Invitación a Rochy'),
            );
          },
          icon: const Icon(Icons.share_rounded, size: 15),
          label: const Text('Invitar'),
        ),
      ],
    ),
  );
}

class _BookModeChoice extends StatelessWidget {
  const _BookModeChoice({
    required this.label,
    required this.icon,
    required this.selected,
    required this.accent,
    required this.theme,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color accent;
  final RochyThemeData theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.14)
              : theme.canvasBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? accent : theme.borderTint,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              icon,
              size: 16,
              color: selected ? accent : theme.inkSecondary,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: RochyTypography.sansTitle(
                selected ? accent : theme.inkPrimary,
                fontSize: 10.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
