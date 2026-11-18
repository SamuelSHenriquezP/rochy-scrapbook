import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/bento_node.dart';
import '../services/media_and_auth_service.dart';
import '../theme/rochy_theme.dart';

/// Contrato de repositorio offline-first (preparado para Isar / Drift / SharedPreferences).
abstract interface class BentoRepository {
  BentoEntity loadEntity();
  List<BentoNode> loadNodes();
  List<RochyNotebook> loadNotebooks();
  String loadActiveNotebookId();
  void saveEntity(BentoEntity entity);
  void replaceAllNodes(List<BentoNode> nodes);
  void saveNode(BentoNode node);
  String exportJsonSnapshot();
  ({BentoEntity entity, List<BentoNode> nodes}) importJsonSnapshot(
    String rawJson,
  );
  List<BentoNode> starterTemplateNodes();

  Future<({
    List<RochyNotebook> notebooks,
    String activeNotebookId,
    bool biometricEnabled,
    bool showPaperGrain,
    double textScaleFactor,
  })?> hydrateFromDisk();

  Future<void> persistToDisk({
    required List<RochyNotebook> notebooks,
    required String activeNotebookId,
    required bool biometricEnabled,
    required bool showPaperGrain,
    required double textScaleFactor,
  });
}

/// Implementación local offline-first respaldada por [SharedPreferences] y
/// lista para migrar a Isar / Drift sin tocar la UI.
class LocalBentoRepository implements BentoRepository {
  LocalBentoRepository() {
    _notebooks = <RochyNotebook>[
      RochyNotebook(
        entity: _seedEntity(),
        nodes: _seedStarterNodes(),
      ),
    ];
    _activeNotebookId = _notebooks.first.entity.id;
  }

  static const _storageKey = 'rochy_notebooks_snapshot_v2';

  late List<RochyNotebook> _notebooks;
  late String _activeNotebookId;

  int get _activeIndex {
    final idx = _notebooks.indexWhere((n) => n.entity.id == _activeNotebookId);
    return idx == -1 ? 0 : idx;
  }

  @override
  BentoEntity loadEntity() => _notebooks[_activeIndex].entity;

  @override
  List<BentoNode> loadNodes() =>
      List<BentoNode>.unmodifiable(_notebooks[_activeIndex].nodes);

  @override
  List<RochyNotebook> loadNotebooks() =>
      List<RochyNotebook>.unmodifiable(_notebooks);

  @override
  String loadActiveNotebookId() => _activeNotebookId;

  @override
  void saveEntity(BentoEntity entity) {
    final idx = _activeIndex;
    _notebooks[idx] = _notebooks[idx].copyWith(entity: entity);
  }

  @override
  void replaceAllNodes(List<BentoNode> nodes) {
    final idx = _activeIndex;
    _notebooks[idx] = _notebooks[idx].copyWith(
      nodes: List<BentoNode>.of(nodes),
    );
  }

  @override
  void saveNode(BentoNode node) {
    final idx = _activeIndex;
    final current = List<BentoNode>.of(_notebooks[idx].nodes);
    final nodeIdx = current.indexWhere((n) => n.id == node.id);
    if (nodeIdx != -1) {
      current[nodeIdx] = node;
    } else {
      current.add(node);
    }
    _notebooks[idx] = _notebooks[idx].copyWith(nodes: current);
  }

