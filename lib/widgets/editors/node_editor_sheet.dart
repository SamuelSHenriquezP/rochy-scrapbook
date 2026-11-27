import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/bento_node.dart';
import '../../providers/bento_canvas_provider.dart';
import '../../services/location_service.dart';
import '../../theme/rochy_theme.dart';
import '../editorial_image.dart';
import '../map_location_picker_sheet.dart';
import '../rochy_color_picker.dart';
import '../rochy_sketch_pad.dart';
import '../staggered_bento_grid.dart';
import 'keepsake_entries_editor.dart';
import 'rochy_photo_crop_sheet.dart';
import 'rochy_video_trim_sheet.dart';

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
  if (ref.read(bentoCanvasProvider).isActiveNotebookReadOnly) return;
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
  late String _authorId;
  late bool _isSurprise;

  late final TextEditingController _titleCtrl;
  late final TextEditingController _secondaryCtrl;
  late final TextEditingController _tertiaryCtrl;
  late final TextEditingController _bodyCtrl;
  late final TextEditingController _mediaLinkCtrl;
  late final TextEditingController _itemsCtrl;
  late final TextEditingController _tagsCtrl;
  late String _iconKey;
  late LocationPinStyle _pinStyle;
  late int _starCount;
  late String _countMode;
  late DateTime _targetDate;
  late String _bookOrMovie;
  late int _rating;
  late List<int> _paletteHexes;
  int _activePaletteIndex = 0;
  bool _showCustomBgPicker = false;
  List<String> _stripImages = <String>[];
  String _stripLayout = 'collage';
  String _moodKey = 'sunny';
  int _energyLevel = 4;
  String _cravingCategory = 'drink';
  bool _planRedeemed = false;
  bool _quotePlainText = false;
  List<SketchStroke> _sketchStrokes = <SketchStroke>[];
  List<PolaroidThreadItem> _threadPhotos = <PolaroidThreadItem>[];
  final List<TextEditingController> _threadCaptionCtrls =
      <TextEditingController>[];
  String _threadStyle = 'jute';
  List<PassportStamp> _passportStamps = [];
  List<SavedChatMessage> _chatMessages = const [
    SavedChatMessage(sender: '', text: '', timeLabel: '12:00'),
    SavedChatMessage(sender: '', text: '', timeLabel: '12:01', isRight: true),
  ];
  String _vintageTicketKind = 'cinema';
  final List<TextEditingController> _aboutPrefixCtrls =
      <TextEditingController>[];
  final List<TextEditingController> _aboutDetailCtrls =
      <TextEditingController>[];
  late final TextEditingController _topSizeCtrl;
  late final TextEditingController _bottomSizeCtrl;
  late final TextEditingController _shoeSizeCtrl;
  late final TextEditingController _accSizeCtrl;
  List<WardrobeSizeEntry> _wardrobeSizes = <WardrobeSizeEntry>[];
  final List<int> _wardrobeSizeRowIds = <int>[];
  int _nextWardrobeSizeRowId = 0;
  List<WardrobeItem> _wardrobeItems = <WardrobeItem>[];
  late String _videoSource;
  String _rawPickedVideoPath = '';
  String _videoThumbnailPath = '';
  int _videoDurationSeconds = 12;
  DateTime? _surpriseUnlockAt;
  String _answerSamuel = '';
  String _answerRochy = '';
  late String _localAudioPath;
  late bool _autoPlayMuted;
  double? _latitude;
  double? _longitude;
  bool _isLocatingGps = false;
  bool _isRecordingAudio = false;
  String _lastInspectedMediaUrl = '';
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
    final canvas = ref.read(bentoCanvasProvider);
    _authorId = (existing?.authorId.isNotEmpty == true)
        ? existing!.authorId
        : canvas.viewerAuthor;
    _isSurprise = existing?.isSurprise ?? false;
    _surpriseUnlockAt = existing?.surpriseUnlockAt;

    _iconKey = 'coffee';
    _pinStyle = LocationPinStyle.polaroid;
    _starCount = 5;
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

    String topSize = '';
    String bottomSize = '';
    String shoeSize = '';
    String accSize = '';

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
        case final TravelPassportPayload p:
          t = p.title;
          _passportStamps = List<PassportStamp>.of(p.stamps);
        case final SavedChatPayload p:
          t = p.title;
          _chatMessages = List<SavedChatMessage>.of(p.messages);
        case final VintageTicketPayload p:
          t = p.title;
          ter = p.code;
          body = p.note;
          _targetDate = p.date;
          _rating = p.rating.clamp(1, 5);
          _vintageTicketKind = p.kind;
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
          _videoThumbnailPath = p.thumbnailUrl;
          _videoDurationSeconds =
              p.durationSeconds > 0 ? p.durationSeconds : 12;
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
          _quotePlainText = p.isPlainText;
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
          _starCount = p.starCount.clamp(1, 5);
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
          while (_paletteHexes.length < 2) {
            _paletteHexes.add(0xFFA85338);
          }
          _activePaletteIndex = 0;
        case final BookMoviePayload p:
          t = p.title;
          sec = p.creator;
          body = p.personalNote;
          media = p.imageUrl;
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
        case final PhotoStripPayload p:
          t = p.title;
          sec = p.caption;
          _stripImages = List<String>.of(p.imageUrls);
          _stripLayout = p.layoutMode;
        case final MoodPulsePayload p:
          t = p.title;
          sec = p.dateLabel;
          body = p.note;
          _moodKey = p.moodKey;
          _energyLevel = p.energyLevel.clamp(1, 5);
        case final CravingRecipePayload p:
          t = p.title;
          sec = p.placeNote;
          media = p.imageUrl;
          items = p.details.join('\n');
          _cravingCategory = p.category;
        case final PlanTicketPayload p:
          t = p.title;
          sec = p.whenLabel;
          ter = p.placeLabel;
          body = p.promiseNote;
          _planRedeemed = p.isRedeemed;
          _latitude = p.latitude;
          _longitude = p.longitude;
        case final SketchDoodlePayload p:
          t = p.title;
          _sketchStrokes = List<SketchStroke>.of(p.strokes);
        case final PolaroidThreadPayload p:
          t = p.title;
          sec = p.note;
          _threadPhotos = List<PolaroidThreadItem>.of(p.items);
          _threadStyle = p.threadStyle;
          for (final item in _threadPhotos) {
            _threadCaptionCtrls.add(
              TextEditingController(text: item.caption)
                ..addListener(_refreshPreview),
            );
          }
        case final CoupleQuestionPayload p:
          t = p.question;
          _answerSamuel = p.answerSamuel;
          _answerRochy = p.answerRochy;
        case final AboutHerPayload p:
          t = p.title;
          for (final entry in p.entries) {
            _aboutPrefixCtrls.add(
              TextEditingController(text: entry.prefix)
                ..addListener(_refreshPreview),
            );
            _aboutDetailCtrls.add(
              TextEditingController(text: entry.detail)
                ..addListener(_refreshPreview),
            );
          }
        case final WardrobeClosetPayload p:
          t = p.title;
          topSize = p.topSize;
          bottomSize = p.bottomSize;
          shoeSize = p.shoeSize;
          accSize = p.accessorySize;
          _wardrobeSizes = List<WardrobeSizeEntry>.of(p.effectiveSizeEntries);
          _wardrobeItems = List<WardrobeItem>.of(p.items);
      }
    } else if (widget.type == BentoNodeType.wardrobeCloset) {
      final aboutHim = canvas.isTalkingAboutHim;
      _wardrobeSizes = <WardrobeSizeEntry>[
        WardrobeSizeEntry(
          typeName: aboutHim ? 'Camisa / Suéter' : 'Blusa / Suéter',
          size: '',
        ),
        WardrobeSizeEntry(
          typeName: aboutHim ? 'Pantalón / Jean' : 'Pantalón / Falda',
          size: '',
        ),
        const WardrobeSizeEntry(typeName: 'Calzado', size: ''),
      ];
    } else if (widget.type == BentoNodeType.aboutHer) {
      final aboutHim = canvas.isTalkingAboutHim;
      final prefixes = aboutHim
          ? const <String>['Él es', 'Él tiene', 'Él siempre']
          : const <String>['Ella es', 'Ella tiene', 'Ella siempre'];
      for (final prefix in prefixes) {
        _aboutPrefixCtrls.add(
          TextEditingController(text: prefix)..addListener(_refreshPreview),
        );
        _aboutDetailCtrls.add(
          TextEditingController()..addListener(_refreshPreview),
        );
      }
    }

    _useLinkSource =
        media.startsWith('http://') || media.startsWith('https://');
    _lastInspectedMediaUrl = existing != null ? media.trim() : '';

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
    _tagsCtrl = TextEditingController(
      text: existing?.tags.join(', ') ?? '',
    );
    _topSizeCtrl = TextEditingController(text: topSize)
      ..addListener(_refreshPreview);
    _bottomSizeCtrl = TextEditingController(text: bottomSize)
      ..addListener(_refreshPreview);
    _shoeSizeCtrl = TextEditingController(text: shoeSize)
      ..addListener(_refreshPreview);
    _accSizeCtrl = TextEditingController(text: accSize)
      ..addListener(_refreshPreview);
  }

  void _refreshPreview() {
    if (widget.type == BentoNodeType.videoMemory && _useLinkSource) {
      _videoSource = _mediaLinkCtrl.text.trim();
    }
    if (_useLinkSource &&
        (widget.type == BentoNodeType.photoHero ||
            widget.type == BentoNodeType.videoMemory)) {
      final url = _mediaLinkCtrl.text.trim();
      if (url != _lastInspectedMediaUrl) {
        _lastInspectedMediaUrl = url;
        _scheduleLinkAspectDetect(url);
      }
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
    _tagsCtrl.dispose();
    for (final c in _threadCaptionCtrls) {
      c.dispose();
    }
    for (final c in _aboutPrefixCtrls) {
      c.dispose();
    }
    for (final c in _aboutDetailCtrls) {
      c.dispose();
    }
    _topSizeCtrl.dispose();
    _bottomSizeCtrl.dispose();
    _shoeSizeCtrl.dispose();
    _accSizeCtrl.dispose();
    super.dispose();
  }

  List<AboutHerEntry> _currentAboutHerEntries() {
    final len = math.min(_aboutPrefixCtrls.length, _aboutDetailCtrls.length);
    final entries = <AboutHerEntry>[];
    for (var i = 0; i < len; i++) {
      final prefix = _aboutPrefixCtrls[i].text.trim();
      final detail = _aboutDetailCtrls[i].text.trim();
      if (prefix.isNotEmpty || detail.isNotEmpty) {
        entries.add(AboutHerEntry(prefix: prefix, detail: detail));
      }
    }
    return entries;
  }

  List<PolaroidThreadItem> _currentThreadItems() {
    return List<PolaroidThreadItem>.generate(_threadPhotos.length, (i) {
      final cap = i < _threadCaptionCtrls.length
          ? _threadCaptionCtrls[i].text.trim()
          : _threadPhotos[i].caption;
      return _threadPhotos[i].copyWith(caption: cap);
    });
  }

  int _defaultColSpan(BentoNodeType t) => (t == BentoNodeType.photoHero ||
          t == BentoNodeType.videoMemory ||
          t == BentoNodeType.polaroidThread ||
          t == BentoNodeType.travelPassport ||
          t == BentoNodeType.savedChat ||
          t == BentoNodeType.coupleQuestion ||
          t == BentoNodeType.wardrobeCloset)
      ? 2
      : 1;

  int _defaultRowSpan(BentoNodeType t) => switch (t) {
        BentoNodeType.travelPassport ||
        BentoNodeType.savedChat ||
        BentoNodeType.vintageTicket ||
        BentoNodeType.coupleQuestion =>
          3,
        BentoNodeType.checkList ||
        BentoNodeType.giftWish ||
        BentoNodeType.photoStrip =>
          3,
        BentoNodeType.locationPin => 1,
        _ => 2,
      };

  BentoColorTheme _defaultColor(BentoNodeType t) => switch (t) {
        BentoNodeType.quote ||
        BentoNodeType.countdown ||
        BentoNodeType.moodPulse =>
          BentoColorTheme.terracotta,
        BentoNodeType.flipDetail ||
        BentoNodeType.photoHero ||
        BentoNodeType.videoMemory =>
          BentoColorTheme.espresso,
        BentoNodeType.locationPin ||
        BentoNodeType.habitChips ||
        BentoNodeType.planTicket =>
          BentoColorTheme.sage,
        BentoNodeType.polaroidThread ||
        BentoNodeType.vintageTicket =>
          BentoColorTheme.sand,
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

  List<CheckListItem> _mergePreservedItems(
    List<String> lines,
    List<CheckListItem>? previous, {
    required String prefix,
    bool defaultFirstHighlighted = false,
  }) {
    final prev = previous ?? const <CheckListItem>[];
    final usedPrevIndices = <int>{};
    final usedIds = <String>{};
    final stamp = DateTime.now().microsecondsSinceEpoch;
    var seq = 0;

    return List<CheckListItem>.generate(lines.length, (i) {
      final text = lines[i];
      CheckListItem? matched;
      for (var pIdx = 0; pIdx < prev.length; pIdx++) {
        if (!usedPrevIndices.contains(pIdx) && prev[pIdx].text.trim() == text) {
          usedPrevIndices.add(pIdx);
          matched = prev[pIdx];
          break;
        }
      }

      String id;
      if (matched != null &&
          matched.id.isNotEmpty &&
          !usedIds.contains(matched.id)) {
        id = matched.id;
      } else {
        do {
          id = '${prefix}_${stamp}_${seq++}';
        } while (usedIds.contains(id));
      }
      usedIds.add(id);

      return CheckListItem(
        id: id,
        text: text,
        isHighlighted:
            matched?.isHighlighted ?? (defaultFirstHighlighted && i == 0),
      );
    });
  }

  BentoPayload _buildPayload() {
    final t = _titleCtrl.text.trim();
    final sec = _secondaryCtrl.text.trim();
    final ter = _tertiaryCtrl.text.trim();
    final body = _bodyCtrl.text.trim();
    final media = _mediaLinkCtrl.text.trim();
    final existingPayload = widget.existingNode?.payload;

    return switch (widget.type) {
      BentoNodeType.travelPassport => TravelPassportPayload(
          title: t, stamps: List<PassportStamp>.of(_passportStamps)),
      BentoNodeType.savedChat => SavedChatPayload(
          title: t, messages: List<SavedChatMessage>.of(_chatMessages)),
      BentoNodeType.vintageTicket => VintageTicketPayload(
          title: t,
          date: _targetDate,
          code: ter,
          rating: _rating,
          note: body,
          kind: _vintageTicketKind),
      BentoNodeType.photoHero => () {
          final prev =
              existingPayload is PhotoHeroPayload ? existingPayload : null;
          return PhotoHeroPayload(
            imageUrl: media,
            title: t,
            dateLabel: sec,
            locationLabel: ter,
            storyBody: body,
            photographerNote: prev?.photographerNote ?? '',
            latitude: _latitude,
            longitude: _longitude,
          );
        }(),
      BentoNodeType.videoMemory => () {
          final prev =
              existingPayload is VideoMemoryPayload ? existingPayload : null;
          return VideoMemoryPayload(
            title: t,
            videoSource: _videoSource.isNotEmpty ? _videoSource : media,
            dateLabel: sec,
            locationLabel: ter,
            caption: body,
            thumbnailUrl: _videoThumbnailPath.isNotEmpty
                ? _videoThumbnailPath
                : (prev?.thumbnailUrl ?? ''),
            durationSeconds: _videoDurationSeconds,
            autoPlayMuted: _autoPlayMuted,
            latitude: _latitude,
            longitude: _longitude,
          );
        }(),
      BentoNodeType.flipDetail => () {
          final prev =
              existingPayload is FlipDetailPayload ? existingPayload : null;
          return FlipDetailPayload(
            title: t,
            microText: sec,
            iconKey: _iconKey,
            voiceNoteLabel: prev?.voiceNoteLabel ?? '',
            recordedDateLabel: ter.isEmpty
                ? (_localAudioPath.isNotEmpty ? 'Audio guardado' : '')
                : ter,
            durationSeconds: prev?.durationSeconds ?? 18,
            backSubtitle: body,
            localAudioPath: _localAudioPath,
            waveformSamples: prev?.waveformSamples ??
                const <double>[
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
          );
        }(),
      BentoNodeType.quote => () {
          final prev = existingPayload is QuotePayload ? existingPayload : null;
          return QuotePayload(
            quoteText: t,
            contextLabel: sec,
            isLoved: prev?.isLoved ?? true,
            loveCount: prev?.loveCount ?? 1,
            isPlainText: _quotePlainText,
          );
        }(),
      BentoNodeType.audioNote => () {
          final prev =
              existingPayload is AudioNotePayload ? existingPayload : null;
          return AudioNotePayload(
            title: t,
            subtitle: sec,
            coverImageUrl: media,
            durationSeconds: prev?.durationSeconds ?? 28,
            recordedAtLabel: prev?.recordedAtLabel ?? '',
            localAudioPath: _localAudioPath,
            waveformSamples: prev?.waveformSamples ??
                const <double>[
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
          );
        }(),
      BentoNodeType.checkList => () {
          final prev =
              existingPayload is CheckListPayload ? existingPayload : null;
          final lines = _parseLines(_itemsCtrl.text);
          return CheckListPayload(
            title: t,
            footerHint: sec,
            items: _mergePreservedItems(
              lines,
              prev?.items,
              prefix: 'chk',
              defaultFirstHighlighted: prev == null,
            ),
          );
        }(),
      BentoNodeType.locationPin => () {
          final prev =
              existingPayload is LocationPinPayload ? existingPayload : null;
          return LocationPinPayload(
            placeName: t,
            caption: sec,
            coordinatesLabel:
                ter.isEmpty && _latitude != null && _longitude != null
                    ? LocationService.formatCoordinates(_latitude!, _longitude!)
                    : ter,
            style: _pinStyle,
            imageUrl: media,
            starCount: _starCount,
            tiltAngle: prev?.tiltAngle ?? -0.04,
            memoryNote: body,
            latitude: _latitude,
            longitude: _longitude,
          );
        }(),
      BentoNodeType.countdown => CountdownPayload(
          title: t,
          targetDate: _targetDate,
          subtitle: sec,
          countMode: _countMode,
        ),
      BentoNodeType.paletteMood => PaletteMoodPayload(
          title: t,
          scentNote: sec,
          swatchHexes: _paletteHexes,
          moodWords: _itemsCtrl.text
              .split(',')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList(),
        ),
      BentoNodeType.bookMovie => BookMoviePayload(
          title: t,
          creator: sec,
          kind: _bookOrMovie,
          personalNote: body,
          rating: _rating,
          imageUrl: media,
        ),
      BentoNodeType.giftWish => () {
          final prev =
              existingPayload is GiftWishPayload ? existingPayload : null;
          final lines = _parseLines(_itemsCtrl.text);
          return GiftWishPayload(
            title: t,
            items: _mergePreservedItems(
              lines,
              prev?.items,
              prefix: 'wish',
            ),
          );
        }(),
      BentoNodeType.loveLetter => LoveLetterPayload(
          title: t,
          previewLine: sec,
          letterBody: body,
          signature: ter,
        ),
      BentoNodeType.habitChips => HabitChipsPayload(
          title: t,
          habits: _parseLines(_itemsCtrl.text),
          footnote: sec,
        ),
      BentoNodeType.photoStrip => PhotoStripPayload(
          title: t,
          imageUrls:
              _stripImages.where((e) => e.trim().isNotEmpty).take(4).toList(),
          caption: sec,
          layoutMode: _stripLayout,
        ),
      BentoNodeType.moodPulse => MoodPulsePayload(
          title: t,
          moodKey: _moodKey,
          energyLevel: _energyLevel,
          note: body,
          dateLabel: sec,
        ),
      BentoNodeType.cravingRecipe => CravingRecipePayload(
          title: t,
          category: _cravingCategory,
          details: _parseLines(_itemsCtrl.text),
          placeNote: sec,
          imageUrl: media,
        ),
      BentoNodeType.planTicket => PlanTicketPayload(
          title: t,
          whenLabel: sec,
          placeLabel: ter,
          promiseNote: body,
          isRedeemed: _planRedeemed,
          latitude: _latitude,
          longitude: _longitude,
        ),
      BentoNodeType.sketchDoodle => SketchDoodlePayload(
          title: t,
          strokes: _sketchStrokes,
        ),
      BentoNodeType.polaroidThread => PolaroidThreadPayload(
          title: t,
          items: _currentThreadItems(),
          threadStyle: _threadStyle,
          note: sec,
        ),
      BentoNodeType.coupleQuestion => CoupleQuestionPayload(
          question: t,
          answerSamuel: _answerSamuel.trim(),
          answerRochy: _answerRochy.trim(),
        ),
      BentoNodeType.aboutHer => AboutHerPayload(
          title: t,
          entries: _currentAboutHerEntries(),
        ),
      BentoNodeType.wardrobeCloset => WardrobeClosetPayload(
          title: t,
          sizeEntries: _wardrobeSizes
              .where(
                (e) => e.typeName.trim().isNotEmpty || e.size.trim().isNotEmpty,
              )
              .map(
                (e) => WardrobeSizeEntry(
                  typeName: e.typeName.trim(),
                  size: e.size.trim(),
                ),
              )
              .toList(),
          items: List<WardrobeItem>.of(_wardrobeItems),
        ),
    };
  }

  bool _validateKeepsake() {
    String? error;
    if (widget.type == BentoNodeType.travelPassport &&
        _passportStamps.any((stamp) => stamp.place.trim().isEmpty)) {
      error = 'Escribe la ciudad o barrio de cada sello.';
    }
    if (widget.type == BentoNodeType.savedChat &&
        (_chatMessages.length < 2 ||
            _chatMessages.length > 4 ||
            _chatMessages.any((message) =>
                message.sender.trim().isEmpty ||
                message.text.trim().isEmpty))) {
      error = 'Guarda entre 2 y 4 mensajes, cada uno con nombre y texto.';
    }
    if (error == null) return true;
    showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
              title: const Text('Revisa el recuerdo'),
              content: Text(error!),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Entendido'))
              ],
            ));
    return false;
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
      customTextColorHex: widget.existingNode?.customTextColorHex,
      useGradient: _useGradient,
      borderRadius: _borderRadius,
      cardDesign: _cardDesign,
      fontStyle: _fontStyle,
      textAlign: _textAlign,
      titleScale: _titleScale,
      isTitleBold: _isTitleBold,
      isFavorite: widget.existingNode?.isFavorite ?? false,
      authorId: _authorId,
      isSurprise: _isSurprise,
      surpriseUnlockAt: _isSurprise ? _surpriseUnlockAt : null,
      partnerReplyText: widget.existingNode?.partnerReplyText ?? '',
      partnerReplyAuthor: widget.existingNode?.partnerReplyAuthor ?? '',
      updatedAt: DateTime.now(),
      linkedNodeIds: widget.existingNode?.linkedNodeIds ?? const <String>[],
      tags: _tagsCtrl.text
          .split(',')
          .map((s) => s.trim().replaceFirst(RegExp(r'^#+'), ''))
          .where((s) => s.isNotEmpty)
          .toList(),
      payload: _buildPayload(),
      createdAt: widget.existingNode?.createdAt ?? DateTime.now(),
    );
  }

  Future<String?> _pickAndCropCompressedPhoto(ImageSource source) async {
    HapticFeedback.selectionClick();
    final service = ref.read(mediaAndAuthServiceProvider);
    final rawPath = await service.pickAndPersistImage(source: source);
    if (rawPath == null || !mounted) return null;

    final cropped = await showRochyPhotoCropSheet(
      context,
      ref,
      sourcePath: rawPath,
      theme: widget.theme,
    );
    if (!mounted) return null;
    return cropped;
  }

  Future<void> _recropCurrentPhoto() async {
    final current = _mediaLinkCtrl.text.trim();
    if (current.isEmpty || current.startsWith('http')) return;
    HapticFeedback.selectionClick();
    final cropped = await showRochyPhotoCropSheet(
      context,
      ref,
      sourcePath: current,
      theme: widget.theme,
    );
    if (cropped == null || !mounted) return;
    final ratio = await ref
        .read(mediaAndAuthServiceProvider)
        .detectImageAspectRatio(cropped);
    if (!mounted) return;
    setState(() {
      _mediaLinkCtrl.text = cropped;
      _useLinkSource = false;
    });
    _applyAspectRatioToGrid(ratio);
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final path = await _pickAndCropCompressedPhoto(source);
    if (path == null || !mounted) return;

    final ratio = await ref
        .read(mediaAndAuthServiceProvider)
        .detectImageAspectRatio(path);
    if (!mounted) return;
    setState(() {
      _mediaLinkCtrl.text = path;
      _useLinkSource = false;
    });
    _applyAspectRatioToGrid(ratio);
  }

  Future<void> _addPhotoToStrip(ImageSource source) async {
    if (_stripImages.length >= 4) return;
    final path = await _pickAndCropCompressedPhoto(source);
    if (path == null || !mounted) return;
    setState(() => _stripImages = <String>[..._stripImages, path]);
  }

  Widget _photoStripEditor(RochyThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _sectionLabel('Fotos del carrete (máximo 4)', theme),
          if (_stripImages.isNotEmpty) ...<Widget>[
            SizedBox(
              height: 76,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _stripImages.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, idx) => Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        width: 72,
                        height: 72,
                        child: EditorialImage(
                          imageUrl: _stripImages[idx],
                          fallbackScene: EditorialFallbackScene.cafeSunlit,
                        ),
                      ),
                    ),
                    Positioned(
                      top: -4,
                      right: -4,
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() {
                            final copy = List<String>.of(_stripImages)
                              ..removeAt(idx);
                            _stripImages = copy;
                          });
                        },
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: theme.charcoal,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.2),
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (_stripImages.length < 4) ...<Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: _WarmActionTile(
                    icon: Icons.photo_library_rounded,
                    label: 'Galería',
                    theme: theme,
                    onTap: () => _addPhotoToStrip(ImageSource.gallery),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _WarmActionTile(
                    icon: Icons.photo_camera_rounded,
                    label: 'Cámara',
                    theme: theme,
                    onTap: () => _addPhotoToStrip(ImageSource.camera),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _mediaLinkCtrl,
                    decoration: InputDecoration(
                      hintText: 'O pega un link https://…',
                      filled: true,
                      fillColor: theme.ivorySurface,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 11,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: theme.borderTint),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: theme.borderTint),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.brandAccent,
                    foregroundColor: const Color(0xFFFAF7F2),
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                  onPressed: () {
                    final url = _mediaLinkCtrl.text.trim();
                    if (url.isEmpty || _stripImages.length >= 4) return;
                    HapticFeedback.selectionClick();
                    setState(() {
                      _stripImages = <String>[..._stripImages, url];
                      _mediaLinkCtrl.clear();
                    });
                  },
                  child: const Text('Sumar'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _addPhotoToThread(ImageSource source) async {
    if (_threadPhotos.length >= 6) return;
    final path = await _pickAndCropCompressedPhoto(source);
    if (path == null || !mounted) return;
    _appendThreadPhoto(path);
  }

  void _appendThreadPhoto(String sourceUrl) {
    final trimmed = sourceUrl.trim();
    if (trimmed.isEmpty || _threadPhotos.length >= 6) return;
    HapticFeedback.selectionClick();
    setState(() {
      _threadPhotos = <PolaroidThreadItem>[
        ..._threadPhotos,
        PolaroidThreadItem(imageUrl: trimmed),
      ];
      _threadCaptionCtrls.add(
        TextEditingController()..addListener(_refreshPreview),
      );
    });
  }

  void _removeThreadPhoto(int index) {
    if (index < 0 || index >= _threadPhotos.length) return;
    HapticFeedback.lightImpact();
    setState(() {
      final photos = List<PolaroidThreadItem>.of(_threadPhotos)
        ..removeAt(index);
      _threadPhotos = photos;
      if (index < _threadCaptionCtrls.length) {
        final removed = _threadCaptionCtrls.removeAt(index);
        removed.dispose();
      }
    });
  }

  void _moveThreadPhoto(int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= _threadPhotos.length) return;
    HapticFeedback.selectionClick();
    setState(() {
      final photos = List<PolaroidThreadItem>.of(_threadPhotos);
      final moved = photos.removeAt(index);
      photos.insert(target, moved);
      _threadPhotos = photos;

      if (index < _threadCaptionCtrls.length &&
          target < _threadCaptionCtrls.length) {
        final movedCtrl = _threadCaptionCtrls.removeAt(index);
        _threadCaptionCtrls.insert(target, movedCtrl);
      }
    });
  }

  Widget _polaroidThreadEditor(RochyThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _sectionLabel('Fotos colgadas en el hilo (hasta 6)', theme),
          for (var i = 0; i < _threadPhotos.length; i++) ...<Widget>[
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.ivorySurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.borderTint),
              ),
              child: Row(
                children: <Widget>[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: EditorialImage(
                        imageUrl: _threadPhotos[i].imageUrl,
                        fallbackScene: EditorialFallbackScene
                            .values[i % EditorialFallbackScene.values.length],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: i < _threadCaptionCtrls.length
                          ? _threadCaptionCtrls[i]
                          : null,
                      style: RochyTypography.sansBody(
                        theme.inkPrimary,
                        fontSize: 13.5,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Nota o fecha Polaroid ${i + 1}',
                        hintStyle: RochyTypography.sansBody(
                          theme.inkSecondary.withValues(alpha: 0.65),
                          fontSize: 12.5,
                        ),
                        isDense: true,
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.72),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 9,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: theme.borderTint),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: theme.borderTint),
                        ),
                      ),
                    ),
                  ),
                  if (_threadPhotos.length > 1) ...<Widget>[
                    const SizedBox(width: 2),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        InkWell(
                          onTap: i > 0 ? () => _moveThreadPhoto(i, -1) : null,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.all(3),
                            child: Icon(
                              Icons.keyboard_arrow_up_rounded,
                              size: 18,
                              color: i > 0
                                  ? theme.inkPrimary
                                  : theme.inkSecondary.withValues(alpha: 0.28),
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: i < _threadPhotos.length - 1
                              ? () => _moveThreadPhoto(i, 1)
                              : null,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.all(3),
                            child: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 18,
                              color: i < _threadPhotos.length - 1
                                  ? theme.inkPrimary
                                  : theme.inkSecondary.withValues(alpha: 0.28),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: theme.inkSecondary,
                    ),
                    onPressed: () => _removeThreadPhoto(i),
                  ),
                ],
              ),
            ),
          ],
          if (_threadPhotos.length < 6) ...<Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: _WarmActionTile(
                    icon: Icons.photo_library_rounded,
                    label: 'Galería',
                    theme: theme,
                    onTap: () => _addPhotoToThread(ImageSource.gallery),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _WarmActionTile(
                    icon: Icons.photo_camera_rounded,
                    label: 'Cámara',
                    theme: theme,
                    onTap: () => _addPhotoToThread(ImageSource.camera),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _mediaLinkCtrl,
                    decoration: InputDecoration(
                      hintText: 'O pega un link https://…',
                      filled: true,
                      fillColor: theme.ivorySurface,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 11,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: theme.borderTint),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: theme.borderTint),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.brandAccent,
                    foregroundColor: const Color(0xFFFAF7F2),
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                  onPressed: () {
                    final url = _mediaLinkCtrl.text.trim();
                    if (url.isEmpty || _threadPhotos.length >= 6) return;
                    _appendThreadPhoto(url);
                    _mediaLinkCtrl.clear();
                  },
                  child: const Text('Colgar'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openVideoTrimmerOn(String sourceVideoPath) async {
    final trimmed = await showRochyVideoTrimSheet(
      context,
      ref,
      sourcePath: sourceVideoPath,
      theme: widget.theme,
    );
    if (trimmed == null || !mounted) return;
    final service = ref.read(mediaAndAuthServiceProvider);
    final ratio = await service.detectVideoAspectRatio(trimmed.videoPath);
    if (!mounted) return;
    setState(() {
      _videoSource = trimmed.videoPath;
      _videoThumbnailPath = trimmed.thumbnailPath;
      _videoDurationSeconds = trimmed.durationSeconds;
      _mediaLinkCtrl.text = trimmed.videoPath;
      _useLinkSource = false;
    });
    _applyAspectRatioToGrid(ratio);
  }

  Future<void> _pickVideo(ImageSource source) async {
    HapticFeedback.selectionClick();
    final service = ref.read(mediaAndAuthServiceProvider);
    final path = await service.pickAndPersistVideo(source: source);
    if (path == null || !mounted) return;
    _rawPickedVideoPath = path;
    await _openVideoTrimmerOn(path);
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
    final aboutHim = ref.watch(
      bentoCanvasProvider.select((s) => s.isTalkingAboutHim),
    );
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
                        ? widget.type.displayNameFor(aboutHim: aboutHim)
                        : 'Editar · ${widget.type.displayNameFor(aboutHim: aboutHim)}',
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
                          children: <Widget>[
                            ..._buildStep1ContentFields(theme),
                            _buildCoupleMetaControls(theme),
                          ],
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
                        if (!_validateKeepsake()) return;
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

  Widget _buildCoupleMetaControls(RochyThemeData theme) {
    final canvas = ref.watch(bentoCanvasProvider);
    final partnerA = canvas.partnerAName;
    final partnerB = canvas.partnerBName;
    final authorLabel = _authorId == 'rochy' ? partnerB : partnerA;
    final otherName = _authorId == 'rochy' ? partnerA : partnerB;

    return Container(
      margin: const EdgeInsets.only(top: 6, bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.ivorySurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.borderTint),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.favorite_rounded,
                size: 14,
                color: theme.brandAccent,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'SORPRESA · ${authorLabel.toUpperCase()}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: RochyTypography.metadata(
                    theme.brandAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ).copyWith(letterSpacing: 0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: _isSurprise
                  ? theme.terracotta.withValues(alpha: 0.10)
                  : theme.canvasBackground.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _isSurprise
                    ? theme.terracotta.withValues(alpha: 0.35)
                    : theme.borderTint,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Material(
                  type: MaterialType.transparency,
                  child: SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    activeTrackColor: theme.terracotta,
                    title: Text(
                      '🎁 Es una sorpresa',
                      style: RochyTypography.sansTitle(
                        theme.inkPrimary,
                        fontSize: 13,
                      ),
                    ),
                    subtitle: Text(
                      _isSurprise && _surpriseUnlockAt != null
                          ? 'Cápsula del tiempo: se abrirá sola el ${_surpriseUnlockAt!.day.toString().padLeft(2, '0')}/${_surpriseUnlockAt!.month.toString().padLeft(2, '0')}/${_surpriseUnlockAt!.year}.'
                          : 'Se mantiene sellada cuando $otherName mire este tablero hasta que la reveles.',
                      style: RochyTypography.metadata(
                        theme.inkSecondary,
                        fontSize: 11,
                      ),
                    ),
                    value: _isSurprise,
                    onChanged: (v) {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _isSurprise = v;
                        if (!v) _surpriseUnlockAt = null;
                      });
                    },
                  ),
                ),
                if (_isSurprise) ...<Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: theme.terracotta,
                            side: BorderSide(
                              color: theme.terracotta.withValues(alpha: 0.45),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                          ),
                          onPressed: () async {
                            HapticFeedback.selectionClick();
                            final now = DateTime.now();
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _surpriseUnlockAt ??
                                  now.add(const Duration(days: 7)),
                              firstDate: DateTime(now.year - 1),
                              lastDate: DateTime(now.year + 10),
                              helpText: 'Fecha para abrir la cápsula',
                            );
                            if (picked != null && mounted) {
                              setState(() {
                                _surpriseUnlockAt = DateTime(
                                  picked.year,
                                  picked.month,
                                  picked.day,
                                );
                              });
                            }
                          },
                          icon: const Icon(Icons.lock_clock_rounded, size: 16),
                          label: Text(
                            _surpriseUnlockAt == null
                                ? 'Programar fecha automática (opcional)'
                                : 'Abrir el ${_surpriseUnlockAt!.day.toString().padLeft(2, '0')}/${_surpriseUnlockAt!.month.toString().padLeft(2, '0')}/${_surpriseUnlockAt!.year}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: RochyTypography.metadata(
                              theme.terracotta,
                              fontSize: 11.2,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      if (_surpriseUnlockAt != null) ...<Widget>[
                        const SizedBox(width: 4),
                        IconButton(
                          tooltip: 'Quitar fecha',
                          visualDensity: VisualDensity.compact,
                          onPressed: () =>
                              setState(() => _surpriseUnlockAt = null),
                          icon: Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: theme.inkSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildStep1ContentFields(RochyThemeData theme) {
    switch (widget.type) {
      case BentoNodeType.travelPassport:
        return [
          _field('Título del pasaporte', _titleCtrl, 'Ej. Nuestro pasaporte',
              theme),
          _sectionLabel('Lugares que visitamos juntos', theme),
          PassportEntriesEditor(
              initial: _passportStamps,
              onChanged: (stamps) {
                setState(() => _passportStamps = stamps);
              }),
        ];
      case BentoNodeType.savedChat:
        return [
          _field('Título de la conversación', _titleCtrl,
              'Ej. Ese día nos reímos mucho', theme),
          ChatMessagesEditor(
              initial: _chatMessages,
              onChanged: (messages) {
                setState(() => _chatMessages = messages);
              }),
        ];
      case BentoNodeType.vintageTicket:
        return [
          _field('Título del ticket', _titleCtrl,
              'Ej. Nuestra primera película', theme),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final entry in const {
              'cinema': 'Cine',
              'concert': 'Concierto',
              'receipt': 'Recibo'
            }.entries)
              ChoiceChip(
                  label: Text(entry.value),
                  selected: _vintageTicketKind == entry.key,
                  onSelected: (_) =>
                      setState(() => _vintageTicketKind = entry.key)),
          ]),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              final chosen = await showDatePicker(
                  context: context,
                  initialDate: _targetDate,
                  firstDate: DateTime(1900),
                  lastDate: DateTime(2200, 12, 31));
              if (chosen != null && mounted) {
                setState(() => _targetDate = chosen);
              }
            },
            icon: const Icon(Icons.calendar_month_rounded),
            label: Text('Fecha del ticket: ${keepsakeDateLabel(_targetDate)}'),
          ),
          _field('Código simbólico', _tertiaryCtrl, 'Ej. AMOR-001', theme),
          _starRatingField(
              label: 'Calificación',
              value: _rating,
              theme: theme,
              onChanged: (value) => setState(() => _rating = value)),
          _field(
              'Nota al pie', _bodyCtrl, 'Qué hizo especial ese momento…', theme,
              maxLines: 3),
        ];

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
              onCropExisting:
                  (_videoSource.isNotEmpty && !_videoSource.startsWith('http'))
                      ? () => _openVideoTrimmerOn(
                            _rawPickedVideoPath.isNotEmpty
                                ? _rawPickedVideoPath
                                : _videoSource,
                          )
                      : null,
              cropLabel:
                  'Recortar video (máx. 30s · ${_videoDurationSeconds}s)',
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
          _field('Fecha (opcional)', _secondaryCtrl, 'Ej. Domingo por la tarde',
              theme),
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
              onCropExisting: _recropCurrentPhoto,
              cropLabel: 'Recortar foto',
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
          _field(
              'Fecha (opcional)', _secondaryCtrl, 'Ej. 14 de octubre', theme),
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
            children: const <({String key, String label, IconData icon})>[
              (key: 'coffee', label: 'Café', icon: Icons.coffee_rounded),
              (key: 'flower', label: 'Flor', icon: Icons.local_florist_rounded),
              (key: 'sun', label: 'Sol', icon: Icons.wb_sunny_rounded),
              (key: 'music', label: 'Música', icon: Icons.music_note_rounded),
              (key: 'book', label: 'Libro', icon: Icons.menu_book_rounded),
              (key: 'cake', label: 'Pastel', icon: Icons.cake_rounded),
              (
                key: 'camera',
                label: 'Cámara',
                icon: Icons.photo_camera_rounded
              ),
              (key: 'heart', label: 'Corazón', icon: Icons.favorite_rounded),
            ].map((item) {
              return _WarmChoicePill(
                label: item.label,
                icon: item.icon,
                selected: _iconKey == item.key,
                theme: theme,
                onTap: () => setState(() => _iconKey = item.key),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          _field('Frase atrás (Cara B)', _bodyCtrl, 'Ej. “Con doble espuma”',
              theme),
          _field('Etiqueta o fecha de voz (opcional)', _tertiaryCtrl,
              'Ej. 12 oct · 0:18', theme),
          _voiceRecorderTile(theme),
        ];

      case BentoNodeType.quote:
        return <Widget>[
          _sectionLabel('Estilo del texto', theme),
          Row(
            children: <Widget>[
              Expanded(
                child: _WarmChoicePill(
                  label: 'Cita con comillas',
                  selected: !_quotePlainText,
                  theme: theme,
                  onTap: () => setState(() => _quotePlainText = false),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _WarmChoicePill(
                  label: 'Texto libre / Nota',
                  selected: _quotePlainText,
                  theme: theme,
                  onTap: () => setState(() => _quotePlainText = true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _field(
            _quotePlainText
                ? 'Texto completo sobre ${ref.read(bentoCanvasProvider).isTalkingAboutHim ? 'él' : 'ella'}'
                : 'Frase que dijo',
            _titleCtrl,
            _quotePlainText
                ? 'Escribe libremente todo lo que quieras contar sobre ${ref.read(bentoCanvasProvider).isTalkingAboutHim ? 'él' : 'ella'}…'
                : 'Ej. En tu paz, encontré mi hogar.',
            theme,
            maxLines: _quotePlainText ? 10 : 4,
          ),
          _field(
            'Título o contexto (opcional)',
            _secondaryCtrl,
            'Ej. Lo que más admiro de ti',
            theme,
          ),
        ];

      case BentoNodeType.audioNote:
        return <Widget>[
          _field(
            'Título',
            _titleCtrl,
            'Ej. Canción que me recuerda a ${ref.read(bentoCanvasProvider).isTalkingAboutHim ? 'él' : 'ella'}',
            theme,
          ),
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
              onCropExisting: _recropCurrentPhoto,
              cropLabel: 'Recortar foto',
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
          _field('Nota al pie (opcional)', _secondaryCtrl,
              'Ej. Toca un detalle para destacarlo', theme),
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
            _starRatingField(
              label: 'Estrellas',
              value: _starCount,
              theme: theme,
              onChanged: (v) => setState(() => _starCount = v),
            ),
          _field('Nota del recuerdo (opcional)', _bodyCtrl,
              'Qué lo hace especial…', theme,
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
          _paletteSwatchEditor(theme),
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
              const SizedBox(width: 8),
              Expanded(
                child: _WarmChoicePill(
                  label: 'Serie',
                  selected: _bookOrMovie == 'series',
                  theme: theme,
                  onTap: () => setState(() => _bookOrMovie = 'series'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _field('Título', _titleCtrl, 'Ej. El Principito', theme),
          _field(
              'Autor o director', _secondaryCtrl, 'Ej. Saint-Exupéry', theme),
          _starRatingField(
            label: 'Calificación',
            value: _rating,
            theme: theme,
            onChanged: (v) => setState(() => _rating = v),
          ),
          _field('Por qué le gusta', _bodyCtrl, 'Su nota personal…', theme,
              maxLines: 2),
          _sourceToggle(
            theme,
            phoneLabel: 'Portada / póster del teléfono',
            linkLabel: 'Link de portada',
          ),
          const SizedBox(height: 10),
          if (!_useLinkSource)
            _phonePickerCards(
              theme: theme,
              galleryTitle: 'Elegir portada',
              cameraTitle: 'Tomar foto',
              hasPicked: _mediaLinkCtrl.text.isNotEmpty &&
                  !_mediaLinkCtrl.text.startsWith('http'),
              onGallery: () => _pickPhoto(ImageSource.gallery),
              onCamera: () => _pickPhoto(ImageSource.camera),
              onCropExisting: _recropCurrentPhoto,
              cropLabel: 'Recortar portada',
            )
          else
            _field(
              'Link de portada o póster (opcional)',
              _mediaLinkCtrl,
              'https://...',
              theme,
            ),
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
          _field('Vista previa en el sobre (opcional)', _secondaryCtrl,
              'Ej. Una nota breve guardada aquí…', theme),
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
          _field('Nota al pie (opcional)', _secondaryCtrl,
              'Ej. Sus pequeños rituales', theme),
        ];

      case BentoNodeType.photoStrip:
        return <Widget>[
          _sectionLabel('Estilo de carrete', theme),
          Row(
            children: <Widget>[
              Expanded(
                child: _WarmChoicePill(
                  label: 'Collage',
                  icon: Icons.grid_view_rounded,
                  selected: _stripLayout == 'collage',
                  theme: theme,
                  onTap: () => setState(() => _stripLayout = 'collage'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _WarmChoicePill(
                  label: 'Deslizable',
                  icon: Icons.view_carousel_rounded,
                  selected: _stripLayout == 'carousel',
                  theme: theme,
                  onTap: () => setState(() => _stripLayout = 'carousel'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _photoStripEditor(theme),
          _field('Título del mini-álbum', _titleCtrl,
              'Ej. Domingo en el centro', theme),
          _field('Subtítulo o fecha (opcional)', _secondaryCtrl,
              'Ej. 4 recuerdos de tarde', theme),
        ];

      case BentoNodeType.moodPulse:
        final aboutHim = ref.read(bentoCanvasProvider).isTalkingAboutHim;
        return <Widget>[
          _sectionLabel('Clima emocional', theme),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <({String key, String label, IconData icon})>[
              (
                key: 'sunny',
                label: aboutHim ? 'Soleado' : 'Soleada',
                icon: Icons.wb_sunny_rounded,
              ),
              (
                key: 'serene',
                label: aboutHim ? 'Sereno' : 'Serena',
                icon: Icons.spa_rounded,
              ),
              (
                key: 'sparkling',
                label: 'Radiante',
                icon: Icons.auto_awesome_rounded,
              ),
              (
                key: 'cozy',
                label: aboutHim ? 'Acogedor' : 'Acogedora',
                icon: Icons.local_cafe_rounded,
              ),
              (
                key: 'nostalgic',
                label: aboutHim ? 'Nostálgico' : 'Nostálgica',
                icon: Icons.nights_stay_rounded,
              ),
              (
                key: 'rainy',
                label: 'Días grises',
                icon: Icons.water_drop_rounded,
              ),
            ].map((m) {
              return _WarmChoicePill(
                label: m.label,
                icon: m.icon,
                selected: _moodKey == m.key,
                theme: theme,
                onTap: () => setState(() => _moodKey = m.key),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          _starRatingField(
            label: 'Nivel de energía',
            value: _energyLevel,
            theme: theme,
            onChanged: (v) => setState(() => _energyLevel = v),
          ),
          _field('Título', _titleCtrl, 'Ej. Con mucha paz hoy', theme),
          _field(
            'Nota breve',
            _bodyCtrl,
            'Cómo ${aboutHim ? 'lo' : 'la'} viste o qué pasó…',
            theme,
            maxLines: 2,
          ),
          _field('Fecha o momento (opcional)', _secondaryCtrl,
              'Ej. Hoy en la tarde', theme),
        ];

      case BentoNodeType.cravingRecipe:
        return <Widget>[
          _sectionLabel('Categoría', theme),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const <({String key, String label, IconData icon})>[
              (key: 'drink', label: 'Bebida', icon: Icons.local_cafe_rounded),
              (key: 'food', label: 'Plato', icon: Icons.restaurant_rounded),
              (
                key: 'dessert',
                label: 'Postre',
                icon: Icons.bakery_dining_rounded
              ),
              (key: 'place', label: 'Sitio', icon: Icons.storefront_rounded),
            ].map((c) {
              return _WarmChoicePill(
                label: c.label,
                icon: c.icon,
                selected: _cravingCategory == c.key,
                theme: theme,
                onTap: () => setState(() => _cravingCategory = c.key),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          _field('Nombre', _titleCtrl, 'Ej. Matcha frío con avena', theme),
          _field('Pedido exacto o ingredientes (uno por línea)', _itemsCtrl,
              'Leche de avena\nPoco hielo\nToque de vainilla', theme,
              maxLines: 4),
          _field('Dónde pedirlo / truco (opcional)', _secondaryCtrl,
              'Ej. En la cafetería de la esquina', theme),
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
              onCropExisting: _recropCurrentPhoto,
              cropLabel: 'Recortar foto',
            )
          else
            _field('Link de foto (opcional)', _mediaLinkCtrl, 'https://...',
                theme),
        ];

      case BentoNodeType.planTicket:
        return <Widget>[
          _field('Plan o promesa', _titleCtrl, 'Ej. Picnic viendo el atardecer',
              theme),
          _field('Cuándo (opcional)', _secondaryCtrl, 'Ej. Este domingo 5 PM',
              theme),
          _field('Lugar (opcional)', _tertiaryCtrl, 'Ej. Paseo de las Murallas',
              theme),
          _realLocationPickerTile(theme, isLocationPin: false),
          _field('Detalle de la promesa (opcional)', _bodyCtrl,
              'Qué vamos a llevar o hacer…', theme,
              maxLines: 2),
          _editorialSwitchTile(
            title: 'Ya lo cumplimos / canjeado',
            value: _planRedeemed,
            theme: theme,
            onChanged: (v) => setState(() => _planRedeemed = v),
          ),
        ];

      case BentoNodeType.sketchDoodle:
        return <Widget>[
          RochySketchPad(
            strokes: _sketchStrokes,
            theme: theme,
            onChanged: (next) => setState(() => _sketchStrokes = next),
          ),
          _field('Título o firma al pie (opcional)', _titleCtrl,
              'Ej. Para ti, Rochy', theme),
        ];

      case BentoNodeType.polaroidThread:
        return <Widget>[
          _field('Título del hilo (opcional)', _titleCtrl,
              'Ej. Tarde en el malecón', theme),
          _polaroidThreadEditor(theme),
          _sectionLabel('Estilo del hilo', theme),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const <({String key, String label, IconData icon})>[
              (key: 'jute', label: 'Yute', icon: Icons.gesture_rounded),
              (
                key: 'terracotta',
                label: 'Terracota',
                icon: Icons.favorite_outline_rounded,
              ),
              (key: 'gold', label: 'Dorado', icon: Icons.auto_awesome_rounded),
              (key: 'ivory', label: 'Marfil', icon: Icons.linear_scale_rounded),
            ].map((item) {
              return _WarmChoicePill(
                label: item.label,
                icon: item.icon,
                selected: _threadStyle == item.key,
                theme: theme,
                onTap: () => setState(() => _threadStyle = item.key),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          _field('Nota del recuerdo (opcional)', _secondaryCtrl,
              'Historia que une estas fotos…', theme,
              maxLines: 2),
        ];

      case BentoNodeType.coupleQuestion:
        final canvas = ref.read(bentoCanvasProvider);
        final isRochyViewer = canvas.viewerAuthor == 'rochy';
        final partnerLabel =
            isRochyViewer ? canvas.partnerAName : canvas.partnerBName;
        final partnerAnswered = isRochyViewer
            ? _answerSamuel.trim().isNotEmpty
            : _answerRochy.trim().isNotEmpty;
        return <Widget>[
          _field(
            'Pregunta para los dos',
            _titleCtrl,
            'Ej. ¿Cuál fue nuestra mejor noche juntos?',
            theme,
            maxLines: 3,
          ),
          _sectionLabel('Ideas rápidas', theme),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const <String>[
              '¿Qué canción te recuerda a nosotros?',
              '¿Cuál es tu recuerdo favorito nuestro?',
              '¿Qué viaje soñamos hacer pronto?',
              '¿Qué detalle mío te hace sonreír?',
            ].map((idea) {
              return ActionChip(
                backgroundColor: theme.ivorySurface,
                label: Text(
                  idea,
                  style:
                      RochyTypography.metadata(theme.inkPrimary, fontSize: 11),
                ),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _titleCtrl.text = idea;
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          TextFormField(
            initialValue: isRochyViewer ? _answerRochy : _answerSamuel,
            maxLines: 3,
            style: RochyTypography.sansBody(theme.inkPrimary, fontSize: 13.5),
            decoration: InputDecoration(
              labelText: 'Tu respuesta (${canvas.viewerDisplayName})',
              hintText:
                  'Escríbela aquí; $partnerLabel la verá cuando también responda.',
              filled: true,
              fillColor: theme.ivorySurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onChanged: (v) {
              setState(() {
                if (isRochyViewer) {
                  _answerRochy = v;
                } else {
                  _answerSamuel = v;
                }
              });
            },
          ),
          if (partnerAnswered) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              '♥ $partnerLabel ya dejó su respuesta en esta pregunta.',
              style: RochyTypography.metadata(
                theme.sage,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ];

      case BentoNodeType.aboutHer:
        final canvas = ref.read(bentoCanvasProvider);
        return <Widget>[
          _field(
            'Título (opcional)',
            _titleCtrl,
            'Ej. Así es ${canvas.personalTargetDisplayName}',
            theme,
          ),
          _aboutHerEditor(theme),
        ];

      case BentoNodeType.wardrobeCloset:
        return <Widget>[
          _field('Título (opcional)', _titleCtrl, 'Ej. Su Clóset', theme),
          _wardrobeClosetEditor(theme),
        ];
    }
  }

  final List<int> _wardrobeRowIds = <int>[];
  int _nextWardrobeRowId = 0;

  int _wardrobeRowKey(int index) {
    while (_wardrobeRowIds.length <= index) {
      _wardrobeRowIds.add(_nextWardrobeRowId++);
    }
    return _wardrobeRowIds[index];
  }

  int _wardrobeSizeRowKey(int index) {
    while (_wardrobeSizeRowIds.length <= index) {
      _wardrobeSizeRowIds.add(_nextWardrobeSizeRowId++);
    }
    return _wardrobeSizeRowIds[index];
  }

  String _previewResolvedSize(WardrobeItem item) {
    if (item.sizeOverride.trim().isNotEmpty) return item.sizeOverride.trim();
    final target = item.garmentType.trim().toLowerCase();
    for (final entry in _wardrobeSizes) {
      if (entry.typeName.trim().toLowerCase() == target &&
          entry.size.trim().isNotEmpty) {
        return entry.size.trim();
      }
    }
    return '';
  }

  Future<void> _pickWardrobeItemPhoto(int index, ImageSource source) async {
    final path = await _pickAndCropCompressedPhoto(source);
    if (path == null || !mounted || index >= _wardrobeItems.length) return;
    setState(() {
      final copy = List<WardrobeItem>.of(_wardrobeItems);
      copy[index] = copy[index].copyWith(imageUrl: path);
      _wardrobeItems = copy;
    });
  }

  Widget _wardrobeClosetEditor(RochyThemeData theme) {
    final garmentOptions = <String>[];
    final seenLower = <String>{};
    for (final e in _wardrobeSizes) {
      final name = e.typeName.trim();
      if (name.isEmpty) continue;
      if (seenLower.add(name.toLowerCase())) {
        garmentOptions.add(name);
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _sectionLabel('Tus tipos de prenda y sus tallas', theme),
          for (var i = 0; i < _wardrobeSizes.length; i++) ...<Widget>[
            Builder(
              builder: (_) {
                final entry = _wardrobeSizes[i];
                final sKey = _wardrobeSizeRowKey(i);
                return Padding(
                  key: ValueKey('wd_srow_$sKey'),
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          key: ValueKey('wd_stype_$sKey'),
                          initialValue: entry.typeName,
                          style: RochyTypography.sansBody(
                            theme.inkPrimary,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Tipo de prenda',
                            hintText: 'Ej. Vestidos, Tenis',
                            isDense: true,
                            filled: true,
                            fillColor: theme.ivorySurface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: theme.borderTint),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: theme.borderTint),
                            ),
                          ),
                          onChanged: (v) {
                            setState(() {
                              final copy =
                                  List<WardrobeSizeEntry>.of(_wardrobeSizes);
                              copy[i] = entry.copyWith(typeName: v);
                              _wardrobeSizes = copy;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          key: ValueKey('wd_ssize_$sKey'),
                          initialValue: entry.size,
                          style: RochyTypography.sansBody(
                            theme.inkPrimary,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Talla',
                            hintText: 'Ej. S, 37',
                            isDense: true,
                            filled: true,
                            fillColor: theme.ivorySurface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: theme.borderTint),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: theme.borderTint),
                            ),
                          ),
                          onChanged: (v) {
                            setState(() {
                              final copy =
                                  List<WardrobeSizeEntry>.of(_wardrobeSizes);
                              copy[i] = entry.copyWith(size: v);
                              _wardrobeSizes = copy;
                            });
                          },
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          setState(() {
                            final copy =
                                List<WardrobeSizeEntry>.of(_wardrobeSizes)
                                  ..removeAt(i);
                            _wardrobeSizes = copy;
                            if (i < _wardrobeSizeRowIds.length) {
                              _wardrobeSizeRowIds.removeAt(i);
                            }
                          });
                        },
                        icon: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: theme.inkSecondary,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _wardrobeSizes = <WardrobeSizeEntry>[
                    ..._wardrobeSizes,
                    const WardrobeSizeEntry(typeName: '', size: ''),
                  ];
                });
              },
              icon: const Icon(Icons.add_rounded, size: 17),
              label: const Text('Agregar tipo de prenda'),
            ),
          ),
          const SizedBox(height: 6),
          _sectionLabel('Prendas y Outfits (polaroids)', theme),
          for (var i = 0; i < _wardrobeItems.length; i++) ...<Widget>[
            Builder(
              builder: (_) {
                final item = _wardrobeItems[i];
                final rowKey = _wardrobeRowKey(i);
                final autoSize = _previewResolvedSize(item);
                return Container(
                  key: ValueKey('wd_card_$rowKey'),
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.ivorySurface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: theme.borderTint),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                              width: 44,
                              height: 44,
                              child: item.imageUrl.trim().isNotEmpty
                                  ? EditorialImage(
                                      imageUrl: item.imageUrl,
                                      fallbackScene:
                                          EditorialFallbackScene.cafeSunlit,
                                    )
                                  : Container(
                                      color: theme.brandAccent
                                          .withValues(alpha: 0.12),
                                      child: Icon(
                                        Icons.checkroom_rounded,
                                        color: theme.brandAccent,
                                        size: 20,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  'Prenda ${i + 1}',
                                  style: RochyTypography.sansTitle(
                                    theme.inkPrimary,
                                    fontSize: 13.5,
                                  ),
                                ),
                                if (autoSize.isNotEmpty)
                                  Text(
                                    'Talla automática: $autoSize',
                                    style: RochyTypography.metadata(
                                      theme.brandAccent,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              setState(() {
                                final copy =
                                    List<WardrobeItem>.of(_wardrobeItems)
                                      ..removeAt(i);
                                _wardrobeItems = copy;
                                if (i < _wardrobeRowIds.length) {
                                  _wardrobeRowIds.removeAt(i);
                                }
                              });
                            },
                            icon: Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: theme.inkSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: const <({String key, String label})>[
                          (key: 'uses', label: 'Lo usa'),
                          (key: 'likes', label: 'Le gusta'),
                          (key: 'gift', label: 'Idea regalo'),
                        ].map((c) {
                          return _WarmChoicePill(
                            label: c.label,
                            selected: item.category == c.key,
                            theme: theme,
                            onTap: () => setState(() {
                              final copy =
                                  List<WardrobeItem>.of(_wardrobeItems);
                              copy[i] = item.copyWith(category: c.key);
                              _wardrobeItems = copy;
                            }),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 6),
                      if (garmentOptions.isEmpty)
                        Text(
                          'Agrega arriba los tipos de prenda para elegir su talla.',
                          style: RochyTypography.metadata(
                            theme.inkSecondary,
                            fontSize: 11.5,
                          ),
                        )
                      else
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: garmentOptions.map((g) {
                            return _WarmChoicePill(
                              label: g,
                              selected: item.garmentType.trim().toLowerCase() ==
                                  g.toLowerCase(),
                              theme: theme,
                              onTap: () => setState(() {
                                final copy =
                                    List<WardrobeItem>.of(_wardrobeItems);
                                copy[i] = item.copyWith(garmentType: g);
                                _wardrobeItems = copy;
                              }),
                            );
                          }).toList(),
                        ),
                      const SizedBox(height: 8),
                      TextFormField(
                        key: ValueKey('wd_name_$rowKey'),
                        initialValue: item.name,
                        onChanged: (v) {
                          final copy = List<WardrobeItem>.of(_wardrobeItems);
                          copy[i] = copy[i].copyWith(name: v);
                          _wardrobeItems = copy;
                        },
                        decoration: InputDecoration(
                          hintText: 'Nombre (ej. Suéter beige, Tenis blancos)',
                          isDense: true,
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.72),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 9,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: theme.borderTint),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: theme.borderTint),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: <Widget>[
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              key: ValueKey('wd_size_$rowKey'),
                              initialValue: item.sizeOverride,
                              onChanged: (v) {
                                final copy =
                                    List<WardrobeItem>.of(_wardrobeItems);
                                copy[i] = copy[i].copyWith(sizeOverride: v);
                                _wardrobeItems = copy;
                              },
                              decoration: InputDecoration(
                                hintText: autoSize.isNotEmpty
                                    ? 'Talla ($autoSize)'
                                    : 'Talla puntual',
                                isDense: true,
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.72),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 9,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      BorderSide(color: theme.borderTint),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      BorderSide(color: theme.borderTint),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              key: ValueKey('wd_note_$rowKey'),
                              initialValue: item.note,
                              onChanged: (v) {
                                final copy =
                                    List<WardrobeItem>.of(_wardrobeItems);
                                copy[i] = copy[i].copyWith(note: v);
                                _wardrobeItems = copy;
                              },
                              decoration: InputDecoration(
                                hintText: 'Nota (opcional)',
                                isDense: true,
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.72),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 9,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      BorderSide(color: theme.borderTint),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      BorderSide(color: theme.borderTint),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: _WarmActionTile(
                              icon: Icons.photo_library_rounded,
                              label: 'Galería',
                              theme: theme,
                              onTap: () => _pickWardrobeItemPhoto(
                                  i, ImageSource.gallery),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: _WarmActionTile(
                              icon: Icons.photo_camera_rounded,
                              label: 'Cámara',
                              theme: theme,
                              onTap: () =>
                                  _pickWardrobeItemPhoto(i, ImageSource.camera),
                            ),
                          ),
                          if (item.imageUrl.trim().isNotEmpty) ...<Widget>[
                            const SizedBox(width: 6),
                            IconButton(
                              tooltip: 'Quitar foto',
                              onPressed: () => setState(() {
                                final copy =
                                    List<WardrobeItem>.of(_wardrobeItems);
                                copy[i] = item.copyWith(imageUrl: '');
                                _wardrobeItems = copy;
                              }),
                              icon: Icon(
                                Icons.hide_image_rounded,
                                size: 18,
                                color: theme.inkSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.brandAccent,
                side: BorderSide(
                  color: theme.brandAccent.withValues(alpha: 0.45),
                ),
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(vertical: 11),
              ),
              onPressed: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _wardrobeItems = <WardrobeItem>[
                    ..._wardrobeItems,
                    const WardrobeItem(name: ''),
                  ];
                });
              },
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Agregar prenda u outfit'),
            ),
          ),
        ],
      ),
    );
  }

  void _addAboutHerRow(String prefix) {
    HapticFeedback.selectionClick();
    setState(() {
      _aboutPrefixCtrls.add(
        TextEditingController(text: prefix)..addListener(_refreshPreview),
      );
      _aboutDetailCtrls.add(
        TextEditingController()..addListener(_refreshPreview),
      );
    });
  }

  void _removeAboutHerRow(int index) {
    if (index < 0 || index >= _aboutPrefixCtrls.length) return;
    HapticFeedback.lightImpact();
    setState(() {
      _aboutPrefixCtrls.removeAt(index).dispose();
      if (index < _aboutDetailCtrls.length) {
        _aboutDetailCtrls.removeAt(index).dispose();
      }
    });
  }

  Widget _aboutHerEditor(RochyThemeData theme) {
    final aboutHim = ref.watch(
      bentoCanvasProvider.select((s) => s.isTalkingAboutHim),
    );
    final pronoun = aboutHim ? 'Él' : 'Ella';
    final count = math.min(_aboutPrefixCtrls.length, _aboutDetailCtrls.length);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _sectionLabel('Frases sobre ${aboutHim ? 'él' : 'ella'}', theme),
          for (var i = 0; i < count; i++) ...<Widget>[
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.ivorySurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.borderTint),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(
                    width: 108,
                    child: TextField(
                      controller: _aboutPrefixCtrls[i],
                      style: RochyTypography.metadata(
                        theme.brandAccent,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: InputDecoration(
                        hintText: '$pronoun es…',
                        isDense: true,
                        filled: true,
                        fillColor: theme.brandAccent.withValues(alpha: 0.08),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 9,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _aboutDetailCtrls[i],
                      maxLines: 3,
                      minLines: 1,
                      style: RochyTypography.sansBody(
                        theme.inkPrimary,
                        fontSize: 13,
                      ),
                      decoration: InputDecoration(
                        hintText: 'lo que quieres decir…',
                        isDense: true,
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.72),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 9,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: theme.borderTint),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: theme.borderTint),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _removeAboutHerRow(i),
                    icon: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: theme.inkSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: (aboutHim
                    ? const <String>[
                        'Él es',
                        'Él tiene',
                        'Él ama',
                        'Él siempre',
                        'Él sueña',
                        'Otro…',
                      ]
                    : const <String>[
                        'Ella es',
                        'Ella tiene',
                        'Ella ama',
                        'Ella siempre',
                        'Ella sueña',
                        'Otro…',
                      ])
                .map((label) {
              return ActionChip(
                backgroundColor: theme.ivorySurface,
                side: BorderSide(color: theme.borderTint),
                avatar: Icon(
                  Icons.add_rounded,
                  size: 15,
                  color: theme.brandAccent,
                ),
                label: Text(
                  label,
                  style: RochyTypography.metadata(
                    theme.inkPrimary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onPressed: () => _addAboutHerRow(label == 'Otro…' ? '' : label),
              );
            }).toList(),
          ),
        ],
      ),
    );
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
        }).toList()
          ..add(
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _showCustomBgPicker = !_showCustomBgPicker);
              },
              child: Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: _showCustomBgPicker
                      ? theme.brandAccent.withValues(alpha: 0.14)
                      : theme.ivorySurface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: _showCustomBgPicker
                        ? theme.brandAccent
                        : theme.borderTint,
                    width: _showCustomBgPicker ? 1.8 : 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      width: 18,
                      height: 18,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: SweepGradient(
                          colors: <Color>[
                            Color(0xFFFF0000),
                            Color(0xFFFFFF00),
                            Color(0xFF00FF00),
                            Color(0xFF00FFFF),
                            Color(0xFF0000FF),
                            Color(0xFFFF00FF),
                            Color(0xFFFF0000),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Color libre',
                      style: RochyTypography.metadata(
                        _showCustomBgPicker
                            ? theme.brandAccent
                            : theme.inkPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ),
      if (_showCustomBgPicker) ...<Widget>[
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.ivorySurface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: theme.borderTint),
          ),
          child: RochyColorPickerBox(
            color: Color(activeColorHex),
            theme: theme,
            squareHeight: 165,
            onColorChanged: (c) =>
                setState(() => _customBgColorHex = c.toARGB32()),
          ),
        ),
      ],
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
      const SizedBox(height: 8),
      _field('Etiquetas para Moments (separadas por coma)', _tagsCtrl,
          'Ej. café, viajes, favorito', theme),
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
    VoidCallback? onCropExisting,
    String cropLabel = 'Recortar / Ajustar',
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
                    'Archivo optimizado en tu teléfono',
                    style: RochyTypography.metadata(
                      theme.sage,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (onCropExisting != null)
                  GestureDetector(
                    onTap: onCropExisting,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.brandAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            Icons.crop_rounded,
                            size: 13,
                            color: theme.brandAccent,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            cropLabel,
                            style: RochyTypography.metadata(
                              theme.brandAccent,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
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

  Future<void> _importAudioFile() async {
    HapticFeedback.selectionClick();
    final service = ref.read(mediaAndAuthServiceProvider);
    if (_isRecordingAudio) {
      await service.stopVoiceRecording();
    }
    final path = await service.pickAndPersistAudio();
    if (path == null || !mounted) return;
    setState(() {
      _isRecordingAudio = false;
      _localAudioPath = path;
    });
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                _isRecordingAudio
                    ? Icons.graphic_eq_rounded
                    : Icons.mic_rounded,
                color: _isRecordingAudio ? theme.terracotta : theme.brandAccent,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _isRecordingAudio
                      ? 'Grabando nota de voz…'
                      : _localAudioPath.isNotEmpty
                          ? 'Audio listo para sonar'
                          : 'Graba o importa un audio (MP3, M4A, WAV, OGG…)',
                  softWrap: true,
                  style:
                      RochyTypography.metadata(theme.inkPrimary, fontSize: 12),
                ),
              ),
              if (_localAudioPath.isNotEmpty && !_isRecordingAudio)
                IconButton(
                  tooltip: 'Quitar audio',
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    setState(() => _localAudioPath = '');
                  },
                  icon: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: theme.inkSecondary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              GestureDetector(
                onTap: _toggleVoiceRecord,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: _isRecordingAudio
                        ? theme.terracotta
                        : theme.brandAccent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        _isRecordingAudio
                            ? Icons.stop_rounded
                            : Icons.mic_rounded,
                        size: 15,
                        color: _isRecordingAudio
                            ? const Color(0xFFFAF7F2)
                            : theme.brandAccent,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _isRecordingAudio ? 'Detener' : 'Grabar',
                        style: RochyTypography.metadata(
                          _isRecordingAudio
                              ? const Color(0xFFFAF7F2)
                              : theme.brandAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              GestureDetector(
                onTap: _importAudioFile,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.sage.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: theme.sage.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.audio_file_rounded,
                        size: 15,
                        color: theme.sage,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Importar archivo',
                        style: RochyTypography.metadata(
                          theme.sage,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _paletteSwatchEditor(RochyThemeData theme) {
    final int safeIdx = _activePaletteIndex
        .clamp(0, math.max(0, _paletteHexes.length - 1))
        .toInt();
    final activeColor = Color(_paletteHexes[safeIdx]);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _sectionLabel(
              'Colores de su paleta (toca un cuadro para editar)', theme),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              for (var i = 0; i < _paletteHexes.length; i++)
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _activePaletteIndex = i);
                  },
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: <Widget>[
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Color(_paletteHexes[i]),
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(
                            color: safeIdx == i
                                ? theme.brandAccent
                                : Colors.black.withValues(alpha: 0.16),
                            width: safeIdx == i ? 2.6 : 1.0,
                          ),
                          boxShadow: safeIdx == i
                              ? <BoxShadow>[
                                  BoxShadow(
                                    color: theme.brandAccent
                                        .withValues(alpha: 0.30),
                                    blurRadius: 8,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                      if (safeIdx == i && _paletteHexes.length > 2)
                        Positioned(
                          top: -6,
                          right: -6,
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              setState(() {
                                _paletteHexes.removeAt(i);
                                _activePaletteIndex = _activePaletteIndex.clamp(
                                    0, _paletteHexes.length - 1);
                              });
                            },
                            child: Container(
                              width: 19,
                              height: 19,
                              decoration: BoxDecoration(
                                color: theme.charcoal,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1.2,
                                ),
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              if (_paletteHexes.length < 5)
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _paletteHexes.add(_paletteHexes[safeIdx]);
                      _activePaletteIndex = _paletteHexes.length - 1;
                    });
                  },
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: theme.ivorySurface,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                        color: theme.brandAccent.withValues(alpha: 0.45),
                      ),
                    ),
                    child: Icon(
                      Icons.add_rounded,
                      color: theme.brandAccent,
                      size: 20,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.ivorySurface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: theme.borderTint),
            ),
            child: RochyColorPickerBox(
              color: activeColor,
              theme: theme,
              squareHeight: 190,
              onColorChanged: (c) {
                setState(() {
                  _paletteHexes[safeIdx] = c.toARGB32();
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _starRatingField({
    required String label,
    required int value,
    required RochyThemeData theme,
    required ValueChanged<int> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _sectionLabel(label, theme),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: theme.ivorySurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.borderTint),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List<Widget>.generate(5, (i) {
                final star = i + 1;
                final filled = star <= value;
                return IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    onChanged(star);
                  },
                  icon: Icon(
                    filled ? Icons.star_rounded : Icons.star_border_rounded,
                    color: filled
                        ? theme.terracotta
                        : theme.inkSecondary.withValues(alpha: 0.45),
                    size: 26,
                  ),
                );
              }),
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
