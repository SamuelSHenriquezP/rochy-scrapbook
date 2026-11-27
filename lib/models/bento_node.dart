import '../services/map_links.dart';
import 'package:flutter/foundation.dart';

part 'keepsake_payloads.dart';

/// Tipos polimórficos de módulos soportados dentro del grafo relacional de Rochy.
enum BentoNodeType {
  photoHero,
  videoMemory,
  flipDetail,
  quote,
  audioNote,
  checkList,
  locationPin,
  countdown,
  paletteMood,
  bookMovie,
  giftWish,
  loveLetter,
  habitChips,
  photoStrip,
  moodPulse,
  cravingRecipe,
  planTicket,
  sketchDoodle,
  polaroidThread,
  travelPassport,
  savedChat,
  vintageTicket,
  aboutHer,
  wardrobeCloset,
  coupleQuestion;

  static BentoNodeType fromWire(String raw) {
    return BentoNodeType.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => BentoNodeType.quote,
    );
  }

  String get displayName => switch (this) {
        BentoNodeType.photoHero => 'Foto con Historia',
        BentoNodeType.videoMemory => 'Video en Vivo',
        BentoNodeType.flipDetail => 'Ritual 3D (Doble Cara)',
        BentoNodeType.quote => 'Cita o Texto Libre',
        BentoNodeType.audioNote => 'Canción o Audio',
        BentoNodeType.checkList => 'Lista Íntima',
        BentoNodeType.locationPin => 'Lugar o Polaroid',
        BentoNodeType.countdown => 'Fecha Especial',
        BentoNodeType.paletteMood => 'Paleta & Esencia',
        BentoNodeType.bookMovie => 'Libro o Película',
        BentoNodeType.giftWish => 'Deseos & Regalos',
        BentoNodeType.loveLetter => 'Carta con Lacre',
        BentoNodeType.habitChips => 'Manías & Hábitos',
        BentoNodeType.photoStrip => 'Carrete de Fotos',
        BentoNodeType.moodPulse => 'Ánimo & Clima',
        BentoNodeType.cravingRecipe => 'Antojo o Receta',
        BentoNodeType.planTicket => 'Plan / Promesa',
        BentoNodeType.sketchDoodle => 'Boceto a Mano',
        BentoNodeType.polaroidThread => 'Hilo de Polaroids',
        BentoNodeType.travelPassport => 'Pasaporte de Sellos',
        BentoNodeType.savedChat => 'Chat Guardado',
        BentoNodeType.vintageTicket => 'Ticket Vintage',
        BentoNodeType.aboutHer => 'Ella es… (Rasgos)',
        BentoNodeType.wardrobeCloset => 'Clóset & Tallas',
        BentoNodeType.coupleQuestion => 'Pregunta para los dos',
      };

  String displayNameFor({required bool aboutHim}) => switch (this) {
        BentoNodeType.aboutHer =>
          aboutHim ? 'Él es… (Rasgos)' : 'Ella es… (Rasgos)',
        _ => displayName,
      };

  String get shortDescription => switch (this) {
        BentoNodeType.photoHero =>
          'Fotografía inmersiva con crónica expandible',
        BentoNodeType.videoMemory =>
          'Clip de galería o URL con marco cinematográfico',
        BentoNodeType.flipDetail =>
          'Tarjeta giratoria 3D con nota de voz atrás',
        BentoNodeType.quote =>
          'Frase con comillas o texto completo hablando de ella',
        BentoNodeType.audioNote => 'Canción o grabación real con onda animada',
        BentoNodeType.checkList => 'Detalles cotidianos que amas recordar',
        BentoNodeType.locationPin =>
          'Píldora de 5 estrellas o Polaroid inclinada',
        BentoNodeType.countdown =>
          'Contador de aniversario, cumple o encuentro',
        BentoNodeType.paletteMood => 'Sus colores, aromas y vibra sensorial',
        BentoNodeType.bookMovie => 'Obra favorita con reseña personal',
        BentoNodeType.giftWish => 'Ideas de regalos, flores o planes juntos',
        BentoNodeType.loveLetter => 'Nota breve sellada que se abre al tocar',
        BentoNodeType.habitChips => 'Nube de pequeños hábitos y gestos suyos',
        BentoNodeType.photoStrip =>
          'Mini-álbum o tira collage de hasta 4 fotos',
        BentoNodeType.moodPulse =>
          'Cómo estuvo hoy con ícono y nivel de energía',
        BentoNodeType.cravingRecipe => 'Bebida, plato o pedido exacto favorito',
        BentoNodeType.planTicket =>
          'Boleto canjeable con fecha y lugar en el mapa',
        BentoNodeType.sketchDoodle => 'Dibujo rápido o firma hecha con el dedo',
        BentoNodeType.polaroidThread =>
          'Polaroids unidas con hilo que cambian de forma',
        BentoNodeType.travelPassport =>
          'Sellos de tinta con lugar, fecha e ícono de cada viaje',
        BentoNodeType.savedChat => 'De dos a cuatro mensajes con nombre y hora',
        BentoNodeType.vintageTicket =>
          'Recibo o entrada con fecha, estrellas y nota al pie',
        BentoNodeType.aboutHer =>
          'Frases tipo "Ella es", "Ella tiene", "Ella ama"',
        BentoNodeType.wardrobeCloset =>
          'Outfits y prendas tipo polaroid con tallas automáticas',
        BentoNodeType.coupleQuestion =>
          'Se revela cuando ambos escriben su respuesta',
      };

  String shortDescriptionFor({required bool aboutHim}) => switch (this) {
        BentoNodeType.aboutHer => aboutHim
            ? 'Frases tipo "Él es", "Él tiene", "Él ama"'
            : 'Frases tipo "Ella es", "Ella tiene", "Ella ama"',
        BentoNodeType.quote => aboutHim
            ? 'Frase con comillas o texto completo hablando de él'
            : 'Frase con comillas o texto completo hablando de ella',
        _ => shortDescription,
      };
}

/// Paleta cromática orgánica asignable a cada tarjeta del cuaderno.
enum BentoColorTheme {
  ivory,
  sand,
  espresso,
  terracotta,
  sage,
  charcoal;

  static BentoColorTheme fromWire(String raw) {
    return BentoColorTheme.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => BentoColorTheme.ivory,
    );
  }

  String get label => switch (this) {
        BentoColorTheme.ivory => 'Marfil',
        BentoColorTheme.sand => 'Arena',
        BentoColorTheme.espresso => 'Café',
        BentoColorTheme.terracotta => 'Terracota',
        BentoColorTheme.sage => 'Salvia',
        BentoColorTheme.charcoal => 'Tostado',
      };
}

/// Estilo tipográfico seleccionable por tarjeta.
enum BentoFontStyle {
  editorialSerif,
  handwritten,
  cleanSans,
  monoTypewriter;

  static BentoFontStyle fromWire(String raw) {
    return BentoFontStyle.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => BentoFontStyle.editorialSerif,
    );
  }

  String get label => switch (this) {
        BentoFontStyle.editorialSerif => 'Serif',
        BentoFontStyle.handwritten => 'Manuscrita',
        BentoFontStyle.cleanSans => 'Moderna',
        BentoFontStyle.monoTypewriter => 'Máquina',
      };
}

/// Acabado visual y textura estructural de cada tarjeta Bento.
enum BentoCardDesign {
  editorial,
  outlined,
  softGlow,
  notebookRuled,
  glassTint;

  static BentoCardDesign fromWire(String raw) {
    return BentoCardDesign.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => BentoCardDesign.editorial,
    );
  }

  String get label => switch (this) {
        BentoCardDesign.editorial => 'Editorial',
        BentoCardDesign.outlined => 'Trazo fino',
        BentoCardDesign.softGlow => 'Halo cálido',
        BentoCardDesign.notebookRuled => 'Libreta',
        BentoCardDesign.glassTint => 'Cristal',
      };
}

/// Alineación tipográfica del contenido de la tarjeta.
enum BentoTextAlign {
  left,
  center,
  right;

  static BentoTextAlign fromWire(String raw) {
    return BentoTextAlign.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => BentoTextAlign.left,
    );
  }

  String get label => switch (this) {
        BentoTextAlign.left => 'Izquierda',
        BentoTextAlign.center => 'Centro',
        BentoTextAlign.right => 'Derecha',
      };
}

/// Visibilidad de un cuaderno respecto a la sala de pareja en la nube.
enum NotebookSharingMode {
  privateOnly,
  sharedEdit,
  sharedViewOnly;