  @override
  String exportJsonSnapshot() {
    final active = _notebooks[_activeIndex];
    return const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
      'entity': active.entity.toJson(),
      'nodes': active.nodes.map((n) => n.toJson()).toList(),
    });
  }

  @override
  ({BentoEntity entity, List<BentoNode> nodes}) importJsonSnapshot(
    String rawJson,
  ) {
    final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
    final entity = BentoEntity.fromJson(
      Map<String, dynamic>.from(decoded['entity'] as Map<dynamic, dynamic>),
    );
    final nodes = (decoded['nodes'] as List<dynamic>)
        .map(
          (item) => BentoNode.fromJson(
            Map<String, dynamic>.from(item as Map<dynamic, dynamic>),
          ),
        )
        .toList();

    final idx = _activeIndex;
    _notebooks[idx] = RochyNotebook(entity: entity, nodes: nodes);
    _activeNotebookId = entity.id;
    return (entity: entity, nodes: List<BentoNode>.unmodifiable(nodes));
  }

  @override
  Future<({
    List<RochyNotebook> notebooks,
    String activeNotebookId,
    bool biometricEnabled,
    bool showPaperGrain,
    double textScaleFactor,
  })?> hydrateFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.isEmpty) return null;

      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final rawBooks = decoded['notebooks'] as List<dynamic>? ?? const [];
      if (rawBooks.isEmpty) return null;

      final loaded = rawBooks
          .map(
            (e) => RochyNotebook.fromJson(
              Map<String, dynamic>.from(e as Map<dynamic, dynamic>),
            ),
          )
          .toList();

      _notebooks = loaded;
      _activeNotebookId =
          decoded['activeNotebookId'] as String? ?? loaded.first.entity.id;

      return (
        notebooks: List<RochyNotebook>.unmodifiable(loaded),
        activeNotebookId: _activeNotebookId,
        biometricEnabled: decoded['biometricEnabled'] as bool? ?? false,
        showPaperGrain: decoded['showPaperGrain'] as bool? ?? true,
        textScaleFactor:
            (decoded['textScaleFactor'] as num?)?.toDouble() ?? 1.0,
      );
    } on MissingPluginException {
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> persistToDisk({
    required List<RochyNotebook> notebooks,
    required String activeNotebookId,
    required bool biometricEnabled,
    required bool showPaperGrain,
    required double textScaleFactor,
  }) async {
    _notebooks = List<RochyNotebook>.of(notebooks);
    _activeNotebookId = activeNotebookId;
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = jsonEncode(<String, dynamic>{
        'activeNotebookId': activeNotebookId,
        'biometricEnabled': biometricEnabled,
        'showPaperGrain': showPaperGrain,
        'textScaleFactor': textScaleFactor,
        'notebooks': notebooks.map((b) => b.toJson()).toList(),
      });
      await prefs.setString(_storageKey, payload);
    } on MissingPluginException {
      // Entorno sin canal nativo (p. ej. test unitario sin mock de plugin).
    } catch (_) {}
  }

  @override
  List<BentoNode> starterTemplateNodes() => _seedStarterNodes();

  static BentoEntity _seedEntity() {
    return BentoEntity(
      id: 'entity_rochy',
      name: 'Rochy',
      subtitle: 'Su cuaderno vivo · Edítalo a tu manera',
      coverImageUrl:
          'https://images.unsplash.com/photo-1511920170033-f8396924c348?auto=format&fit=crop&w=1080&q=85',
      shortBio:
          'Un espacio íntimo para reunir lo que ama, sus rituales cotidianos, lugares, videos y frases que la definen.',
      birthDate: DateTime(1998, 4, 19),
      anniversaryDate: DateTime(2023, 10, 14),
      activeThemeId: RochyThemes.arenaCalida.id,
    );
  }

  static List<BentoNode> _seedStarterNodes() {
    return <BentoNode>[
      BentoNode(
        id: 'node_hero_cafe',
        type: BentoNodeType.photoHero,
        colSpan: 2,
        rowSpan: 2,
        colorTheme: BentoColorTheme.espresso,
        linkedNodeIds: const ['node_flip_coffee', 'node_pin_baloco'],
        tags: const ['café', 'mañanas', 'calle baloco'],
        createdAt: DateTime(2025, 10, 14, 9, 30),
        payload: const PhotoHeroPayload(
          imageUrl:
              'https://images.unsplash.com/photo-1517841905240-472988babdf9?auto=format&fit=crop&w=1100&q=85',
          title: 'Mañanas de sol y café',
          dateLabel: '14 de octubre',
          locationLabel: 'Calle Baloco',
          storyBody:
              'Estábamos en la mesa de la esquina cuando el sol empezó a colarse entre los balcones de madera. '
              'Sostuvo su taza con las dos manos, miró hacia la plaza y sonrió como si el tiempo no tuviera ninguna prisa.',
          photographerNote: 'Luz de 9:40 AM · Mesa junto al ventanal',
          latitude: 10.4238,
          longitude: -75.5510,
        ),
      ),
      BentoNode(
        id: 'node_flip_coffee',
        type: BentoNodeType.flipDetail,
        colSpan: 1,
        rowSpan: 2,
        colorTheme: BentoColorTheme.espresso,
        linkedNodeIds: const ['node_hero_cafe', 'node_pin_baloco'],
        tags: const ['café', 'hábitos', 'voz'],
        createdAt: DateTime(2025, 10, 12, 10, 15),
        payload: const FlipDetailPayload(
          title: 'Su café favorito',
          microText: 'Caramel Macchiato, extra caliente',
          iconKey: 'coffee',
          voiceNoteLabel: 'Nota de voz · Pedido de siempre',
          recordedDateLabel: '12 oct · 0:18',
          durationSeconds: 18,
          backSubtitle: '“Con doble espuma, por favor”',
          waveformSamples: <double>[
            0.28, 0.54, 0.78, 0.44, 0.90, 0.65, 0.36, 0.84, 0.96, 0.58, 0.42,
            0.76, 0.60, 0.32, 0.72, 0.48, 0.86, 0.50, 0.30, 0.40,
          ],
        ),
      ),
      BentoNode(
        id: 'node_checklist_details',
        type: BentoNodeType.checkList,
        colSpan: 1,
        rowSpan: 3,
        colorTheme: BentoColorTheme.ivory,
        fontStyle: BentoFontStyle.handwritten,
        linkedNodeIds: const ['node_quote_peace', 'node_audio_song'],
        tags: const ['hábitos', 'detalles', 'cotidiano'],
        createdAt: DateTime(2025, 10, 16, 20, 5),
        payload: const CheckListPayload(
          title: 'Detalles que amo',
          footerHint: 'Toca un detalle para destacarlo',
          items: <CheckListItem>[
            CheckListItem(
              id: 'det_1',
              text: 'Su risa cuando se olvida de algo',
              isHighlighted: true,
            ),
            CheckListItem(
              id: 'det_2',
              text: 'Cómo organiza sus libros por color',
            ),
            CheckListItem(
              id: 'det_3',
              text: 'Que siempre guarde boletos en su bolsillo',
            ),
          ],
        ),
      ),
      BentoNode(
        id: 'node_quote_peace',
        type: BentoNodeType.quote,
        colSpan: 1,
        rowSpan: 2,
        colorTheme: BentoColorTheme.terracotta,
        linkedNodeIds: const ['node_checklist_details', 'node_pin_sunday'],
        tags: const ['citas', 'hogar', 'calma'],
        createdAt: DateTime(2025, 10, 18, 22, 10),
        payload: const QuotePayload(
          quoteText: 'En tu paz, encontré mi hogar.',
          contextLabel: 'Dicho bajito tras la lluvia',
          isLoved: true,
          loveCount: 5,
        ),
      ),
      BentoNode(
        id: 'node_pin_baloco',
        type: BentoNodeType.locationPin,
        colSpan: 1,
        rowSpan: 1,
        colorTheme: BentoColorTheme.sage,
        linkedNodeIds: const ['node_flip_coffee', 'node_hero_cafe'],
        tags: const ['viajes', 'café', 'calle baloco'],
        createdAt: DateTime(2025, 10, 19, 11, 0),
        payload: const LocationPinPayload(
          placeName: 'Café en la Calle Baloco',
          caption: 'Nuestro rincón de 5 estrellas',
          coordinatesLabel: '10.4236° N · 75.5512° O',
          style: LocationPinStyle.constellationPill,
          starCount: 5,
          memoryNote:
              'La esquina donde siempre pedimos dos tazas y compartimos el último croissant.',
          latitude: 10.4236,
          longitude: -75.5512,
        ),
      ),
      BentoNode(
        id: 'node_audio_song',
        type: BentoNodeType.audioNote,
        colSpan: 1,
        rowSpan: 2,
        colorTheme: BentoColorTheme.ivory,
        fontStyle: BentoFontStyle.cleanSans,
        linkedNodeIds: const ['node_checklist_details', 'node_pin_sunday'],
        tags: const ['música', 'tardes', 'recuerdos'],
        createdAt: DateTime(2025, 10, 21, 18, 40),
        payload: const AudioNotePayload(
          title: 'Canción que me recuerda a ella',
          subtitle: 'Tune: \'La Vie En Rose · Acústico\'',
          coverImageUrl:
              'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?auto=format&fit=crop&w=400&q=80',
          durationSeconds: 32,
          recordedAtLabel: 'Vinilo de domingo',
          waveformSamples: <double>[
            0.22, 0.35, 0.62, 0.48, 0.86, 0.94, 0.72, 0.56, 0.88, 0.64, 0.40,
            0.78, 0.92, 0.54, 0.36, 0.68, 0.44, 0.28, 0.50, 0.34, 0.24, 0.18,
          ],
        ),
      ),
      BentoNode(
        id: 'node_pin_sunday',
        type: BentoNodeType.locationPin,
        colSpan: 1,
        rowSpan: 2,
        colorTheme: BentoColorTheme.ivory,
        fontStyle: BentoFontStyle.handwritten,
        linkedNodeIds: const ['node_quote_peace', 'node_audio_song'],
        tags: const ['domingos', 'caminatas', 'viajes'],
        createdAt: DateTime(2025, 10, 26, 17, 15),
        payload: const LocationPinPayload(
          placeName: 'Paseo de las Murallas',
          caption: 'Caminatas de domingo',
          coordinatesLabel: '10.4274° N · 75.5504° O',
          style: LocationPinStyle.polaroid,
          imageUrl:
              'https://images.unsplash.com/photo-1516589178581-6cd7833ae3b2?auto=format&fit=crop&w=700&q=85',
          tiltAngle: -0.045,
          memoryNote:
              'Caminar tomados de la mano sin mirar el reloj mientras cae la tarde.',
          latitude: 10.4274,
          longitude: -75.5504,
        ),
      ),
      BentoNode(
        id: 'node_palette_mood',
        type: BentoNodeType.paletteMood,
        colSpan: 1,
        rowSpan: 3,
        colorTheme: BentoColorTheme.sand,
        linkedNodeIds: const ['node_flip_coffee', 'node_quote_peace'],
        tags: const ['esencia', 'colores'],
        createdAt: DateTime(2025, 10, 27, 15, 0),
        payload: const PaletteMoodPayload(
          title: 'Su esencia',
          scentNote: 'Vainilla tibia y lluvia',
          swatchHexes: <int>[
            0xFFA85338,
            0xFF5B6E58,
            0xFFE2B89B,
            0xFF6B3D22,
          ],
          moodWords: <String>['Serena', 'Luminosa', 'Curiosa', 'Dulce'],
        ),
      ),
      BentoNode(
        id: 'node_countdown_days',
        type: BentoNodeType.countdown,
        colSpan: 1,
        rowSpan: 2,
        colorTheme: BentoColorTheme.charcoal,
        linkedNodeIds: const ['node_hero_cafe'],
        tags: const ['fechas', 'nosotros'],
        createdAt: DateTime(2025, 10, 28, 12, 0),
        payload: CountdownPayload(
          title: 'Desde aquel café',
          targetDate: DateTime(2023, 10, 14),
          subtitle: 'Cada día suma',
          countMode: 'since',
        ),
      ),
      BentoNode(
        id: 'node_love_letter',
        type: BentoNodeType.loveLetter,
        colSpan: 1,
        rowSpan: 1,
        colorTheme: BentoColorTheme.ivory,
        linkedNodeIds: const ['node_quote_peace'],
        tags: const ['cartas', 'íntimo'],
        createdAt: DateTime(2025, 10, 29, 21, 0),
        payload: const LoveLetterPayload(
          title: 'Para un día gris',
          previewLine: 'Ábrela cuando necesites calma…',
          letterBody:
              'Quise guardar en este rincón todas las razones pequeñas por las que iluminas cada día.',
          signature: 'Siempre tuyo',
        ),
      ),
    ];
  }
}

