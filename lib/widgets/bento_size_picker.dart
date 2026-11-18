import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/bento_canvas_provider.dart';

Future<void> showBentoSizePicker(BuildContext context, String nodeId) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _BentoSizePicker(nodeId: nodeId),
    );

class _BentoSizePicker extends ConsumerWidget {
  const _BentoSizePicker({required this.nodeId});

  final String nodeId;
  static const _heights = ['Bajo', 'Normal', 'Alto', 'Grande', 'Extra alto'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nodes = ref.watch(bentoCanvasProvider).nodes;
    final index = nodes.indexWhere((n) => n.id == nodeId);
    if (index < 0) return const SizedBox.shrink();
    final node = nodes[index];
    final theme = ref.watch(activeRochyThemeProvider);
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.75,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
          child: Row(children: [
            const Expanded(
              child: Text('Tamaño de la tarjeta',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            ),
            IconButton(
              tooltip: 'Listo',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.check_rounded),
            ),
          ]),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Text('Elige un tamaño. El cambio se guarda al instante.'),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisExtent: 100,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: 10,
            itemBuilder: (context, i) {
              final cols = i % 2 + 1;
              final rows = i ~/ 2 + 1;
              final selected = node.colSpan == cols && node.rowSpan == rows;
              final label =
                  '${cols == 1 ? 'Medio ancho' : 'Ancho completo'} · ${_heights[rows - 1]}';
              return Semantics(
                selected: selected,
                button: true,
                label: label,
                child: Material(
                  color: selected
                      ? theme.brandAccent.withValues(alpha: 0.12)
                      : theme.ivorySurface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      width: selected ? 2 : 1,
                      color: selected ? theme.brandAccent : theme.borderTint,
                    ),
                  ),
                  child: InkWell(
                    key: ValueKey('bento_size_${cols}x$rows'),
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      ref.read(bentoCanvasProvider.notifier).resizeNode(
                            nodeId,
                            colSpan: cols,
                            rowSpan: rows,
                          );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(children: [
                        Expanded(
                          child: Center(
                            child: Container(
                              width: cols == 1 ? 32 : 68,
                              height: 12.0 + rows * 6,
                              decoration: BoxDecoration(
                                color: theme.brandAccent
                                    .withValues(alpha: selected ? 0.85 : 0.3),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: selected
                                  ? const Icon(Icons.check,
                                      size: 16, color: Colors.white)
                                  : null,
                            ),
                          ),
                        ),
                        Text(label,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            style: TextStyle(
                                fontSize: 12, color: theme.inkPrimary)),
                      ]),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}