  String get label => switch (this) {
        NotebookSharingMode.privateOnly => 'Privado',
        NotebookSharingMode.sharedEdit => 'Compartido',
        NotebookSharingMode.sharedViewOnly => 'Solo vista',
      };

  static NotebookSharingMode fromKey(
    String? raw, {
    bool fallbackCouple = false,
  }) {
    for (final value in NotebookSharingMode.values) {
      if (value.name == raw) return value;
    }
    return fallbackCouple
        ? NotebookSharingMode.sharedEdit
        : NotebookSharingMode.privateOnly;
  }
}

/// Sujeto central de cada cuaderno personal (Memory Graph Root).
@immutable
class BentoEntity {
  const BentoEntity({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.coverImageUrl,
    required this.shortBio,
    required this.birthDate,
    required this.anniversaryDate,
    this.activeThemeId = 'arena_calida',
    this.isCoupleShared = false,
    this.sharingMode = NotebookSharingMode.privateOnly,
    this.ownerAuthorId = '',
    this.updatedAt,
  });

  final String id;
  final String name;
  final String subtitle;
  final String coverImageUrl;
  final String shortBio;
  final DateTime birthDate;
  final DateTime anniversaryDate;
  final String activeThemeId;
  final bool isCoupleShared;
  final NotebookSharingMode sharingMode;
  final String ownerAuthorId;
  final DateTime? updatedAt;

  // An explicit private mode wins over legacy shared flags.
  bool get syncsToCloud => sharingMode != NotebookSharingMode.privateOnly;

  bool canManageFor(String viewerAuthor) =>
      ownerAuthorId.isNotEmpty && ownerAuthorId == viewerAuthor;

  bool canReadFor(String viewerAuthor) =>
      sharingMode != NotebookSharingMode.privateOnly ||
      canManageFor(viewerAuthor);

  bool isReadOnlyFor(String viewerAuthor) =>
      !canReadFor(viewerAuthor) ||
      (sharingMode == NotebookSharingMode.sharedViewOnly &&
          !canManageFor(viewerAuthor));

  BentoEntity copyWith({
    String? id,
    String? name,
    String? subtitle,
    String? coverImageUrl,
    String? shortBio,
    DateTime? birthDate,
    DateTime? anniversaryDate,
    String? activeThemeId,
    bool? isCoupleShared,
    NotebookSharingMode? sharingMode,
    String? ownerAuthorId,
    DateTime? updatedAt,
  }) {
    final nextMode = sharingMode ?? this.sharingMode;
    final nextCouple = isCoupleShared ??
        (sharingMode != null
            ? nextMode != NotebookSharingMode.privateOnly
            : this.isCoupleShared);
    return BentoEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      subtitle: subtitle ?? this.subtitle,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      shortBio: shortBio ?? this.shortBio,
      birthDate: birthDate ?? this.birthDate,
      anniversaryDate: anniversaryDate ?? this.anniversaryDate,
      activeThemeId: activeThemeId ?? this.activeThemeId,
      isCoupleShared: nextCouple,
      sharingMode: nextMode,
      ownerAuthorId: ownerAuthorId ?? this.ownerAuthorId,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'subtitle': subtitle,
      'coverImageUrl': coverImageUrl,
      'shortBio': shortBio,
      'birthDate': birthDate.toIso8601String(),
      'anniversaryDate': anniversaryDate.toIso8601String(),
      'activeThemeId': activeThemeId,
      'isCoupleShared': syncsToCloud,
      'sharingMode': sharingMode.name,
      'ownerAuthorId': ownerAuthorId,
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory BentoEntity.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    final fallbackCouple =
        json['isCoupleShared'] as bool? ?? (id == 'entity_nosotros');
    final mode = NotebookSharingMode.fromKey(
      json['sharingMode'] as String?,
      fallbackCouple: fallbackCouple,
    );
    return BentoEntity(
      id: id,
      name: json['name'] as String,
      subtitle: json['subtitle'] as String? ?? '',
      coverImageUrl: json['coverImageUrl'] as String? ?? '',
      shortBio: json['shortBio'] as String? ?? '',
      birthDate: DateTime.parse(json['birthDate'] as String),
      anniversaryDate: DateTime.parse(json['anniversaryDate'] as String),
      activeThemeId: json['activeThemeId'] as String? ?? 'arena_calida',
      isCoupleShared: mode != NotebookSharingMode.privateOnly,
      sharingMode: mode,
      ownerAuthorId: (json['ownerAuthorId'] as String? ?? '').trim(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
    );
  }
}

/// Cuaderno completo asociado a una persona (entidad + lista de módulos).
@immutable
class RochyNotebook {
  const RochyNotebook({
    required this.entity,
    required this.nodes,
  });

  final BentoEntity entity;
  final List<BentoNode> nodes;

  RochyNotebook copyWith({
    BentoEntity? entity,
    List<BentoNode>? nodes,
  }) {
    return RochyNotebook(
      entity: entity ?? this.entity,
      nodes: nodes ?? this.nodes,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'entity': entity.toJson(),
        'nodes': nodes.map((n) => n.toJson()).toList(),
      };

  factory RochyNotebook.fromJson(Map<String, dynamic> json) {
    return RochyNotebook(
      entity: BentoEntity.fromJson(
        Map<String, dynamic>.from(json['entity'] as Map<dynamic, dynamic>),
      ),
      nodes: (json['nodes'] as List<dynamic>)
          .map(
            (e) => BentoNode.fromJson(
              Map<String, dynamic>.from(e as Map<dynamic, dynamic>),
            ),
          )
          .toList(),
    );
  }
}

/// Nodo polimórfico dentro del lienzo Bento Scrapbook y su grafo relacional.
@immutable
class BentoNode {
  const BentoNode({
    required this.id,
    required this.type,
    required this.colSpan,
    required this.rowSpan,
    required this.colorTheme,
    required this.linkedNodeIds,
    required this.tags,
    required this.payload,
    required this.createdAt,
    this.fontStyle = BentoFontStyle.editorialSerif,
    this.cardDesign = BentoCardDesign.editorial,
    this.textAlign = BentoTextAlign.left,
    this.customBgColorHex,
    this.customTextColorHex,
    this.useGradient = false,
    this.borderRadius = 24.0,
    this.titleScale = 1.0,
    this.isTitleBold = true,
    this.isFavorite = false,
    this.authorId = '',
    this.isSurprise = false,
    this.surpriseUnlockAt,
    this.partnerReplyText = '',
    this.partnerReplyAuthor = '',
    this.updatedAt,
  })  : assert(colSpan >= 1 && colSpan <= 2, 'colSpan debe ser 1 o 2'),
        assert(
            rowSpan >= 1 && rowSpan <= 20, 'rowSpan debe estar entre 1 y 20');

  final String id;
  final BentoNodeType type;
  final int colSpan;
  final int rowSpan;
  final BentoColorTheme colorTheme;
  final BentoFontStyle fontStyle;
  final BentoCardDesign cardDesign;
  final BentoTextAlign textAlign;

  /// Color personalizado opcional (ARGB int) que anula el tema predefinido.
  final int? customBgColorHex;
  final int? customTextColorHex;
  final bool useGradient;
  final double borderRadius;
  final double titleScale;
  final bool isTitleBold;
  final bool isFavorite;
  final String authorId;
  final bool isSurprise;
  final DateTime? surpriseUnlockAt;
  final String partnerReplyText;
  final String partnerReplyAuthor;
  final DateTime? updatedAt;

  final List<String> linkedNodeIds;
  final List<String> tags;
  final BentoPayload payload;
  final DateTime createdAt;

  DateTime get effectiveUpdatedAt => updatedAt ?? createdAt;

  bool get isSurpriseCurrentlyLocked {
    if (!isSurprise) return false;
    final unlock = surpriseUnlockAt;
    if (unlock == null) return true;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(unlock.year, unlock.month, unlock.day);
    return today.isBefore(target);
  }