/// Estado inmutable multi-cuaderno del lienzo Rochy.
@immutable
class BentoCanvasState {
  const BentoCanvasState({
    required this.notebooks,
    required this.activeNotebookId,
    this.selectedNodeId,
    this.activeWidgetId,
    this.activeAudioNodeId,
    this.isAudioPlaying = false,
    this.audioProgress = 0.0,
    this.activeTabIndex = 0,
    this.activeTagFilter,
    this.showPaperGrain = true,
    this.textScaleFactor = 1.0,
    this.isEditMode = false,
    this.isConnectingMode = false,
    this.isBiometricEnabled = false,
    this.isUnlocked = true,
    this.flippedNodeIds = const <String>{},
    this.focusedMapNodeId,
  });

  final List<RochyNotebook> notebooks;
  final String activeNotebookId;
  final String? selectedNodeId;
  final String? activeWidgetId;
  final String? activeAudioNodeId;
  final bool isAudioPlaying;
  final double audioProgress;
  final int activeTabIndex;
  final String? activeTagFilter;
  final bool showPaperGrain;
  final double textScaleFactor;
  final bool isEditMode;
  final bool isConnectingMode;
  final bool isBiometricEnabled;
  final bool isUnlocked;
  final Set<String> flippedNodeIds;
  final String? focusedMapNodeId;

