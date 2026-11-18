import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/map_links.dart';

class GoogleMapsButton extends StatelessWidget {
  const GoogleMapsButton({
    super.key,
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: 'Cómo llegar con Google Maps',
        visualDensity: VisualDensity.compact,
        icon: const Icon(Icons.directions_rounded, size: 22),
        onPressed: () async {
          final uri =
              MapLinks.googleMaps(latitude, longitude, directions: true);
          final opened = await MapLinks.open(uri);
          if (opened || !context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('No se pudo abrir Google Maps.'),
              action: SnackBarAction(
                label: 'Copiar enlace',
                onPressed: () => Clipboard.setData(
                  ClipboardData(text: uri.toString()),
                ),
              ),
            ),
          );
        },
      );
}