  int? get daysUntilSurpriseUnlock {
    final unlock = surpriseUnlockAt;
    if (unlock == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(unlock.year, unlock.month, unlock.day);
    final diff = target.difference(today).inDays;
    return diff > 0 ? diff : 0;
  }

  /// Título legible para barras de contexto, explorador y grafo relacional.
  String get displayTitle => switch (payload) {
        final TravelPassportPayload p => p.title,
        final SavedChatPayload p => p.title,
        final VintageTicketPayload p => p.title,
        final PhotoHeroPayload p => p.title,
        final VideoMemoryPayload p => p.title,
        final FlipDetailPayload p => p.title,
        final QuotePayload p => 'Cita · "${p.quoteText}"',
        final AudioNotePayload p => p.title,
        final CheckListPayload p => p.title,
        final LocationPinPayload p => p.placeName,
        final CountdownPayload p => p.title,
        final PaletteMoodPayload p => p.title,
        final BookMoviePayload p => p.title,
        final GiftWishPayload p => p.title,
        final LoveLetterPayload p => p.title,
        final HabitChipsPayload p => p.title,
        final PhotoStripPayload p => p.title,
        final MoodPulsePayload p => p.title,
        final CravingRecipePayload p => p.title,
        final PlanTicketPayload p => p.title,
        final SketchDoodlePayload p =>
          p.title.isNotEmpty ? p.title : 'Boceto a mano',
        final PolaroidThreadPayload p =>
          p.title.isNotEmpty ? p.title : 'Hilo de polaroids',
        final AboutHerPayload p => p.title.isNotEmpty
            ? p.title
            : (authorId == 'rochy' ||
                    p.entries.any(
                      (e) =>
                          e.prefix.trim().toLowerCase().startsWith('él') ||
                          e.prefix.trim().toLowerCase().startsWith('el '),
                    )
                ? 'Sobre él'
                : 'Sobre ella'),
        final WardrobeClosetPayload p =>
          p.title.isNotEmpty ? p.title : 'Su Clóset',
        final CoupleQuestionPayload p =>
          p.question.isNotEmpty ? p.question : 'Pregunta para los dos',
      };

  /// Coordenadas reales si el nodo representa un rincón o memoria geolocalizada.
  ({double lat, double lng})? get mapCoordinates => switch (payload) {
        final LocationPinPayload p
            when isValidMapPoint(p.latitude, p.longitude) =>
          (lat: p.latitude!, lng: p.longitude!),
        final PhotoHeroPayload p
            when isValidMapPoint(p.latitude, p.longitude) =>
          (lat: p.latitude!, lng: p.longitude!),
        final VideoMemoryPayload p
            when isValidMapPoint(p.latitude, p.longitude) =>
          (lat: p.latitude!, lng: p.longitude!),
        final PlanTicketPayload p
            when isValidMapPoint(p.latitude, p.longitude) =>
          (lat: p.latitude!, lng: p.longitude!),
        _ => null,
      };

  /// Nombre corto del lugar asociado al nodo para marcadores del mapa.
  String get mapPlaceTitle => switch (payload) {
        final LocationPinPayload p => p.placeName,
        final PhotoHeroPayload p =>
          p.locationLabel.isNotEmpty ? p.locationLabel : p.title,
        final VideoMemoryPayload p =>
          p.locationLabel.isNotEmpty ? p.locationLabel : p.title,
        final PlanTicketPayload p =>
          p.placeLabel.isNotEmpty ? p.placeLabel : p.title,
        _ => displayTitle,
      };

  /// Nota o descripción breve para mostrar al seleccionar el pin en el mapa.
  String get mapDescription => switch (payload) {
        final LocationPinPayload p =>
          p.memoryNote.isNotEmpty ? p.memoryNote : p.caption,
        final PhotoHeroPayload p =>
          p.storyBody.isNotEmpty ? p.storyBody : p.title,
        final VideoMemoryPayload p =>
          p.caption.isNotEmpty ? p.caption : p.title,
        final PlanTicketPayload p =>
          p.promiseNote.isNotEmpty ? p.promiseNote : p.whenLabel,
        _ => '',
      };

  /// Imagen de portada opcional del recuerdo en el mapa.
  String get mapCoverImage => switch (payload) {
        final LocationPinPayload p => p.imageUrl,
        final PhotoHeroPayload p => p.imageUrl,
        final VideoMemoryPayload p => p.thumbnailUrl,
        _ => '',
      };

  BentoNode copyWith({
    String? id,
    BentoNodeType? type,
    int? colSpan,
    int? rowSpan,
    BentoColorTheme? colorTheme,
    BentoFontStyle? fontStyle,
    BentoCardDesign? cardDesign,
    BentoTextAlign? textAlign,
    int? customBgColorHex,
    bool clearCustomBgColor = false,
    int? customTextColorHex,
    bool clearCustomTextColor = false,
    bool? useGradient,
    double? borderRadius,
    double? titleScale,
    bool? isTitleBold,
    bool? isFavorite,
    String? authorId,
    bool? isSurprise,
    DateTime? surpriseUnlockAt,
    bool clearSurpriseUnlockAt = false,
    String? partnerReplyText,
    String? partnerReplyAuthor,
    DateTime? updatedAt,
    List<String>? linkedNodeIds,
    List<String>? tags,
    BentoPayload? payload,
    DateTime? createdAt,
  }) {
    return BentoNode(
      id: id ?? this.id,
      type: type ?? this.type,
      colSpan: colSpan ?? this.colSpan,
      rowSpan: rowSpan ?? this.rowSpan,
      colorTheme: colorTheme ?? this.colorTheme,
      fontStyle: fontStyle ?? this.fontStyle,
      cardDesign: cardDesign ?? this.cardDesign,
      textAlign: textAlign ?? this.textAlign,
      customBgColorHex: clearCustomBgColor
          ? null
          : (customBgColorHex ?? this.customBgColorHex),
      customTextColorHex: clearCustomTextColor
          ? null
          : (customTextColorHex ?? this.customTextColorHex),
      useGradient: useGradient ?? this.useGradient,
      borderRadius: borderRadius ?? this.borderRadius,
      titleScale: titleScale ?? this.titleScale,
      isTitleBold: isTitleBold ?? this.isTitleBold,
      isFavorite: isFavorite ?? this.isFavorite,
      authorId: authorId ?? this.authorId,
      isSurprise: isSurprise ?? this.isSurprise,
      surpriseUnlockAt: clearSurpriseUnlockAt
          ? null
          : (surpriseUnlockAt ?? this.surpriseUnlockAt),
      partnerReplyText: partnerReplyText ?? this.partnerReplyText,
      partnerReplyAuthor: partnerReplyAuthor ?? this.partnerReplyAuthor,
      updatedAt: updatedAt ?? this.updatedAt,
      linkedNodeIds: linkedNodeIds ?? this.linkedNodeIds,
      tags: tags ?? this.tags,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'type': type.name,
      'colSpan': colSpan,
      'rowSpan': rowSpan,
      'colorTheme': colorTheme.name,
      'fontStyle': fontStyle.name,
      'cardDesign': cardDesign.name,
      'textAlign': textAlign.name,
      'customBgColorHex': customBgColorHex,
      'customTextColorHex': customTextColorHex,
      'useGradient': useGradient,
      'borderRadius': borderRadius,
      'titleScale': titleScale,
      'isTitleBold': isTitleBold,
      'isFavorite': isFavorite,
      'authorId': authorId,
      'isSurprise': isSurprise,
      'surpriseUnlockAt': surpriseUnlockAt?.toIso8601String(),
      'partnerReplyText': partnerReplyText,
      'partnerReplyAuthor': partnerReplyAuthor,
      'updatedAt': (updatedAt ?? createdAt).toIso8601String(),
      'linkedNodeIds': linkedNodeIds,
      'tags': tags,
      'createdAt': createdAt.toIso8601String(),
      'payload': payload.toJson(),
    };
  }

  factory BentoNode.fromJson(Map<String, dynamic> json) {
    final type = BentoNodeType.fromWire(json['type'] as String);
    final payloadMap =
        Map<String, dynamic>.from(json['payload'] as Map<dynamic, dynamic>);

    return BentoNode(
      id: json['id'] as String,
      type: type,
      colSpan: (json['colSpan'] as num).toInt().clamp(1, 2),
      rowSpan: (json['rowSpan'] as num).toInt().clamp(1, 20),
      colorTheme: BentoColorTheme.fromWire(json['colorTheme'] as String),
      fontStyle: BentoFontStyle.fromWire(
        json['fontStyle'] as String? ?? 'editorialSerif',
      ),
      cardDesign: BentoCardDesign.fromWire(
        json['cardDesign'] as String? ?? 'editorial',
      ),
      textAlign: BentoTextAlign.fromWire(
        json['textAlign'] as String? ?? 'left',
      ),
      customBgColorHex: (json['customBgColorHex'] as num?)?.toInt(),
      customTextColorHex: (json['customTextColorHex'] as num?)?.toInt(),
      useGradient: json['useGradient'] as bool? ?? false,
      borderRadius: (json['borderRadius'] as num?)?.toDouble() ?? 24.0,
      titleScale: (json['titleScale'] as num?)?.toDouble() ?? 1.0,
      isTitleBold: json['isTitleBold'] as bool? ?? true,
      isFavorite: json['isFavorite'] as bool? ?? false,
      authorId: json['authorId'] as String? ?? '',
      isSurprise: json['isSurprise'] as bool? ?? false,
      surpriseUnlockAt: json['surpriseUnlockAt'] != null
          ? DateTime.tryParse(json['surpriseUnlockAt'] as String)
          : null,
      partnerReplyText: json['partnerReplyText'] as String? ?? '',
      partnerReplyAuthor: json['partnerReplyAuthor'] as String? ?? '',
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
      linkedNodeIds: List<String>.from(json['linkedNodeIds'] as List<dynamic>),
      tags: List<String>.from(json['tags'] as List<dynamic>),
      createdAt: DateTime.parse(json['createdAt'] as String),
      payload: BentoPayload.fromJson(type, payloadMap),
    );
  }
}

/// Unión sellada tipada para los datos específicos de cada módulo Bento.
@immutable
sealed class BentoPayload {
  const BentoPayload();