  RochyNotebook get activeNotebook {
    for (final b in notebooks) {
      if (b.entity.id == activeNotebookId) return b;
    }
    return notebooks.first;
  }

  BentoEntity get entity => activeNotebook.entity;
  List<BentoNode> get nodes => activeNotebook.nodes;

  BentoNode? get selectedNode {
    if (selectedNodeId == null) return null;
    for (final node in nodes) {
      if (node.id == selectedNodeId) return node;
    }
    return null;
  }

  Set<String> get relatedNodeIds {
    final current = selectedNode;
    if (current == null) return const <String>{};

    final related = <String>{...current.linkedNodeIds};
    for (final candidate in nodes) {
      if (candidate.linkedNodeIds.contains(current.id)) {
        related.add(candidate.id);
      }
    }
    related.remove(current.id);
    return related;
  }

  List<String> get allTags {
    final seen = <String>{};
    for (final node in nodes) {
      seen.addAll(node.tags);
    }
    return seen.toList();
  }

  BentoCanvasState copyWith({
    List<RochyNotebook>? notebooks,
    String? activeNotebookId,
    String? selectedNodeId,
    bool clearSelectedNode = false,
    String? activeWidgetId,
    bool clearActiveWidget = false,
    String? activeAudioNodeId,
    bool clearActiveAudio = false,
    bool? isAudioPlaying,
    double? audioProgress,
    int? activeTabIndex,
    String? activeTagFilter,
    bool clearTagFilter = false,
    bool? showPaperGrain,
    double? textScaleFactor,
    bool? isEditMode,
    bool? isConnectingMode,
    bool? isBiometricEnabled,
    bool? isUnlocked,
    Set<String>? flippedNodeIds,
    String? focusedMapNodeId,
    bool clearFocusedMapNode = false,
  }) {
    return BentoCanvasState(
      notebooks: notebooks ?? this.notebooks,
      activeNotebookId: activeNotebookId ?? this.activeNotebookId,
      selectedNodeId:
          clearSelectedNode ? null : (selectedNodeId ?? this.selectedNodeId),
      activeWidgetId:
          clearActiveWidget ? null : (activeWidgetId ?? this.activeWidgetId),
      activeAudioNodeId: clearActiveAudio
          ? null
          : (activeAudioNodeId ?? this.activeAudioNodeId),
      isAudioPlaying: isAudioPlaying ?? this.isAudioPlaying,
      audioProgress: audioProgress ?? this.audioProgress,
      activeTabIndex: activeTabIndex ?? this.activeTabIndex,
      activeTagFilter:
          clearTagFilter ? null : (activeTagFilter ?? this.activeTagFilter),
      showPaperGrain: showPaperGrain ?? this.showPaperGrain,
      textScaleFactor: textScaleFactor ?? this.textScaleFactor,
      isEditMode: isEditMode ?? this.isEditMode,
      isConnectingMode: isConnectingMode ?? this.isConnectingMode,
      isBiometricEnabled: isBiometricEnabled ?? this.isBiometricEnabled,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      flippedNodeIds: flippedNodeIds ?? this.flippedNodeIds,
      focusedMapNodeId: clearFocusedMapNode
          ? null
          : (focusedMapNodeId ?? this.focusedMapNodeId),
    );
  }
}

final bentoRepositoryProvider = Provider<BentoRepository>((ref) {
  return LocalBentoRepository();
});

final mediaAndAuthServiceProvider = Provider<MediaAndAuthService>((ref) {
  final service = MediaAndAuthService();
  ref.onDispose(service.dispose);
  return service;
});

/// Controlador principal Riverpod con persistencia en disco, multi-cuaderno y audio real.
class BentoCanvasNotifier extends Notifier<BentoCanvasState> {
  Timer? _audioTicker;
  AudioPlayer? _audioPlayer;
  StreamSubscription<Duration>? _positionSub;

