import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:local_auth/local_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:video_player/video_player.dart';

/// Servicio desacoplado para selección de fotos/videos de galería, grabación
/// de notas de voz y autenticación biométrica offline-first.
class MediaAndAuthService {
  MediaAndAuthService();

  final ImagePicker _picker = ImagePicker();
  final LocalAuthentication _localAuth = LocalAuthentication();
  AudioRecorder? _recorder;

  Future<Directory> _ensureMediaDir() async {
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

      final dir = await _ensureMediaDir();
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

      final dir = await _ensureMediaDir();
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

      final dir = await _ensureMediaDir();
      final path =
          '${dir.path}${Platform.pathSeparator}voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder!.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 96000),
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

  void dispose() {
    _recorder?.dispose();
  }
}