  Map<String, dynamic> toJson();

  factory BentoPayload.fromJson(
    BentoNodeType type,
    Map<String, dynamic> json,
  ) {
    return switch (type) {
      BentoNodeType.travelPassport => TravelPassportPayload.fromJson(json),
      BentoNodeType.savedChat => SavedChatPayload.fromJson(json),
      BentoNodeType.vintageTicket => VintageTicketPayload.fromJson(json),
      BentoNodeType.photoHero => PhotoHeroPayload.fromJson(json),
      BentoNodeType.videoMemory => VideoMemoryPayload.fromJson(json),
      BentoNodeType.flipDetail => FlipDetailPayload.fromJson(json),
      BentoNodeType.quote => QuotePayload.fromJson(json),
      BentoNodeType.audioNote => AudioNotePayload.fromJson(json),
      BentoNodeType.checkList => CheckListPayload.fromJson(json),
      BentoNodeType.locationPin => LocationPinPayload.fromJson(json),
      BentoNodeType.countdown => CountdownPayload.fromJson(json),
      BentoNodeType.paletteMood => PaletteMoodPayload.fromJson(json),
      BentoNodeType.bookMovie => BookMoviePayload.fromJson(json),
      BentoNodeType.giftWish => GiftWishPayload.fromJson(json),
      BentoNodeType.loveLetter => LoveLetterPayload.fromJson(json),
      BentoNodeType.habitChips => HabitChipsPayload.fromJson(json),
      BentoNodeType.photoStrip => PhotoStripPayload.fromJson(json),
      BentoNodeType.moodPulse => MoodPulsePayload.fromJson(json),
      BentoNodeType.cravingRecipe => CravingRecipePayload.fromJson(json),
      BentoNodeType.planTicket => PlanTicketPayload.fromJson(json),
      BentoNodeType.sketchDoodle => SketchDoodlePayload.fromJson(json),
      BentoNodeType.polaroidThread => PolaroidThreadPayload.fromJson(json),
      BentoNodeType.aboutHer => AboutHerPayload.fromJson(json),
      BentoNodeType.wardrobeCloset => WardrobeClosetPayload.fromJson(json),
      BentoNodeType.coupleQuestion => CoupleQuestionPayload.fromJson(json),
    };
  }
}

@immutable
class PhotoHeroPayload extends BentoPayload {
  const PhotoHeroPayload({
    required this.imageUrl,
    required this.title,
    required this.dateLabel,
    required this.locationLabel,
    required this.storyBody,
    this.photographerNote = '',
    this.latitude,
    this.longitude,
  });

  final String imageUrl;
  final String title;
  final String dateLabel;
  final String locationLabel;
  final String storyBody;
  final String photographerNote;
  final double? latitude;
  final double? longitude;

  PhotoHeroPayload copyWith({
    String? imageUrl,
    String? title,
    String? dateLabel,
    String? locationLabel,
    String? storyBody,
    String? photographerNote,
    double? latitude,
    double? longitude,
    bool clearCoordinates = false,
  }) {
    return PhotoHeroPayload(
      imageUrl: imageUrl ?? this.imageUrl,
      title: title ?? this.title,
      dateLabel: dateLabel ?? this.dateLabel,
      locationLabel: locationLabel ?? this.locationLabel,
      storyBody: storyBody ?? this.storyBody,
      photographerNote: photographerNote ?? this.photographerNote,
      latitude: clearCoordinates ? null : (latitude ?? this.latitude),
      longitude: clearCoordinates ? null : (longitude ?? this.longitude),
    );
  }

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'imageUrl': imageUrl,
        'title': title,
        'dateLabel': dateLabel,
        'locationLabel': locationLabel,
        'storyBody': storyBody,
        'photographerNote': photographerNote,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      };

  factory PhotoHeroPayload.fromJson(Map<String, dynamic> json) {
    return PhotoHeroPayload(
      imageUrl: json['imageUrl'] as String? ?? '',
      title: json['title'] as String,
      dateLabel: json['dateLabel'] as String? ?? '',
      locationLabel: json['locationLabel'] as String? ?? '',
      storyBody: json['storyBody'] as String? ?? '',
      photographerNote: json['photographerNote'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }
}

@immutable
class VideoMemoryPayload extends BentoPayload {
  const VideoMemoryPayload({
    required this.title,
    required this.videoSource,
    required this.dateLabel,
    required this.locationLabel,
    this.caption = '',
    this.thumbnailUrl = '',
    this.durationSeconds = 12,
    this.autoPlayMuted = true,
    this.latitude,
    this.longitude,
  });

  final String title;
  final String videoSource;
  final String dateLabel;
  final String locationLabel;
  final String caption;
  final String thumbnailUrl;
  final int durationSeconds;
  final bool autoPlayMuted;
  final double? latitude;
  final double? longitude;

  VideoMemoryPayload copyWith({
    String? title,
    String? videoSource,
    String? dateLabel,
    String? locationLabel,
    String? caption,
    String? thumbnailUrl,
    int? durationSeconds,
    bool? autoPlayMuted,
    double? latitude,
    double? longitude,
    bool clearCoordinates = false,
  }) {
    return VideoMemoryPayload(
      title: title ?? this.title,
      videoSource: videoSource ?? this.videoSource,
      dateLabel: dateLabel ?? this.dateLabel,
      locationLabel: locationLabel ?? this.locationLabel,
      caption: caption ?? this.caption,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      autoPlayMuted: autoPlayMuted ?? this.autoPlayMuted,
      latitude: clearCoordinates ? null : (latitude ?? this.latitude),
      longitude: clearCoordinates ? null : (longitude ?? this.longitude),
    );
  }

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'title': title,
        'videoSource': videoSource,
        'dateLabel': dateLabel,
        'locationLabel': locationLabel,
        'caption': caption,
        'thumbnailUrl': thumbnailUrl,
        'durationSeconds': durationSeconds,
        'autoPlayMuted': autoPlayMuted,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      };

  factory VideoMemoryPayload.fromJson(Map<String, dynamic> json) {
    return VideoMemoryPayload(
      title: json['title'] as String,
      videoSource: json['videoSource'] as String? ?? '',
      dateLabel: json['dateLabel'] as String? ?? '',
      locationLabel: json['locationLabel'] as String? ?? '',
      caption: json['caption'] as String? ?? '',
      thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 12,
      autoPlayMuted: json['autoPlayMuted'] as bool? ?? true,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }
}

@immutable
class FlipDetailPayload extends BentoPayload {
  const FlipDetailPayload({
    required this.title,
    required this.microText,
    required this.iconKey,
    required this.voiceNoteLabel,
    required this.recordedDateLabel,
    required this.durationSeconds,
    required this.waveformSamples,
    this.backSubtitle = '',
    this.localAudioPath = '',
  });

  final String title;
  final String microText;
  final String iconKey;
  final String voiceNoteLabel;
  final String recordedDateLabel;
  final int durationSeconds;
  final List<double> waveformSamples;
  final String backSubtitle;
  final String localAudioPath;

  FlipDetailPayload copyWith({
    String? title,
    String? microText,
    String? iconKey,
    String? voiceNoteLabel,
    String? recordedDateLabel,
    int? durationSeconds,
    List<double>? waveformSamples,
    String? backSubtitle,
    String? localAudioPath,
  }) {
    return FlipDetailPayload(
      title: title ?? this.title,
      microText: microText ?? this.microText,
      iconKey: iconKey ?? this.iconKey,
      voiceNoteLabel: voiceNoteLabel ?? this.voiceNoteLabel,
      recordedDateLabel: recordedDateLabel ?? this.recordedDateLabel,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      waveformSamples: waveformSamples ?? this.waveformSamples,
      backSubtitle: backSubtitle ?? this.backSubtitle,
      localAudioPath: localAudioPath ?? this.localAudioPath,
    );
  }

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'title': title,
        'microText': microText,
        'iconKey': iconKey,
        'voiceNoteLabel': voiceNoteLabel,
        'recordedDateLabel': recordedDateLabel,
        'durationSeconds': durationSeconds,
        'waveformSamples': waveformSamples,
        'backSubtitle': backSubtitle,
        'localAudioPath': localAudioPath,
      };

  factory FlipDetailPayload.fromJson(Map<String, dynamic> json) {
    return FlipDetailPayload(
      title: json['title'] as String,
      microText: json['microText'] as String,
      iconKey: json['iconKey'] as String? ?? 'coffee',
      voiceNoteLabel: json['voiceNoteLabel'] as String? ?? 'Nota de voz',
      recordedDateLabel: json['recordedDateLabel'] as String? ?? '',
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 18,
      waveformSamples: (json['waveformSamples'] as List<dynamic>? ??
              const <double>[0.3, 0.7, 0.5, 0.9, 0.4, 0.8])
          .map((e) => (e as num).toDouble())
          .toList(),
      backSubtitle: json['backSubtitle'] as String? ?? '',
      localAudioPath: json['localAudioPath'] as String? ?? '',
    );
  }
}

@immutable
class QuotePayload extends BentoPayload {
  const QuotePayload({
    required this.quoteText,
    required this.contextLabel,
    this.isLoved = false,
    this.loveCount = 1,
    this.isPlainText = false,
  });

