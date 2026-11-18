import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/bento_node.dart';
import '../../providers/bento_canvas_provider.dart';
import '../../services/location_service.dart';
import '../../theme/rochy_theme.dart';
import '../map_location_picker_sheet.dart';
import '../staggered_bento_grid.dart';

/// Editor editorial en 2 pasos ("Por partes") con vista previa fija en vivo,
/// selector directo "Del teléfono / Por link" y alta personalización visual.
Future<void> showNodeEditorSheet(
  BuildContext context,
  WidgetRef ref, {
  required BentoNodeType type,
  BentoNode? existingNode,
  PickedMapLocation? initialLocation,
}) async {
  final theme = ref.read(activeRochyThemeProvider);
  final messenger = ScaffoldMessenger.maybeOf(context);

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return DraggableScrollableSheet(
        initialChildSize: 0.91,
        minChildSize: 0.58,
        maxChildSize: 0.96,
        builder: (context, scrollController) {
          return _NodeEditorSheetBody(
            type: existingNode?.type ?? type,
            existingNode: existingNode,
            initialLocation: initialLocation,
            theme: theme,
            scrollController: scrollController,
            onSave: (node) {
              final notifier = ref.read(bentoCanvasProvider.notifier);
              if (existingNode == null) {
                notifier.addNode(node);
              } else {
                notifier.updateNode(node);
              }
              Navigator.of(sheetContext).pop();
            },
            onDelete: existingNode == null
                ? null
                : () {
                    final notifier = ref.read(bentoCanvasProvider.notifier);
                    final removed = notifier.deleteNode(existingNode.id);
                    Navigator.of(sheetContext).pop();
                    if (removed != null && messenger != null) {
                      messenger.clearSnackBars();
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            'Eliminado: ${removed.node.displayTitle}',
                          ),
                          action: SnackBarAction(
                            label: 'Deshacer',
                            onPressed: () {
                              notifier.restoreDeletedNode(
                                removed.node,
                                removed.index,
                              );
                            },
                          ),
                        ),
                      );
                    }
                  },
          );
        },
      );
    },
  );
}

class _NodeEditorSheetBody extends ConsumerStatefulWidget {
  const _NodeEditorSheetBody({
    required this.type,
    required this.existingNode,
    this.initialLocation,
    required this.theme,
    required this.scrollController,
    required this.onSave,
    this.onDelete,
  });

  final BentoNodeType type;
  final BentoNode? existingNode;
  final PickedMapLocation? initialLocation;
  final RochyThemeData theme;
  final ScrollController scrollController;
  final ValueChanged<BentoNode> onSave;
  final VoidCallback? onDelete;

  @override
  ConsumerState<_NodeEditorSheetBody> createState() =>
      _NodeEditorSheetBodyState();
}

class _NodeEditorSheetBodyState extends ConsumerState<_NodeEditorSheetBody> {
  int _step = 0; // 0 = Contenido, 1 = Estilo & Diseño
  bool _useLinkSource = false;

  late int _colSpan;
  late int _rowSpan;
  late BentoColorTheme _colorTheme;
  int? _customBgColorHex;
  late bool _useGradient;
  late double _borderRadius;
  late BentoCardDesign _cardDesign;
  late BentoFontStyle _fontStyle;
  late BentoTextAlign _textAlign;
  late double _titleScale;
  late bool _isTitleBold;

  late final TextEditingController _titleCtrl;
  late final TextEditingController _secondaryCtrl;
  late final TextEditingController _tertiaryCtrl;
  late final TextEditingController _bodyCtrl;
  late final TextEditingController _mediaLinkCtrl;
  late final TextEditingController _itemsCtrl;
  late String _iconKey;
  late LocationPinStyle _pinStyle;
  late String _countMode;
  late DateTime _targetDate;
  late String _bookOrMovie;
  late int _rating;
  late List<int> _paletteHexes;
  late String _videoSource;
  late String _localAudioPath;
  late bool _autoPlayMuted;
  double? _latitude;
  double? _longitude;
  bool _isLocatingGps = false;
  bool _isRecordingAudio = false;
  Timer? _linkInspectDebounce;

  /// Paleta amplia curada de 12 tonos editoriales para personalizar cualquier tarjeta.
  static const _customPaletteHexes = <int>[
    0xFFF5F1EB, // Marfil
    0xFFEFE8DF, // Arena
    0xFFEAD4C4, // Durazno suave
    0xFFA85338, // Terracota
    0xFFC27255, // Arcilla tibia
    0xFF5B6E58, // Salvia
    0xFF7D9177, // Olivo claro
    0xFF6B3D22, // Café tostado
    0xFF382923, // Espresso oscuro
    0xFF4F5D73, // Azul pizarra
    0xFF8C6B75, // Malva apagado
    0xFFD4A373, // Miel tostada
  ];

