import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/bento_node.dart';

final rochyBackupServiceProvider = Provider<RochyBackupService>((ref) {
  return RochyBackupService();
});

class RochyBackupExportResult {
  const RochyBackupExportResult({
    required this.file,
    required this.notebookCount,
    required this.nodeCount,
    required this.mediaCount,
    required this.sizeBytes,
  });

  final File file;
  final int notebookCount;
  final int nodeCount;
  final int mediaCount;
  final int sizeBytes;
}

class RochyRestoredBundle {
  const RochyRestoredBundle({
    required this.notebooks,
    required this.activeNotebookId,
    required this.showPaperGrain,
    required this.textScaleFactor,
    required this.restoredMediaCount,
    this.partnerAAvatarUrl = '',
    this.partnerBAvatarUrl = '',
    this.partnerAName = '',
    this.partnerBName = '',
    this.deletedNodeIds = const <String>{},
  });

  final List<RochyNotebook> notebooks;
  final String activeNotebookId;
  final bool? showPaperGrain;
  final double? textScaleFactor;
  final int restoredMediaCount;
  final String partnerAAvatarUrl;
  final String partnerBAvatarUrl;
  final String partnerAName;
  final String partnerBName;
  final Set<String> deletedNodeIds;
}

class RochyParsedBackup {
  RochyParsedBackup({
    required this.notebooks,
    required this.activeNotebookId,
    required this.showPaperGrain,
    required this.textScaleFactor,
    required this.mediaEntryCount,
    required this.exportedAtIso,
    this.partnerAAvatarUrl = '',
    this.partnerBAvatarUrl = '',
    this.partnerAName = '',
    this.partnerBName = '',
    this.deletedNodeIds = const <String>{},
    Archive? archive,
    InputFileStream? fileStream,
  })  : _archive = archive,
        _fileStream = fileStream;

  final List<RochyNotebook> notebooks;
  final String activeNotebookId;
  final bool? showPaperGrain;
  final double? textScaleFactor;
  final int mediaEntryCount;
  final String? exportedAtIso;
  final String partnerAAvatarUrl;
  final String partnerBAvatarUrl;
  final String partnerAName;
  final String partnerBName;
  final Set<String> deletedNodeIds;
  final Archive? _archive;
  final InputFileStream? _fileStream;

  int get totalNodeCount =>
      notebooks.fold<int>(0, (sum, book) => sum + book.nodes.length);

  Future<void> close() async {
    try {
      await _archive?.clear();
    } catch (_) {}
    try {
      await _fileStream?.close();
    } catch (_) {}
  }
}

/// Servicio para crear, compartir y restaurar respaldos portables `.rochy.zip`
/// que empaquetan cuadernos, ajustes y todos los archivos multimedia locales.
class RochyBackupService {
  static const String backupFormat = 'rochy_backup';
  static const int backupVersion = 1;
  static const String mediaScheme = 'rochy_media://';

  String _joinPath(String dir, String child) {
    final sep = Platform.pathSeparator;
    return dir.endsWith(sep) ? '$dir$child' : '$dir$sep$child';
  }

  String _basename(String filePath) {
    final parts = filePath
        .split(RegExp(r'[/\\]'))
        .where((segment) => segment.isNotEmpty)
        .toList();
    return parts.isEmpty ? filePath : parts.last;
  }

  String _extension(String filePath) {
    final name = _basename(filePath);
    final dot = name.lastIndexOf('.');
    if (dot <= 0 || dot >= name.length - 1) return '';
    return name.substring(dot);
  }

  bool isLocalMediaPath(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return false;
    if (trimmed.startsWith('http://') ||
        trimmed.startsWith('https://') ||
        trimmed.startsWith('assets/') ||
        trimmed.startsWith(mediaScheme) ||
        trimmed.startsWith('data:')) {
      return false;
    }
    try {
      return File(trimmed).existsSync();
    } catch (_) {
      return false;
    }
  }

  int countLocalMediaFiles(List<RochyNotebook> notebooks) {
    final unique = <String>{};
    for (final book in notebooks) {
      _rewriteNotebookMedia(book, (raw) {
        if (isLocalMediaPath(raw)) {
          unique.add(raw.trim());
        }
        return raw;
      });
    }
    return unique.length;
  }

