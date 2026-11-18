import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/bento_node.dart';
import '../providers/bento_canvas_provider.dart';
import '../theme/rochy_theme.dart';
import '../widgets/editors/entity_editor_sheet.dart';
import '../widgets/editors/module_picker_sheet.dart';
import '../widgets/editors/node_editor_sheet.dart';
import '../widgets/editors/notebook_switcher_sheet.dart';
import '../widgets/rochy_real_map_tab.dart';
import '../widgets/staggered_bento_grid.dart';

/// Pantalla principal de "Rochy".
///
/// Combina el lienzo Bento Scrapbook en la pestaña [Home] con vistas finitas y
/// coherentes para [Moments] (grafo por etiquetas), [Map] (lugares con historia)
/// y [Settings] (temas editoriales, textura de papel y perfil de entidad).
class BentoScrapbookView extends ConsumerWidget {
  const BentoScrapbookView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canvas = ref.watch(bentoCanvasProvider);
    final theme = ref.watch(activeRochyThemeProvider);

    if (canvas.isBiometricEnabled && !canvas.isUnlocked) {
      return _BiometricLockScreen(theme: theme, entityName: canvas.entity.name);
    }

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(canvas.textScaleFactor),
      ),
      child: Scaffold(
        backgroundColor: theme.canvasBackground,
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                theme.canvasBackground,
                theme.canvasSecondary,
              ],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () =>
                  ref.read(bentoCanvasProvider.notifier).clearNodeFocus(),
              child: IndexedStack(
                index: canvas.activeTabIndex,
                children: const <Widget>[
                  _HomeScrapbookTab(),
                  _MomentsGraphTab(),
                  RochyRealMapTab(),
                  _SettingsThemesTab(),
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: _MinimalBottomNavBar(
          theme: theme,
          currentIndex: canvas.activeTabIndex,
          onSelect: (index) {
            HapticFeedback.selectionClick();
            ref.read(bentoCanvasProvider.notifier).setTabIndex(index);
          },
        ),
      ),
    );
  }
}

/// Pestaña 0: Lienzo principal Bento Scrapbook personalizable por el usuario.
class _HomeScrapbookTab extends ConsumerWidget {
  const _HomeScrapbookTab();