  @override
  BentoCanvasState build() {
    ref.onDispose(() {
      _stopTicker();
      _positionSub?.cancel();
      _audioPlayer?.dispose();
    });

    final repo = ref.read(bentoRepositoryProvider);
    final initial = BentoCanvasState(
      notebooks: repo.loadNotebooks(),
      activeNotebookId: repo.loadActiveNotebookId(),
    );

    Future.microtask(_hydrate);
    return initial;
  }

  Future<void> _hydrate() async {
    final repo = ref.read(bentoRepositoryProvider);
    final restored = await repo.hydrateFromDisk();
    if (restored == null) return;

    // Backfill coordenadas reales para los nodos semilla si venían de una versión previa.
    final migratedBooks = restored.notebooks.map((book) {
      final updatedNodes = book.nodes.map((node) {
        if (node.mapCoordinates != null) return node;
        if (node.id == 'node_pin_baloco' &&
            node.payload is LocationPinPayload) {
          final p = node.payload as LocationPinPayload;
          return node.copyWith(
            payload: p.copyWith(
              latitude: 10.4236,
              longitude: -75.5512,
              coordinatesLabel: '10.4236° N · 75.5512° O',
            ),
          );
        }
        if (node.id == 'node_pin_sunday' &&
            node.payload is LocationPinPayload) {
          final p = node.payload as LocationPinPayload;
          return node.copyWith(
            payload: p.copyWith(
              latitude: 10.4274,
              longitude: -75.5504,
              coordinatesLabel: '10.4274° N · 75.5504° O',
            ),
          );
        }
        if (node.id == 'node_hero_cafe' && node.payload is PhotoHeroPayload) {
          final p = node.payload as PhotoHeroPayload;
          return node.copyWith(
            payload: p.copyWith(latitude: 10.4238, longitude: -75.5510),
          );
        }
        return node;
      }).toList(growable: false);
      return book.copyWith(nodes: updatedNodes);
    }).toList(growable: false);

    state = state.copyWith(
      notebooks: migratedBooks,
      activeNotebookId: restored.activeNotebookId,
      isBiometricEnabled: restored.biometricEnabled,
      isUnlocked: !restored.biometricEnabled,
      showPaperGrain: restored.showPaperGrain,
      textScaleFactor: restored.textScaleFactor,
    );
  }

  void _persist() {
    unawaited(
      ref.read(bentoRepositoryProvider).persistToDisk(
            notebooks: state.notebooks,
            activeNotebookId: state.activeNotebookId,
            biometricEnabled: state.isBiometricEnabled,
            showPaperGrain: state.showPaperGrain,
            textScaleFactor: state.textScaleFactor,
          ),
    );
  }

  void _replaceActiveNotebook(RochyNotebook Function(RochyNotebook) transform) {
    final updatedBooks = state.notebooks
        .map(
          (b) => b.entity.id == state.activeNotebookId ? transform(b) : b,
        )
        .toList(growable: false);
    state = state.copyWith(notebooks: updatedBooks);
    _persist();
  }

  void toggleNodeFocus(String nodeId) {
    if (state.selectedNodeId == nodeId) {
      state = state.copyWith(
        clearSelectedNode: true,
        clearActiveWidget: true,
        isConnectingMode: false,
      );
    } else {
      state = state.copyWith(selectedNodeId: nodeId);
    }
  }

  /// Activa un widget en el lienzo tras mantenerlo presionado (redimensionar / mover / arco).
  void activateWidget(String nodeId) {
    state = state.copyWith(
      activeWidgetId: nodeId,
      selectedNodeId: nodeId,
      isConnectingMode: false,
    );
  }

  void clearNodeFocus() {
    if (state.selectedNodeId != null ||
        state.activeWidgetId != null ||
        state.isConnectingMode) {
      state = state.copyWith(
        clearSelectedNode: true,
        clearActiveWidget: true,
        isConnectingMode: false,
      );
    }
  }

  void toggleEditMode() {
    state = state.copyWith(
      isEditMode: !state.isEditMode,
      isConnectingMode: false,
      clearActiveWidget: true,
      clearSelectedNode: true,
    );
  }

  void setTabIndex(int index) {
    state = state.copyWith(
      activeTabIndex: index.clamp(0, 3),
      clearSelectedNode: true,
    );
  }

  void toggleTagFilter(String? tag) {
    if (tag == null || state.activeTagFilter == tag) {
      state = state.copyWith(clearTagFilter: true);
    } else {
      state = state.copyWith(activeTagFilter: tag);
    }
  }

  void updateEntity(BentoEntity updatedEntity) {
    _replaceActiveNotebook((b) => b.copyWith(entity: updatedEntity));
  }

  void createNotebook({
    required String name,
    required String subtitle,
    String shortBio = '',
    bool startBlank = true,
  }) {
    pauseAudio();
    final id = 'entity_${DateTime.now().microsecondsSinceEpoch}';
    final entity = BentoEntity(
      id: id,
      name: name.trim().isEmpty ? 'Nuevo cuaderno' : name.trim(),
      subtitle: subtitle.trim(),
      coverImageUrl: '',
      shortBio: shortBio.trim(),
      birthDate: DateTime(2000, 1, 1),
      anniversaryDate: DateTime.now(),
      activeThemeId: state.entity.activeThemeId,
    );
    final nodes = startBlank
        ? const <BentoNode>[]
        : ref.read(bentoRepositoryProvider).starterTemplateNodes();

    final nextBooks = <RochyNotebook>[
      ...state.notebooks,
      RochyNotebook(entity: entity, nodes: nodes),
    ];

    state = state.copyWith(
      notebooks: nextBooks,
      activeNotebookId: id,
      clearSelectedNode: true,
      clearActiveAudio: true,
      clearTagFilter: true,
      isEditMode: false,
    );
    _persist();
  }