  Future<RochyBackupExportResult> createPortableBackup({
    required List<RochyNotebook> notebooks,
    required String activeNotebookId,
    required bool showPaperGrain,
    required double textScaleFactor,
    String partnerAAvatarUrl = '',
    String partnerBAvatarUrl = '',
    String partnerAName = 'Sam',
    String partnerBName = 'Rochy',
    Set<String> deletedNodeIds = const <String>{},
  }) async {
    final pathToKey = <String, String>{};
    final orderedFiles = <({String key, File file})>[];
    var mediaSeq = 0;

    String registerOrRewrite(String raw) {
      final trimmed = raw.trim();
      if (!isLocalMediaPath(trimmed)) return raw;

      final existingKey = pathToKey[trimmed];
      if (existingKey != null) {
        return '$mediaScheme$existingKey';
      }

      mediaSeq++;
      final rawExt = _extension(trimmed).toLowerCase();
      final cleanExt = RegExp(r'^\.[a-z0-9]{1,8}$').hasMatch(rawExt)
          ? rawExt
          : '.bin';
      final key = 'm_${mediaSeq.toString().padLeft(3, '0')}$cleanExt';
      pathToKey[trimmed] = key;
      orderedFiles.add((key: key, file: File(trimmed)));
      return '$mediaScheme$key';
    }

    final portableBooks = notebooks
        .map((book) => _rewriteNotebookMedia(book, registerOrRewrite))
        .toList(growable: false);

    final portableAvatarA = registerOrRewrite(partnerAAvatarUrl);
    final portableAvatarB = registerOrRewrite(partnerBAvatarUrl);

    final manifestJson = const JsonEncoder.withIndent('  ').convert(
      <String, dynamic>{
        'format': backupFormat,
        'version': backupVersion,
        'exportedAt': DateTime.now().toIso8601String(),
        'activeNotebookId': activeNotebookId,
        'showPaperGrain': showPaperGrain,
        'textScaleFactor': textScaleFactor,
        'coupleMeta': <String, dynamic>{
          'partnerAName': partnerAName,
          'partnerBName': partnerBName,
          'partnerAAvatarUrl': portableAvatarA,
          'partnerBAvatarUrl': portableAvatarB,
          'deletedNodeIds': deletedNodeIds.toList(growable: false),
        },
        'notebooks': portableBooks.map((b) => b.toJson()).toList(),
      },
    );

    final now = DateTime.now();
    final stamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';

    final tempDir = await getTemporaryDirectory();
    final outPath = _joinPath(tempDir.path, 'Rochy_Respaldo_$stamp.rochy.zip');
    final outFile = File(outPath);
    if (await outFile.exists()) {
      await outFile.delete();
    }

    final encoder = ZipFileEncoder();
    encoder.create(outFile.path);
    try {
      encoder.addArchiveFile(ArchiveFile.string('manifest.json', manifestJson));
      for (final item in orderedFiles) {
        if (await item.file.exists()) {
          await encoder.addFile(
            item.file,
            'media/${item.key}',
            ZipFileEncoder.store,
          );
        }
      }
      await encoder.close();
    } catch (_) {
      try {
        await encoder.close();
      } catch (_) {}
      rethrow;
    }

    final nodeCount = notebooks.fold<int>(0, (sum, b) => sum + b.nodes.length);
    final sizeBytes = await outFile.length();
    return RochyBackupExportResult(
      file: outFile,
      notebookCount: notebooks.length,
      nodeCount: nodeCount,
      mediaCount: orderedFiles.length,
      sizeBytes: sizeBytes,
    );
  }

  Future<ShareResult> shareBackupFile(File file) {
    return SharePlus.instance.share(
      ShareParams(
        files: <XFile>[
          XFile(
            file.path,
            mimeType: 'application/zip',
            name: _basename(file.path),
          ),
        ],
        subject: 'Respaldo completo de Rochy',
        title: 'Exportar respaldo Rochy',
        text: 'Archivo portable de Rochy con cuadernos, fotos, videos y notas de voz.',
      ),
    );
  }

  Future<PlatformFile?> pickBackupFile() {
    return FilePicker.pickFile(
      dialogTitle: 'Elige tu respaldo (.rochy.zip o .json)',
      type: FileType.any,
    );
  }

  Future<RochyParsedBackup> parseBackupFile(File file) async {
    InputFileStream? fileStream;
    try {
      final header = await _readMagicHeader(file);
      final looksZip =
          header.length >= 2 && header[0] == 0x50 && header[1] == 0x4B; // PK

      if (looksZip) {
        fileStream = InputFileStream(file.path);
        final archive = ZipDecoder().decodeStream(fileStream);
        return _buildParsedFromArchive(archive, fileStream: fileStream);
      }

      final text = await file.readAsString();
      return _parseManifestOrLegacyJson(text);
    } catch (_) {
      try {
        await fileStream?.close();
      } catch (_) {}
      rethrow;
    }
  }

  Future<RochyParsedBackup> parseBackupPlatformFile(PlatformFile picked) async {
    final localPath = picked.path;
    if (localPath != null && await File(localPath).exists()) {
      return parseBackupFile(File(localPath));
    }
    // Fallback para URIs SAF (content://) sin ruta directa en disco.
    final bytes = await picked.readAsBytes();
    return _parseBytes(bytes);
  }