  Future<void> _openAddModule(BuildContext context, WidgetRef ref) async {
    final chosenType = await showModulePickerSheet(context, ref);
    if (chosenType == null || !context.mounted) return;
    await showNodeEditorSheet(context, ref, type: chosenType);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canvas = ref.watch(bentoCanvasProvider);
    final theme = ref.watch(activeRochyThemeProvider);
    final selectedNode = canvas.selectedNode;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    _HeaderActionButton(
                      icon: canvas.isEditMode
                          ? Icons.check_rounded
                          : Icons.tune_rounded,
                      tooltip: canvas.isEditMode
                          ? 'Terminar edición'
                          : 'Editar y reordenar tarjetas',
                      active: canvas.isEditMode,
                      theme: theme,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        ref
                            .read(bentoCanvasProvider.notifier)
                            .toggleEditMode();
                      },
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => showNotebookSwitcherSheet(context, ref),
                        onLongPress: () => showEntityEditorSheet(context, ref),
                        child: Column(
                          children: <Widget>[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Flexible(
                                  child: Text(
                                    canvas.entity.name,
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: RochyTypography.brandTitle(
                                      theme.brandAccent,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 20,
                                  color: theme.brandAccent.withValues(alpha: 0.7),
                                ),
                              ],
                            ),
                            if (canvas.isEditMode)
                              Text(
                                'Arrastra para mover · Tira de los bordes blancos',
                                style: RochyTypography.metadata(
                                  theme.brandAccent,
                                  fontSize: 10.2,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    _HeaderActionButton(
                      icon: Icons.add_rounded,
                      tooltip: 'Añadir módulo',
                      active: true,
                      theme: theme,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _openAddModule(context, ref);
                      },
                    ),
                  ],
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  child: selectedNode == null
                      ? const SizedBox(height: 4)
                      : Padding(
                          padding: const EdgeInsets.only(top: 10, bottom: 2),
                          child: _RelationFocusBanner(
                            theme: theme,
                            selectedNode: selectedNode,
                            linkedCount: canvas.relatedNodeIds.length,
                            isConnectingMode: canvas.isConnectingMode,
                            onEdit: () => showNodeEditorSheet(
                              context,
                              ref,
                              type: selectedNode.type,
                              existingNode: selectedNode,
                            ),
                            onClear: () => ref
                                .read(bentoCanvasProvider.notifier)
                                .clearNodeFocus(),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
        if (canvas.nodes.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(
                    Icons.dashboard_customize_rounded,
                    size: 46,
                    color: theme.brandAccent.withValues(alpha: 0.7),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Lienzo en blanco para ${canvas.entity.name}',
                    textAlign: TextAlign.center,
                    style: RochyTypography.cardSerifTitle(
                      theme.inkPrimary,
                      fontSize: 21,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Arma su perfil vivo eligiendo módulos: fotos, citas, cafés favoritos, cartas, colores o lugares.',
                    textAlign: TextAlign.center,
                    style: RochyTypography.sansBody(
                      theme.inkSecondary,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.brandAccent,
                      foregroundColor: const Color(0xFFFAF7F2),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 13,
                      ),
                      shape: const StadiumBorder(),
                    ),
                    onPressed: () => _openAddModule(context, ref),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Elegir primer módulo'),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => ref
                        .read(bentoCanvasProvider.notifier)
                        .restoreStarterTemplate(),
                    child: Text(
                      'Cargar plantilla de inspiración',
                      style: RochyTypography.sansTitle(
                        theme.inkSecondary,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        else ...<Widget>[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
            sliver: SliverToBoxAdapter(
              child: StaggeredBentoGrid(nodes: canvas.nodes),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
              child: Center(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.brandAccent,
                    backgroundColor: theme.ivorySurface.withValues(alpha: 0.7),
                    side: BorderSide(
                      color: theme.brandAccent.withValues(alpha: 0.35),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 11,
                    ),
                    shape: const StadiumBorder(),
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    _openAddModule(context, ref);
                  },
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 17),
                  label: Text(
                    'Añadir otro módulo (13 tipos)',
                    style: RochyTypography.sansTitle(
                      theme.brandAccent,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _HeaderActionButton extends StatelessWidget {
  const _HeaderActionButton({
    required this.icon,
    required this.tooltip,
    required this.active,
    required this.theme,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool active;
  final RochyThemeData theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: active ? theme.brandAccent : theme.ivorySurface,
            shape: BoxShape.circle,
            border: Border.all(
              color: active ? theme.brandAccent : theme.borderTint,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: const Color(0xFF2D1E16).withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            icon,
            size: 19,
            color: active ? const Color(0xFFFAF7F2) : theme.inkPrimary,
          ),
        ),
      ),
    );
  }
}

class _RelationFocusBanner extends StatelessWidget {
  const _RelationFocusBanner({
    required this.theme,
    required this.selectedNode,
    required this.linkedCount,
    required this.isConnectingMode,
    required this.onEdit,
    required this.onClear,
  });

  final RochyThemeData theme;
  final BentoNode selectedNode;
  final int linkedCount;
  final bool isConnectingMode;
  final VoidCallback onEdit;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 7, 10, 7),
      decoration: BoxDecoration(
        color: isConnectingMode ? theme.brandAccent : theme.ivorySurface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isConnectingMode
              ? theme.brandAccent
              : theme.haloColor.withValues(alpha: 0.65),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: theme.haloColor.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            isConnectingMode ? Icons.link_rounded : Icons.hub_rounded,
            size: 14,
            color: isConnectingMode
                ? const Color(0xFFFAF7F2)
                : theme.brandAccent,
          ),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              isConnectingMode
                  ? 'Toca otra tarjeta para unir ($linkedCount)'
                  : '${selectedNode.displayTitle} · $linkedCount vínculos',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: RochyTypography.metadata(
                isConnectingMode ? const Color(0xFFFAF7F2) : theme.inkPrimary,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (!isConnectingMode) ...<Widget>[
            GestureDetector(
              onTap: onEdit,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: theme.brandAccent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Editar',
                  style: RochyTypography.metadata(
                    theme.brandAccent,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
          GestureDetector(
            onTap: onClear,
            child: Container(
              padding: isConnectingMode
                  ? const EdgeInsets.symmetric(horizontal: 8, vertical: 3)
                  : EdgeInsets.zero,
              decoration: isConnectingMode
                  ? BoxDecoration(
                      color: const Color(0xFFFAF7F2).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(999),
                    )
                  : null,
              child: isConnectingMode
                  ? Text(
                      'Listo',
                      style: RochyTypography.metadata(
                        const Color(0xFFFAF7F2),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: theme.inkSecondary,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pestaña 1: Explorador relacional filtrado por etiquetas del cuaderno.
class _MomentsGraphTab extends ConsumerWidget {
  const _MomentsGraphTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canvas = ref.watch(bentoCanvasProvider);
    final theme = ref.watch(activeRochyThemeProvider);
    final activeTag = canvas.activeTagFilter;
    final favCount = canvas.nodes.where((n) => n.isFavorite).length;

    final filtered = activeTag == null
        ? canvas.nodes
        : activeTag == '__favorites__'
            ? canvas.nodes.where((n) => n.isFavorite).toList()
            : canvas.nodes.where((n) => n.tags.contains(activeTag)).toList();

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
      children: <Widget>[
        Text(
          'Momentos & Hilos',
          style: RochyTypography.brandTitle(theme.brandAccent).copyWith(
            fontSize: 25,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Explora cómo se entrelazan sus hábitos, lugares y frases.',
          style: RochyTypography.sansBody(theme.inkSecondary, fontSize: 13),
        ),
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: <Widget>[
              _FilterChipPill(
                label: 'Todos (${canvas.nodes.length})',
                selected: activeTag == null,
                theme: theme,
                onTap: () => ref
                    .read(bentoCanvasProvider.notifier)
                    .toggleTagFilter(null),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: _FilterChipPill(
                  label: '♥ Favoritos ($favCount)',
                  selected: activeTag == '__favorites__',
                  theme: theme,
                  onTap: () => ref
                      .read(bentoCanvasProvider.notifier)
                      .toggleTagFilter('__favorites__'),
                ),
              ),
              ...canvas.allTags.map((tag) {
                return Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: _FilterChipPill(
                    label: '#$tag',
                    selected: activeTag == tag,
                    theme: theme,
                    onTap: () => ref
                        .read(bentoCanvasProvider.notifier)
                        .toggleTagFilter(tag),
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ...filtered.map((node) {
          final cardBg = theme.cardSurface(node.colorTheme);
          final primaryInk = theme.cardPrimaryText(node.colorTheme);
          final secondaryInk = theme.cardSecondaryText(node.colorTheme);

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: () {
                HapticFeedback.selectionClick();
                final notifier = ref.read(bentoCanvasProvider.notifier);
                notifier.setTabIndex(0);
                notifier.toggleNodeFocus(node.id);
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: theme.borderTint),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: const Color(0xFF2D1E16).withValues(alpha: 0.06),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: primaryInk.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              _typeLabel(node.type),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: RochyTypography.metadata(
                                primaryInk,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.hub_rounded,
                          size: 13,
                          color: secondaryInk,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${node.linkedNodeIds.length} vínculos',
                          style: RochyTypography.metadata(
                            secondaryInk,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      node.displayTitle,
                      style: RochyTypography.cardSerifTitle(
                        primaryInk,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: node.tags.map((tag) {
                        return Text(
                          '#$tag',
                          style: RochyTypography.metadata(
                            secondaryInk,
                            fontSize: 11,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  String _typeLabel(BentoNodeType type) => type.displayName;
}

class _FilterChipPill extends StatelessWidget {
  const _FilterChipPill({
    required this.label,
    required this.selected,
    required this.theme,
    required this.onTap,
  });

  final String label;
  final bool selected;
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
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? theme.brandAccent : theme.ivorySurface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? theme.brandAccent : theme.borderTint,
          ),
        ),
        child: Text(
          label,
          style: RochyTypography.metadata(
            selected ? const Color(0xFFFAF7F2) : theme.inkPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Pestaña 3: Personalización editorial, temas de color, tipografía y respaldo JSON.
class _SettingsThemesTab extends ConsumerWidget {
  const _SettingsThemesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canvas = ref.watch(bentoCanvasProvider);
    final theme = ref.watch(activeRochyThemeProvider);
    final entity = canvas.entity;

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
      children: <Widget>[
        Text(
          'Cuaderno & Estilo',
          style: RochyTypography.brandTitle(theme.brandAccent).copyWith(
            fontSize: 25,
          ),
        ),
        const SizedBox(height: 14),

        // Tarjeta de entidad (Sujeto central del Memory Graph)
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: theme.ivorySurface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: theme.borderTint),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: const Color(0xFF2D1E16).withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.asset(
                      'assets/icon/rochy_icon.png',
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return CircleAvatar(
                          radius: 24,
                          backgroundColor:
                              theme.terracotta.withValues(alpha: 0.16),
                          child: Text(
                            entity.name.substring(0, 1),
                            style: RochyTypography.cardSerifTitle(
                              theme.brandAccent,
                              fontSize: 22,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          entity.name,
                          style: RochyTypography.cardSerifTitle(
                            theme.inkPrimary,
                            fontSize: 20,
                          ),
                        ),
                        Text(
                          entity.subtitle,
                          style: RochyTypography.metadata(
                            theme.inkSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                entity.shortBio,
                style: RochyTypography.sansBody(
                  theme.inkSecondary,
                  fontSize: 13.5,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.brandAccent,
                        side: BorderSide(
                          color: theme.brandAccent.withValues(alpha: 0.45),
                        ),
                        shape: const StadiumBorder(),
                      ),
                      onPressed: () => showEntityEditorSheet(context, ref),
                      icon: const Icon(Icons.edit_rounded, size: 15),
                      label: const Text('Editar persona'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.inkSecondary,
                        side: BorderSide(color: theme.borderTint),
                        shape: const StadiumBorder(),
                      ),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (dialogContext) => AlertDialog(
                            backgroundColor: theme.ivorySurface,
                            title: Text(
                              '¿Vaciar el lienzo actual?',
                              style: RochyTypography.cardSerifTitle(
                                theme.inkPrimary,
                                fontSize: 18,
                              ),
                            ),
                            content: const Text(
                              'Se quitarán las tarjetas de este cuaderno para que empieces desde cero. Siempre puedes restaurar la plantilla o crear otro cuaderno.',
                            ),
                            actions: <Widget>[
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(dialogContext).pop(false),
                                child: const Text('Cancelar'),
                              ),
                              FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: theme.terracotta,
                                ),
                                onPressed: () =>
                                    Navigator.of(dialogContext).pop(true),
                                child: const Text('Vaciar'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          HapticFeedback.mediumImpact();
                          ref.read(bentoCanvasProvider.notifier).clearCanvas();
                          ref.read(bentoCanvasProvider.notifier).setTabIndex(0);
                        }
                      },
                      icon: const Icon(Icons.layers_clear_rounded, size: 15),
                      label: const Text('Lienzo en blanco'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),

        Text(
          'Atmósfera cromática',
          style: RochyTypography.cardSerifTitle(theme.inkPrimary, fontSize: 18),
        ),
        const SizedBox(height: 10),
        ...RochyThemes.all.map((candidate) {
          final isActive = candidate.id == theme.id;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                HapticFeedback.selectionClick();
                ref.read(bentoCanvasProvider.notifier).selectTheme(candidate.id);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.ivorySurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isActive ? theme.brandAccent : theme.borderTint,
                    width: isActive ? 1.8 : 1.0,
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    // Muestras de paleta
                    Row(
                      children: <Color>[
                        candidate.canvasBackground,
                        candidate.terracotta,
                        candidate.sage,
                        candidate.espresso,
                      ].map((swatch) {
                        return Container(
                          width: 18,
                          height: 18,
                          margin: const EdgeInsets.only(right: 4),
                          decoration: BoxDecoration(
                            color: swatch,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.black.withValues(alpha: 0.12),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            candidate.name,
                            style: RochyTypography.sansTitle(
                              theme.inkPrimary,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            candidate.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: RochyTypography.metadata(
                              theme.inkSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isActive)
                      Icon(
                        Icons.check_circle_rounded,
                        color: theme.brandAccent,
                        size: 20,
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 14),

        // Ajustes táctiles y de lectura
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.ivorySurface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: theme.borderTint),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              children: <Widget>[
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                activeTrackColor: theme.brandAccent,
                title: Text(
                  'Micro-textura de papel artesanal',
                  style: RochyTypography.sansTitle(
                    theme.inkPrimary,
                    fontSize: 13.5,
                  ),
                ),
                subtitle: Text(
                  'Agrega grano sutil de fibra sobre cada tarjeta',
                  style: RochyTypography.metadata(
                    theme.inkSecondary,
                    fontSize: 11.5,
                  ),
                ),
                value: canvas.showPaperGrain,
                onChanged: (value) {
                  HapticFeedback.selectionClick();
                  ref
                      .read(bentoCanvasProvider.notifier)
                      .togglePaperGrain(value);
                },
              ),
              const Divider(height: 18),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                activeTrackColor: theme.brandAccent,
                title: Text(
                  'Bloqueo privado (Huella / Face ID)',
                  style: RochyTypography.sansTitle(
                    theme.inkPrimary,
                    fontSize: 13.5,
                  ),
                ),
                subtitle: Text(
                  'Protege tu cuaderno al abrir la aplicación',
                  style: RochyTypography.metadata(
                    theme.inkSecondary,
                    fontSize: 11.5,
                  ),
                ),
                value: canvas.isBiometricEnabled,
                onChanged: (value) async {
                  HapticFeedback.selectionClick();
                  if (value) {
                    final ok = await ref
                        .read(mediaAndAuthServiceProvider)
                        .authenticate(
                          reason: 'Activa el bloqueo privado en Rochy',
                        );
                    if (ok) {
                      ref
                          .read(bentoCanvasProvider.notifier)
                          .setBiometricEnabled(true);
                    }
                  } else {
                    ref
                        .read(bentoCanvasProvider.notifier)
                        .setBiometricEnabled(false);
                  }
                },
              ),
              const Divider(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    'Escala tipográfica',
                    style: RochyTypography.sansTitle(
                      theme.inkPrimary,
                      fontSize: 13.5,
                    ),
                  ),
                  Text(
                    '${(canvas.textScaleFactor * 100).round()}%',
                    style: RochyTypography.metadata(
                      theme.brandAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Slider(
                value: canvas.textScaleFactor,
                min: 0.92,
                max: 1.12,
                divisions: 4,
                activeColor: theme.brandAccent,
                onChanged: (value) {
                  ref
                      .read(bentoCanvasProvider.notifier)
                      .setTextScaleFactor(value);
                },
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.brandAccent,
                    side: BorderSide(color: theme.brandAccent.withValues(alpha: 0.5)),
                    shape: const StadiumBorder(),
                  ),
                  onPressed: () {
                    final snapshot = ref
                        .read(bentoRepositoryProvider)
                        .exportJsonSnapshot();
                    showDialog<void>(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        backgroundColor: theme.ivorySurface,
                        title: Text(
                          'Snapshot Serializable (Isar / Drift)',
                          style: RochyTypography.cardSerifTitle(
                            theme.inkPrimary,
                            fontSize: 18,
                          ),
                        ),
                        content: SingleChildScrollView(
                          child: SelectableText(
                            snapshot,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                            ),
                          ),
                        ),
                        actions: <Widget>[
                          TextButton(
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: snapshot));
                              Navigator.of(dialogContext).pop();
                            },
                            child: const Text('Copiar JSON'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            child: const Text('Cerrar'),
                          ),
                        ],
                      ),
                    );
                  },
                  icon: const Icon(Icons.data_object_rounded, size: 16),
                  label: const Text('Inspeccionar / copiar respaldo JSON'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.brandAccent,
                    side: BorderSide(
                      color: theme.brandAccent.withValues(alpha: 0.4),
                    ),
                    shape: const StadiumBorder(),
                  ),
                  onPressed: () async {
                    final ctrl = TextEditingController();
                    await showDialog<void>(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        backgroundColor: theme.ivorySurface,
                        title: Text(
                          'Restaurar desde respaldo JSON',
                          style: RochyTypography.cardSerifTitle(
                            theme.inkPrimary,
                            fontSize: 18,
                          ),
                        ),
                        content: TextField(
                          controller: ctrl,
                          maxLines: 6,
                          decoration: const InputDecoration(
                            hintText: 'Pega aquí el JSON exportado…',
                            border: OutlineInputBorder(),
                          ),
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
                              try {
                                ref
                                    .read(bentoCanvasProvider.notifier)
                                    .importJsonSnapshot(ctrl.text);
                                Navigator.of(dialogContext).pop();
                                ref
                                    .read(bentoCanvasProvider.notifier)
                                    .setTabIndex(0);
                              } catch (_) {
                                ScaffoldMessenger.maybeOf(context)
                                    ?.showSnackBar(
                                  const SnackBar(
                                    content: Text('JSON inválido o incompleto'),
                                  ),
                                );
                              }
                            },
                            child: const Text('Restaurar'),
                          ),
                        ],
                      ),
                    );
                    ctrl.dispose();
                  },
                  icon: const Icon(Icons.restore_page_rounded, size: 16),
                  label: const Text('Importar respaldo JSON'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.inkSecondary,
                    side: BorderSide(color: theme.borderTint),
                    shape: const StadiumBorder(),
                  ),
                  onPressed: () => showNotebookSwitcherSheet(context, ref),
                  icon: const Icon(Icons.bookmarks_rounded, size: 16),
                  label: const Text('Cambiar o crear otro cuaderno'),
                ),
              ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Barra de navegación inferior minimalista idéntica al lenguaje visual de Rochy.
class _MinimalBottomNavBar extends StatelessWidget {
  const _MinimalBottomNavBar({
    required this.theme,
    required this.currentIndex,
    required this.onSelect,
  });

  final RochyThemeData theme;
  final int currentIndex;
  final ValueChanged<int> onSelect;

  static const _items = <({IconData icon, IconData activeIcon, String label})>[
    (
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'Home',
    ),
    (
      icon: Icons.photo_library_outlined,
      activeIcon: Icons.photo_library_rounded,
      label: 'Moments',
    ),
    (
      icon: Icons.location_on_outlined,
      activeIcon: Icons.location_on_rounded,
      label: 'Map',
    ),
    (
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings_rounded,
      label: 'Settings',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.navBarBackground.withValues(alpha: 0.97),
        border: Border(
          top: BorderSide(
            color: theme.inkSecondary.withValues(alpha: 0.14),
            width: 0.8,
          ),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF2D1E16).withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List<Widget>.generate(_items.length, (index) {
              final item = _items[index];
              final isActive = index == currentIndex;
              final color =
                  isActive ? theme.brandAccent : theme.inkSecondary;

              return Expanded(
                child: InkWell(
                  onTap: () => onSelect(index),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      AnimatedScale(
                        duration: const Duration(milliseconds: 180),
                        scale: isActive ? 1.08 : 1.0,
                        child: Icon(
                          isActive ? item.activeIcon : item.icon,
                          size: 22,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.label,
                        style: RochyTypography.metadata(
                          color,
                          fontSize: 11,
                          fontWeight:
                              isActive ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

/// Pantalla de bloqueo biométrico íntimo cuando está activado en Ajustes.
class _BiometricLockScreen extends ConsumerWidget {
  const _BiometricLockScreen({
    required this.theme,
    required this.entityName,
  });

  final RochyThemeData theme;
  final String entityName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: theme.canvasBackground,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset(
                    'assets/icon/rochy_icon.png',
                    width: 84,
                    height: 84,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return CircleAvatar(
                        radius: 40,
                        backgroundColor:
                            theme.brandAccent.withValues(alpha: 0.14),
                        child: Icon(
                          Icons.lock_rounded,
                          size: 32,
                          color: theme.brandAccent,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  entityName,
                  style: RochyTypography.brandTitle(theme.brandAccent),
                ),
                const SizedBox(height: 8),
                Text(
                  'Este cuaderno está protegido de forma privada.',
                  textAlign: TextAlign.center,
                  style: RochyTypography.sansBody(
                    theme.inkSecondary,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 26),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.brandAccent,
                    foregroundColor: const Color(0xFFFAF7F2),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    shape: const StadiumBorder(),
                  ),
                  onPressed: () async {
                    HapticFeedback.lightImpact();
                    final ok = await ref
                        .read(mediaAndAuthServiceProvider)
                        .authenticate();
                    if (ok) {
                      ref
                          .read(bentoCanvasProvider.notifier)
                          .unlockWithBiometrics();
                    }
                  },
                  icon: const Icon(Icons.fingerprint_rounded, size: 20),
                  label: const Text('Desbloquear cuaderno'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