  final String quoteText;
  final String contextLabel;
  final bool isLoved;
  final int loveCount;
  final bool isPlainText;

  QuotePayload copyWith({
    String? quoteText,
    String? contextLabel,
    bool? isLoved,
    int? loveCount,
    bool? isPlainText,
  }) {
    return QuotePayload(
      quoteText: quoteText ?? this.quoteText,
      contextLabel: contextLabel ?? this.contextLabel,
      isLoved: isLoved ?? this.isLoved,
      loveCount: loveCount ?? this.loveCount,
      isPlainText: isPlainText ?? this.isPlainText,
    );
  }

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'quoteText': quoteText,
        'contextLabel': contextLabel,
        'isLoved': isLoved,
        'loveCount': loveCount,
        'isPlainText': isPlainText,
      };

  factory QuotePayload.fromJson(Map<String, dynamic> json) {
    return QuotePayload(
      quoteText: json['quoteText'] as String,
      contextLabel: json['contextLabel'] as String? ?? '',
      isLoved: json['isLoved'] as bool? ?? false,
      loveCount: (json['loveCount'] as num?)?.toInt() ?? 1,
      isPlainText: json['isPlainText'] as bool? ?? false,
    );
  }
}

@immutable
class AudioNotePayload extends BentoPayload {
  const AudioNotePayload({
    required this.title,
    required this.subtitle,
    required this.coverImageUrl,
    required this.durationSeconds,
    required this.waveformSamples,
    this.recordedAtLabel = '',
    this.localAudioPath = '',
  });

  final String title;
  final String subtitle;
  final String coverImageUrl;
  final int durationSeconds;
  final List<double> waveformSamples;
  final String recordedAtLabel;
  final String localAudioPath;

  AudioNotePayload copyWith({
    String? title,
    String? subtitle,
    String? coverImageUrl,
    int? durationSeconds,
    List<double>? waveformSamples,
    String? recordedAtLabel,
    String? localAudioPath,
  }) {
    return AudioNotePayload(
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      waveformSamples: waveformSamples ?? this.waveformSamples,
      recordedAtLabel: recordedAtLabel ?? this.recordedAtLabel,
      localAudioPath: localAudioPath ?? this.localAudioPath,
    );
  }

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'title': title,
        'subtitle': subtitle,
        'coverImageUrl': coverImageUrl,
        'durationSeconds': durationSeconds,
        'waveformSamples': waveformSamples,
        'recordedAtLabel': recordedAtLabel,
        'localAudioPath': localAudioPath,
      };

  factory AudioNotePayload.fromJson(Map<String, dynamic> json) {
    return AudioNotePayload(
      title: json['title'] as String,
      subtitle: json['subtitle'] as String? ?? '',
      coverImageUrl: json['coverImageUrl'] as String? ?? '',
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 24,
      waveformSamples: (json['waveformSamples'] as List<dynamic>? ??
              const <double>[0.3, 0.6, 0.8, 0.5, 0.7])
          .map((e) => (e as num).toDouble())
          .toList(),
      recordedAtLabel: json['recordedAtLabel'] as String? ?? '',
      localAudioPath: json['localAudioPath'] as String? ?? '',
    );
  }
}

@immutable
class CheckListItem {
  const CheckListItem({
    required this.id,
    required this.text,
    this.isHighlighted = false,
  });

  final String id;
  final String text;
  final bool isHighlighted;

  CheckListItem copyWith({
    String? id,
    String? text,
    bool? isHighlighted,
  }) {
    return CheckListItem(
      id: id ?? this.id,
      text: text ?? this.text,
      isHighlighted: isHighlighted ?? this.isHighlighted,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'text': text,
        'isHighlighted': isHighlighted,
      };

  factory CheckListItem.fromJson(Map<String, dynamic> json) {
    return CheckListItem(
      id: json['id'] as String,
      text: json['text'] as String,
      isHighlighted: json['isHighlighted'] as bool? ?? false,
    );
  }
}

@immutable
class CheckListPayload extends BentoPayload {
  const CheckListPayload({
    required this.title,
    required this.items,
    this.footerHint = '',
  });

  final String title;
  final List<CheckListItem> items;
  final String footerHint;

  CheckListPayload copyWith({
    String? title,
    List<CheckListItem>? items,
    String? footerHint,
  }) {
    return CheckListPayload(
      title: title ?? this.title,
      items: items ?? this.items,
      footerHint: footerHint ?? this.footerHint,
    );
  }

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'title': title,
        'items': items.map((e) => e.toJson()).toList(),
        'footerHint': footerHint,
      };

  factory CheckListPayload.fromJson(Map<String, dynamic> json) {
    return CheckListPayload(
      title: json['title'] as String,
      items: (json['items'] as List<dynamic>)
          .map(
            (e) => CheckListItem.fromJson(
              Map<String, dynamic>.from(e as Map<dynamic, dynamic>),
            ),
          )
          .toList(),
      footerHint: json['footerHint'] as String? ?? '',
    );
  }
}

enum LocationPinStyle {
  constellationPill,
  polaroid;

  static LocationPinStyle fromWire(String raw) {
    return LocationPinStyle.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => LocationPinStyle.constellationPill,
    );
  }
}

@immutable
class LocationPinPayload extends BentoPayload {
  const LocationPinPayload({
    required this.placeName,
    required this.caption,
    required this.coordinatesLabel,
    required this.style,
    this.imageUrl = '',
    this.starCount = 5,
    this.tiltAngle = -0.04,
    this.memoryNote = '',
    this.latitude,
    this.longitude,
  });

  final String placeName;
  final String caption;
  final String coordinatesLabel;
  final LocationPinStyle style;
  final String imageUrl;
  final int starCount;
  final double tiltAngle;
  final String memoryNote;
  final double? latitude;
  final double? longitude;