  void switchNotebook(String notebookId) {
    if (state.activeNotebookId == notebookId) return;
    pauseAudio();
    state = state.copyWith(
      activeNotebookId: notebookId,
      clearSelectedNode: true,
      clearActiveAudio: true,
      clearTagFilter: true,
      isEditMode: false,
    );
    _persist();
  }

  void deleteNotebook(String notebookId) {
    if (state.notebooks.length <= 1) return;
    pauseAudio();
    final remaining = state.notebooks
        .where((b) => b.entity.id != notebookId)
        .toList(growable: false);
    final nextId = state.activeNotebookId == notebookId
        ? remaining.first.entity.id
        : state.activeNotebookId;
    state = state.copyWith(
      notebooks: remaining,
      activeNotebookId: nextId,
      clearSelectedNode: true,
      clearActiveAudio: true,
      clearTagFilter: true,
    );
    _persist();
  }

  void addNode(BentoNode node) {
    _replaceActiveNotebook(
      (b) => b.copyWith(nodes: <BentoNode>[...b.nodes, node]),
    );
  }

  void updateNode(BentoNode updated) {
    _replaceActiveNotebook(
      (b) => b.copyWith(
        nodes: b.nodes
            .map((n) => n.id == updated.id ? updated : n)
            .toList(growable: false),
      ),
    );
  }

  /// Elimina un módulo y devuelve (nodo, índice) para permitir Deshacer.
  ({BentoNode node, int index})? deleteNode(String nodeId) {
    if (state.activeAudioNodeId == nodeId) {
      pauseAudio();
    }
    final index = state.nodes.indexWhere((n) => n.id == nodeId);
    if (index == -1) return null;
    final removed = state.nodes[index];

    final nextNodes = state.nodes
        .where((n) => n.id != nodeId)
        .map(
          (n) => n.linkedNodeIds.contains(nodeId)
              ? n.copyWith(
                  linkedNodeIds:
                      n.linkedNodeIds.where((id) => id != nodeId).toList(),
                )
              : n,
        )
        .toList(growable: false);

    _replaceActiveNotebook((b) => b.copyWith(nodes: nextNodes));
    if (state.selectedNodeId == nodeId) {
      state = state.copyWith(clearSelectedNode: true);
    }
    return (node: removed, index: index);
  }

  void restoreDeletedNode(BentoNode node, int index) {
    final mutable = List<BentoNode>.of(state.nodes);
    final safeIndex = index.clamp(0, mutable.length);
    mutable.insert(safeIndex, node);
    _replaceActiveNotebook((b) => b.copyWith(nodes: mutable));
  }

  void moveNode(String nodeId, int delta) {
    final index = state.nodes.indexWhere((n) => n.id == nodeId);
    if (index == -1) return;
    final target = (index + delta).clamp(0, state.nodes.length - 1);
    if (target == index) return;

    final mutable = List<BentoNode>.of(state.nodes);
    final moved = mutable.removeAt(index);
    mutable.insert(target, moved);
    _replaceActiveNotebook((b) => b.copyWith(nodes: mutable));
  }

  /// Reordena arrastrando una tarjeta hasta la posición de otra.
  void reorderNode(String draggedId, String targetId) {
    if (draggedId == targetId) return;
    final fromIndex = state.nodes.indexWhere((n) => n.id == draggedId);
    final toIndex = state.nodes.indexWhere((n) => n.id == targetId);
    if (fromIndex == -1 || toIndex == -1) return;

    final mutable = List<BentoNode>.of(state.nodes);
    final item = mutable.removeAt(fromIndex);
    mutable.insert(toIndex, item);
    _replaceActiveNotebook((b) => b.copyWith(nodes: mutable));
  }

  /// Cambia directamente el tamaño en la retícula Bento de una tarjeta.
  void resizeNode(String nodeId, {int? colSpan, int? rowSpan}) {
    _replaceActiveNotebook((b) {
      final updated = b.nodes.map((n) {
        if (n.id != nodeId) return n;
        return n.copyWith(
          colSpan: (colSpan ?? n.colSpan).clamp(1, 2),
          rowSpan: (rowSpan ?? n.rowSpan).clamp(1, 5),
        );
      }).toList(growable: false);
      return b.copyWith(nodes: updated);
    });
  }

  /// Alterna el estado de favorito de cualquier tarjeta del cuaderno.
  void toggleNodeFavorite(String nodeId) {
    _replaceActiveNotebook((b) {
      final updated = b.nodes.map((n) {
        if (n.id != nodeId) return n;
        return n.copyWith(isFavorite: !n.isFavorite);
      }).toList(growable: false);
      return b.copyWith(nodes: updated);
    });
  }

  /// Abre la pestaña de Mapa y enfoca la cámara en un recuerdo específico.
  void focusNodeOnMap(String nodeId) {
    state = state.copyWith(
      activeTabIndex: 2,
      focusedMapNodeId: nodeId,
    );
  }

  void clearFocusedMapNode() {
    if (state.focusedMapNodeId != null) {
      state = state.copyWith(clearFocusedMapNode: true);
    }
  }