  @override
  void initState() {
    super.initState();
    final existing = widget.existingNode;
    _colSpan = existing?.colSpan ?? _defaultColSpan(widget.type);
    _rowSpan = existing?.rowSpan ?? _defaultRowSpan(widget.type);
    _colorTheme = existing?.colorTheme ?? _defaultColor(widget.type);
    _customBgColorHex = existing?.customBgColorHex;
    _useGradient = existing?.useGradient ?? false;
    _borderRadius = existing?.borderRadius ?? 24.0;
    _cardDesign = existing?.cardDesign ?? BentoCardDesign.editorial;
    _fontStyle = existing?.fontStyle ?? BentoFontStyle.editorialSerif;
    _textAlign = existing?.textAlign ?? BentoTextAlign.left;
    _titleScale = existing?.titleScale ?? 1.0;
    _isTitleBold = existing?.isTitleBold ?? true;

    _iconKey = 'coffee';
    _pinStyle = LocationPinStyle.polaroid;
    _countMode = 'since';
    _targetDate = DateTime.now();
    _bookOrMovie = 'book';
    _rating = 5;
    _paletteHexes = <int>[0xFFA85338, 0xFF5B6E58, 0xFFE2B89B, 0xFF6B3D22];
    _videoSource = '';
    _localAudioPath = '';
    _autoPlayMuted = true;

    String t = '';
    String sec = '';
    String ter = '';
    String body = '';
    String media = '';
    String items = '';

    final payload = existing?.payload;
    if (payload == null && widget.initialLocation != null) {
      final loc = widget.initialLocation!;
      _latitude = loc.latitude;
      _longitude = loc.longitude;
      if (widget.type == BentoNodeType.locationPin) {
        t = loc.placeName;
        ter = loc.coordinatesLabel;
      } else {
        ter = loc.placeName;
      }
    }
    if (payload != null) {
      switch (payload) {
        case final PhotoHeroPayload p:
          t = p.title;
          sec = p.dateLabel;
          ter = p.locationLabel;
          body = p.storyBody;
          media = p.imageUrl;
          _latitude = p.latitude;
          _longitude = p.longitude;
        case final VideoMemoryPayload p:
          t = p.title;
          sec = p.dateLabel;
          ter = p.locationLabel;
          body = p.caption;
          _videoSource = p.videoSource;
          media = p.videoSource;
          _autoPlayMuted = p.autoPlayMuted;
          _latitude = p.latitude;
          _longitude = p.longitude;
        case final FlipDetailPayload p:
          t = p.title;
          sec = p.microText;
          ter = p.recordedDateLabel;
          body = p.backSubtitle;
          _iconKey = p.iconKey;
          _localAudioPath = p.localAudioPath;
        case final QuotePayload p:
          t = p.quoteText;
          sec = p.contextLabel;
        case final AudioNotePayload p:
          t = p.title;
          sec = p.subtitle;
          media = p.coverImageUrl;
          _localAudioPath = p.localAudioPath;
        case final CheckListPayload p:
          t = p.title;
          sec = p.footerHint;
          items = p.items.map((e) => e.text).join('\n');
        case final LocationPinPayload p:
          t = p.placeName;
          sec = p.caption;
          ter = p.coordinatesLabel;
          body = p.memoryNote;
          media = p.imageUrl;
          _pinStyle = p.style;
          _latitude = p.latitude;
          _longitude = p.longitude;
        case final CountdownPayload p:
          t = p.title;
          sec = p.subtitle;
          _targetDate = p.targetDate;
          _countMode = p.countMode;
        case final PaletteMoodPayload p:
          t = p.title;
          sec = p.scentNote;
          items = p.moodWords.join(', ');
          _paletteHexes = List<int>.of(p.swatchHexes);
        case final BookMoviePayload p:
          t = p.title;
          sec = p.creator;
          body = p.personalNote;
          _bookOrMovie = p.kind;
          _rating = p.rating;
        case final GiftWishPayload p:
          t = p.title;
          items = p.items.map((e) => e.text).join('\n');
        case final LoveLetterPayload p:
          t = p.title;
          sec = p.previewLine;
          body = p.letterBody;
          ter = p.signature;
        case final HabitChipsPayload p:
          t = p.title;
          sec = p.footnote;
          items = p.habits.join('\n');
      }
    }

    _useLinkSource =
        media.startsWith('http://') || media.startsWith('https://');

    _titleCtrl = TextEditingController(text: t)..addListener(_refreshPreview);
    _secondaryCtrl = TextEditingController(text: sec)
      ..addListener(_refreshPreview);
    _tertiaryCtrl = TextEditingController(text: ter)
      ..addListener(_refreshPreview);
    _bodyCtrl = TextEditingController(text: body)..addListener(_refreshPreview);
    _mediaLinkCtrl = TextEditingController(text: media)
      ..addListener(_refreshPreview);
    _itemsCtrl = TextEditingController(text: items)
      ..addListener(_refreshPreview);
  }

  void _refreshPreview() {
    if (widget.type == BentoNodeType.videoMemory && _useLinkSource) {
      _videoSource = _mediaLinkCtrl.text.trim();
    }
    if (_useLinkSource &&
        (widget.type == BentoNodeType.photoHero ||
            widget.type == BentoNodeType.videoMemory)) {
      _scheduleLinkAspectDetect(_mediaLinkCtrl.text.trim());
    }
    if (mounted) setState(() {});
  }

  void _scheduleLinkAspectDetect(String url) {
    _linkInspectDebounce?.cancel();
    if (!url.startsWith('http://') && !url.startsWith('https://')) return;
    _linkInspectDebounce = Timer(const Duration(milliseconds: 650), () async {
      final service = ref.read(mediaAndAuthServiceProvider);
      final ratio = widget.type == BentoNodeType.videoMemory
          ? await service.detectVideoAspectRatio(url)
          : await service.detectImageAspectRatio(url);
      if (mounted) _applyAspectRatioToGrid(ratio);
    });
  }

  @override
  void dispose() {
    _linkInspectDebounce?.cancel();
    _titleCtrl.dispose();
    _secondaryCtrl.dispose();
    _tertiaryCtrl.dispose();
    _bodyCtrl.dispose();
    _mediaLinkCtrl.dispose();
    _itemsCtrl.dispose();
    super.dispose();
  }

  int _defaultColSpan(BentoNodeType t) =>
      (t == BentoNodeType.photoHero || t == BentoNodeType.videoMemory) ? 2 : 1;

  int _defaultRowSpan(BentoNodeType t) => switch (t) {
        BentoNodeType.checkList || BentoNodeType.giftWish => 3,
        BentoNodeType.locationPin => 1,
        _ => 2,
      };