  LocationPinPayload copyWith({
    String? placeName,
    String? caption,
    String? coordinatesLabel,
    LocationPinStyle? style,
    String? imageUrl,
    int? starCount,
    double? tiltAngle,
    String? memoryNote,
    double? latitude,
    double? longitude,
    bool clearCoordinates = false,
  }) {
    return LocationPinPayload(
      placeName: placeName ?? this.placeName,
      caption: caption ?? this.caption,
      coordinatesLabel: coordinatesLabel ?? this.coordinatesLabel,
      style: style ?? this.style,
      imageUrl: imageUrl ?? this.imageUrl,
      starCount: starCount ?? this.starCount,
      tiltAngle: tiltAngle ?? this.tiltAngle,
      memoryNote: memoryNote ?? this.memoryNote,
      latitude: clearCoordinates ? null : (latitude ?? this.latitude),
      longitude: clearCoordinates ? null : (longitude ?? this.longitude),
    );
  }

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'placeName': placeName,
        'caption': caption,
        'coordinatesLabel': coordinatesLabel,
        'style': style.name,
        'imageUrl': imageUrl,
        'starCount': starCount,
        'tiltAngle': tiltAngle,
        'memoryNote': memoryNote,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      };

  factory LocationPinPayload.fromJson(Map<String, dynamic> json) {
    return LocationPinPayload(
      placeName: json['placeName'] as String,
      caption: json['caption'] as String? ?? '',
      coordinatesLabel: json['coordinatesLabel'] as String? ?? '',
      style: LocationPinStyle.fromWire(json['style'] as String? ?? 'polaroid'),
      imageUrl: json['imageUrl'] as String? ?? '',
      starCount: (json['starCount'] as num?)?.toInt() ?? 5,
      tiltAngle: (json['tiltAngle'] as num?)?.toDouble() ?? -0.04,
      memoryNote: json['memoryNote'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }
}

@immutable
class CountdownPayload extends BentoPayload {
  const CountdownPayload({
    required this.title,
    required this.targetDate,
    required this.subtitle,
    this.countMode = 'since',
  });

  final String title;
  final DateTime targetDate;
  final String subtitle;
  final String countMode;

  CountdownPayload copyWith({
    String? title,
    DateTime? targetDate,
    String? subtitle,
    String? countMode,
  }) {
    return CountdownPayload(
      title: title ?? this.title,
      targetDate: targetDate ?? this.targetDate,
      subtitle: subtitle ?? this.subtitle,
      countMode: countMode ?? this.countMode,
    );
  }

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'title': title,
        'targetDate': targetDate.toIso8601String(),
        'subtitle': subtitle,
        'countMode': countMode,
      };

  factory CountdownPayload.fromJson(Map<String, dynamic> json) {
    return CountdownPayload(
      title: json['title'] as String,
      targetDate: DateTime.parse(json['targetDate'] as String),
      subtitle: json['subtitle'] as String? ?? '',
      countMode: json['countMode'] as String? ?? 'since',
    );
  }
}

@immutable
class PaletteMoodPayload extends BentoPayload {
  const PaletteMoodPayload({
    required this.title,
    required this.scentNote,
    required this.swatchHexes,
    required this.moodWords,
  });

  final String title;
  final String scentNote;
  final List<int> swatchHexes;
  final List<String> moodWords;

  PaletteMoodPayload copyWith({
    String? title,
    String? scentNote,
    List<int>? swatchHexes,
    List<String>? moodWords,
  }) {
    return PaletteMoodPayload(
      title: title ?? this.title,
      scentNote: scentNote ?? this.scentNote,
      swatchHexes: swatchHexes ?? this.swatchHexes,
      moodWords: moodWords ?? this.moodWords,
    );
  }

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'title': title,
        'scentNote': scentNote,
        'swatchHexes': swatchHexes,
        'moodWords': moodWords,
      };

  factory PaletteMoodPayload.fromJson(Map<String, dynamic> json) {
    return PaletteMoodPayload(
      title: json['title'] as String,
      scentNote: json['scentNote'] as String? ?? '',
      swatchHexes: (json['swatchHexes'] as List<dynamic>)
          .map((e) => (e as num).toInt())
          .toList(),
      moodWords: List<String>.from(json['moodWords'] as List<dynamic>),
    );
  }
}

@immutable
class BookMoviePayload extends BentoPayload {
  const BookMoviePayload({
    required this.title,
    required this.creator,
    required this.kind,
    required this.personalNote,
    this.rating = 5,
    this.imageUrl = '',
  });

  final String title;
  final String creator;
  final String kind;
  final String personalNote;
  final int rating;
  final String imageUrl;

  BookMoviePayload copyWith({
    String? title,
    String? creator,
    String? kind,
    String? personalNote,
    int? rating,
    String? imageUrl,
  }) {
    return BookMoviePayload(
      title: title ?? this.title,
      creator: creator ?? this.creator,
      kind: kind ?? this.kind,
      personalNote: personalNote ?? this.personalNote,
      rating: rating ?? this.rating,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'title': title,
        'creator': creator,
        'kind': kind,
        'personalNote': personalNote,
        'rating': rating,
        'imageUrl': imageUrl,
      };

  factory BookMoviePayload.fromJson(Map<String, dynamic> json) {
    return BookMoviePayload(
      title: json['title'] as String,
      creator: json['creator'] as String? ?? '',
      kind: json['kind'] as String? ?? 'book',
      personalNote: json['personalNote'] as String? ?? '',
      rating: (json['rating'] as num?)?.toInt() ?? 5,
      imageUrl: json['imageUrl'] as String? ?? '',
    );
  }
}

@immutable
class GiftWishPayload extends BentoPayload {
  const GiftWishPayload({
    required this.title,
    required this.items,
  });

  final String title;
  final List<CheckListItem> items;

  GiftWishPayload copyWith({
    String? title,
    List<CheckListItem>? items,
  }) {
    return GiftWishPayload(
      title: title ?? this.title,
      items: items ?? this.items,
    );
  }

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'title': title,
        'items': items.map((e) => e.toJson()).toList(),
      };

  factory GiftWishPayload.fromJson(Map<String, dynamic> json) {
    return GiftWishPayload(
      title: json['title'] as String,
      items: (json['items'] as List<dynamic>)
          .map(
            (e) => CheckListItem.fromJson(
              Map<String, dynamic>.from(e as Map<dynamic, dynamic>),
            ),
          )
          .toList(),
    );
  }
}

@immutable
class LoveLetterPayload extends BentoPayload {
  const LoveLetterPayload({
    required this.title,
    required this.previewLine,
    required this.letterBody,
    required this.signature,
  });

  final String title;
  final String previewLine;
  final String letterBody;
  final String signature;

  LoveLetterPayload copyWith({
    String? title,
    String? previewLine,
    String? letterBody,
    String? signature,
  }) {
    return LoveLetterPayload(
      title: title ?? this.title,
      previewLine: previewLine ?? this.previewLine,
      letterBody: letterBody ?? this.letterBody,
      signature: signature ?? this.signature,
    );
  }

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'title': title,
        'previewLine': previewLine,
        'letterBody': letterBody,
        'signature': signature,
      };

  factory LoveLetterPayload.fromJson(Map<String, dynamic> json) {
    return LoveLetterPayload(
      title: json['title'] as String,
      previewLine: json['previewLine'] as String? ?? '',
      letterBody: json['letterBody'] as String? ?? '',
      signature: json['signature'] as String? ?? '',
    );
  }
}

@immutable
class HabitChipsPayload extends BentoPayload {
  const HabitChipsPayload({
    required this.title,
    required this.habits,
    this.footnote = '',
  });

  final String title;
  final List<String> habits;
  final String footnote;

  HabitChipsPayload copyWith({
    String? title,
    List<String>? habits,
    String? footnote,
  }) {
    return HabitChipsPayload(
      title: title ?? this.title,
      habits: habits ?? this.habits,
      footnote: footnote ?? this.footnote,
    );
  }

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'title': title,
        'habits': habits,
        'footnote': footnote,
      };

  factory HabitChipsPayload.fromJson(Map<String, dynamic> json) {
    return HabitChipsPayload(
      title: json['title'] as String,
      habits: List<String>.from(json['habits'] as List<dynamic>),
      footnote: json['footnote'] as String? ?? '',
    );
  }
}

@immutable
class PhotoStripPayload extends BentoPayload {
  const PhotoStripPayload({
    required this.title,
    required this.imageUrls,
    this.caption = '',
    this.layoutMode = 'collage',
  });

  final String title;
  final List<String> imageUrls;
  final String caption;
  final String layoutMode;

  PhotoStripPayload copyWith({
    String? title,
    List<String>? imageUrls,
    String? caption,
    String? layoutMode,
  }) {
    return PhotoStripPayload(
      title: title ?? this.title,
      imageUrls: imageUrls ?? this.imageUrls,
      caption: caption ?? this.caption,
      layoutMode: layoutMode ?? this.layoutMode,
    );
  }

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'title': title,
        'imageUrls': imageUrls,
        'caption': caption,
        'layoutMode': layoutMode,
      };

  factory PhotoStripPayload.fromJson(Map<String, dynamic> json) {
    return PhotoStripPayload(
      title: json['title'] as String? ?? 'Mini-álbum',
      imageUrls:
          List<String>.from(json['imageUrls'] as List<dynamic>? ?? const []),
      caption: json['caption'] as String? ?? '',
      layoutMode: json['layoutMode'] as String? ?? 'collage',
    );
  }
}

@immutable
class MoodPulsePayload extends BentoPayload {
  const MoodPulsePayload({
    required this.title,
    required this.moodKey,
    this.energyLevel = 4,
    this.note = '',
    this.dateLabel = '',
  });

  final String title;
  final String moodKey;
  final int energyLevel;
  final String note;
  final String dateLabel;

