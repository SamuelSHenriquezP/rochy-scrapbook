import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Variante artística offline-first cuando no hay red disponible o la imagen carga.
enum EditorialFallbackScene {
  cafeSunlit,
  handsSunday,
  vinylWarm,
  cinemaReel,
}

/// Imagen editorial inteligente: soporta archivos locales de galería, URLs de red
/// con fade-in suave y respaldo ilustrado offline-first.
class EditorialImage extends StatelessWidget {
  const EditorialImage({
    super.key,
    required this.imageUrl,
    required this.fallbackScene,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
  });

  final String imageUrl;
  final EditorialFallbackScene fallbackScene;
  final BoxFit fit;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return _OfflineSceneCanvas(scene: fallbackScene);
    }

    final isRemote =
        imageUrl.startsWith('http://') || imageUrl.startsWith('https://');

    if (!isRemote && !kIsWeb) {
      final file = File(imageUrl);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: fit,
          alignment: alignment,
          errorBuilder: (context, error, stackTrace) {
            return _OfflineSceneCanvas(scene: fallbackScene);
          },
        );
      }
      return _OfflineSceneCanvas(scene: fallbackScene);
    }

    return Image.network(
      imageUrl,
      fit: fit,
      alignment: alignment,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) return child;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 420),
          child: frame != null
              ? child
              : _OfflineSceneCanvas(scene: fallbackScene),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return _OfflineSceneCanvas(scene: fallbackScene);
      },
    );
  }
}

class _OfflineSceneCanvas extends StatelessWidget {
  const _OfflineSceneCanvas({required this.scene});

  final EditorialFallbackScene scene;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _EditorialScenePainter(scene: scene),
      child: const SizedBox.expand(),
    );
  }
}

class _EditorialScenePainter extends CustomPainter {
  const _EditorialScenePainter({required this.scene});

  final EditorialFallbackScene scene;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    final Gradient bgGradient = switch (scene) {
      EditorialFallbackScene.cafeSunlit => const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFFE7C7A5),
            Color(0xFFC58A63),
            Color(0xFF6B3D22),
          ],
        ),
      EditorialFallbackScene.handsSunday => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0xFFDCC7B4),
            Color(0xFFB58A6C),
            Color(0xFF5D4638),
          ],
        ),
      EditorialFallbackScene.vinylWarm => const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFF8B654E),
            Color(0xFF3E2920),
          ],
        ),
      EditorialFallbackScene.cinemaReel => const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFF4B382F),
            Color(0xFF8F4E37),
            Color(0xFF281D18),
          ],
        ),
    };

    canvas.drawRect(rect, Paint()..shader = bgGradient.createShader(rect));

    final sunPaint = Paint()
      ..color = const Color(0xFFFFF5E6).withValues(alpha: 0.24)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 26);

    canvas.drawCircle(
      Offset(size.width * 0.72, size.height * 0.26),
      size.shortestSide * 0.32,
      sunPaint,
    );

    final silhouettePaint = Paint()
      ..color = const Color(0xFF2D1E17).withValues(alpha: 0.22)
      ..style = PaintingStyle.fill;

    switch (scene) {
      case EditorialFallbackScene.cafeSunlit:
        final cupCenter = Offset(size.width * 0.5, size.height * 0.58);
        final cupRect = RRect.fromRectAndCorners(
          Rect.fromCenter(
            center: cupCenter,
            width: size.width * 0.22,
            height: size.height * 0.26,
          ),
          bottomLeft: const Radius.circular(24),
          bottomRight: const Radius.circular(24),
          topLeft: const Radius.circular(6),
          topRight: const Radius.circular(6),
        );
        canvas.drawRRect(cupRect, silhouettePaint);
      case EditorialFallbackScene.handsSunday:
        final horizonY = size.height * 0.66;
        final hillPath = Path()
          ..moveTo(0, horizonY)
          ..quadraticBezierTo(
            size.width * 0.5,
            horizonY - size.height * 0.12,
            size.width,
            horizonY + 8,
          )
          ..lineTo(size.width, size.height)
          ..lineTo(0, size.height)
          ..close();
        canvas.drawPath(hillPath, silhouettePaint);
      case EditorialFallbackScene.vinylWarm:
        final center = Offset(size.width * 0.5, size.height * 0.5);
        canvas.drawCircle(center, size.shortestSide * 0.34, silhouettePaint);
        canvas.drawCircle(
          center,
          size.shortestSide * 0.11,
          Paint()..color = const Color(0xFFD99B72).withValues(alpha: 0.8),
        );
      case EditorialFallbackScene.cinemaReel:
        // Perforaciones sutiles estilo película Super-8 en los bordes
        final sprocketPaint = Paint()
          ..color = const Color(0xFFFAF7F2).withValues(alpha: 0.18);
        for (var y = 14.0; y < size.height - 10; y += 22) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(8, y, 6, 10),
              const Radius.circular(2),
            ),
            sprocketPaint,
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(size.width - 14, y, 6, 10),
              const Radius.circular(2),
            ),
            sprocketPaint,
          );
        }
    }
  }

  @override
  bool shouldRepaint(covariant _EditorialScenePainter oldDelegate) {
    return oldDelegate.scene != scene;
  }
}
