import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import '../services/map_links.dart';

/// OpenStreetMap with flutter_map's HTTP-aware native cache (browser cache on web).
class OpenStreetMapTiles extends StatefulWidget {
  const OpenStreetMapTiles({super.key});

  @override
  State<OpenStreetMapTiles> createState() => _OpenStreetMapTilesState();
}

class _OpenStreetMapTilesState extends State<OpenStreetMapTiles> {
  bool _failed = false;
  int _attempt = 0;

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          TileLayer(
            key: ValueKey(_attempt),
            urlTemplate: const String.fromEnvironment('MAP_TILE_URL',
                defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
            userAgentPackageName: 'com.rochy.rochy',
            maxNativeZoom: 19,
            errorTileCallback: (_, __, ___) {
              if (_failed) return;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _failed = true);
              });
            },
          ),
          if (_failed)
            Positioned(
              left: 12,
              right: 12,
              top: 110,
              child: Material(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Row(children: [
                    const Expanded(
                      child: Text(
                          'No se pudo cargar el mapa. Revisa tu conexión.',
                          style: TextStyle(fontSize: 12)),
                    ),
                    TextButton(
                      onPressed: () => setState(() {
                        _failed = false;
                        _attempt++;
                      }),
                      child: const Text('Reintentar'),
                    ),
                  ]),
                ),
              ),
            ),
        ],
      );
}

/// Always visible, above the bottom cards and picker controls.
class OpenStreetMapAttribution extends StatelessWidget {
  const OpenStreetMapAttribution({super.key, this.bottom = 0});

  final double bottom;

  @override
  Widget build(BuildContext context) => Positioned(
        right: 4,
        bottom: bottom,
        child: Material(
          color: Colors.white.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(4),
          child: InkWell(
            onTap: () async {
              final opened = await MapLinks.open(
                  Uri.parse('https://www.openstreetmap.org/copyright'));
              if (!opened && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content:
                      Text('Datos © OpenStreetMap contributors · ODbL 1.0'),
                ));
              }
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Text('© OpenStreetMap contributors',
                  style: TextStyle(fontSize: 10, color: Colors.black87)),
            ),
          ),
        ),
      );
}