  BentoColorTheme _defaultColor(BentoNodeType t) => switch (t) {
        BentoNodeType.quote ||
        BentoNodeType.countdown =>
          BentoColorTheme.terracotta,
        BentoNodeType.flipDetail ||
        BentoNodeType.photoHero ||
        BentoNodeType.videoMemory =>
          BentoColorTheme.espresso,
        BentoNodeType.locationPin ||
        BentoNodeType.habitChips =>
          BentoColorTheme.sage,
        _ => BentoColorTheme.ivory,
      };

  void _applyAspectRatioToGrid(double? ratio) {
    if (ratio == null) return;
    setState(() {
      if (ratio < 0.85) {
        // Vertical (9:16, 3:4): ocupa 1 columna x altura 3
        _colSpan = 1;
        _rowSpan = 3;
      } else if (ratio > 1.25) {
        // Horizontal (16:9, 4:3): ocupa 2 columnas x altura 2
        _colSpan = 2;
        _rowSpan = 2;
      } else {
        // Cuadrada (1:1): 1 columna x altura 2
        _colSpan = 1;
        _rowSpan = 2;
      }
    });
  }

  List<String> _parseLines(String raw) {
    return raw
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  BentoPayload _buildPayload() {
    final t = _titleCtrl.text.trim();
    final sec = _secondaryCtrl.text.trim();
    final ter = _tertiaryCtrl.text.trim();
    final body = _bodyCtrl.text.trim();
    final media = _mediaLinkCtrl.text.trim();

    return switch (widget.type) {
      BentoNodeType.photoHero => PhotoHeroPayload(
          imageUrl: media,
          title: t,
          dateLabel: sec,
          locationLabel: ter,
          storyBody: body,
          latitude: _latitude,
          longitude: _longitude,
        ),
      BentoNodeType.videoMemory => VideoMemoryPayload(
          title: t,
          videoSource: _videoSource.isNotEmpty ? _videoSource : media,
          dateLabel: sec,
          locationLabel: ter,
          caption: body,
          autoPlayMuted: _autoPlayMuted,
          latitude: _latitude,
          longitude: _longitude,
        ),
      BentoNodeType.flipDetail => FlipDetailPayload(
          title: t.isEmpty ? 'Su detalle favorito' : t,
          microText: sec.isEmpty ? 'Toca para ver la nota detrás' : sec,
          iconKey: _iconKey,
          voiceNoteLabel: 'Nota de voz',
          recordedDateLabel: ter.isEmpty ? 'Grabado hoy · 0:15' : ter,
          durationSeconds: 18,
          backSubtitle: body.isEmpty ? '“Me encanta este detalle tuyo”' : body,
          localAudioPath: _localAudioPath,
          waveformSamples: const <double>[
            0.30,
            0.56,
            0.80,
            0.45,
            0.92,
            0.64,
            0.38,
            0.85,
            0.90,
            0.52,
            0.40,
            0.74,
            0.58,
            0.34,
            0.68,
            0.46,
            0.82,
            0.48,
          ],
        ),
      BentoNodeType.quote => QuotePayload(
          quoteText: t.isEmpty ? 'En los detalles pequeños vive lo eterno.' : t,
          contextLabel: sec,
          isLoved:
              (widget.existingNode?.payload as QuotePayload?)?.isLoved ?? true,
          loveCount:
              (widget.existingNode?.payload as QuotePayload?)?.loveCount ?? 1,
        ),
      BentoNodeType.audioNote => AudioNotePayload(
          title: t.isEmpty ? 'Canción que me recuerda a ella' : t,
          subtitle: sec.isEmpty ? 'Melodía guardada' : sec,
          coverImageUrl: media,
          durationSeconds: 28,
          localAudioPath: _localAudioPath,
          waveformSamples: const <double>[
            0.24,
            0.38,
            0.65,
            0.50,
            0.88,
            0.95,
            0.70,
            0.58,
            0.86,
            0.60,
            0.42,
            0.78,
            0.90,
            0.54,
            0.38,
            0.66,
            0.44,
            0.28,
            0.48,
            0.32,
          ],
        ),
      BentoNodeType.checkList => CheckListPayload(
          title: t.isEmpty ? 'Detalles que amo' : t,
          footerHint: sec.isEmpty ? 'Toca para destacar' : sec,
          items: () {
            final lines = _parseLines(_itemsCtrl.text);
            if (lines.isEmpty) {
              return const <CheckListItem>[
                CheckListItem(
                  id: 'item_1',
                  text: 'Primer detalle favorito',
                  isHighlighted: true,
                ),
              ];
            }
            return List<CheckListItem>.generate(
              lines.length,
              (i) => CheckListItem(
                id: 'chk_$i',
                text: lines[i],
                isHighlighted: i == 0,
              ),
            );
          }(),
        ),
      BentoNodeType.locationPin => LocationPinPayload(
          placeName: t.isEmpty ? 'Rincón especial' : t,
          caption: sec.isEmpty ? (t.isEmpty ? 'Caminata' : t) : sec,
          coordinatesLabel: ter.isEmpty
              ? (_latitude != null && _longitude != null
                  ? LocationService.formatCoordinates(_latitude!, _longitude!)
                  : 'Lugar favorito')
              : ter,
          style: _pinStyle,
          imageUrl: media,
          memoryNote: body,
          latitude: _latitude,
          longitude: _longitude,
        ),
      BentoNodeType.countdown => CountdownPayload(
          title: t.isEmpty ? 'Nuestro día especial' : t,
          targetDate: _targetDate,
          subtitle: sec,
          countMode: _countMode,
        ),
      BentoNodeType.paletteMood => PaletteMoodPayload(
          title: t.isEmpty ? 'Su esencia & colores' : t,
          scentNote: sec.isEmpty ? 'Vainilla, café y lluvia' : sec,
          swatchHexes: _paletteHexes,
          moodWords: _itemsCtrl.text
              .split(',')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList(),
        ),
      BentoNodeType.bookMovie => BookMoviePayload(
          title: t.isEmpty ? 'Obra favorita' : t,
          creator: sec,
          kind: _bookOrMovie,
          personalNote: body,
          rating: _rating,
        ),
      BentoNodeType.giftWish => GiftWishPayload(
          title: t.isEmpty ? 'Ideas & Deseos' : t,
          items: () {
            final lines = _parseLines(_itemsCtrl.text);
            if (lines.isEmpty) {
              return const <CheckListItem>[
                CheckListItem(id: 'wish_1', text: 'Flores amarillas'),
              ];
            }
            return List<CheckListItem>.generate(
              lines.length,
              (i) => CheckListItem(id: 'wish_$i', text: lines[i]),
            );
          }(),
        ),
      BentoNodeType.loveLetter => LoveLetterPayload(
          title: t.isEmpty ? 'Para leer cuando quieras' : t,
          previewLine: sec.isEmpty ? 'Una nota breve guardada aquí…' : sec,
          letterBody: body.isEmpty
              ? 'Quise dejar por escrito lo mucho que valoro cada momento contigo.'
              : body,
          signature: ter,
        ),
      BentoNodeType.habitChips => HabitChipsPayload(
          title: t.isEmpty ? 'Sus pequeñas manías' : t,
          habits: () {
            final lines = _parseLines(_itemsCtrl.text);
            return lines.isEmpty
                ? const <String>['Canta bajito', 'Toma café tibio']
                : lines;
          }(),
          footnote: sec,
        ),
    };
  }

  BentoNode _buildDraftNode() {
    return BentoNode(
      id: widget.existingNode?.id ??
          'node_${widget.type.name}_${DateTime.now().microsecondsSinceEpoch}',
      type: widget.type,
      colSpan: _colSpan,
      rowSpan: _rowSpan,
      colorTheme: _colorTheme,
      customBgColorHex: _customBgColorHex,
      useGradient: _useGradient,
      borderRadius: _borderRadius,
      cardDesign: _cardDesign,
      fontStyle: _fontStyle,
      textAlign: _textAlign,
      titleScale: _titleScale,
      isTitleBold: _isTitleBold,
      isFavorite: widget.existingNode?.isFavorite ?? false,
      linkedNodeIds: widget.existingNode?.linkedNodeIds ?? const <String>[],
      tags: widget.existingNode?.tags ?? const <String>[],
      payload: _buildPayload(),
      createdAt: widget.existingNode?.createdAt ?? DateTime.now(),
    );
  }

  Future<void> _pickPhoto(ImageSource source) async {
    HapticFeedback.selectionClick();
    final service = ref.read(mediaAndAuthServiceProvider);
    final path = await service.pickAndPersistImage(source: source);
    if (path == null || !mounted) return;

    final ratio = await service.detectImageAspectRatio(path);
    if (!mounted) return;
    setState(() {
      _mediaLinkCtrl.text = path;
      _useLinkSource = false;
    });
    _applyAspectRatioToGrid(ratio);
  }

  Future<void> _pickVideo(ImageSource source) async {
    HapticFeedback.selectionClick();
    final service = ref.read(mediaAndAuthServiceProvider);
    final path = await service.pickAndPersistVideo(source: source);
    if (path == null || !mounted) return;

    final ratio = await service.detectVideoAspectRatio(path);
    if (!mounted) return;
    setState(() {
      _videoSource = path;
      _mediaLinkCtrl.text = path;
      _useLinkSource = false;
    });
    _applyAspectRatioToGrid(ratio);
  }

  Future<void> _toggleVoiceRecord() async {
    HapticFeedback.mediumImpact();
    final service = ref.read(mediaAndAuthServiceProvider);
    if (_isRecordingAudio) {
      final path = await service.stopVoiceRecording();
      if (!mounted) return;
      setState(() {
        _isRecordingAudio = false;
        if (path != null && path.isNotEmpty) {
          _localAudioPath = path;
        }
      });
    } else {
      final started = await service.startVoiceRecording();
      if (!mounted) return;
      if (started) {
        setState(() => _isRecordingAudio = true);
      } else {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text(
              'Activa el permiso del micrófono para grabar una nota real.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final previewNode = _buildDraftNode();

    return Container(
      decoration: BoxDecoration(
        color: theme.canvasBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: theme.borderTint),
      ),
      child: Column(
        children: <Widget>[
          const SizedBox(height: 10),
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: theme.inkSecondary.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(999),
            ),
          ),

          // Cabecera limpia
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 10, 12, 4),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    widget.existingNode == null
                        ? widget.type.displayName
                        : 'Editar · ${widget.type.displayName}',
                    style: RochyTypography.brandTitle(theme.brandAccent)
                        .copyWith(fontSize: 21),
                  ),
                ),
                if (widget.onDelete != null)
                  IconButton(
                    tooltip: 'Eliminar',
                    onPressed: widget.onDelete,
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: theme.terracotta,
                    ),
                  ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close_rounded, color: theme.inkSecondary),
                ),
              ],
            ),
          ),

          // Vista previa fija en vivo (no desaparece al desplazarse)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
            child: Container(
              height: 146,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.canvasSecondary,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: theme.borderTint),
              ),
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  width: _colSpan == 2 ? double.infinity : 156,
                  height: _rowSpan == 1 ? 82 : 124,
                  child: IgnorePointer(
                    child: buildPolymorphicBentoCard(
                      node: previewNode,
                      theme: theme,
                      showPaperGrain: true,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Selector editorial de 2 pasos (sin morado por defecto de Material)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: theme.sandSurface,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                children: <Widget>[
                  _StepTabPill(
                    label: '1 · Contenido',
                    selected: _step == 0,
                    theme: theme,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _step = 0);
                    },
                  ),
                  _StepTabPill(
                    label: '2 · Diseño & Color',
                    selected: _step == 1,
                    theme: theme,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _step = 1);
                    },
                  ),
                ],
              ),
            ),
          ),

          // Contenido por partes con transición animada
          Expanded(
            child: ListView(
              controller: widget.scrollController,
              padding: EdgeInsets.fromLTRB(20, 4, 20, 16 + bottomInset),
              children: <Widget>[
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: _step == 0
                      ? Column(
                          key: const ValueKey<int>(0),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _buildStep1ContentFields(theme),
                        )
                      : Column(
                          key: const ValueKey<int>(1),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _buildStep2DesignControls(theme),
                        ),
                ),
              ],
            ),
          ),

          // Pie con navegación rápida entre pasos y Guardar
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
              child: Row(
                children: <Widget>[
                  if (_step == 0)
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _step = 1);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: theme.ivorySurface,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: theme.brandAccent.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              'Personalizar estilo →',
                              style: RochyTypography.sansTitle(
                                theme.brandAccent,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _step = 0);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: theme.ivorySurface,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: theme.borderTint),
                          ),
                          child: Center(
                            child: Text(
                              '← Volver al contenido',
                              style: RochyTypography.sansTitle(
                                theme.inkPrimary,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.brandAccent,
                        foregroundColor: const Color(0xFFFAF7F2),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: const StadiumBorder(),
                      ),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        widget.onSave(_buildDraftNode());
                      },
                      child: Text(
                        widget.existingNode == null ? 'Agregar' : 'Guardar',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildStep1ContentFields(RochyThemeData theme) {
    switch (widget.type) {
      case BentoNodeType.videoMemory:
        return <Widget>[
          _sourceToggle(theme,
              phoneLabel: 'Del teléfono', linkLabel: 'Por link'),
          const SizedBox(height: 12),
          if (!_useLinkSource) ...<Widget>[
            _phonePickerCards(
              theme: theme,
              galleryTitle: 'Elegir video',
              cameraTitle: 'Grabar video',
              hasPicked:
                  _videoSource.isNotEmpty && !_videoSource.startsWith('http'),
              onGallery: () => _pickVideo(ImageSource.gallery),
              onCamera: () => _pickVideo(ImageSource.camera),
            ),
          ] else
            _field(
              'Link del video (.mp4)',
              _mediaLinkCtrl,
              'https://.../video.mp4',
              theme,
            ),
          const SizedBox(height: 12),
          _field('Título', _titleCtrl, 'Ej. Bailando bajo la lluvia', theme),
          _field('Lugar (opcional)', _tertiaryCtrl, 'Ej. Balcón de la casa',
              theme),
          _realLocationPickerTile(theme, isLocationPin: false),
          _field('Nota breve (opcional)', _bodyCtrl, 'Qué pasó en ese clip…',
              theme,
              maxLines: 2),
          _editorialSwitchTile(
            title: 'Reproducir en silencio en el lienzo',
            value: _autoPlayMuted,
            theme: theme,
            onChanged: (v) => setState(() => _autoPlayMuted = v),
          ),
        ];

      case BentoNodeType.photoHero:
        return <Widget>[
          _sourceToggle(theme,
              phoneLabel: 'Del teléfono', linkLabel: 'Por link'),
          const SizedBox(height: 12),
          if (!_useLinkSource)
            _phonePickerCards(
              theme: theme,
              galleryTitle: 'Elegir foto',
              cameraTitle: 'Tomar foto',
              hasPicked: _mediaLinkCtrl.text.isNotEmpty &&
                  !_mediaLinkCtrl.text.startsWith('http'),
              onGallery: () => _pickPhoto(ImageSource.gallery),
              onCamera: () => _pickPhoto(ImageSource.camera),
            )
          else
            _field(
              'Link de la foto',
              _mediaLinkCtrl,
              'https://...',
              theme,
            ),
          const SizedBox(height: 12),
          _field('Título del momento', _titleCtrl, 'Ej. Mañanas de sol y café',
              theme),
          _field('Lugar (opcional)', _tertiaryCtrl, 'Ej. Calle Baloco', theme),
          _realLocationPickerTile(theme, isLocationPin: false),
          _field('Historia corta', _bodyCtrl, 'Cuenta el recuerdo…', theme,
              maxLines: 3),
        ];

      case BentoNodeType.flipDetail:
        return <Widget>[
          _field('Título frontal', _titleCtrl, 'Ej. Su café favorito', theme),
          _field('Detalle breve', _secondaryCtrl,
              'Ej. Caramel Macchiato, extra caliente', theme),
          _sectionLabel('Ícono', theme),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const <String>[
              'coffee',
              'flower',
              'sun',
              'music',
              'book',
              'cake',
              'camera',
              'heart',
            ].map((k) {
              return _WarmChoicePill(
                label: k,
                selected: _iconKey == k,
                theme: theme,
                onTap: () => setState(() => _iconKey = k),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          _field('Frase atrás (Cara B)', _bodyCtrl, 'Ej. “Con doble espuma”',
              theme),
          _voiceRecorderTile(theme),
        ];

      case BentoNodeType.quote:
        return <Widget>[
          _field('Frase que dijo', _titleCtrl,
              'Ej. En tu paz, encontré mi hogar.', theme,
              maxLines: 3),
          _field('Contexto (opcional)', _secondaryCtrl, 'Ej. Tras la lluvia',
              theme),
        ];

      case BentoNodeType.audioNote:
        return <Widget>[
          _field('Título', _titleCtrl, 'Ej. Canción que me recuerda a ella',
              theme),
          _field('Artista o dedicatoria', _secondaryCtrl, 'Ej. La Vie En Rose',
              theme),
          _voiceRecorderTile(theme),
          _sourceToggle(theme,
              phoneLabel: 'Portada del teléfono',
              linkLabel: 'Portada por link'),
          const SizedBox(height: 10),
          if (!_useLinkSource)
            _phonePickerCards(
              theme: theme,
              galleryTitle: 'Elegir carátula',
              cameraTitle: 'Tomar foto',
              hasPicked: _mediaLinkCtrl.text.isNotEmpty &&
                  !_mediaLinkCtrl.text.startsWith('http'),
              onGallery: () => _pickPhoto(ImageSource.gallery),
              onCamera: () => _pickPhoto(ImageSource.camera),
            )
          else
            _field('Link de carátula', _mediaLinkCtrl, 'https://...', theme),
        ];

      case BentoNodeType.checkList:
        return <Widget>[
          _field('Título', _titleCtrl, 'Ej. Detalles que amo', theme),
          _field('Cosas que amas (una por línea)', _itemsCtrl,
              'Su risa cuando olvida algo\nCómo ordena sus libros', theme,
              maxLines: 5),
        ];

      case BentoNodeType.locationPin:
        return <Widget>[
          _sectionLabel('Formato', theme),
          Row(
            children: <Widget>[
              Expanded(
                child: _WarmChoicePill(
                  label: 'Polaroid',
                  selected: _pinStyle == LocationPinStyle.polaroid,
                  theme: theme,
                  onTap: () =>
                      setState(() => _pinStyle = LocationPinStyle.polaroid),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _WarmChoicePill(
                  label: '5 Estrellas',
                  selected: _pinStyle == LocationPinStyle.constellationPill,
                  theme: theme,
                  onTap: () => setState(
                    () => _pinStyle = LocationPinStyle.constellationPill,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _field('Nombre del lugar', _titleCtrl, 'Ej. Café en la Calle Baloco',
              theme),
          _realLocationPickerTile(theme, isLocationPin: true),
          if (_pinStyle == LocationPinStyle.polaroid) ...<Widget>[
            _sourceToggle(theme,
                phoneLabel: 'Foto del teléfono', linkLabel: 'Foto por link'),
            const SizedBox(height: 10),
            if (!_useLinkSource)
              _phonePickerCards(
                theme: theme,
                galleryTitle: 'Elegir foto',
                cameraTitle: 'Tomar foto',
                hasPicked: _mediaLinkCtrl.text.isNotEmpty &&
                    !_mediaLinkCtrl.text.startsWith('http'),
                onGallery: () => _pickPhoto(ImageSource.gallery),
                onCamera: () => _pickPhoto(ImageSource.camera),
              )
            else
              _field('Link de foto', _mediaLinkCtrl, 'https://...', theme),
            const SizedBox(height: 10),
            _field('Pie manuscrito', _secondaryCtrl, 'Ej. Caminatas de domingo',
                theme),
          ] else
            _field('Nota del lugar', _bodyCtrl, 'Qué lo hace especial…', theme,
                maxLines: 2),
        ];

      case BentoNodeType.countdown:
        return <Widget>[
          _field('Título de la fecha', _titleCtrl, 'Ej. Nuestro primer café',
              theme),
          _field('Subtítulo', _secondaryCtrl, 'Ej. Cada día suma', theme),
          Row(
            children: <Widget>[
              Expanded(
                child: _WarmChoicePill(
                  label: 'Días desde',
                  selected: _countMode == 'since',
                  theme: theme,
                  onTap: () => setState(() => _countMode = 'since'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _WarmChoicePill(
                  label: 'Días hasta',
                  selected: _countMode == 'until',
                  theme: theme,
                  onTap: () => setState(() => _countMode = 'until'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _targetDate,
                firstDate: DateTime(1960),
                lastDate: DateTime(2040),
              );
              if (picked != null) setState(() => _targetDate = picked);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: theme.ivorySurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.borderTint),
              ),
              child: Row(
                children: <Widget>[
                  Icon(Icons.calendar_today_rounded,
                      size: 17, color: theme.brandAccent),
                  const SizedBox(width: 10),
                  Text(
                    'Fecha: ${_targetDate.day}/${_targetDate.month}/${_targetDate.year}',
                    style: RochyTypography.sansTitle(theme.inkPrimary,
                        fontSize: 13.5),
                  ),
                ],
              ),
            ),
          ),
        ];

      case BentoNodeType.paletteMood:
        return <Widget>[
          _field('Título', _titleCtrl, 'Ej. Su esencia & colores', theme),
          _field(
              'Aroma favorito', _secondaryCtrl, 'Ej. Vainilla y lluvia', theme),
          _field('Palabras de su vibra (por coma)', _itemsCtrl,
              'Serena, luminosa, dulce', theme),
        ];

      case BentoNodeType.bookMovie:
        return <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: _WarmChoicePill(
                  label: 'Libro',
                  selected: _bookOrMovie == 'book',
                  theme: theme,
                  onTap: () => setState(() => _bookOrMovie = 'book'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _WarmChoicePill(
                  label: 'Película',
                  selected: _bookOrMovie == 'movie',
                  theme: theme,
                  onTap: () => setState(() => _bookOrMovie = 'movie'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _field('Título', _titleCtrl, 'Ej. El Principito', theme),
          _field(
              'Autor o director', _secondaryCtrl, 'Ej. Saint-Exupéry', theme),
          _field('Por qué le gusta', _bodyCtrl, 'Su nota personal…', theme,
              maxLines: 2),
        ];

      case BentoNodeType.giftWish:
        return <Widget>[
          _field('Título', _titleCtrl, 'Ej. Flores & Deseos', theme),
          _field('Ideas (una por línea)', _itemsCtrl,
              'Girasoles\nTaza artesanal', theme,
              maxLines: 5),
        ];

      case BentoNodeType.loveLetter:
        return <Widget>[
          _field('Título del sobre', _titleCtrl, 'Ej. Para un día gris', theme),
          _field('Carta completa', _bodyCtrl, 'Escribe lo que quieras decirle…',
              theme,
              maxLines: 5),
          _field('Firma', _tertiaryCtrl, 'Ej. Con cariño', theme),
        ];

      case BentoNodeType.habitChips:
        return <Widget>[
          _field('Título', _titleCtrl, 'Ej. Sus pequeñas manías', theme),
          _field('Hábitos (uno por línea)', _itemsCtrl,
              'Canta bajito\nOrdena libros por color', theme,
              maxLines: 5),
        ];
    }
  }

  List<Widget> _buildStep2DesignControls(RochyThemeData theme) {
    final activeColorHex =
        _customBgColorHex ?? theme.cardSurface(_colorTheme).toARGB32();

    return <Widget>[
      _sectionLabel('Paleta y color de fondo', theme),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: _customPaletteHexes.map((hex) {
          final isSelected = activeColorHex == hex;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _customBgColorHex = hex);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Color(hex),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? theme.brandAccent
                      : Colors.black.withValues(alpha: 0.14),
                  width: isSelected ? 2.6 : 1.0,
                ),
                boxShadow: isSelected
                    ? <BoxShadow>[
                        BoxShadow(
                          color: theme.brandAccent.withValues(alpha: 0.35),
                          blurRadius: 10,
                        ),
                      ]
                    : null,
              ),
              child: isSelected
                  ? Icon(
                      Icons.check_rounded,
                      size: 17,
                      color: Color(hex).computeLuminance() < 0.38
                          ? const Color(0xFFFAF7F2)
                          : theme.inkPrimary,
                    )
                  : null,
            ),
          );
        }).toList(),
      ),
      const SizedBox(height: 12),
      _editorialSwitchTile(
        title: 'Degradado orgánico sutil',
        value: _useGradient,
        theme: theme,
        onChanged: (v) => setState(() => _useGradient = v),
      ),
      const SizedBox(height: 12),
      _sectionLabel('Acabado del diseño', theme),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: BentoCardDesign.values.map((d) {
          return _WarmChoicePill(
            label: d.label,
            selected: _cardDesign == d,
            theme: theme,
            onTap: () => setState(() => _cardDesign = d),
          );
        }).toList(),
      ),
      const SizedBox(height: 16),
      _sectionLabel('Tipografía', theme),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: BentoFontStyle.values.map((f) {
          return _WarmChoicePill(
            label: f.label,
            selected: _fontStyle == f,
            theme: theme,
            onTap: () => setState(() => _fontStyle = f),
          );
        }).toList(),
      ),
      const SizedBox(height: 14),
      _sectionLabel('Alineación y peso', theme),
      Row(
        children: <Widget>[
          for (final align in BentoTextAlign.values) ...<Widget>[
            Expanded(
              child: _WarmChoicePill(
                label: align.label,
                selected: _textAlign == align,
                theme: theme,
                onTap: () => setState(() => _textAlign = align),
              ),
            ),
            const SizedBox(width: 6),
          ],
          _WarmChoicePill(
            label: 'Negrita',
            selected: _isTitleBold,
            theme: theme,
            onTap: () => setState(() => _isTitleBold = !_isTitleBold),
          ),
        ],
      ),
      const SizedBox(height: 14),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          _sectionLabel('Esquinas curvas', theme),
          Text(
            '${_borderRadius.round()} px',
            style: RochyTypography.metadata(theme.brandAccent, fontSize: 12),
          ),
        ],
      ),
      Slider(
        value: _borderRadius,
        min: 10,
        max: 34,
        activeColor: theme.brandAccent,
        inactiveColor: theme.sandSurface,
        onChanged: (v) => setState(() => _borderRadius = v),
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          _sectionLabel('Escala de título', theme),
          Text(
            '${(_titleScale * 100).round()}%',
            style: RochyTypography.metadata(theme.brandAccent, fontSize: 12),
          ),
        ],
      ),
      Slider(
        value: _titleScale,
        min: 0.85,
        max: 1.25,
        activeColor: theme.brandAccent,
        inactiveColor: theme.sandSurface,
        onChanged: (v) => setState(() => _titleScale = v),
      ),
    ];
  }

  Widget _sourceToggle(
    RochyThemeData theme, {
    required String phoneLabel,
    required String linkLabel,
  }) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _WarmChoicePill(
            label: phoneLabel,
            icon: Icons.smartphone_rounded,
            selected: !_useLinkSource,
            theme: theme,
            onTap: () => setState(() => _useLinkSource = false),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _WarmChoicePill(
            label: linkLabel,
            icon: Icons.link_rounded,
            selected: _useLinkSource,
            theme: theme,
            onTap: () => setState(() => _useLinkSource = true),
          ),
        ),
      ],
    );
  }

  Widget _phonePickerCards({
    required RochyThemeData theme,
    required String galleryTitle,
    required String cameraTitle,
    required bool hasPicked,
    required VoidCallback onGallery,
    required VoidCallback onCamera,
  }) {
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: _WarmActionTile(
                icon: Icons.photo_library_rounded,
                label: galleryTitle,
                theme: theme,
                onTap: onGallery,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _WarmActionTile(
                icon: Icons.photo_camera_rounded,
                label: cameraTitle,
                theme: theme,
                onTap: onCamera,
              ),
            ),
          ],
        ),
        if (hasPicked) ...<Widget>[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: theme.sage.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: <Widget>[
                Icon(Icons.check_circle_rounded, size: 15, color: theme.sage),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Archivo guardado desde tu teléfono',
                    style: RochyTypography.metadata(
                      theme.sage,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _openMapLocationPicker(
    RochyThemeData theme, {
    required bool isLocationPin,
  }) async {
    final currentPlace =
        isLocationPin ? _titleCtrl.text.trim() : _tertiaryCtrl.text.trim();
    final picked = await MapLocationPickerSheet.show(
      context,
      theme: theme,
      initialLatitude: _latitude,
      initialLongitude: _longitude,
      initialPlaceName: currentPlace,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _latitude = picked.latitude;
      _longitude = picked.longitude;
      if (isLocationPin) {
        if (picked.placeName.isNotEmpty) _titleCtrl.text = picked.placeName;
        _tertiaryCtrl.text = picked.coordinatesLabel;
      } else {
        _tertiaryCtrl.text = picked.placeName;
      }
    });
  }

  Future<void> _fillWithCurrentGps({required bool isLocationPin}) async {
    HapticFeedback.lightImpact();
    setState(() => _isLocatingGps = true);
    final res = await ref.read(locationServiceProvider).getCurrentLocation();
    if (!mounted) return;
    setState(() => _isLocatingGps = false);

    if (!res.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.errorMessage ?? 'No se pudo obtener el GPS.'),
        ),
      );
      return;
    }

    final coords = LocationService.formatCoordinates(
      res.latitude!,
      res.longitude!,
    );
    setState(() {
      _latitude = res.latitude;
      _longitude = res.longitude;
      if (isLocationPin) {
        if ((res.placeName ?? '').isNotEmpty &&
            _titleCtrl.text.trim().isEmpty) {
          _titleCtrl.text = res.placeName!;
        } else if ((res.placeName ?? '').isNotEmpty) {
          _titleCtrl.text = res.placeName!;
        }
        _tertiaryCtrl.text = coords;
      } else if ((res.placeName ?? '').isNotEmpty) {
        _tertiaryCtrl.text = res.placeName!;
      }
    });
  }

  Widget _realLocationPickerTile(
    RochyThemeData theme, {
    required bool isLocationPin,
  }) {
    final hasCoords = _latitude != null && _longitude != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: _WarmActionTile(
                  icon: Icons.map_rounded,
                  label: hasCoords ? 'Cambiar en mapa' : 'Elegir en mapa',
                  theme: theme,
                  onTap: () => _openMapLocationPicker(
                    theme,
                    isLocationPin: isLocationPin,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _WarmActionTile(
                  icon: Icons.my_location_rounded,
                  label: _isLocatingGps ? 'Buscando GPS…' : 'Usar mi GPS',
                  theme: theme,
                  onTap: _isLocatingGps
                      ? () {}
                      : () => _fillWithCurrentGps(
                            isLocationPin: isLocationPin,
                          ),
                ),
              ),
            ],
          ),
          if (hasCoords) ...<Widget>[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: theme.sage.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: <Widget>[
                  Icon(Icons.location_on_rounded, size: 15, color: theme.sage),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      LocationService.formatCoordinates(
                        _latitude!,
                        _longitude!,
                      ),
                      style: RochyTypography.metadata(
                        theme.sage,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() {
                      _latitude = null;
                      _longitude = null;
                    }),
                    child: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: theme.inkSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _editorialSwitchTile({
    required String title,
    required bool value,
    required RochyThemeData theme,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: theme.ivorySurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.borderTint),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              title,
              style: RochyTypography.sansTitle(theme.inkPrimary, fontSize: 13),
            ),
          ),
          Switch.adaptive(
            value: value,
            activeTrackColor: theme.brandAccent,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _voiceRecorderTile(RochyThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.ivorySurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _isRecordingAudio ? theme.terracotta : theme.borderTint,
        ),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            _isRecordingAudio ? Icons.graphic_eq_rounded : Icons.mic_rounded,
            color: _isRecordingAudio ? theme.terracotta : theme.brandAccent,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _isRecordingAudio
                  ? 'Grabando nota de voz…'
                  : _localAudioPath.isNotEmpty
                      ? 'Nota de voz lista para sonar'
                      : 'Grabar nota de voz del teléfono',
              style: RochyTypography.metadata(theme.inkPrimary, fontSize: 12),
            ),
          ),
          GestureDetector(
            onTap: _toggleVoiceRecord,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _isRecordingAudio
                    ? theme.terracotta
                    : theme.brandAccent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                _isRecordingAudio ? 'Detener' : 'Grabar',
                style: RochyTypography.metadata(
                  _isRecordingAudio
                      ? const Color(0xFFFAF7F2)
                      : theme.brandAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text, RochyThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
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

  Widget _field(
    String label,
    TextEditingController ctrl,
    String hint,
    RochyThemeData theme, {
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _sectionLabel(label, theme),
          TextField(
            controller: ctrl,
            maxLines: maxLines,
            decoration: InputDecoration(
              hintText: hint,
              filled: true,
              fillColor: theme.ivorySurface,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: theme.borderTint),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: theme.borderTint),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: theme.brandAccent, width: 1.4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepTabPill extends StatelessWidget {
  const _StepTabPill({
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
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected ? theme.ivorySurface : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            boxShadow: selected
                ? <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: RochyTypography.metadata(
                selected ? theme.brandAccent : theme.inkSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WarmChoicePill extends StatelessWidget {
  const _WarmChoicePill({
    required this.label,
    required this.selected,
    required this.theme,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final RochyThemeData theme;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? theme.brandAccent : theme.ivorySurface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? theme.brandAccent : theme.borderTint,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(
                icon,
                size: 15,
                color: selected ? const Color(0xFFFAF7F2) : theme.inkPrimary,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: RochyTypography.metadata(
                selected ? const Color(0xFFFAF7F2) : theme.inkPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WarmActionTile extends StatelessWidget {
  const _WarmActionTile({
    required this.icon,
    required this.label,
    required this.theme,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final RochyThemeData theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: theme.ivorySurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: theme.brandAccent.withValues(alpha: 0.30),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, size: 18, color: theme.brandAccent),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: RochyTypography.sansTitle(
                  theme.inkPrimary,
                  fontSize: 12.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