  /// Cicla rápidamente por los 10 tamaños Bento disponibles (1 o 2 cols x 5 alturas).
  void cycleNodeSize(String nodeId) {
    const cycle = <(int, int)>[
      (1, 1),
      (1, 2),
      (1, 3),
      (1, 4),
      (1, 5),
      (2, 1),
      (2, 2),
      (2, 3),
      (2, 4),
      (2, 5),
    ];
    final current = state.nodes.firstWhere(
      (n) => n.id == nodeId,
      orElse: () => state.nodes.first,
    );
    final idx = cycle.indexOf((current.colSpan, current.rowSpan));
    final next = cycle[(idx + 1) % cycle.length];
    resizeNode(nodeId, colSpan: next.$1, rowSpan: next.$2);
  }

  /// Activa la conexión meramente visual desde el menú radial estilo Pinterest.
  void startVisualConnection(String nodeId) {
    state = state.copyWith(
      selectedNodeId: nodeId,
      clearActiveWidget: true,
      isConnectingMode: true,
      isEditMode: false,
    );
  }

  void stopVisualConnection() {
    state = state.copyWith(
      isConnectingMode: false,
      clearSelectedNode: true,
    );
  }

  /// Conecta o desconecta visualmente el nodo enfocado con [targetId].
  void toggleVisualLink(String targetId) {
    final sourceId = state.selectedNodeId;
    if (sourceId == null || sourceId == targetId) return;

    _replaceActiveNotebook((b) {
      final sourceNode = b.nodes.firstWhere((n) => n.id == sourceId);
      final targetNode = b.nodes.firstWhere((n) => n.id == targetId);
      final alreadyLinked = sourceNode.linkedNodeIds.contains(targetId) ||
          targetNode.linkedNodeIds.contains(sourceId);

      final updated = b.nodes.map((n) {
        if (n.id == sourceId) {
          final next = alreadyLinked
              ? n.linkedNodeIds.where((id) => id != targetId).toList()
              : <String>{...n.linkedNodeIds, targetId}.toList();
          return n.copyWith(linkedNodeIds: next);
        }
        if (n.id == targetId && alreadyLinked) {
          return n.copyWith(
            linkedNodeIds:
                n.linkedNodeIds.where((id) => id != sourceId).toList(),
          );
        }
        return n;
      }).toList(growable: false);

      return b.copyWith(nodes: updated);
    });
  }

  void clearCanvas() {
    pauseAudio();
    _replaceActiveNotebook((b) => b.copyWith(nodes: const <BentoNode>[]));
    state = state.copyWith(
      clearSelectedNode: true,
      clearActiveAudio: true,
      clearTagFilter: true,
    );
  }

  void restoreStarterTemplate() {
    pauseAudio();
    final starter = ref.read(bentoRepositoryProvider).starterTemplateNodes();
    _replaceActiveNotebook((b) => b.copyWith(nodes: starter));
    state = state.copyWith(
      clearSelectedNode: true,
      clearActiveAudio: true,
      clearTagFilter: true,
    );
  }

  void importJsonSnapshot(String rawJson) {
    pauseAudio();
    final imported =
        ref.read(bentoRepositoryProvider).importJsonSnapshot(rawJson);
    _replaceActiveNotebook(
      (_) => RochyNotebook(entity: imported.entity, nodes: imported.nodes),
    );
    state = state.copyWith(
      activeNotebookId: imported.entity.id,
      clearSelectedNode: true,
      clearActiveAudio: true,
      clearTagFilter: true,
    );
  }

  void selectTheme(String themeId) {
    _replaceActiveNotebook(
      (b) => b.copyWith(entity: b.entity.copyWith(activeThemeId: themeId)),
    );
  }

  void togglePaperGrain(bool enabled) {
    state = state.copyWith(showPaperGrain: enabled);
    _persist();
  }

  void setTextScaleFactor(double factor) {
    state = state.copyWith(textScaleFactor: factor.clamp(0.92, 1.12));
    _persist();
  }

  void setBiometricEnabled(bool enabled) {
    state = state.copyWith(
      isBiometricEnabled: enabled,
      isUnlocked: true,
    );
    _persist();
  }

  void unlockWithBiometrics() {
    state = state.copyWith(isUnlocked: true);
  }

  void setCardFlipped(String nodeId, bool isFlipped) {
    final nextSet = <String>{...state.flippedNodeIds};
    if (isFlipped) {
      nextSet.add(nodeId);
    } else {
      nextSet.remove(nodeId);
      if (state.activeAudioNodeId == nodeId && state.isAudioPlaying) {
        pauseAudio();
      }
    }
    state = state.copyWith(flippedNodeIds: nextSet);
  }

  void toggleQuoteLove(String nodeId) {
    _replaceActiveNotebook((b) {
      final updatedNodes = b.nodes.map((node) {
        if (node.id != nodeId) return node;
        final payload = node.payload;
        if (payload is! QuotePayload) return node;

        final nextLoved = !payload.isLoved;
        final nextCount = nextLoved
            ? payload.loveCount + 1
            : (payload.loveCount - 1).clamp(0, 999);
        return node.copyWith(
          payload: payload.copyWith(
            isLoved: nextLoved,
            loveCount: nextCount,
          ),
        );
      }).toList(growable: false);
      return b.copyWith(nodes: updatedNodes);
    });
  }

