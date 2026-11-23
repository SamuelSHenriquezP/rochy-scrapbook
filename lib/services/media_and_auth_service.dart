import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:local_auth/local_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:video_player/video_player.dart';

/// Servicio desacoplado para selección de fotos/videos de galería, grabación
/// de notas de voz y autenticación biométrica offline-first.
/// de notas de voz, recorte/compresión multimedia y autenticación biométrica.
class MediaAndAuthService {
  MediaAndAuthService();

  static const MethodChannel _mediaProcessorChannel =
      MethodChannel('com.rochy.rochy/media_processor');

  final ImagePicker _picker = ImagePicker();
  final LocalAuthentication _localAuth = LocalAuthentication();
  AudioRecorder? _recorder;

  Future<Directory> ensureMediaDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final mediaDir =
        Directory('${docs.path}${Platform.pathSeparator}rochy_media');
    if (!await mediaDir.exists()) {
      await mediaDir.create(recursive: true);
    }
    return mediaDir;
  }

  /// Selecciona una fotografía de la galería y la copia al almacenamiento local.
  Future<String?> pickAndPersistImage({
    ImageSource source = ImageSource.gallery,
  }) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 88,
      );
      if (picked == null) return null;

      final dir = await ensureMediaDir();
      final ext =
          picked.path.contains('.') ? picked.path.split('.').last : 'jpg';
      final targetPath =
          '${dir.path}${Platform.pathSeparator}img_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final saved = await File(picked.path).copy(targetPath);
      return saved.path;
    } on MissingPluginException {
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Selecciona un video de la galería y lo copia al almacenamiento local.
  Future<String?> pickAndPersistVideo({
    ImageSource source = ImageSource.gallery,
  }) async {
    try {
      final picked = await _picker.pickVideo(
        source: source,
        maxDuration: const Duration(minutes: 3),
      );
      if (picked == null) return null;

      final dir = await ensureMediaDir();
      final ext =
          picked.path.contains('.') ? picked.path.split('.').last : 'mp4';
      final targetPath =
          '${dir.path}${Platform.pathSeparator}vid_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final saved = await File(picked.path).copy(targetPath);
      return saved.path;
    } on MissingPluginException {
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Inicia la grabación de una nota de voz real en formato AAC/M4A.
  Future<bool> startVoiceRecording() async {
    try {
      _recorder ??= AudioRecorder();
      final hasPerm = await _recorder!.hasPermission();
      if (!hasPerm) return false;

      final dir = await ensureMediaDir();
      final path =
          '${dir.path}${Platform.pathSeparator}voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder!.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 64000,
          sampleRate: 22050,
        ),
        path: path,
      );
      return true;
    } on MissingPluginException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Detiene la grabación activa y devuelve la ruta local del archivo de audio.
  Future<String?> stopVoiceRecording() async {
    try {
      final path = await _recorder?.stop();
      return path;
    } on MissingPluginException {
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Importa un archivo de audio (MP3, M4A, AAC, WAV, OGG, FLAC, OPUS, 3GP, etc.)
  /// y lo copia al almacenamiento local de la app.
  Future<String?> pickAndPersistAudio() async {
    try {
      final picked = await FilePicker.pickFile(
        dialogTitle: 'Elige un audio o nota de voz',
        type: FileType.audio,
      );
      if (picked == null) return null;

      final dir = await ensureMediaDir();
      final rawExt = (picked.extension ?? '').toLowerCase();
      final safeExt = RegExp(r'^[a-z0-9]{2,6}$').hasMatch(rawExt)
          ? rawExt
          : 'm4a';
      final targetPath =
          '${dir.path}${Platform.pathSeparator}aud_${DateTime.now().millisecondsSinceEpoch}.$safeExt';

      final srcPath = picked.path;
      if (srcPath != null && await File(srcPath).exists()) {
        final saved = await File(srcPath).copy(targetPath);
        return saved.path;
      }

      final bytes = await picked.readAsBytes();
      if (bytes.isEmpty) return null;
      await File(targetPath).writeAsBytes(bytes, flush: true);
      return targetPath;
    } on MissingPluginException {
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> canUseBiometrics() async {
    try {
      final supported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      return supported || canCheck;
    } on MissingPluginException {
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticate({
    String reason = 'Desbloquea tu cuaderno íntimo en Rochy',
  }) async {
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
    } on MissingPluginException {
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Detecta la relación de aspecto (ancho/alto) de una imagen local o URL.
  Future<double?> detectImageAspectRatio(String source) async {
    try {
      final isRemote =
          source.startsWith('http://') || source.startsWith('https://');
      if (isRemote) {
        final completer = Completer<double?>();
        final provider = NetworkImage(source);
        final stream = provider.resolve(ImageConfiguration.empty);
        late final ImageStreamListener listener;
        listener = ImageStreamListener(
          (info, _) {
            stream.removeListener(listener);
            final img = info.image;
            final ratio = img.height == 0 ? null : img.width / img.height;
            if (!completer.isCompleted) completer.complete(ratio);
          },
          onError: (_, __) {
            stream.removeListener(listener);
            if (!completer.isCompleted) completer.complete(null);
          },
        );
        stream.addListener(listener);
        return await completer.future.timeout(
          const Duration(seconds: 6),
          onTimeout: () => null,
        );
      }

      final bytes = await File(source).readAsBytes();
      final ui.Image img = await decodeImageFromList(bytes);
      if (img.height == 0) return null;
      final ratio = img.width / img.height;
      img.dispose();
      return ratio;
    } catch (_) {
      return null;
    }
  }

  /// Detecta la relación de aspecto (ancho/alto) de un video local o remoto.
  Future<double?> detectVideoAspectRatio(String source) async {
    VideoPlayerController? ctrl;
    try {
      final isRemote =
          source.startsWith('http://') || source.startsWith('https://');
      ctrl = isRemote
          ? VideoPlayerController.networkUrl(Uri.parse(source))
          : VideoPlayerController.file(File(source));
      await ctrl.initialize();
      final ratio = ctrl.value.aspectRatio;
      return ratio > 0 ? ratio : null;
    } catch (_) {
      return null;
    } finally {
      await ctrl?.dispose();
    }
  }

  /// Recorta (con coordenadas normalizadas 0..1), rota y comprime una imagen
  /// para guardarla liviana en el cuaderno y subirla sin gastar cuota en Firebase.
  Future<({String path, int sizeBytes, double aspectRatio})?>
      processCroppedAndCompressedImage({
    required String sourcePath,
    double cropLeft = 0.0,
    double cropTop = 0.0,
    double cropWidth = 1.0,
    double cropHeight = 1.0,
    int rotationDegrees = 0,
    int maxDimension = 1280,
    int quality = 78,
  }) async {
    try {
      final dir = await ensureMediaDir();
      final outputPath =
          '${dir.path}${Platform.pathSeparator}img_opt_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final raw = await _mediaProcessorChannel.invokeMapMethod<String, dynamic>(
        'cropAndCompressImage',
        <String, dynamic>{
          'sourcePath': sourcePath,
          'outputPath': outputPath,
          'cropLeft': cropLeft,
          'cropTop': cropTop,
          'cropWidth': cropWidth,
          'cropHeight': cropHeight,
          'rotationDegrees': rotationDegrees,
          'maxDimension': maxDimension,
          'quality': quality,
        },
      );
      if (raw != null && raw['path'] is String) {
        final w = (raw['width'] as num?)?.toDouble() ?? 1.0;
        final h = (raw['height'] as num?)?.toDouble() ?? 1.0;
        final sizeBytes = (raw['sizeBytes'] as num?)?.toInt() ??
            await File(raw['path'] as String).length();
        return (
          path: raw['path'] as String,
          sizeBytes: sizeBytes,
          aspectRatio: h > 0 ? w / h : 1.0,
        );
      }
    } on MissingPluginException {
      return fallbackDartCropImage(
        sourcePath: sourcePath,
        cropLeft: cropLeft,
        cropTop: cropTop,
        cropWidth: cropWidth,
        cropHeight: cropHeight,
        maxDimension: maxDimension,
      );
    } catch (_) {
      return fallbackDartCropImage(
        sourcePath: sourcePath,
        cropLeft: cropLeft,
        cropTop: cropTop,
        cropWidth: cropWidth,
        cropHeight: cropHeight,
        maxDimension: maxDimension,
      );
    }
    return null;
  }

  Future<({String path, int sizeBytes, double aspectRatio})?>
      fallbackDartCropImage({
    required String sourcePath,
    required double cropLeft,
    required double cropTop,
    required double cropWidth,
    required double cropHeight,
    required int maxDimension,
  }) async {
    try {
      final bytes = await File(sourcePath).readAsBytes();
      final img = await decodeImageFromList(bytes);
      final srcW = img.width.toDouble();
      final srcH = img.height.toDouble();
      final sx = (cropLeft * srcW).clamp(0.0, math.max(0.0, srcW - 2)).toDouble();
      final sy = (cropTop * srcH).clamp(0.0, math.max(0.0, srcH - 2)).toDouble();
      final sw =
          (cropWidth * srcW).clamp(2.0, math.max(2.0, srcW - sx)).toDouble();
      final sh =
          (cropHeight * srcH).clamp(2.0, math.max(2.0, srcH - sy)).toDouble();

      final maxSide = math.max(sw, sh);
      final scale = maxSide > maxDimension ? maxDimension / maxSide : 1.0;
      final outW = math.max(1, (sw * scale).round());
      final outH = math.max(1, (sh * scale).round());

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawImageRect(
        img,
        ui.Rect.fromLTWH(sx, sy, sw, sh),
        ui.Rect.fromLTWH(0, 0, outW.toDouble(), outH.toDouble()),
        ui.Paint()..filterQuality = ui.FilterQuality.high,
      );
      final picture = recorder.endRecording();
      final outImage = await picture.toImage(outW, outH);
      final byteData =
          await outImage.toByteData(format: ui.ImageByteFormat.png);
      img.dispose();
      outImage.dispose();
      if (byteData == null) return null;

      final dir = await ensureMediaDir();
      final outPath =
          '${dir.path}${Platform.pathSeparator}img_opt_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(outPath);
      await file.writeAsBytes(byteData.buffer.asUint8List(), flush: true);
      return (
        path: file.path,
        sizeBytes: await file.length(),
        aspectRatio: outW / outH,
      );
    } catch (_) {
      return null;
    }
  }

  /// Extrae duración, proporción y miniaturas de un video para el recortador visual.
  Future<({int durationMs, List<String> thumbnails, double aspectRatio})>
      inspectVideoForTrimmer(String sourcePath, {int frameCount = 8}) async {
    try {
      final dir = await ensureMediaDir();
      final thumbDir = '${dir.path}${Platform.pathSeparator}thumbs';
      final raw = await _mediaProcessorChannel.invokeMapMethod<String, dynamic>(
        'extractVideoInfoAndThumbnails',
        <String, dynamic>{
          'sourcePath': sourcePath,
          'outputDir': thumbDir,
          'frameCount': frameCount,
        },
      );
      if (raw != null) {
        final durationMs = (raw['durationMs'] as num?)?.toInt() ?? 0;
        final w = (raw['width'] as num?)?.toDouble() ?? 16.0;
        final h = (raw['height'] as num?)?.toDouble() ?? 9.0;
        final thumbs = (raw['thumbnails'] as List<dynamic>? ?? const [])
            .map((e) => e.toString())
            .toList(growable: false);
        return (
          durationMs: durationMs,
          thumbnails: thumbs,
          aspectRatio: h > 0 ? w / h : 16 / 9,
        );
      }
    } catch (_) {}

    // Respaldo leyendo duración directamente desde VideoPlayerController
    VideoPlayerController? ctrl;
    try {
      ctrl = VideoPlayerController.file(File(sourcePath));
      await ctrl.initialize();
      final ms = ctrl.value.duration.inMilliseconds;
      final ratio = ctrl.value.aspectRatio > 0 ? ctrl.value.aspectRatio : 16 / 9;
      return (durationMs: ms, thumbnails: const <String>[], aspectRatio: ratio);
    } catch (_) {
      return (
        durationMs: 0,
        thumbnails: const <String>[],
        aspectRatio: 16 / 9,
      );
    } finally {
      await ctrl?.dispose();
    }
  }

  /// Recorta el video al rango [startMs, endMs] (máx. 30 s) y genera su miniatura.
  Future<
      ({
        String videoPath,
        String thumbnailPath,
        int durationSeconds,
        int sizeBytes,
      })?> trimAndOptimizeVideoFile({
    required String sourcePath,
    required int startMs,
    required int endMs,
  }) async {
    try {
      final dir = await ensureMediaDir();
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final outVideo =
          '${dir.path}${Platform.pathSeparator}vid_trim_$stamp.mp4';
      final outThumb =
          '${dir.path}${Platform.pathSeparator}vid_thumb_$stamp.jpg';

      final raw = await _mediaProcessorChannel.invokeMapMethod<String, dynamic>(
        'trimAndOptimizeVideo',
        <String, dynamic>{
          'sourcePath': sourcePath,
          'outputPath': outVideo,
          'thumbnailOutputPath': outThumb,
          'startMs': startMs,
          'endMs': endMs,
        },
      );
      if (raw != null && raw['videoPath'] is String) {
        final vPath = raw['videoPath'] as String;
        final tPath = (raw['thumbnailPath'] as String?) ?? '';
        final durSec = (raw['durationSeconds'] as num?)?.toInt() ?? 1;
        final sizeBytes =
            (raw['sizeBytes'] as num?)?.toInt() ?? await File(vPath).length();
        return (
          videoPath: vPath,
          thumbnailPath: tPath,
          durationSeconds: durSec,
          sizeBytes: sizeBytes,
        );
      }
    } catch (_) {}
    return null;
  }

  void dispose() {
    _recorder?.dispose();
  }
}