  MoodPulsePayload copyWith({
    String? title,
    String? moodKey,
    int? energyLevel,
    String? note,
    String? dateLabel,
  }) {
    return MoodPulsePayload(
      title: title ?? this.title,
      moodKey: moodKey ?? this.moodKey,
      energyLevel: energyLevel ?? this.energyLevel,
      note: note ?? this.note,
      dateLabel: dateLabel ?? this.dateLabel,
    );
  }

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'title': title,
        'moodKey': moodKey,
        'energyLevel': energyLevel,
        'note': note,
        'dateLabel': dateLabel,
      };

  factory MoodPulsePayload.fromJson(Map<String, dynamic> json) {
    return MoodPulsePayload(
      title: json['title'] as String? ?? 'Cómo está hoy',
      moodKey: json['moodKey'] as String? ?? 'sunny',
      energyLevel: (json['energyLevel'] as num?)?.toInt().clamp(1, 5) ?? 4,
      note: json['note'] as String? ?? '',
      dateLabel: json['dateLabel'] as String? ?? '',
    );
  }
}

@immutable
class CravingRecipePayload extends BentoPayload {
  const CravingRecipePayload({
    required this.title,
    this.category = 'drink',
    required this.details,
    this.placeNote = '',
    this.imageUrl = '',
  });

  final String title;
  final String category;
  final List<String> details;
  final String placeNote;
  final String imageUrl;

  CravingRecipePayload copyWith({
    String? title,
    String? category,
    List<String>? details,
    String? placeNote,
    String? imageUrl,
  }) {
    return CravingRecipePayload(
      title: title ?? this.title,
      category: category ?? this.category,
      details: details ?? this.details,
      placeNote: placeNote ?? this.placeNote,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'title': title,
        'category': category,
        'details': details,
        'placeNote': placeNote,
        'imageUrl': imageUrl,
      };

  factory CravingRecipePayload.fromJson(Map<String, dynamic> json) {
    return CravingRecipePayload(
      title: json['title'] as String? ?? 'Antojo favorito',
      category: json['category'] as String? ?? 'drink',
      details: List<String>.from(json['details'] as List<dynamic>? ?? const []),
      placeNote: json['placeNote'] as String? ?? '',
      imageUrl: json['imageUrl'] as String? ?? '',
    );
  }
}

@immutable
class PlanTicketPayload extends BentoPayload {
  const PlanTicketPayload({
    required this.title,
    this.whenLabel = '',
    this.placeLabel = '',
    this.promiseNote = '',
    this.isRedeemed = false,
    this.latitude,
    this.longitude,
  });

  final String title;
  final String whenLabel;
  final String placeLabel;
  final String promiseNote;
  final bool isRedeemed;
  final double? latitude;
  final double? longitude;

  PlanTicketPayload copyWith({
    String? title,
    String? whenLabel,
    String? placeLabel,
    String? promiseNote,
    bool? isRedeemed,
    double? latitude,
    double? longitude,
    bool clearCoordinates = false,
  }) {
    return PlanTicketPayload(
      title: title ?? this.title,
      whenLabel: whenLabel ?? this.whenLabel,
      placeLabel: placeLabel ?? this.placeLabel,
      promiseNote: promiseNote ?? this.promiseNote,
      isRedeemed: isRedeemed ?? this.isRedeemed,
      latitude: clearCoordinates ? null : (latitude ?? this.latitude),
      longitude: clearCoordinates ? null : (longitude ?? this.longitude),
    );
  }

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'title': title,
        'whenLabel': whenLabel,
        'placeLabel': placeLabel,
        'promiseNote': promiseNote,
        'isRedeemed': isRedeemed,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      };

  factory PlanTicketPayload.fromJson(Map<String, dynamic> json) {
    return PlanTicketPayload(
      title: json['title'] as String? ?? 'Plan juntos',
      whenLabel: json['whenLabel'] as String? ?? '',
      placeLabel: json['placeLabel'] as String? ?? '',
      promiseNote: json['promiseNote'] as String? ?? '',
      isRedeemed: json['isRedeemed'] as bool? ?? false,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }
}

@immutable
class SketchStroke {
  const SketchStroke({
    required this.colorHex,
    required this.strokeWidth,
    required this.points,
  });

  final int colorHex;
  final double strokeWidth;

  /// Puntos normalizados [x, y] en el rango 0.0..1.0 respecto al lienzo del boceto.
  final List<List<double>> points;

  SketchStroke copyWith({
    int? colorHex,
    double? strokeWidth,
    List<List<double>>? points,
  }) {
    return SketchStroke(
      colorHex: colorHex ?? this.colorHex,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      points: points ?? this.points,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'colorHex': colorHex,
        'strokeWidth': strokeWidth,
        'points': points,
      };

  factory SketchStroke.fromJson(Map<String, dynamic> json) {
    final rawPoints = json['points'] as List<dynamic>? ?? const [];
    final parsed = <List<double>>[];
    for (final pt in rawPoints) {
      if (pt is List && pt.length >= 2) {
        parsed.add(<double>[
          (pt[0] as num).toDouble(),
          (pt[1] as num).toDouble(),
        ]);
      }
    }
    return SketchStroke(
      colorHex: (json['colorHex'] as num?)?.toInt() ?? 0xFFA85338,
      strokeWidth: (json['strokeWidth'] as num?)?.toDouble() ?? 4.0,
      points: parsed,
    );
  }
}

@immutable
class SketchDoodlePayload extends BentoPayload {
  const SketchDoodlePayload({
    this.title = '',
    required this.strokes,
  });

  final String title;
  final List<SketchStroke> strokes;

  SketchDoodlePayload copyWith({
    String? title,
    List<SketchStroke>? strokes,
  }) {
    return SketchDoodlePayload(
      title: title ?? this.title,
      strokes: strokes ?? this.strokes,
    );
  }

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'title': title,
        'strokes': strokes.map((s) => s.toJson()).toList(),
      };

  factory SketchDoodlePayload.fromJson(Map<String, dynamic> json) {
    final raw = json['strokes'] as List<dynamic>? ?? const [];
    return SketchDoodlePayload(
      title: json['title'] as String? ?? '',
      strokes: raw
          .map(
            (e) => SketchStroke.fromJson(
              Map<String, dynamic>.from(e as Map<dynamic, dynamic>),
            ),
          )
          .toList(),
    );
  }
}

@immutable
class PolaroidThreadItem {
  const PolaroidThreadItem({
    required this.imageUrl,
    this.caption = '',
  });

  final String imageUrl;
  final String caption;

  PolaroidThreadItem copyWith({
    String? imageUrl,
    String? caption,
  }) {
    return PolaroidThreadItem(
      imageUrl: imageUrl ?? this.imageUrl,
      caption: caption ?? this.caption,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'imageUrl': imageUrl,
        'caption': caption,
      };

  factory PolaroidThreadItem.fromJson(Map<String, dynamic> json) {
    return PolaroidThreadItem(
      imageUrl: json['imageUrl'] as String? ?? '',
      caption: json['caption'] as String? ?? '',
    );
  }
}

@immutable
class PolaroidThreadPayload extends BentoPayload {
  const PolaroidThreadPayload({
    this.title = '',
    required this.items,
    this.threadStyle = 'jute',
    this.note = '',
  });

  final String title;
  final List<PolaroidThreadItem> items;

  /// Estilo del hilo visual: 'jute', 'terracotta', 'gold', 'ivory'.
  final String threadStyle;
  final String note;

  PolaroidThreadPayload copyWith({
    String? title,
    List<PolaroidThreadItem>? items,
    String? threadStyle,
    String? note,
  }) {
    return PolaroidThreadPayload(
      title: title ?? this.title,
      items: items ?? this.items,
      threadStyle: threadStyle ?? this.threadStyle,
      note: note ?? this.note,
    );
  }

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'title': title,
        'items': items.map((e) => e.toJson()).toList(),
        'threadStyle': threadStyle,
        'note': note,
      };

  factory PolaroidThreadPayload.fromJson(Map<String, dynamic> json) {
    final raw = json['items'] as List<dynamic>? ?? const [];
    return PolaroidThreadPayload(
      title: json['title'] as String? ?? '',
      items: raw
          .map(
            (e) => PolaroidThreadItem.fromJson(
              Map<String, dynamic>.from(e as Map<dynamic, dynamic>),
            ),
          )
          .toList(),
      threadStyle: json['threadStyle'] as String? ?? 'jute',
      note: json['note'] as String? ?? '',
    );
  }
}

@immutable
class AboutHerEntry {
  const AboutHerEntry({
    required this.prefix,
    required this.detail,
  });

  final String prefix;
  final String detail;

