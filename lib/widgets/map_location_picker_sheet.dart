import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../services/location_service.dart';
import '../services/map_links.dart';
import 'google_maps_button.dart';
import 'open_street_map_layers.dart';
import '../theme/rochy_theme.dart';

@immutable
class PickedMapLocation {
  const PickedMapLocation({
    required this.latitude,
    required this.longitude,
    required this.placeName,
    required this.coordinatesLabel,
  });

  final double latitude;
  final double longitude;
  final String placeName;
  final String coordinatesLabel;
}

/// Modal interactivo con mapa real (OpenStreetMap / CartoDB Voyager),
/// buscador de lugares reales y botón de GPS para fijar coordenadas exactas.
class MapLocationPickerSheet extends ConsumerStatefulWidget {
  const MapLocationPickerSheet({
    super.key,
    required this.theme,
    this.initialLatitude,
    this.initialLongitude,
    this.initialPlaceName = '',
  });

  final RochyThemeData theme;
  final double? initialLatitude;
  final double? initialLongitude;
  final String initialPlaceName;

  static Future<PickedMapLocation?> show(
    BuildContext context, {
    required RochyThemeData theme,
    double? initialLatitude,
    double? initialLongitude,
    String initialPlaceName = '',
  }) {
    return showModalBottomSheet<PickedMapLocation>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MapLocationPickerSheet(
        theme: theme,
        initialLatitude: initialLatitude,
        initialLongitude: initialLongitude,
        initialPlaceName: initialPlaceName,
      ),
    );
  }

  @override
  ConsumerState<MapLocationPickerSheet> createState() =>
      _MapLocationPickerSheetState();
}