  Future<RochyRestoredBundle> materializeBackupMedia(
    RochyParsedBackup parsed,
  ) async {
    final archive = parsed._archive;
    final keyToLocalPath = <String, String>{};
    var restoredMediaCount = 0;

    if (archive != null) {
      final docs = await getApplicationDocumentsDirectory();
      final mediaDir = Directory(_joinPath(docs.path, 'rochy_media'));
      if (!await mediaDir.exists()) {
        await mediaDir.create(recursive: true);
      }

      final prefix = 'bkp_${DateTime.now().millisecondsSinceEpoch}_';
      for (final entry in archive.files) {
        if (!entry.isFile || entry.isSymbolicLink) continue;
        if (!entry.name.startsWith('media/')) continue;

        final rawKey = entry.name.substring('media/'.length);
        if (rawKey.isEmpty ||
            rawKey.contains('..') ||
            rawKey.contains('/') ||
            rawKey.contains('\\')) {
          continue;
        }

        final safeKey = rawKey.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
        final destPath = _joinPath(mediaDir.path, '$prefix$safeKey');
        final out = OutputFileStream(destPath);
        try {
          entry.writeContent(out);
        } finally {
          await out.close();
        }
        keyToLocalPath['$mediaScheme$rawKey'] = destPath;
        restoredMediaCount++;
      }
    }

    String resolveRestoredPath(String raw) {
      if (raw.startsWith(mediaScheme)) {
        return keyToLocalPath[raw] ?? '';
      }
      return raw;
    }

    final restoredBooks = parsed.notebooks
        .map((book) => _rewriteNotebookMedia(book, resolveRestoredPath))
        .toList(growable: false);

    return RochyRestoredBundle(
      notebooks: restoredBooks,
      activeNotebookId: parsed.activeNotebookId,
      showPaperGrain: parsed.showPaperGrain,
      textScaleFactor: parsed.textScaleFactor,
      restoredMediaCount: restoredMediaCount,
      partnerAAvatarUrl: resolveRestoredPath(parsed.partnerAAvatarUrl),
      partnerBAvatarUrl: resolveRestoredPath(parsed.partnerBAvatarUrl),
      partnerAName: parsed.partnerAName,
      partnerBName: parsed.partnerBName,
      deletedNodeIds: parsed.deletedNodeIds,
    );
  }

  Future<List<int>> _readMagicHeader(File file) async {
    final raf = await file.open();
    try {
      return await raf.read(4);
    } finally {
      await raf.close();
    }
  }

  RochyParsedBackup _parseBytes(Uint8List bytes) {
    final isZip = bytes.length >= 2 && bytes[0] == 0x50 && bytes[1] == 0x4B;
    if (isZip) {
      final archive = ZipDecoder().decodeBytes(bytes);
      return _buildParsedFromArchive(archive);
    }
    return _parseManifestOrLegacyJson(utf8.decode(bytes));
  }

  RochyParsedBackup _buildParsedFromArchive(
    Archive archive, {
    InputFileStream? fileStream,
  }) {
    final manifestEntry = archive.findFile('manifest.json');
    if (manifestEntry == null) {
      throw const FormatException('Falta manifest.json dentro del respaldo.');
    }
    final manifestBytes = manifestEntry.readBytes();
    if (manifestBytes == null || manifestBytes.isEmpty) {
      throw const FormatException('manifest.json vacío.');
    }

    final mediaCount = archive.files
        .where(
          (f) =>
              f.isFile &&
              !f.isSymbolicLink &&
              f.name.startsWith('media/') &&
              f.name.length > 'media/'.length,
        )
        .length;

    return _parseManifestOrLegacyJson(
      utf8.decode(manifestBytes),
      mediaEntryCount: mediaCount,
      archive: archive,
      fileStream: fileStream,
    );
  }