  void toggleCheckListItem(String nodeId, String itemId) {
    _replaceActiveNotebook((b) {
      final updatedNodes = b.nodes.map((node) {
        if (node.id != nodeId) return node;
        final payload = node.payload;
        if (payload is! CheckListPayload) return node;

        final updatedItems = payload.items
            .map(
              (item) => item.id == itemId
                  ? item.copyWith(isHighlighted: !item.isHighlighted)
                  : item,
            )
            .toList();
        return node.copyWith(payload: payload.copyWith(items: updatedItems));
      }).toList(growable: false);
      return b.copyWith(nodes: updatedNodes);
    });
  }

  void toggleGiftWishItem(String nodeId, String itemId) {
    _replaceActiveNotebook((b) {
      final updatedNodes = b.nodes.map((node) {
        if (node.id != nodeId) return node;
        final payload = node.payload;
        if (payload is! GiftWishPayload) return node;

        final updatedItems = payload.items
            .map(
              (item) => item.id == itemId
                  ? item.copyWith(isHighlighted: !item.isHighlighted)
                  : item,
            )
            .toList();
        return node.copyWith(payload: payload.copyWith(items: updatedItems));
      }).toList(growable: false);
      return b.copyWith(nodes: updatedNodes);
    });
  }

  String _resolveLocalAudioPath(String nodeId) {
    for (final n in state.nodes) {
      if (n.id != nodeId) continue;
      final p = n.payload;
      if (p is FlipDetailPayload) return p.localAudioPath;
      if (p is AudioNotePayload) return p.localAudioPath;
    }
    return '';
  }

  Future<void> toggleAudioPlayback(
    String nodeId, {
    int durationSeconds = 24,
  }) async {
    if (state.activeAudioNodeId == nodeId && state.isAudioPlaying) {
      pauseAudio();
      return;
    }

    final isNewTrack = state.activeAudioNodeId != nodeId;
    final startProgress =
        isNewTrack || state.audioProgress >= 0.99 ? 0.0 : state.audioProgress;

    state = state.copyWith(
      activeAudioNodeId: nodeId,
      isAudioPlaying: true,
      audioProgress: startProgress,
    );

    final localPath = _resolveLocalAudioPath(nodeId);
    if (localPath.isNotEmpty && !kIsWeb && File(localPath).existsSync()) {
      final startedReal = await _playRealAudioFile(localPath, startProgress);
      if (startedReal) return;
    }

    _startTicker(durationSeconds: durationSeconds);
  }

  Future<bool> _playRealAudioFile(String path, double startProgress) async {
    try {
      _stopTicker();
      _audioPlayer ??= AudioPlayer();
      await _positionSub?.cancel();

      final duration = await _audioPlayer!.setFilePath(path);
      final totalMs = duration?.inMilliseconds ?? 1;
      if (startProgress > 0 && duration != null) {
        await _audioPlayer!.seek(
          Duration(milliseconds: (totalMs * startProgress).round()),
        );
      }

      _positionSub = _audioPlayer!.positionStream.listen((pos) {
        if (!state.isAudioPlaying) return;
        final ratio =
            totalMs > 0 ? (pos.inMilliseconds / totalMs).clamp(0.0, 1.0) : 0.0;
        if (ratio >= 0.995) {
          pauseAudio();
          state = state.copyWith(audioProgress: 0.0);
        } else {
          state = state.copyWith(audioProgress: ratio);
        }
      });

      unawaited(_audioPlayer!.play());
      return true;
    } on MissingPluginException {
      return false;
    } catch (_) {
      return false;
    }
  }

  void seekAudio(String nodeId, double progress, {int durationSeconds = 24}) {
    final clamped = progress.clamp(0.0, 1.0);
    state = state.copyWith(
      activeAudioNodeId: nodeId,
      audioProgress: clamped,
    );
    final player = _audioPlayer;
    if (player != null && player.duration != null) {
      final targetMs = (player.duration!.inMilliseconds * clamped).round();
      unawaited(player.seek(Duration(milliseconds: targetMs)));
    } else if (state.isAudioPlaying) {
      _startTicker(durationSeconds: durationSeconds);
    }
  }

  void pauseAudio() {
    _stopTicker();
    try {
      unawaited(_audioPlayer?.pause());
    } on MissingPluginException {
      // Ignorado en entornos sin canal de plataforma.
    } catch (_) {
      // Ignorado si el reproductor aún no se inicializó.
    }
    state = state.copyWith(isAudioPlaying: false);
  }

  void _startTicker({required int durationSeconds}) {
    _stopTicker();
    const tickMs = 60;
    final totalMs = (durationSeconds <= 0 ? 20 : durationSeconds) * 1000;
    final step = tickMs / totalMs;

    _audioTicker = Timer.periodic(const Duration(milliseconds: tickMs), (_) {
      final next = state.audioProgress + step;
      if (next >= 1.0) {
        _stopTicker();
        state = state.copyWith(
          isAudioPlaying: false,
          audioProgress: 0.0,
        );
      } else {
        state = state.copyWith(audioProgress: next);
      }
    });
  }

  void _stopTicker() {
    _audioTicker?.cancel();
    _audioTicker = null;
  }
}

final bentoCanvasProvider =
    NotifierProvider<BentoCanvasNotifier, BentoCanvasState>(
  BentoCanvasNotifier.new,
);

final activeRochyThemeProvider = Provider<RochyThemeData>((ref) {
  final themeId =
      ref.watch(bentoCanvasProvider.select((s) => s.entity.activeThemeId));
  return RochyThemes.byId(themeId);
});