  AboutHerEntry copyWith({
    String? prefix,
    String? detail,
  }) {
    return AboutHerEntry(
      prefix: prefix ?? this.prefix,
      detail: detail ?? this.detail,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'prefix': prefix,
        'detail': detail,
      };

  factory AboutHerEntry.fromJson(Map<String, dynamic> json) {
    return AboutHerEntry(
      prefix: json['prefix'] as String? ?? '',
      detail: json['detail'] as String? ?? '',
    );
  }
}

@immutable
class AboutHerPayload extends BentoPayload {
  const AboutHerPayload({
    this.title = '',
    required this.entries,
  });

  final String title;
  final List<AboutHerEntry> entries;

  AboutHerPayload copyWith({
    String? title,
    List<AboutHerEntry>? entries,
  }) {
    return AboutHerPayload(
      title: title ?? this.title,
      entries: entries ?? this.entries,
    );
  }

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'title': title,
        'entries': entries.map((e) => e.toJson()).toList(),
      };

  factory AboutHerPayload.fromJson(Map<String, dynamic> json) {
    final raw = json['entries'] as List<dynamic>? ?? const [];
    return AboutHerPayload(
      title: json['title'] as String? ?? '',
      entries: raw
          .map(
            (e) => AboutHerEntry.fromJson(
              Map<String, dynamic>.from(e as Map<dynamic, dynamic>),
            ),
          )
          .toList(),
    );
  }
}

@immutable
class WardrobeItem {
  const WardrobeItem({
    required this.name,
    this.garmentType = 'top',
    this.category = 'uses',
    this.imageUrl = '',
    this.sizeOverride = '',
    this.note = '',
    this.gifted = false,
  });

  final String name;

  /// 'top' | 'bottom' | 'shoes' | 'accessory' | 'outfit'.
  final String garmentType;

  /// 'uses' | 'likes' | 'gift'.
  final String category;
  final String imageUrl;
  final String sizeOverride;
  final String note;
  final bool gifted;

  WardrobeItem copyWith({
    String? name,
    String? garmentType,
    String? category,
    String? imageUrl,
    String? sizeOverride,
    String? note,
    bool? gifted,
  }) {
    return WardrobeItem(
      name: name ?? this.name,
      garmentType: garmentType ?? this.garmentType,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      sizeOverride: sizeOverride ?? this.sizeOverride,
      note: note ?? this.note,
      gifted: gifted ?? this.gifted,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'garmentType': garmentType,
        'category': category,
        'imageUrl': imageUrl,
        'sizeOverride': sizeOverride,
        'note': note,
        'gifted': gifted,
      };

  factory WardrobeItem.fromJson(Map<String, dynamic> json) {
    return WardrobeItem(
      name: json['name'] as String? ?? '',
      garmentType: json['garmentType'] as String? ?? 'top',
      category: json['category'] as String? ?? 'uses',
      imageUrl: json['imageUrl'] as String? ?? '',
      sizeOverride: json['sizeOverride'] as String? ?? '',
      note: json['note'] as String? ?? '',
      gifted: json['gifted'] as bool? ?? false,
    );
  }
}

@immutable
class WardrobeSizeEntry {
  const WardrobeSizeEntry({
    required this.typeName,
    required this.size,
  });

  final String typeName;
  final String size;

  WardrobeSizeEntry copyWith({
    String? typeName,
    String? size,
  }) {
    return WardrobeSizeEntry(
      typeName: typeName ?? this.typeName,
      size: size ?? this.size,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'typeName': typeName,
        'size': size,
      };

  factory WardrobeSizeEntry.fromJson(Map<String, dynamic> json) {
    return WardrobeSizeEntry(
      typeName: json['typeName'] as String? ?? '',
      size: json['size'] as String? ?? '',
    );
  }
}

@immutable
class WardrobeClosetPayload extends BentoPayload {
  const WardrobeClosetPayload({
    this.title = '',
    this.topSize = '',
    this.bottomSize = '',
    this.shoeSize = '',
    this.accessorySize = '',
    this.sizeEntries = const <WardrobeSizeEntry>[],
    required this.items,
  });

  final String title;
  final String topSize;
  final String bottomSize;
  final String shoeSize;
  final String accessorySize;
  final List<WardrobeSizeEntry> sizeEntries;
  final List<WardrobeItem> items;

  List<WardrobeSizeEntry> get effectiveSizeEntries {
    if (sizeEntries.isNotEmpty) return sizeEntries;
    return <WardrobeSizeEntry>[
      if (topSize.trim().isNotEmpty)
        WardrobeSizeEntry(typeName: 'Arriba', size: topSize.trim()),
      if (bottomSize.trim().isNotEmpty)
        WardrobeSizeEntry(typeName: 'Abajo', size: bottomSize.trim()),
      if (shoeSize.trim().isNotEmpty)
        WardrobeSizeEntry(typeName: 'Calzado', size: shoeSize.trim()),
      if (accessorySize.trim().isNotEmpty)
        WardrobeSizeEntry(typeName: 'Accesorio', size: accessorySize.trim()),
    ];
  }

  String resolveSizeFor(WardrobeItem item) {
    final override = item.sizeOverride.trim();
    if (override.isNotEmpty) return override;
    final key = item.garmentType.trim().toLowerCase();
    for (final entry in effectiveSizeEntries) {
      if (entry.typeName.trim().toLowerCase() == key &&
          entry.size.trim().isNotEmpty) {
        return entry.size.trim();
      }
    }
    return switch (item.garmentType) {
      'bottom' => bottomSize.trim(),
      'shoes' => shoeSize.trim(),
      'accessory' => accessorySize.trim(),
      'outfit' => <String>[
          topSize.trim(),
          bottomSize.trim(),
        ].where((s) => s.isNotEmpty).join(' / '),
      _ => topSize.trim(),
    };
  }

  WardrobeClosetPayload copyWith({
    String? title,
    String? topSize,
    String? bottomSize,
    String? shoeSize,
    String? accessorySize,
    List<WardrobeSizeEntry>? sizeEntries,
    List<WardrobeItem>? items,
  }) {
    return WardrobeClosetPayload(
      title: title ?? this.title,
      topSize: topSize ?? this.topSize,
      bottomSize: bottomSize ?? this.bottomSize,
      shoeSize: shoeSize ?? this.shoeSize,
      accessorySize: accessorySize ?? this.accessorySize,
      sizeEntries: sizeEntries ?? this.sizeEntries,
      items: items ?? this.items,
    );
  }

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'title': title,
        'topSize': topSize,
        'bottomSize': bottomSize,
        'shoeSize': shoeSize,
        'accessorySize': accessorySize,
        'sizeEntries': sizeEntries.map((e) => e.toJson()).toList(),
        'items': items.map((e) => e.toJson()).toList(),
      };

  factory WardrobeClosetPayload.fromJson(Map<String, dynamic> json) {
    final raw = json['items'] as List<dynamic>? ?? const [];
    final rawSizes = json['sizeEntries'] as List<dynamic>? ?? const [];
    return WardrobeClosetPayload(
      title: json['title'] as String? ?? '',
      topSize: json['topSize'] as String? ?? '',
      bottomSize: json['bottomSize'] as String? ?? '',
      shoeSize: json['shoeSize'] as String? ?? '',
      accessorySize: json['accessorySize'] as String? ?? '',
      sizeEntries: rawSizes
          .map(
            (e) => WardrobeSizeEntry.fromJson(
              Map<String, dynamic>.from(e as Map<dynamic, dynamic>),
            ),
          )
          .toList(),
      items: raw
          .map(
            (e) => WardrobeItem.fromJson(
              Map<String, dynamic>.from(e as Map<dynamic, dynamic>),
            ),
          )
          .toList(),
    );
  }
}

@immutable
class CoupleQuestionPayload extends BentoPayload {
  const CoupleQuestionPayload({
    required this.question,
    this.answerSamuel = '',
    this.answerRochy = '',
  });

  final String question;
  final String answerSamuel;
  final String answerRochy;

  bool get bothAnswered =>
      answerSamuel.trim().isNotEmpty && answerRochy.trim().isNotEmpty;

  CoupleQuestionPayload copyWith({
    String? question,
    String? answerSamuel,
    String? answerRochy,
  }) {
    return CoupleQuestionPayload(
      question: question ?? this.question,
      answerSamuel: answerSamuel ?? this.answerSamuel,
      answerRochy: answerRochy ?? this.answerRochy,
    );
  }

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'question': question,
        'answerSamuel': answerSamuel,
        'answerRochy': answerRochy,
      };

  factory CoupleQuestionPayload.fromJson(Map<String, dynamic> json) {
    return CoupleQuestionPayload(
      question: json['question'] as String? ?? '',
      answerSamuel: json['answerSamuel'] as String? ?? '',
      answerRochy: json['answerRochy'] as String? ?? '',
    );
  }
}