  RochyParsedBackup _parseManifestOrLegacyJson(
    String rawJson, {
    int mediaEntryCount = 0,
    Archive? archive,
    InputFileStream? fileStream,
  }) {
    final decoded = jsonDecode(rawJson);
    if (decoded is! Map) {
      throw const FormatException('Estructura de respaldo inválida.');
    }
    final map = Map<String, dynamic>.from(decoded);

    if (map.containsKey('notebooks') && map['notebooks'] is List) {
      final rawBooks = map['notebooks'] as List<dynamic>;
      final notebooks = rawBooks
          .map(
            (e) => RochyNotebook.fromJson(
              Map<String, dynamic>.from(e as Map<dynamic, dynamic>),
            ),
          )
          .toList(growable: false);
      if (notebooks.isEmpty) {
        throw const FormatException('El respaldo no contiene cuadernos.');
      }
      final activeId = map['activeNotebookId'] as String?;
      final rawCoupleMeta = map['coupleMeta'];
      final coupleMeta = rawCoupleMeta is Map
          ? Map<String, dynamic>.from(rawCoupleMeta)
          : const <String, dynamic>{};
      final rawDeleted =
          coupleMeta['deletedNodeIds'] as List<dynamic>? ?? const <dynamic>[];
      final deletedNodeIds = rawDeleted
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toSet();
      return RochyParsedBackup(
        notebooks: notebooks,
        activeNotebookId:
            activeId != null && activeId.isNotEmpty
                ? activeId
                : notebooks.first.entity.id,
        showPaperGrain: map['showPaperGrain'] as bool?,
        textScaleFactor: (map['textScaleFactor'] as num?)?.toDouble(),
        mediaEntryCount: mediaEntryCount,
        exportedAtIso: map['exportedAt'] as String?,
        partnerAAvatarUrl:
            (coupleMeta['partnerAAvatarUrl'] as String? ?? '').trim(),
        partnerBAvatarUrl:
            (coupleMeta['partnerBAvatarUrl'] as String? ?? '').trim(),
        partnerAName: (coupleMeta['partnerAName'] as String? ?? '').trim(),
        partnerBName: (coupleMeta['partnerBName'] as String? ?? '').trim(),
        deletedNodeIds: deletedNodeIds,
        archive: archive,
        fileStream: fileStream,
      );
    }

    // Compatibilidad con snapshot JSON clásico de un solo cuaderno.
    if (map.containsKey('entity') && map.containsKey('nodes')) {
      final book = RochyNotebook.fromJson(map);
      return RochyParsedBackup(
        notebooks: <RochyNotebook>[book],
        activeNotebookId: book.entity.id,
        showPaperGrain: null,
        textScaleFactor: null,
        mediaEntryCount: mediaEntryCount,
        exportedAtIso: null,
        archive: archive,
        fileStream: fileStream,
      );
    }

    throw const FormatException('Formato de respaldo no reconocido.');
  }

  RochyNotebook _rewriteNotebookMedia(
    RochyNotebook book,
    String Function(String raw) rewrite,
  ) {
    return book.copyWith(
      entity: book.entity.copyWith(
        coverImageUrl: rewrite(book.entity.coverImageUrl),
      ),
      nodes: book.nodes
          .map(
            (node) => node.copyWith(
              payload: _rewritePayloadMedia(node.payload, rewrite),
            ),
          )
          .toList(growable: false),
    );
  }

  BentoPayload _rewritePayloadMedia(
    BentoPayload payload,
    String Function(String raw) rewrite,
  ) {
    return switch (payload) {
      final PhotoHeroPayload p => p.copyWith(imageUrl: rewrite(p.imageUrl)),
      final VideoMemoryPayload p => p.copyWith(
          videoSource: rewrite(p.videoSource),
          thumbnailUrl: rewrite(p.thumbnailUrl),
        ),
      final FlipDetailPayload p => p.copyWith(
          localAudioPath: rewrite(p.localAudioPath),
        ),
      final AudioNotePayload p => p.copyWith(
          coverImageUrl: rewrite(p.coverImageUrl),
          localAudioPath: rewrite(p.localAudioPath),
        ),
      final LocationPinPayload p => p.copyWith(imageUrl: rewrite(p.imageUrl)),
      final PhotoStripPayload p => p.copyWith(
          imageUrls: p.imageUrls.map(rewrite).toList(growable: false),
        ),
      final CravingRecipePayload p => p.copyWith(imageUrl: rewrite(p.imageUrl)),
      final BookMoviePayload p => p.copyWith(imageUrl: rewrite(p.imageUrl)),
      final PolaroidThreadPayload p => p.copyWith(
          items: p.items
              .map((item) => item.copyWith(imageUrl: rewrite(item.imageUrl)))
              .toList(growable: false),
        ),
      final WardrobeClosetPayload p => p.copyWith(
          items: p.items
              .map((item) => item.copyWith(imageUrl: rewrite(item.imageUrl)))
              .toList(growable: false),
        ),
      QuotePayload() ||
      CheckListPayload() ||
      CountdownPayload() ||
      PaletteMoodPayload() ||
      GiftWishPayload() ||
      LoveLetterPayload() ||
      HabitChipsPayload() ||
      MoodPulsePayload() ||
      PlanTicketPayload() ||
      TravelPassportPayload() ||
      SavedChatPayload() ||
      VintageTicketPayload() ||
      SketchDoodlePayload() ||
      CoupleQuestionPayload() ||
      AboutHerPayload() =>
        payload,
    };
  }
}