class _MapLocationPickerSheetState
    extends ConsumerState<MapLocationPickerSheet> {
  static const _fallbackLat = 10.4236;
  static const _fallbackLng = -75.5512;

  late final MapController _mapController;
  late final TextEditingController _searchCtrl;
  Timer? _searchDebounce;
  int _searchGeneration = 0;
  int _pointGeneration = 0;

  late LatLng _selectedPoint;
  String _selectedName = '';
  String _selectedSubtitle = '';
  bool _hasSelection = false;
  bool _isSearching = false;
  bool _isResolving = false;
  bool _isLocating = false;
  List<PlaceSearchResult> _results = const <PlaceSearchResult>[];

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _searchCtrl = TextEditingController();
    _selectedPoint = LatLng(
      isValidMapPoint(widget.initialLatitude, widget.initialLongitude)
          ? widget.initialLatitude!
          : _fallbackLat,
      isValidMapPoint(widget.initialLatitude, widget.initialLongitude)
          ? widget.initialLongitude!
          : _fallbackLng,
    );
    _hasSelection =
        isValidMapPoint(widget.initialLatitude, widget.initialLongitude);
    _selectedName = _hasSelection ? widget.initialPlaceName.trim() : '';
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    final generation = ++_searchGeneration;
    final q = value.trim();
    if (q.length < 2) {
      setState(() {
        _results = const <PlaceSearchResult>[];
        _isSearching = false;
      });
      return;
    }
    setState(() => _isSearching = true);
    _searchDebounce = Timer(const Duration(milliseconds: 450), () async {
      final hits = await ref.read(locationServiceProvider).searchPlaces(q);
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _results = hits;
        _isSearching = false;
      });
    });
  }

  void _selectSearchResult(PlaceSearchResult hit) {
    _searchDebounce?.cancel();
    _searchGeneration++;
    _pointGeneration++;
    HapticFeedback.selectionClick();
    final target = LatLng(hit.latitude, hit.longitude);
    FocusScope.of(context).unfocus();
    setState(() {
      _selectedPoint = target;
      _selectedName = hit.shortName;
      _selectedSubtitle = hit.subtitle;
      _results = const <PlaceSearchResult>[];
      _isSearching = false;
      _isResolving = false;
      _hasSelection = true;
    });
    _mapController.move(target, 16.0);
  }

  Future<void> _onMapTap(LatLng point) async {
    final generation = ++_pointGeneration;
    _searchDebounce?.cancel();
    _searchGeneration++;
    HapticFeedback.lightImpact();
    setState(() {
      _selectedPoint = point;
      _hasSelection = true;
      _selectedName = 'Rincón marcado';
      _selectedSubtitle = '';
      _isSearching = false;
      _isResolving = true;
      _results = const <PlaceSearchResult>[];
    });
    final resolved = await ref
        .read(locationServiceProvider)
        .reverseGeocode(point.latitude, point.longitude);
    if (!mounted || generation != _pointGeneration) return;
    setState(() {
      _isResolving = false;
      if (resolved != null) {
        _selectedName = resolved.shortName;
        _selectedSubtitle = resolved.subtitle;
      } else if (_selectedName.isEmpty) {
        _selectedName = 'Rincón marcado';
      }
    });
  }

  Future<void> _useCurrentGps() async {
    HapticFeedback.mediumImpact();
    final generation = ++_pointGeneration;
    setState(() => _isLocating = true);
    final res = await ref.read(locationServiceProvider).getCurrentLocation();
    if (!mounted) return;
    setState(() => _isLocating = false);
    if (generation != _pointGeneration) return;

    if (!res.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.errorMessage ?? 'No se pudo obtener tu ubicación.'),
        ),
      );
      return;
    }

    final point = LatLng(res.latitude!, res.longitude!);
    setState(() {
      _selectedPoint = point;
      _hasSelection = true;
      _isResolving = false;
      _selectedName = res.placeName ?? 'Mi ubicación actual';
      _selectedSubtitle = res.subtitle ?? '';
      _results = const <PlaceSearchResult>[];
    });
    _mapController.move(point, 16.2);
  }

  void _confirm() {
    if (!_hasSelection) return;
    HapticFeedback.mediumImpact();
    final coords = LocationService.formatCoordinates(
      _selectedPoint.latitude,
      _selectedPoint.longitude,
    );
    Navigator.of(context).pop(
      PickedMapLocation(
        latitude: _selectedPoint.latitude,
        longitude: _selectedPoint.longitude,
        placeName:
            _selectedName.isEmpty ? 'Rincón especial' : _selectedName.trim(),
        coordinatesLabel: coords,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final height = MediaQuery.of(context).size.height * 0.84;
    final coordsText = LocationService.formatCoordinates(
      _selectedPoint.latitude,
      _selectedPoint.longitude,
    );

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: theme.canvasBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: <Widget>[
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.borderTint,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 14, 10),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Elegir ubicación real',
                    style: RochyTypography.cardSerifTitle(
                      theme.brandAccent,
                      fontSize: 20,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close_rounded, color: theme.inkSecondary),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Container(
              decoration: BoxDecoration(
                color: theme.ivorySurface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: theme.borderTint),
              ),
              child: TextField(
                controller: _searchCtrl,
                onChanged: _onSearchChanged,
                style: RochyTypography.sansBody(theme.inkPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Buscar calle, café, barrio o ciudad…',
                  hintStyle: RochyTypography.sansBody(
                    theme.inkSecondary.withValues(alpha: 0.7),
                    fontSize: 13.5,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: theme.brandAccent,
                    size: 20,
                  ),
                  suffixIcon: _isSearching
                      ? Padding(
                          padding: const EdgeInsets.all(12),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.brandAccent,
                            ),
                          ),
                        )
                      : (_searchCtrl.text.isNotEmpty
                          ? IconButton(
                              onPressed: () {
                                _searchCtrl.clear();
                                _onSearchChanged('');
                              },
                              icon: Icon(
                                Icons.clear_rounded,
                                size: 18,
                                color: theme.inkSecondary,
                              ),
                            )
                          : null),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 13),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  children: <Widget>[
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _selectedPoint,
                        initialZoom: 15.2,
                        minZoom: 2.5,
                        maxZoom: 18.5,
                        onTap: (_, latLng) => _onMapTap(latLng),
                      ),
                      children: <Widget>[
                        const OpenStreetMapTiles(),
                        MarkerLayer(
                          markers: <Marker>[
                            if (_hasSelection)
                              Marker(
                                point: _selectedPoint,
                                width: 54,
                                height: 54,
                                alignment: Alignment.topCenter,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Container(
                                      padding: const EdgeInsets.all(7),
                                      decoration: BoxDecoration(
                                        color: theme.brandAccent,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 2.2,
                                        ),
                                        boxShadow: <BoxShadow>[
                                          BoxShadow(
                                            color: Colors.black
                                                .withValues(alpha: 0.28),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.favorite_rounded,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                    const OpenStreetMapAttribution(bottom: 62),
                    // Resultados de búsqueda flotantes
                    if (_results.isNotEmpty)
                      Positioned(
                        top: 8,
                        left: 8,
                        right: 8,
                        child: Material(
                          color: theme.ivorySurface,
                          elevation: 8,
                          borderRadius: BorderRadius.circular(18),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 220),
                            child: ListView.separated(
                              shrinkWrap: true,
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              itemCount: _results.length,
                              separatorBuilder: (_, __) => Divider(
                                height: 1,
                                color: theme.borderTint,
                              ),
                              itemBuilder: (context, idx) {
                                final hit = _results[idx];
                                return ListTile(
                                  dense: true,
                                  leading: Icon(
                                    Icons.place_rounded,
                                    color: theme.brandAccent,
                                    size: 19,
                                  ),
                                  title: Text(
                                    hit.shortName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: RochyTypography.sansTitle(
                                      theme.inkPrimary,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                  subtitle: Text(
                                    hit.subtitle.isNotEmpty
                                        ? hit.subtitle
                                        : hit.displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: RochyTypography.metadata(
                                      theme.inkSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                  onTap: () => _selectSearchResult(hit),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    // Botón flotante de GPS real
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: GestureDetector(
                        onTap: _isLocating ? null : _useCurrentGps,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: theme.ivorySurface,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: theme.borderTint),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.16),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              if (_isLocating)
                                SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: theme.brandAccent,
                                  ),
                                )
                              else
                                Icon(
                                  Icons.my_location_rounded,
                                  size: 17,
                                  color: theme.brandAccent,
                                ),
                              const SizedBox(width: 7),
                              Text(
                                'Mi GPS',
                                style: RochyTypography.sansTitle(
                                  theme.inkPrimary,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Pista arriba izquierda
                    Positioned(
                      left: 12,
                      bottom: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xCC241913),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Toca el mapa para mover el pin',
                          style: RochyTypography.metadata(
                            Colors.white,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(18, 12, 18, 22),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.ivorySurface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: theme.borderTint),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              _isResolving
                                  ? 'Identificando lugar…'
                                  : (_selectedName.isEmpty
                                      ? 'Toca un punto o busca arriba'
                                      : _selectedName),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: RochyTypography.sansTitle(
                                theme.inkPrimary,
                                fontSize: 14.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _selectedSubtitle.isNotEmpty
                            ? '$_selectedSubtitle · $coordsText'
                            : (_hasSelection
                                ? coordsText
                                : 'Selecciona una ubicación real'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: RochyTypography.metadata(
                          theme.inkSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_hasSelection)
                  GoogleMapsButton(
                    latitude: _selectedPoint.latitude,
                    longitude: _selectedPoint.longitude,
                  ),
                const SizedBox(width: 10),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.brandAccent,
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                  ),
                  onPressed: _hasSelection && !_isResolving ? _confirm : null,
                  child: const Text('Usar aquí'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
