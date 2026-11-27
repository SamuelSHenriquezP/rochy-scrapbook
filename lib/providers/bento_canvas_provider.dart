import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/bento_node.dart';
import '../services/media_and_auth_service.dart';
import '../services/browser_snapshot_store.dart';
import '../services/rochy_account_service.dart';
import '../services/rochy_protected_media.dart';
import '../services/rochy_cloud_sync_service.dart';
import '../services/rochy_notification_service.dart';
import '../theme/rochy_theme.dart';

const String kRochyNotebookId = 'entity_rochy';
const String kSamuelNotebookId = 'entity_samuel';
const String kNosotrosNotebookId = 'entity_nosotros';

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
  List<BentoNode> starterTemplateNodes({String? notebookId});

  Future<
      ({
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
        nodes: const <BentoNode>[],
      ),
      RochyNotebook(
        entity: seedNosotrosEntity(),
        nodes: const <BentoNode>[],
      ),
    ];
    _activeNotebookId = _notebooks.first.entity.id;
  }

  static const _storageKey = 'rochy_notebooks_snapshot_v2';
  static const _couplePrefsKey = 'rochy_couple_prefs_v1';

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
  Future<
      ({
        List<RochyNotebook> notebooks,
        String activeNotebookId,
        bool biometricEnabled,
        bool showPaperGrain,
        double textScaleFactor,
      })?> hydrateFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = kIsWeb
          ? await readBrowserSnapshot(_storageKey) ??
              prefs.getString(_storageKey)
          : prefs.getString(_storageKey);
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
      if (kIsWeb) {
        await writeBrowserSnapshot(_storageKey, payload);
      } else {
        await prefs.setString(_storageKey, payload);
      }
    } on MissingPluginException {
      // Entorno sin canal nativo (p. ej. test unitario sin mock de plugin).
    } catch (_) {}
  }

  Future<
      ({
        String viewerAuthor,
        String partnerAName,
        String partnerBName,
        String partnerAAvatarUrl,
        String partnerBAvatarUrl,
        Set<String> deletedNodeIds,
        FirebaseCoupleConfig? cloudConfig,
      })?> hydrateCouplePrefsFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_couplePrefsKey);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final rawViewer = decoded['viewerAuthor'] as String? ?? 'samuel';
      final viewerAuthor = rawViewer == 'rochy' ? 'rochy' : 'samuel';
      final rawPartnerA = (decoded['partnerAName'] as String?)?.trim() ?? '';
      final partnerAName =
          rawPartnerA.isEmpty || rawPartnerA == 'Samuel' ? 'Sam' : rawPartnerA;
      final partnerBName =
          (decoded['partnerBName'] as String?)?.trim().isNotEmpty == true
              ? (decoded['partnerBName'] as String).trim()
              : 'Rochy';
      final partnerAAvatarUrl =
          (decoded['partnerAAvatarUrl'] as String? ?? '').trim();
      final partnerBAvatarUrl =
          (decoded['partnerBAvatarUrl'] as String? ?? '').trim();
      final rawDeleted =
          decoded['deletedNodeIds'] as List<dynamic>? ?? const [];
      final deletedNodeIds = rawDeleted
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toSet();
      final rawCloud = decoded['cloudConfig'];
      final cloudConfig = rawCloud is Map
          ? FirebaseCoupleConfig.fromJson(Map<String, dynamic>.from(rawCloud))
          : null;
      return (
        viewerAuthor: viewerAuthor,
        partnerAName: partnerAName,
        partnerBName: partnerBName,
        partnerAAvatarUrl: partnerAAvatarUrl,
        partnerBAvatarUrl: partnerBAvatarUrl,
        deletedNodeIds: deletedNodeIds,
        cloudConfig: cloudConfig,
      );
    } on MissingPluginException {
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> persistCouplePrefsToDisk({
    required String viewerAuthor,
    required String partnerAName,
    required String partnerBName,
    required String partnerAAvatarUrl,
    required String partnerBAvatarUrl,
    required Set<String> deletedNodeIds,
    required FirebaseCoupleConfig cloudConfig,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _couplePrefsKey,
        jsonEncode(<String, dynamic>{
          'viewerAuthor': viewerAuthor,
          'partnerAName': partnerAName,
          'partnerBName': partnerBName,
          'partnerAAvatarUrl': partnerAAvatarUrl,
          'partnerBAvatarUrl': partnerBAvatarUrl,
          'deletedNodeIds': deletedNodeIds.toList(growable: false),
          'cloudConfig': cloudConfig.toJson(),
        }),
      );
    } on MissingPluginException {
      // Ignorado sin canal nativo.
    } catch (_) {}
  }

  @override
  List<BentoNode> starterTemplateNodes({String? notebookId}) {
    return const <BentoNode>[];
  }

  static BentoEntity seedSamuelEntity() {
    return BentoEntity(
      ownerAuthorId: 'rochy',
      id: kSamuelNotebookId,
      name: 'Sam',
      subtitle: 'Su cuaderno vivo · Por Rochy',
      coverImageUrl:
          'https://images.unsplash.com/photo-1511920170033-f8396924c348?auto=format&fit=crop&w=1080&q=85',
      shortBio:
          'Mi espacio íntimo para guardar lo que él ama, sus cafés, tallas, lugares, canciones y frases que lo definen.',
      birthDate: DateTime(1998, 4, 19),
      anniversaryDate: DateTime(2023, 10, 14),
      activeThemeId: RochyThemes.arenaCalida.id,
    );
  }

  static List<BentoNode> seedSamuelStarterNodes() {
    return <BentoNode>[
      BentoNode(
        id: 'sam_about_him',
        type: BentoNodeType.aboutHer,
        colSpan: 2,
        rowSpan: 2,
        colorTheme: BentoColorTheme.espresso,
        linkedNodeIds: const ['sam_checklist_details'],
        tags: const ['él', 'esencia'],
        authorId: 'rochy',
        createdAt: DateTime(2025, 11, 1, 10, 0),
        payload: const AboutHerPayload(
          title: 'Sobre él',
          entries: <AboutHerEntry>[
            AboutHerEntry(prefix: 'Él es', detail: 'mi lugar seguro'),
            AboutHerEntry(
              prefix: 'Él tiene',
              detail: 'una forma única de hacerme reír',
            ),
            AboutHerEntry(
              prefix: 'Él siempre',
              detail: 'cuida cada detalle sin decirlo',
            ),
          ],
        ),
      ),
      BentoNode(
        id: 'sam_flip_coffee',
        type: BentoNodeType.flipDetail,
        colSpan: 1,
        rowSpan: 2,
        colorTheme: BentoColorTheme.terracotta,
        linkedNodeIds: const ['sam_audio_song'],
        tags: const ['café', 'hábitos'],
        authorId: 'rochy',
        createdAt: DateTime(2025, 11, 2, 11, 15),
        payload: const FlipDetailPayload(
          title: 'Su café favorito',
          microText: 'Americano o latte tibio',
          iconKey: 'coffee',
          voiceNoteLabel: 'Nota de voz · Pedido de él',
          recordedDateLabel: '12 oct · 0:18',
          durationSeconds: 18,
          waveformSamples: <double>[
            0.25,
            0.55,
            0.85,
            0.45,
            0.90,
            0.65,
            0.40,
            0.78,
            0.50,
            0.35,
          ],
          backSubtitle: '“Sin azúcar o con un toque ligero”',
        ),
      ),
      BentoNode(
        id: 'sam_audio_song',
        type: BentoNodeType.audioNote,
        colSpan: 1,
        rowSpan: 2,
        colorTheme: BentoColorTheme.ivory,
        linkedNodeIds: const ['sam_flip_coffee'],
        tags: const ['música', 'él'],
        authorId: 'rochy',
        createdAt: DateTime(2025, 11, 3, 18, 40),
        payload: const AudioNotePayload(
          title: 'Canción que me recuerda a él',
          subtitle: 'Para escuchar pensándolo',
          coverImageUrl: '',
          durationSeconds: 30,
          waveformSamples: <double>[
            0.22,
            0.45,
            0.72,
            0.58,
            0.86,
            0.92,
            0.68,
            0.52,
            0.80,
            0.60,
          ],
          recordedAtLabel: 'Nuestra lista',
        ),
      ),
      BentoNode(
        id: 'sam_checklist_details',
        type: BentoNodeType.checkList,
        colSpan: 2,
        rowSpan: 2,
        colorTheme: BentoColorTheme.sand,
        fontStyle: BentoFontStyle.handwritten,
        linkedNodeIds: const ['sam_about_him'],
        tags: const ['detalles', 'él'],
        authorId: 'rochy',
        createdAt: DateTime(2025, 11, 4, 20, 5),
        payload: const CheckListPayload(
          title: 'Detalles que amo de él',
          footerHint: 'Toca un detalle para destacarlo',
          items: <CheckListItem>[
            CheckListItem(
              id: 'sam_det_1',
              text: 'Cómo me mira cuando hablo emocionada',
              isHighlighted: true,
            ),
            CheckListItem(
              id: 'sam_det_2',
              text: 'Su paciencia para escucharme siempre',
            ),
          ],
        ),
      ),
    ];
  }

  static BentoEntity seedNosotrosEntity() {
    return BentoEntity(
      ownerAuthorId: 'samuel',
      id: kNosotrosNotebookId,
      name: 'Nosotros',
      subtitle: 'Rochy & Sam · Compartido',
      coverImageUrl:
          'https://images.unsplash.com/photo-1516589178581-6cd7833ae3b2?auto=format&fit=crop&w=1080&q=85',
      shortBio:
          'Nuestro tablero compartido para llenar juntos: momentos, lugares, sorpresas y preguntas para los dos.',
      birthDate: DateTime(1998, 4, 19),
      anniversaryDate: DateTime(2023, 10, 14),
      activeThemeId: RochyThemes.arenaCalida.id,
      isCoupleShared: true,
      sharingMode: NotebookSharingMode.sharedEdit,
    );
  }

  static List<BentoNode> seedNosotrosStarterNodes() {
    return <BentoNode>[
      BentoNode(
        id: 'nos_countdown_together',
        type: BentoNodeType.countdown,
        colSpan: 1,
        rowSpan: 2,
        colorTheme: BentoColorTheme.terracotta,
        linkedNodeIds: const ['nos_hero_place'],
        tags: const ['nosotros', 'aniversario'],
        authorId: 'samuel',
        createdAt: DateTime(2025, 11, 1, 9, 0),
        payload: CountdownPayload(
          title: 'Rochy & Sam',
          targetDate: DateTime(2023, 10, 14),
          subtitle: 'Sumando capítulos juntos',
          countMode: 'since',
        ),
      ),
      BentoNode(
        id: 'nos_quote_duo',
        type: BentoNodeType.quote,
        colSpan: 1,
        rowSpan: 2,
        colorTheme: BentoColorTheme.ivory,
        linkedNodeIds: const ['nos_checklist_dreams'],
        tags: const ['nosotros', 'citas'],
        authorId: 'rochy',
        createdAt: DateTime(2025, 11, 2, 18, 20),
        payload: const QuotePayload(
          quoteText: 'Contigo hasta los días normales se sienten como fiesta.',
          contextLabel: 'Nuestro lema en casa',
          isLoved: true,
          loveCount: 8,
        ),
      ),
      BentoNode(
        id: 'nos_hero_place',
        type: BentoNodeType.photoHero,
        colSpan: 2,
        rowSpan: 2,
        colorTheme: BentoColorTheme.espresso,
        linkedNodeIds: const ['nos_countdown_together', 'nos_passport_trips'],
        tags: const ['citas', 'nosotros', 'atardecer'],
        authorId: 'samuel',
        createdAt: DateTime(2025, 11, 3, 17, 45),
        payload: const PhotoHeroPayload(
          imageUrl:
              'https://images.unsplash.com/photo-1516589178581-6cd7833ae3b2?auto=format&fit=crop&w=1080&q=85',
          title: 'Nuestro lugar de siempre',
          dateLabel: 'Caminata de domingo',
          locationLabel: 'Murallas al caer el sol',
          storyBody:
              'Aquí pueden ir subiendo fotos de cada salida juntos, con su historia y el lugar exacto en el mapa.',
          photographerNote: 'Foto compartida · Tablero Nosotros',
          latitude: 10.4274,
          longitude: -75.5504,
        ),
      ),
      BentoNode(
        id: 'nos_checklist_dreams',
        type: BentoNodeType.checkList,
        colSpan: 1,
        rowSpan: 3,
        colorTheme: BentoColorTheme.sand,
        fontStyle: BentoFontStyle.handwritten,
        linkedNodeIds: const ['nos_quote_duo'],
        tags: const ['planes', 'sueños', 'nosotros'],
        authorId: 'rochy',
        createdAt: DateTime(2025, 11, 4, 20, 10),
        payload: const CheckListPayload(
          title: 'Nuestra lista por cumplir',
          footerHint: 'Cada uno agrega ideas nuevas',
          items: <CheckListItem>[
            CheckListItem(
              id: 'nos_plan_1',
              text: 'Hacer un picnic sin ver el celular',
              isHighlighted: true,
            ),
            CheckListItem(
              id: 'nos_plan_2',
              text: 'Cocinar juntos pasta casera un viernes',
            ),
            CheckListItem(
              id: 'nos_plan_3',
              text: 'Escapada de fin de semana frente al mar',
            ),
          ],
        ),
      ),
      BentoNode(
        id: 'nos_plan_ticket_surprise',
        type: BentoNodeType.planTicket,
        colSpan: 1,
        rowSpan: 2,
        colorTheme: BentoColorTheme.sage,
        linkedNodeIds: const ['nos_countdown_together'],
        tags: const ['cita', 'sorpresa'],
        authorId: 'samuel',
        isSurprise: true,
        createdAt: DateTime(2025, 11, 5, 14, 0),
        payload: const PlanTicketPayload(
          title: 'Vale por una cena sorpresa',
          whenLabel: 'Este sábado · 7:30 PM',
          placeLabel: 'Lugar secreto en el centro',
          promiseNote:
              'Vístete cómoda y linda: esta noche yo me encargo de todo.',
          isRedeemed: false,
          latitude: 10.4238,
          longitude: -75.5510,
        ),
      ),
      BentoNode(
        id: 'nos_chat_funny',
        type: BentoNodeType.savedChat,
        colSpan: 2,
        rowSpan: 2,
        colorTheme: BentoColorTheme.ivory,
        linkedNodeIds: const [],
        tags: const ['risas', 'chat'],
        authorId: 'rochy',
        createdAt: DateTime(2025, 11, 6, 21, 30),
        payload: const SavedChatPayload(
          title: 'Chistes internos que solo nosotros entendemos',
          messages: <SavedChatMessage>[
            SavedChatMessage(
              sender: 'Rochy',
              text: 'Prometimos hoy no pedir postre…',
              timeLabel: '8:14 PM',
            ),
            SavedChatMessage(
              sender: 'Sam',
              text: 'Ya pedí dos cucharas por si acaso 😂',
              timeLabel: '8:15 PM',
              isRight: true,
            ),
          ],
        ),
      ),
      BentoNode(
        id: 'nos_couple_question_1',
        type: BentoNodeType.coupleQuestion,
        colSpan: 2,
        rowSpan: 3,
        colorTheme: BentoColorTheme.ivory,
        linkedNodeIds: const <String>[],
        tags: const <String>['nosotros', 'pregunta'],
        authorId: 'samuel',
        createdAt: DateTime(2025, 11, 7, 19, 0),
        payload: const CoupleQuestionPayload(
          question:
              '¿Cuál es el recuerdo nuestro que te saca una sonrisa al instante?',
          answerSamuel:
              'Cuando nos quedamos hablando sin darnos cuenta de la hora.',
          answerRochy: '',
        ),
      ),
    ];
  }

  static BentoEntity _seedEntity() {
    return BentoEntity(
      ownerAuthorId: 'samuel',
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
    this.activeAuthorFilter,
    this.viewerAuthor = 'samuel',
    this.partnerAName = 'Sam',
    this.partnerBName = 'Rochy',
    this.partnerAAvatarUrl = '',
    this.partnerBAvatarUrl = '',
    this.deletedNodeIds = const <String>{},
    this.cloudConfig = const FirebaseCoupleConfig(),
    this.isCloudSyncing = false,
    this.lastCloudSyncAt,
    this.lastCloudSyncError,
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
  final String? activeAuthorFilter;
  final String viewerAuthor;
  final String partnerAName;
  final String partnerBName;
  final String partnerAAvatarUrl;
  final String partnerBAvatarUrl;
  final Set<String> deletedNodeIds;
  final FirebaseCoupleConfig cloudConfig;
  final bool isCloudSyncing;
  final DateTime? lastCloudSyncAt;
  final String? lastCloudSyncError;
  final bool showPaperGrain;
  final double textScaleFactor;
  final bool isEditMode;
  final bool isConnectingMode;
  final bool isBiometricEnabled;
  final bool isUnlocked;
  final Set<String> flippedNodeIds;
  final String? focusedMapNodeId;

  RochyNotebook get activeNotebook {
    for (final b in visibleNotebooks) {
      if (b.entity.id == activeNotebookId) return b;
    }
    if (visibleNotebooks.isNotEmpty) return visibleNotebooks.first;
    return RochyNotebook(
        entity: BentoEntity(
          id: '__locked_private__',
          name: 'Cuaderno privado',
          subtitle: '',
          coverImageUrl: '',
          shortBio: '',
          birthDate: DateTime(2000),
          anniversaryDate: DateTime(2000),
        ),
        nodes: const []);
  }

  List<RochyNotebook> get visibleNotebooks => notebooks
      .where((book) => book.entity.canReadFor(viewerAuthor))
      .toList(growable: false);

  bool get isNosotrosActive =>
      activeNotebook.entity.syncsToCloud ||
      activeNotebookId == kNosotrosNotebookId;
  bool get isActiveNotebookReadOnly =>
      activeNotebook.entity.isReadOnlyFor(viewerAuthor);
  bool get isTalkingAboutHim => viewerAuthor == 'rochy';
  String get personalTargetNotebookId =>
      viewerAuthor == 'rochy' ? kSamuelNotebookId : kRochyNotebookId;
  String get personalTargetDisplayName =>
      viewerAuthor == 'rochy' ? partnerAName : partnerBName;
  String get viewerDisplayName =>
      viewerAuthor == 'rochy' ? partnerBName : partnerAName;
  String get otherPartnerDisplayName =>
      viewerAuthor == 'rochy' ? partnerAName : partnerBName;

  String authorLabelFor(String authorId) => switch (authorId) {
        'rochy' => partnerBName,
        'samuel' => partnerAName,
        _ => '',
      };

  bool isHiddenSurpriseForViewer(BentoNode node) {
    if (!node.isSurpriseCurrentlyLocked || node.authorId.isEmpty) return false;
    return node.authorId != viewerAuthor;
  }

  BentoEntity get entity => activeNotebook.entity;
  List<BentoNode> get nodes => activeNotebook.nodes;

  List<BentoNode> get visibleCanvasNodes {
    if (!isNosotrosActive || activeAuthorFilter == null) return nodes;
    if (activeAuthorFilter == '__surprises__') {
      return nodes.where((n) => n.isSurprise).toList(growable: false);
    }
    return nodes
        .where((n) => n.authorId == activeAuthorFilter)
        .toList(growable: false);
  }

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
    String? activeAuthorFilter,
    bool clearAuthorFilter = false,
    String? viewerAuthor,
    String? partnerAName,
    String? partnerBName,
    String? partnerAAvatarUrl,
    String? partnerBAvatarUrl,
    Set<String>? deletedNodeIds,
    FirebaseCoupleConfig? cloudConfig,
    bool? isCloudSyncing,
    DateTime? lastCloudSyncAt,
    String? lastCloudSyncError,
    bool clearCloudSyncError = false,
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
      activeAuthorFilter: clearAuthorFilter
          ? null
          : (activeAuthorFilter ?? this.activeAuthorFilter),
      viewerAuthor: viewerAuthor ?? this.viewerAuthor,
      partnerAName: partnerAName ?? this.partnerAName,
      partnerBName: partnerBName ?? this.partnerBName,
      partnerAAvatarUrl: partnerAAvatarUrl ?? this.partnerAAvatarUrl,
      partnerBAvatarUrl: partnerBAvatarUrl ?? this.partnerBAvatarUrl,
      deletedNodeIds: deletedNodeIds ?? this.deletedNodeIds,
      cloudConfig: cloudConfig ?? this.cloudConfig,
      isCloudSyncing: isCloudSyncing ?? this.isCloudSyncing,
      lastCloudSyncAt: lastCloudSyncAt ?? this.lastCloudSyncAt,
      lastCloudSyncError: clearCloudSyncError
          ? null
          : (lastCloudSyncError ?? this.lastCloudSyncError),
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
  Timer? _cloudDebounceTimer;
  Timer? _cloudPollTimer;
  AudioPlayer? _audioPlayer;
  ProtectedMediaPlayback? _audioPlayback;
  StreamSubscription<Duration>? _positionSub;
  String? _loadedAudioNodeId;
  bool _hasCompletedInitialCloudSync = false;
  String _lastNotifiedRemoteAtIso = '';

  @override
  BentoCanvasState build() {
    ref.onDispose(() {
      _stopTicker();
      _cloudDebounceTimer?.cancel();
      _cloudPollTimer?.cancel();
      _positionSub?.cancel();
      _audioPlayer?.dispose();
      _audioPlayback?.release();
    });

    final repo = ref.read(bentoRepositoryProvider);
    final initial = BentoCanvasState(
      notebooks: repo.loadNotebooks(),
      activeNotebookId: repo.loadActiveNotebookId(),
    );

    _hydrationFuture = Future.microtask(_hydrate);
    return initial;
  }

  int _localRevision = 0;
  Future<void>? _hydrationFuture;
  Future<void> get whenHydrated => _hydrationFuture ?? Future.value();

  Future<void> _hydrate() async {
    unawaited(
      ref
          .read(rochyNotificationServiceProvider)
          .ensureInitialized(requestPermission: true),
    );
    final repo = ref.read(bentoRepositoryProvider);
    final couplePrefs = repo is LocalBentoRepository
        ? await repo.hydrateCouplePrefsFromDisk()
        : null;
    final restored = await repo.hydrateFromDisk();
    // Do not replace edits made while startup was awaiting disk I/O.
    if (_localRevision != 0) return;
    if (restored == null) {
      if (couplePrefs != null) {
        state = state.copyWith(
          viewerAuthor: couplePrefs.viewerAuthor,
          partnerAName: couplePrefs.partnerAName,
          partnerBName: couplePrefs.partnerBName,
          partnerAAvatarUrl: couplePrefs.partnerAAvatarUrl,
          partnerBAvatarUrl: couplePrefs.partnerBAvatarUrl,
          deletedNodeIds: couplePrefs.deletedNodeIds,
          cloudConfig: couplePrefs.cloudConfig ?? state.cloudConfig,
        );
      }
      _syncPeriodicPolling();
      if (state.cloudConfig.isConfigured && state.cloudConfig.autoSyncEnabled) {
        unawaited(syncNowWithFirebase(silent: true));
      }
      return;
    }

    final purgedDemoIds = <String>{};
    final migratedBooks = restored.notebooks.map((book) {
      var nextEntity = book.entity;
      if (nextEntity.ownerAuthorId.isEmpty) {
        nextEntity = nextEntity.copyWith(
            ownerAuthorId: nextEntity.id == kSamuelNotebookId
                ? 'rochy'
                : (couplePrefs?.viewerAuthor ?? 'samuel'));
      }
      if (nextEntity.id == kSamuelNotebookId && nextEntity.name == 'Samuel') {
        nextEntity = nextEntity.copyWith(name: 'Sam');
      } else if (nextEntity.id == kNosotrosNotebookId &&
          nextEntity.subtitle == 'Rochy & Samuel · Modo Pareja') {
        nextEntity = nextEntity.copyWith(
          subtitle: 'Rochy & Sam · Compartido',
        );
      }

      final updatedNodes = <BentoNode>[];
      for (final node in book.nodes) {
        if (RochyCloudSyncService.isUnmodifiedDemoNode(node)) {
          purgedDemoIds.add(node.id);
          continue;
        }
        updatedNodes.add(node);
      }
      return book.copyWith(entity: nextEntity, nodes: updatedNodes);
    }).toList(growable: false);

    final effectiveDeleted = <String>{
      ...(couplePrefs?.deletedNodeIds ?? state.deletedNodeIds),
      ...purgedDemoIds,
    };

    var withBaseBooks = migratedBooks;
    if (!effectiveDeleted.contains('__book__:$kNosotrosNotebookId') &&
        !withBaseBooks.any((b) =>
            b.entity.isCoupleShared || b.entity.id == kNosotrosNotebookId)) {
      withBaseBooks = <RochyNotebook>[
        ...withBaseBooks,
        RochyNotebook(
          entity: LocalBentoRepository.seedNosotrosEntity(),
          nodes: const <BentoNode>[],
        ),
      ];
    }

    final validActiveId =
        withBaseBooks.any((b) => b.entity.id == restored.activeNotebookId)
            ? restored.activeNotebookId
            : withBaseBooks.first.entity.id;

    state = state.copyWith(
      notebooks: withBaseBooks,
      activeNotebookId: validActiveId,
      isBiometricEnabled: restored.biometricEnabled,
      isUnlocked: !restored.biometricEnabled,
      showPaperGrain: restored.showPaperGrain,
      textScaleFactor: restored.textScaleFactor,
      viewerAuthor: couplePrefs?.viewerAuthor ?? state.viewerAuthor,
      partnerAName: couplePrefs?.partnerAName ?? state.partnerAName,
      partnerBName: couplePrefs?.partnerBName ?? state.partnerBName,
      partnerAAvatarUrl:
          couplePrefs?.partnerAAvatarUrl ?? state.partnerAAvatarUrl,
      partnerBAvatarUrl:
          couplePrefs?.partnerBAvatarUrl ?? state.partnerBAvatarUrl,
      deletedNodeIds: effectiveDeleted,
      cloudConfig: couplePrefs?.cloudConfig ?? state.cloudConfig,
    );

    if (purgedDemoIds.isNotEmpty ||
        withBaseBooks.length != migratedBooks.length) {
      _persist();
    }
    _syncPeriodicPolling();
    if (state.cloudConfig.isConfigured && state.cloudConfig.autoSyncEnabled) {
      unawaited(syncNowWithFirebase(silent: true));
    }
  }

  void _persist() {
    _localRevision++;
    final repo = ref.read(bentoRepositoryProvider);
    unawaited(
      repo.persistToDisk(
        notebooks: state.notebooks,
        activeNotebookId: state.activeNotebookId,
        biometricEnabled: state.isBiometricEnabled,
        showPaperGrain: state.showPaperGrain,
        textScaleFactor: state.textScaleFactor,
      ),
    );
    if (repo is LocalBentoRepository) {
      unawaited(
        repo.persistCouplePrefsToDisk(
          viewerAuthor: state.viewerAuthor,
          partnerAName: state.partnerAName,
          partnerBName: state.partnerBName,
          partnerAAvatarUrl: state.partnerAAvatarUrl,
          partnerBAvatarUrl: state.partnerBAvatarUrl,
          deletedNodeIds: state.deletedNodeIds,
          cloudConfig: state.cloudConfig,
        ),
      );
    }
  }

  void _replaceActiveNotebook(RochyNotebook Function(RochyNotebook) transform) {
    if (state.isActiveNotebookReadOnly) return;
    final updatedBooks = state.notebooks
        .map(
          (b) => b.entity.id == state.activeNotebookId ? transform(b) : b,
        )
        .toList(growable: false);
    state = state.copyWith(notebooks: updatedBooks);
    _persist();
    _scheduleAutoCloudSync();
  }

  void _syncPeriodicPolling() {
    _cloudPollTimer?.cancel();
    _cloudPollTimer = null;
    if (state.cloudConfig.isConfigured && state.cloudConfig.autoSyncEnabled) {
      _cloudPollTimer = Timer.periodic(
        const Duration(seconds: 25),
        (_) => unawaited(syncNowWithFirebase(silent: true)),
      );
    }
  }

  void _scheduleAutoCloudSync({Duration delay = const Duration(seconds: 3)}) {
    if (!state.cloudConfig.isConfigured || !state.cloudConfig.autoSyncEnabled) {
      return;
    }
    _cloudDebounceTimer?.cancel();
    _cloudDebounceTimer = Timer(
      delay,
      () => unawaited(syncNowWithFirebase(silent: true)),
    );
  }

  void updateCloudConfig(FirebaseCoupleConfig config) {
    state = state.copyWith(
      cloudConfig: config,
      clearCloudSyncError: true,
    );
    _persist();
    _syncPeriodicPolling();
  }

  void disconnectCloud() {
    _cloudDebounceTimer?.cancel();
    _cloudPollTimer?.cancel();
    state = state.copyWith(
      cloudConfig: const FirebaseCoupleConfig(
        projectId: '',
        storageBucket: '',
        apiKey: '',
        autoSyncEnabled: false,
      ),
      isCloudSyncing: false,
      clearCloudSyncError: true,
    );
    _persist();
  }

  Future<CloudSyncResult?> syncNowWithFirebase({bool silent = false}) async {
    if (!state.cloudConfig.isConfigured || state.isCloudSyncing) {
      return null;
    }
    state = state.copyWith(
      isCloudSyncing: true,
      clearCloudSyncError: true,
    );
    final syncRevision = _localRevision;
    final syncConfig = state.cloudConfig;
    final syncAuthor = state.viewerAuthor;
    try {
      final result =
          await ref.read(rochyCloudSyncServiceProvider).syncCoupleWorkspace(
                config: state.cloudConfig,
                localNotebooks: state.notebooks,
                viewerAuthor: state.viewerAuthor,
                mediaService: ref.read(mediaAndAuthServiceProvider),
                localDeletedIds: state.deletedNodeIds,
                partnerAAvatarUrl: state.partnerAAvatarUrl,
                partnerBAvatarUrl: state.partnerBAvatarUrl,
              );
      if (state.cloudConfig.projectId != syncConfig.projectId ||
          state.cloudConfig.storageBucket != syncConfig.storageBucket ||
          state.cloudConfig.coupleRoomId != syncConfig.coupleRoomId ||
          state.viewerAuthor != syncAuthor) {
        state = state.copyWith(isCloudSyncing: false);
        _scheduleAutoCloudSync();
        return null;
      }
      final hasNewLocalChanges = _localRevision != syncRevision;
      final effectiveDeleted = {
        ...result.deletedNodeIds,
        ...state.deletedNodeIds
      };
      if (!hasNewLocalChanges) {
        effectiveDeleted.removeAll(result.acknowledgedVisibilityChanges);
      }
      final syncedNotebooks = !hasNewLocalChanges
          ? result.mergedLocalNotebooks
          : RochyCloudSyncService.mergeNotebooksPure(
              localNotebooks: state.notebooks,
              incomingNotebooks: result.mergedLocalNotebooks,
              deletedIds: effectiveDeleted,
              localOwner: state.viewerAuthor,
              includeOwnPrivate: true,
            ).notebooks;
      final selectedDeleted = state.selectedNodeId != null &&
          effectiveDeleted.contains(state.selectedNodeId);
      final activeWidgetDeleted = state.activeWidgetId != null &&
          effectiveDeleted.contains(state.activeWidgetId);
      state = state.copyWith(
        notebooks: syncedNotebooks,
        deletedNodeIds: effectiveDeleted,
        partnerAAvatarUrl: result.partnerAAvatarUrl,
        partnerBAvatarUrl: result.partnerBAvatarUrl,
        clearSelectedNode: selectedDeleted,
        clearActiveWidget: activeWidgetDeleted,
        isConnectingMode: selectedDeleted ? false : state.isConnectingMode,
        isCloudSyncing: false,
        lastCloudSyncAt: result.pendingMedia == 0 ? DateTime.now() : null,
        lastCloudSyncError: result.pendingMedia > 0
            ? '${result.pendingMedia} archivo(s) pendientes de subir desde el dispositivo original. Se reintentará automáticamente.'
            : null,
        clearCloudSyncError: result.pendingMedia == 0,
      );
      _persist();

      final partnerChanged = result.remoteUpdatedBy.isNotEmpty &&
          result.remoteUpdatedBy != state.viewerAuthor &&
          (result.addedNodes > 0 || result.updatedNodes > 0) &&
          (result.remoteUpdatedAtIso.isEmpty ||
              result.remoteUpdatedAtIso != _lastNotifiedRemoteAtIso);
      if (_hasCompletedInitialCloudSync && partnerChanged) {
        final who = state.authorLabelFor(result.remoteUpdatedBy);
        unawaited(
          ref
              .read(rochyNotificationServiceProvider)
              .showPartnerChangeNotification(
                partnerName:
                    who.isNotEmpty ? who : state.otherPartnerDisplayName,
                addedNodes: result.addedNodes,
                updatedNodes: result.updatedNodes,
                roomLabel: state.cloudConfig.coupleRoomId,
              ),
        );
      }
      if (result.remoteUpdatedAtIso.isNotEmpty) {
        _lastNotifiedRemoteAtIso = result.remoteUpdatedAtIso;
      }
      _hasCompletedInitialCloudSync = true;
      if (hasNewLocalChanges) {
        _scheduleAutoCloudSync();
      } else if (result.pendingMedia > 0) {
        _scheduleAutoCloudSync(delay: const Duration(seconds: 25));
      } else {
        _cloudDebounceTimer?.cancel();
        _cloudDebounceTimer = null;
      }
      return result;
    } catch (e) {
      state = state.copyWith(
        isCloudSyncing: false,
        lastCloudSyncError: e.toString(),
      );
      _scheduleAutoCloudSync(delay: const Duration(seconds: 25));
      if (!silent) rethrow;
      return null;
    }
  }

  void toggleNodeFocus(String nodeId) {
    if (state.selectedNodeId == nodeId) {
      state = state.copyWith(
        clearSelectedNode: true,
        clearActiveWidget: true,
        isConnectingMode: false,
      );
    } else {
      state = state.copyWith(
        selectedNodeId: nodeId,
        clearActiveWidget: true,
        isConnectingMode: false,
      );
    }
  }

  /// Activa un widget en el lienzo tras mantenerlo presionado (redimensionar / mover / menú).
  void activateWidget(String nodeId) {
    if (state.isActiveNotebookReadOnly) return;
    state = state.copyWith(
      activeWidgetId: nodeId,
      clearSelectedNode: true,
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
    if (state.isActiveNotebookReadOnly) return;
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
      clearActiveWidget: true,
      isConnectingMode: false,
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
    if (updatedEntity.id != state.entity.id) return;
    _replaceActiveNotebook((b) => b.copyWith(
            entity: updatedEntity.copyWith(
          ownerAuthorId: b.entity.ownerAuthorId,
          updatedAt: DateTime.now(),
          sharingMode: b.entity.sharingMode,
          isCoupleShared: b.entity.syncsToCloud,
        )));
  }

  void createNotebook({
    required String name,
    required String subtitle,
    String shortBio = '',
    bool startBlank = true,
    bool isCoupleShared = false,
    NotebookSharingMode? sharingMode,
  }) {
    pauseAudio();
    final effectiveMode = sharingMode ??
        (isCoupleShared
            ? NotebookSharingMode.sharedEdit
            : NotebookSharingMode.privateOnly);
    final syncs = effectiveMode != NotebookSharingMode.privateOnly;
    final id = 'entity_${DateTime.now().microsecondsSinceEpoch}';
    final entity = BentoEntity(
      id: id,
      name: name.trim().isEmpty
          ? (syncs ? 'Nosotros' : 'Nuevo cuaderno')
          : name.trim(),
      subtitle: subtitle.trim().isNotEmpty
          ? subtitle.trim()
          : (syncs
              ? '${state.partnerBName} & ${state.partnerAName} · ${effectiveMode.label}'
              : ''),
      coverImageUrl: '',
      shortBio: shortBio.trim(),
      birthDate: DateTime(2000, 1, 1),
      anniversaryDate: DateTime.now(),
      activeThemeId: state.entity.activeThemeId,
      isCoupleShared: syncs,
      sharingMode: effectiveMode,
      ownerAuthorId: state.viewerAuthor,
    );

    final nextBooks = <RochyNotebook>[
      ...state.notebooks,
      RochyNotebook(entity: entity, nodes: const <BentoNode>[]),
    ];

    state = state.copyWith(
      notebooks: nextBooks,
      activeNotebookId: id,
      clearSelectedNode: true,
      clearActiveWidget: true,
      isConnectingMode: false,
      clearActiveAudio: true,
      clearTagFilter: true,
      clearAuthorFilter: true,
      clearFocusedMapNode: true,
      isEditMode: false,
    );
    _persist();
    if (syncs) {
      _scheduleAutoCloudSync();
    }
  }

  void setNotebookSharingMode(
    String notebookId,
    NotebookSharingMode mode,
  ) {
    final book =
        state.notebooks.where((b) => b.entity.id == notebookId).firstOrNull;
    if (book == null || !book.entity.canManageFor(state.viewerAuthor)) return;
    final updatedBooks = state.notebooks.map((book) {
      if (book.entity.id != notebookId) return book;
      final owner = book.entity.ownerAuthorId.isEmpty
          ? state.viewerAuthor
          : book.entity.ownerAuthorId;
      return book.copyWith(
        entity: book.entity.copyWith(
          sharingMode: mode,
          updatedAt: DateTime.now(),
          isCoupleShared: mode != NotebookSharingMode.privateOnly,
          ownerAuthorId: owner,
        ),
      );
    }).toList(growable: false);
    state = state.copyWith(
      notebooks: updatedBooks,
      isEditMode: false,
      deletedNodeIds: {
        ...state.deletedNodeIds
            .where((id) => !id.startsWith('__visibility__:$notebookId:')),
        '__visibility__:$notebookId:${mode.name}',
      },
    );
    _persist();
    _scheduleAutoCloudSync();
  }

  /// Crea e inicializa una nueva sala compartida en Firebase con código único.
  Future<CloudSyncResult?> createCoupleRoom(String rawRoomCode) async {
    final normalized = RochyCloudSyncService.normalizeRoomCode(rawRoomCode);
    await ref
        .read(rochyNotificationServiceProvider)
        .ensureInitialized(requestPermission: true);
    final nextConfig = state.cloudConfig.copyWith(
      coupleRoomId: normalized,
      autoSyncEnabled: true,
    );
    _hasCompletedInitialCloudSync = false;
    _lastNotifiedRemoteAtIso = '';
    updateCloudConfig(nextConfig);
    return syncNowWithFirebase(silent: false);
  }

  /// Verifica que la sala exista en Firebase y une este teléfono a la sala de la pareja.
  Future<CloudSyncResult?> joinCoupleRoom(String rawInput) async {
    final extracted = RochyCloudSyncService.extractRoomCode(rawInput);
    if (extracted.isEmpty) {
      throw const FirebaseSyncException(
        'Escribe o pega el código de la sala que te compartió tu pareja.',
      );
    }
    await ref
        .read(rochyNotificationServiceProvider)
        .ensureInitialized(requestPermission: true);
    final service = ref.read(rochyCloudSyncServiceProvider);
    final exists = await service.checkRoomExists(
      config: state.cloudConfig,
      roomCode: extracted,
    );
    if (!exists) {
      throw FirebaseSyncException(
        'No encontramos ninguna sala con el código "${extracted.toUpperCase()}". Verifica el código o pídele a tu pareja que toque "Crear sala" primero.',
      );
    }
    final nextConfig = state.cloudConfig.copyWith(
      coupleRoomId: extracted,
      autoSyncEnabled: true,
    );
    _hasCompletedInitialCloudSync = false;
    _lastNotifiedRemoteAtIso = '';
    updateCloudConfig(nextConfig);
    return syncNowWithFirebase(silent: false);
  }

  void setViewerAuthor(String authorId) {
    final normalized = authorId == 'rochy' ? 'rochy' : 'samuel';
    final linkedProfile = ref.read(rochyAccountProvider).authorId;
    if (linkedProfile != null && linkedProfile != normalized) return;
    if (state.viewerAuthor == normalized) return;
    var nextActiveId = state.activeNotebookId;
    if (state.activeNotebookId == kRochyNotebookId ||
        state.activeNotebookId == kSamuelNotebookId) {
      nextActiveId =
          normalized == 'rochy' ? kSamuelNotebookId : kRochyNotebookId;
    }
    state = state.copyWith(
      viewerAuthor: normalized,
      isEditMode: false,
      activeNotebookId: nextActiveId,
      clearSelectedNode: true,
      clearActiveWidget: true,
      clearTagFilter: true,
      clearAuthorFilter: true,
      isConnectingMode: false,
    );
    _persist();
  }

  void updateCoupleNames({
    required String partnerAName,
    required String partnerBName,
  }) {
    final a = partnerAName.trim().isEmpty ? 'Sam' : partnerAName.trim();
    final b = partnerBName.trim().isEmpty ? 'Rochy' : partnerBName.trim();
    final updatedBooks = state.notebooks.map((book) {
      if (book.entity.id == kNosotrosNotebookId) {
        return book.copyWith(
          entity: book.entity.copyWith(subtitle: '$a y $b'),
        );
      }
      if (book.entity.id == kSamuelNotebookId) {
        return book.copyWith(entity: book.entity.copyWith(name: a));
      }
      if (book.entity.id == kRochyNotebookId) {
        return book.copyWith(entity: book.entity.copyWith(name: b));
      }
      return book;
    }).toList(growable: false);
    state = state.copyWith(
      notebooks: updatedBooks,
      partnerAName: a,
      partnerBName: b,
    );
    _persist();
  }

  void setAuthorFilter(String? filter) {
    if (filter == null || state.activeAuthorFilter == filter) {
      state = state.copyWith(clearAuthorFilter: true);
    } else {
      state = state.copyWith(activeAuthorFilter: filter);
    }
  }

  void toggleNodeSurprise(String nodeId) {
    final now = DateTime.now();
    _replaceActiveNotebook((b) {
      final updated = b.nodes.map((n) {
        if (n.id != nodeId) return n;
        final nextAuthor =
            n.authorId.isNotEmpty ? n.authorId : state.viewerAuthor;
        return n.copyWith(
          authorId: nextAuthor,
          isSurprise: !n.isSurprise,
          updatedAt: now,
        );
      }).toList(growable: false);
      return b.copyWith(nodes: updated);
    });
  }

  void switchNotebook(String notebookId) {
    if (state.activeNotebookId == notebookId) return;
    pauseAudio();
    state = state.copyWith(
      activeNotebookId: notebookId,
      clearSelectedNode: true,
      clearActiveWidget: true,
      isConnectingMode: false,
      clearActiveAudio: true,
      clearTagFilter: true,
      clearAuthorFilter: true,
      clearFocusedMapNode: true,
      isEditMode: false,
    );
    _persist();
  }

  void deleteNotebook(String notebookId) {
    final book =
        state.notebooks.where((b) => b.entity.id == notebookId).firstOrNull;
    if (book == null || !book.entity.canManageFor(state.viewerAuthor)) return;
    if (state.notebooks.length <= 1) {
      return;
    }
    pauseAudio();
    final remaining = state.notebooks
        .where((b) => b.entity.id != notebookId)
        .toList(growable: false);
    if (remaining.isEmpty) return;
    final nextId = state.activeNotebookId == notebookId
        ? remaining.first.entity.id
        : state.activeNotebookId;
    final nextDeleted = <String>{
      ...state.deletedNodeIds,
      '__book__:$notebookId',
    };
    state = state.copyWith(
      notebooks: remaining,
      activeNotebookId: nextId,
      deletedNodeIds: nextDeleted,
      clearSelectedNode: true,
      clearActiveWidget: true,
      isConnectingMode: false,
      clearActiveAudio: true,
      clearTagFilter: true,
      clearAuthorFilter: true,
      clearFocusedMapNode: true,
    );
    _persist();
    _scheduleAutoCloudSync();
  }

  void addNode(BentoNode node) {
    _replaceActiveNotebook(
      (b) => b.copyWith(nodes: <BentoNode>[...b.nodes, node]),
    );
  }

  void updateNode(BentoNode updated) {
    final stamped = updated.copyWith(updatedAt: DateTime.now());
    _replaceActiveNotebook(
      (b) => b.copyWith(
        nodes: b.nodes
            .map((n) => n.id == stamped.id ? stamped : n)
            .toList(growable: false),
      ),
    );
  }

  /// Elimina un módulo y devuelve (nodo, índice) para permitir Deshacer.
  ({BentoNode node, int index})? deleteNode(String nodeId) {
    if (state.isActiveNotebookReadOnly) return null;
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

    final nextDeleted = <String>{...state.deletedNodeIds, nodeId};
    final selectedDeleted = state.selectedNodeId == nodeId;
    final activeDeleted = state.activeWidgetId == nodeId;
    final mapDeleted = state.focusedMapNodeId == nodeId;
    state = state.copyWith(
      deletedNodeIds: nextDeleted,
      clearSelectedNode: selectedDeleted,
      clearActiveWidget: activeDeleted,
      clearFocusedMapNode: mapDeleted,
      isConnectingMode: selectedDeleted ? false : state.isConnectingMode,
    );
    _replaceActiveNotebook((b) => b.copyWith(nodes: nextNodes));
    return (node: removed, index: index);
  }

  void restoreDeletedNode(BentoNode node, int index) {
    if (state.isActiveNotebookReadOnly) return;
    final nextDeleted = Set<String>.of(state.deletedNodeIds)..remove(node.id);
    state = state.copyWith(deletedNodeIds: nextDeleted);
    final mutable = List<BentoNode>.of(state.nodes);
    final safeIndex = index.clamp(0, mutable.length);
    mutable.insert(safeIndex, node);
    _replaceActiveNotebook((b) => b.copyWith(nodes: mutable));
  }

  void setPartnerAvatar({
    required String authorId,
    required String imagePath,
  }) {
    final normalized = imagePath.trim();
    if (normalized.isEmpty) return;
    if (authorId == 'rochy') {
      state = state.copyWith(partnerBAvatarUrl: normalized);
    } else {
      state = state.copyWith(partnerAAvatarUrl: normalized);
    }
    _persist();
    _scheduleAutoCloudSync();
  }

  void savePartnerReply(String nodeId, String replyText) {
    final trimmed = replyText.trim();
    final now = DateTime.now();
    _replaceActiveNotebook((b) {
      final updated = b.nodes.map((n) {
        if (n.id != nodeId) return n;
        return n.copyWith(
          partnerReplyText: trimmed,
          partnerReplyAuthor: trimmed.isEmpty ? '' : state.viewerAuthor,
          updatedAt: now,
        );
      }).toList(growable: false);
      return b.copyWith(nodes: updated);
    });
  }

  void saveCoupleQuestionAnswer(String nodeId, String answerText) {
    final trimmed = answerText.trim();
    final now = DateTime.now();
    final isRochy = state.viewerAuthor == 'rochy';
    _replaceActiveNotebook((b) {
      final updated = b.nodes.map((n) {
        if (n.id != nodeId) return n;
        final payload = n.payload;
        if (payload is! CoupleQuestionPayload) return n;
        final nextPayload = isRochy
            ? payload.copyWith(answerRochy: trimmed)
            : payload.copyWith(answerSamuel: trimmed);
        return n.copyWith(
          payload: nextPayload,
          updatedAt: now,
        );
      }).toList(growable: false);
      return b.copyWith(nodes: updated);
    });
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
    final now = DateTime.now();
    _replaceActiveNotebook((b) {
      final updated = b.nodes.map((n) {
        if (n.id != nodeId) return n;
        return n.copyWith(
          colSpan: (colSpan ?? n.colSpan).clamp(1, 2),
          rowSpan: (rowSpan ?? n.rowSpan).clamp(1, 20),
          updatedAt: now,
        );
      }).toList(growable: false);
      return b.copyWith(nodes: updated);
    });
  }

  /// Alterna el estado de favorito de cualquier tarjeta del cuaderno.
  void toggleNodeFavorite(String nodeId) {
    final now = DateTime.now();
    _replaceActiveNotebook((b) {
      final updated = b.nodes.map((n) {
        if (n.id != nodeId) return n;
        return n.copyWith(
          isFavorite: !n.isFavorite,
          updatedAt: now,
        );
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
    final current = state.nodes.where((n) => n.id == nodeId).firstOrNull;
    if (current == null) return;
    final idx = cycle.indexOf((current.colSpan, current.rowSpan));
    final next = cycle[(idx + 1) % cycle.length];
    resizeNode(nodeId, colSpan: next.$1, rowSpan: next.$2);
  }

  /// Activa la conexión meramente visual desde el menú contextual.
  void startVisualConnection(String nodeId) {
    if (state.isActiveNotebookReadOnly) return;
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
      final sourceNode = b.nodes.where((n) => n.id == sourceId).firstOrNull;
      final targetNode = b.nodes.where((n) => n.id == targetId).firstOrNull;
      if (sourceNode == null || targetNode == null) return b;
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
    if (state.isActiveNotebookReadOnly) return;
    state = state.copyWith(deletedNodeIds: {
      ...state.deletedNodeIds,
      ...state.nodes.map((n) => n.id)
    });
    pauseAudio();
    _replaceActiveNotebook((b) => b.copyWith(nodes: const <BentoNode>[]));
    state = state.copyWith(
      clearSelectedNode: true,
      clearActiveWidget: true,
      isConnectingMode: false,
      clearActiveAudio: true,
      clearTagFilter: true,
      clearFocusedMapNode: true,
    );
  }

  void restoreStarterTemplate() {
    if (state.isActiveNotebookReadOnly) return;
    pauseAudio();
    final starter = ref.read(bentoRepositoryProvider).starterTemplateNodes(
          notebookId: state.activeNotebookId,
        );
    final restoredIds = starter.map((n) => n.id).toSet();
    final nextDeleted = Set<String>.of(state.deletedNodeIds)
      ..removeAll(restoredIds);
    state = state.copyWith(
      deletedNodeIds: nextDeleted,
      clearSelectedNode: true,
      clearActiveWidget: true,
      isConnectingMode: false,
      clearActiveAudio: true,
      clearTagFilter: true,
      clearAuthorFilter: true,
      clearFocusedMapNode: true,
    );
    _replaceActiveNotebook((b) => b.copyWith(nodes: starter));
  }

  /// Fusiona cuadernos recibidos de la pareja sin sobrescribir cambios más recientes.
  ({int addedNodes, int updatedNodes}) mergeCoupleNotebooks(
    List<RochyNotebook> incomingNotebooks,
  ) {
    if (incomingNotebooks.isEmpty) {
      return (addedNodes: 0, updatedNodes: 0);
    }
    pauseAudio();

    final merged = RochyCloudSyncService.mergeNotebooksPure(
      localNotebooks: state.notebooks,
      incomingNotebooks: incomingNotebooks,
      deletedIds: state.deletedNodeIds,
      localOwner: state.viewerAuthor,
    );

    state = state.copyWith(
      notebooks: merged.notebooks,
      clearSelectedNode: true,
      clearActiveWidget: true,
      isConnectingMode: false,
    );
    _persist();
    return (addedNodes: merged.addedNodes, updatedNodes: merged.updatedNodes);
  }

  /// Exporta un código compacto para enviar por WhatsApp/portapapeles a la pareja.
  String exportCoupleQuickCode({bool onlyNosotros = false}) {
    final targetBooks = state.notebooks
        .where((book) =>
            book.entity.syncsToCloud &&
            (!onlyNosotros || book.entity.id == kNosotrosNotebookId))
        .toList(growable: false);
    final payloadJson = jsonEncode(<String, dynamic>{
      'format': 'rochy_couple_sync',
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'notebooks': targetBooks.map((b) => b.toJson()).toList(),
    });
    final compressed = const GZipEncoder().encode(utf8.encode(payloadJson));
    return 'ROCHY-SYNC:${base64UrlEncode(compressed)}';
  }

  /// Importa y fusiona un código compacto (`ROCHY-SYNC:...`) o JSON recibido de la pareja.
  ({int addedNodes, int updatedNodes}) importCoupleQuickCode(String rawCode) {
    final trimmed = rawCode.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('El código de sincronización está vacío.');
    }

    String jsonString;
    if (trimmed.startsWith('ROCHY-SYNC:')) {
      final body = trimmed
          .substring('ROCHY-SYNC:'.length)
          .replaceAll(RegExp(r'\s+'), '');
      final normalized = base64Url.normalize(body);
      final decodedBytes =
          const GZipDecoder().decodeBytes(base64Url.decode(normalized));
      jsonString = utf8.decode(decodedBytes);
    } else {
      jsonString = trimmed;
    }

    final decoded = jsonDecode(jsonString);
    if (decoded is! Map) {
      throw const FormatException('Formato de código inválido.');
    }
    final map = Map<String, dynamic>.from(decoded);
    final List<RochyNotebook> incomingBooks;

    if (map.containsKey('notebooks') && map['notebooks'] is List) {
      incomingBooks = (map['notebooks'] as List<dynamic>)
          .map(
            (e) => RochyNotebook.fromJson(
              Map<String, dynamic>.from(e as Map<dynamic, dynamic>),
            ),
          )
          .toList(growable: false);
    } else if (map.containsKey('entity') && map.containsKey('nodes')) {
      incomingBooks = <RochyNotebook>[RochyNotebook.fromJson(map)];
    } else {
      throw const FormatException('No se encontraron cuadernos válidos.');
    }

    return mergeCoupleNotebooks(incomingBooks);
  }

  void importJsonSnapshot(String rawJson) {
    if (state.isActiveNotebookReadOnly) return;
    pauseAudio();
    final imported =
        ref.read(bentoRepositoryProvider).importJsonSnapshot(rawJson);
    final collision = state.notebooks.any(
      (b) =>
          b.entity.id == imported.entity.id &&
          b.entity.id != state.activeNotebookId,
    );
    final effectiveEntity = collision
        ? imported.entity.copyWith(
            id: 'entity_import_${DateTime.now().microsecondsSinceEpoch}',
          )
        : imported.entity;

    final updatedBooks = state.notebooks
        .map(
          (b) => b.entity.id == state.activeNotebookId
              ? RochyNotebook(entity: effectiveEntity, nodes: imported.nodes)
              : b,
        )
        .toList(growable: false);

    state = state.copyWith(
      notebooks: updatedBooks,
      activeNotebookId: effectiveEntity.id,
      clearSelectedNode: true,
      clearActiveWidget: true,
      isConnectingMode: false,
      clearActiveAudio: true,
      clearTagFilter: true,
      clearFocusedMapNode: true,
    );
    _persist();
  }

  void restorePortableBackup({
    required List<RochyNotebook> notebooks,
    required String activeNotebookId,
    bool? showPaperGrain,
    double? textScaleFactor,
    required bool mergeWithExisting,
    String partnerAAvatarUrl = '',
    String partnerBAvatarUrl = '',
    String partnerAName = '',
    String partnerBName = '',
    Set<String> deletedNodeIds = const <String>{},
  }) {
    if (notebooks.isEmpty) return;
    pauseAudio();

    late final List<RochyNotebook> nextBooks;
    late final String nextActiveId;

    if (mergeWithExisting) {
      final existingIds = state.notebooks.map((b) => b.entity.id).toSet();
      final appended = <RochyNotebook>[];
      final stamp = DateTime.now().microsecondsSinceEpoch;
      for (var i = 0; i < notebooks.length; i++) {
        final book = notebooks[i];
        var id = book.entity.id;
        if (existingIds.contains(id)) {
          id = '${id}_bkp_${stamp}_$i';
        }
        existingIds.add(id);
        appended.add(book.copyWith(entity: book.entity.copyWith(id: id)));
      }
      nextBooks = <RochyNotebook>[...state.notebooks, ...appended];
      nextActiveId = appended.first.entity.id;
    } else {
      nextBooks = List<RochyNotebook>.unmodifiable(notebooks);
      final hasMatch = nextBooks.any((b) => b.entity.id == activeNotebookId);
      nextActiveId = hasMatch ? activeNotebookId : nextBooks.first.entity.id;
    }

    state = state.copyWith(
      notebooks: nextBooks,
      activeNotebookId: nextActiveId,
      showPaperGrain: mergeWithExisting
          ? state.showPaperGrain
          : (showPaperGrain ?? state.showPaperGrain),
      textScaleFactor: mergeWithExisting
          ? state.textScaleFactor
          : (textScaleFactor?.clamp(0.92, 1.12) ?? state.textScaleFactor),
      partnerAAvatarUrl: !mergeWithExisting && partnerAAvatarUrl.isNotEmpty
          ? partnerAAvatarUrl
          : (state.partnerAAvatarUrl.isEmpty ? partnerAAvatarUrl : null),
      partnerBAvatarUrl: !mergeWithExisting && partnerBAvatarUrl.isNotEmpty
          ? partnerBAvatarUrl
          : (state.partnerBAvatarUrl.isEmpty ? partnerBAvatarUrl : null),
      partnerAName:
          !mergeWithExisting && partnerAName.isNotEmpty ? partnerAName : null,
      partnerBName:
          !mergeWithExisting && partnerBName.isNotEmpty ? partnerBName : null,
      deletedNodeIds: mergeWithExisting
          ? <String>{...state.deletedNodeIds, ...deletedNodeIds}
          : deletedNodeIds,
      clearSelectedNode: true,
      clearActiveWidget: true,
      isConnectingMode: false,
      clearActiveAudio: true,
      clearTagFilter: true,
      clearFocusedMapNode: true,
    );
    _persist();
    _scheduleAutoCloudSync();
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
    final now = DateTime.now();
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
          updatedAt: now,
          payload: payload.copyWith(
            isLoved: nextLoved,
            loveCount: nextCount,
          ),
        );
      }).toList(growable: false);
      return b.copyWith(nodes: updatedNodes);
    });
  }

  void toggleCheckListItem(String nodeId, String itemId, {int? index}) {
    final now = DateTime.now();
    _replaceActiveNotebook((b) {
      final updatedNodes = b.nodes.map((node) {
        if (node.id != nodeId) return node;
        final payload = node.payload;
        if (payload is! CheckListPayload) return node;

        final hasValidIndex = index != null &&
            index >= 0 &&
            index < payload.items.length &&
            payload.items[index].id == itemId;

        final updatedItems = List<CheckListItem>.generate(
          payload.items.length,
          (i) {
            final item = payload.items[i];
            final match = hasValidIndex ? i == index : item.id == itemId;
            return match
                ? item.copyWith(isHighlighted: !item.isHighlighted)
                : item;
          },
        );
        return node.copyWith(
          updatedAt: now,
          payload: payload.copyWith(items: updatedItems),
        );
      }).toList(growable: false);
      return b.copyWith(nodes: updatedNodes);
    });
  }

  void toggleGiftWishItem(String nodeId, String itemId, {int? index}) {
    final now = DateTime.now();
    _replaceActiveNotebook((b) {
      final updatedNodes = b.nodes.map((node) {
        if (node.id != nodeId) return node;
        final payload = node.payload;
        if (payload is! GiftWishPayload) return node;

        final hasValidIndex = index != null &&
            index >= 0 &&
            index < payload.items.length &&
            payload.items[index].id == itemId;

        final updatedItems = List<CheckListItem>.generate(
          payload.items.length,
          (i) {
            final item = payload.items[i];
            final match = hasValidIndex ? i == index : item.id == itemId;
            return match
                ? item.copyWith(isHighlighted: !item.isHighlighted)
                : item;
          },
        );
        return node.copyWith(
          updatedAt: now,
          payload: payload.copyWith(items: updatedItems),
        );
      }).toList(growable: false);
      return b.copyWith(nodes: updatedNodes);
    });
  }

  void togglePlanRedeemed(String nodeId) {
    final now = DateTime.now();
    _replaceActiveNotebook((b) {
      final updatedNodes = b.nodes.map((node) {
        if (node.id != nodeId) return node;
        final payload = node.payload;
        if (payload is! PlanTicketPayload) return node;
        return node.copyWith(
          updatedAt: now,
          payload: payload.copyWith(isRedeemed: !payload.isRedeemed),
        );
      }).toList(growable: false);
      return b.copyWith(nodes: updatedNodes);
    });
  }

  void toggleWardrobeGifted(String nodeId, int itemIndex) {
    final now = DateTime.now();
    _replaceActiveNotebook((b) {
      final updatedNodes = b.nodes.map((node) {
        if (node.id != nodeId) return node;
        final payload = node.payload;
        if (payload is! WardrobeClosetPayload) return node;
        if (itemIndex < 0 || itemIndex >= payload.items.length) return node;
        final updatedItems = List<WardrobeItem>.of(payload.items);
        updatedItems[itemIndex] = updatedItems[itemIndex].copyWith(
          gifted: !updatedItems[itemIndex].gifted,
        );
        return node.copyWith(
          updatedAt: now,
          payload: payload.copyWith(items: updatedItems),
        );
      }).toList(growable: false);
      return b.copyWith(nodes: updatedNodes);
    });
  }

  void cycleMoodEnergy(String nodeId) {
    final now = DateTime.now();
    _replaceActiveNotebook((b) {
      final updatedNodes = b.nodes.map((node) {
        if (node.id != nodeId) return node;
        final payload = node.payload;
        if (payload is! MoodPulsePayload) return node;
        final next = (payload.energyLevel % 5) + 1;
        return node.copyWith(
          updatedAt: now,
          payload: payload.copyWith(energyLevel: next),
        );
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
    final playableUrl = RochyProtectedMedia.isProtected(localPath) ||
        localPath.startsWith('https://') ||
        localPath.startsWith('http://') ||
        localPath.startsWith('data:') ||
        localPath.startsWith('blob:');
    if (localPath.isNotEmpty &&
        (playableUrl || (!kIsWeb && File(localPath).existsSync()))) {
      final startedReal =
          await _playRealAudioFile(nodeId, localPath, startProgress);
      if (startedReal) return;
    }

    _loadedAudioNodeId = null;
    try {
      unawaited(_audioPlayer?.pause());
    } on MissingPluginException {
      // Ignorado en entornos sin canal de plataforma.
    } catch (_) {}
    _stopTicker();
    state = state.copyWith(isAudioPlaying: false);
  }

  Future<bool> _playRealAudioFile(
    String nodeId,
    String path,
    double startProgress,
  ) async {
    try {
      _stopTicker();
      _audioPlayer ??= AudioPlayer();
      await _positionSub?.cancel();

      var playbackPath = path;
      var headers = <String, String>{};
      if (RochyProtectedMedia.isProtected(path)) {
        final media = await ref
            .read(rochyProtectedMediaProvider)
            .playback(path, state.cloudConfig);
        _audioPlayback?.release();
        _audioPlayback = media;
        playbackPath = media.url;
        headers = media.headers;
      }
      final uri = Uri.tryParse(playbackPath);
      final duration =
          uri != null && ['http', 'https', 'data', 'blob'].contains(uri.scheme)
              ? await _audioPlayer!.setUrl(playbackPath, headers: headers)
              : await _audioPlayer!.setFilePath(playbackPath);
      final totalMs = duration?.inMilliseconds ?? 1;
      if (startProgress > 0 && duration != null) {
        await _audioPlayer!.seek(
          Duration(milliseconds: (totalMs * startProgress).round()),
        );
      }
      _loadedAudioNodeId = nodeId;

      _positionSub = _audioPlayer!.positionStream.listen((pos) {
        if (!state.isAudioPlaying || state.activeAudioNodeId != nodeId) return;
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
      _loadedAudioNodeId = null;
      return false;
    } catch (_) {
      _loadedAudioNodeId = null;
      return false;
    }
  }

  void seekAudio(String nodeId, double progress, {int durationSeconds = 24}) {
    final clamped = progress.clamp(0.0, 1.0);
    if (state.activeAudioNodeId != nodeId) {
      _stopTicker();
      if (_loadedAudioNodeId != null) {
        _loadedAudioNodeId = null;
        try {
          unawaited(_audioPlayer?.pause());
        } on MissingPluginException {
          // Ignorado en entornos sin canal de plataforma.
        } catch (_) {}
      }
      state = state.copyWith(
        activeAudioNodeId: nodeId,
        isAudioPlaying: false,
        audioProgress: clamped,
      );
      return;
    }

    state = state.copyWith(
      activeAudioNodeId: nodeId,
      audioProgress: clamped,
    );
    final player = _audioPlayer;
    if (_loadedAudioNodeId == nodeId &&
        player != null &&
        player.duration != null) {
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
