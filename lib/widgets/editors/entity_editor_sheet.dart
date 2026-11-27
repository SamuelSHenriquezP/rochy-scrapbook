import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/bento_node.dart';
import '../../providers/bento_canvas_provider.dart';
import '../../theme/rochy_theme.dart';

/// Editor del perfil central de la persona ([BentoEntity]).
Future<void> showEntityEditorSheet(BuildContext context, WidgetRef ref) async {
  final state = ref.read(bentoCanvasProvider);
  if (state.isActiveNotebookReadOnly) return;
  final theme = ref.read(activeRochyThemeProvider);
  final entity = state.entity;
  final aboutHim = state.isTalkingAboutHim;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return _EntityEditorForm(
        entity: entity,
        theme: theme,
        aboutHim: aboutHim,
        onSave: (updated) {
          ref.read(bentoCanvasProvider.notifier).updateEntity(updated);
          Navigator.of(sheetContext).pop();
        },
      );
    },
  );
}

class _EntityEditorForm extends StatefulWidget {
  const _EntityEditorForm({
    required this.entity,
    required this.theme,
    required this.aboutHim,
    required this.onSave,
  });

  final BentoEntity entity;
  final RochyThemeData theme;
  final bool aboutHim;
  final ValueChanged<BentoEntity> onSave;

  @override
  State<_EntityEditorForm> createState() => _EntityEditorFormState();
}

class _EntityEditorFormState extends State<_EntityEditorForm> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _subtitleCtrl;
  late final TextEditingController _bioCtrl;
  late DateTime _birthDate;
  late DateTime _anniversaryDate;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.entity.name);
    _subtitleCtrl = TextEditingController(text: widget.entity.subtitle);
    _bioCtrl = TextEditingController(text: widget.entity.shortBio);
    _birthDate = widget.entity.birthDate;
    _anniversaryDate = widget.entity.anniversaryDate;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _subtitleCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isBirth}) async {
    final initial = isBirth ? _birthDate : _anniversaryDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1950),
      lastDate: DateTime(2040),
    );
    if (picked == null) return;
    setState(() {
      if (isBirth) {
        _birthDate = picked;
      } else {
        _anniversaryDate = picked;
      }
    });
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(22, 16, 22, 24 + bottomInset),
      decoration: BoxDecoration(
        color: theme.canvasBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        border: Border.all(color: theme.borderTint),
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
                  color: theme.inkSecondary.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Perfil de la persona',
              style: RochyTypography.brandTitle(theme.brandAccent)
                  .copyWith(fontSize: 23),
            ),
            const SizedBox(height: 14),
            _fieldLabel('Nombre o apodo', theme),
            TextField(
              controller: _nameCtrl,
              decoration: _inputDeco('Ej. Rochy, Camila…', theme),
            ),
            const SizedBox(height: 12),
            _fieldLabel('Subtítulo del cuaderno', theme),
            TextField(
              controller: _subtitleCtrl,
              decoration: _inputDeco('Ej. Su mundo en pequeñas piezas', theme),
            ),
            const SizedBox(height: 12),
            _fieldLabel('Biografía breve / esencia', theme),
            TextField(
              controller: _bioCtrl,
              maxLines: 3,
              decoration: _inputDeco(
                'Qué ${widget.aboutHim ? 'lo' : 'la'} hace especial…',
                theme,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDate(isBirth: true),
                    icon: const Icon(Icons.cake_rounded, size: 16),
                    label: Text('Cumple: ${_formatDate(_birthDate)}'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDate(isBirth: false),
                    icon: const Icon(Icons.favorite_rounded, size: 16),
                    label: Text('Inicio: ${_formatDate(_anniversaryDate)}'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: theme.brandAccent,
                  foregroundColor: const Color(0xFFFAF7F2),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: const StadiumBorder(),
                ),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  final name = _nameCtrl.text.trim();
                  widget.onSave(
                    widget.entity.copyWith(
                      name: name.isEmpty ? widget.entity.name : name,
                      subtitle: _subtitleCtrl.text.trim(),
                      shortBio: _bioCtrl.text.trim(),
                      birthDate: _birthDate,
                      anniversaryDate: _anniversaryDate,
                    ),
                  );
                },
                child: const Text('Guardar perfil'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fieldLabel(String text, RochyThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: RochyTypography.metadata(
          theme.inkSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String hint, RochyThemeData theme) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: theme.ivorySurface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: theme.borderTint),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: theme.borderTint),
      ),
    );
  }
}
