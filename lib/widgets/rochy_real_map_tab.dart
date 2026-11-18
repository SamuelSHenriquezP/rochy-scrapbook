import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../models/bento_node.dart';
import '../providers/bento_canvas_provider.dart';
import '../services/location_service.dart';
import '../theme/rochy_theme.dart';
import '../views/story_detail_view.dart';
import 'editorial_image.dart';
import 'editors/node_editor_sheet.dart';
import 'map_location_picker_sheet.dart';
import 'google_maps_button.dart';
import 'open_street_map_layers.dart';

/// Mapa interactivo OpenStreetMap con GPS, lugares y pines georreferenciados.
class RochyRealMapTab extends ConsumerStatefulWidget {
  const RochyRealMapTab({super.key});

  @override
  ConsumerState<RochyRealMapTab> createState() => _RochyRealMapTabState();
}

class _RochyRealMapTabState extends ConsumerState<RochyRealMapTab> {
  static const _fallbackCenter = LatLng(10.4242, -75.5508);

  late final MapController _mapController;
  late final PageController _cardPageController;
  late final TextEditingController _searchCtrl;
  Timer? _searchDebounce;
  int _searchGeneration = 0;
  int _pointGeneration = 0;

  String? _selectedNodeId;
  LatLng? _myGpsPoint;
  bool _isLocating = false;

  // Pin temporal cuando el usuario busca o toca cualquier rincón del mapa.
  LatLng? _droppedPoint;
  String _droppedName = '';
  String _droppedSubtitle = '';
  bool _isResolvingDrop = false;

  // Buscador de lugares reales.
  bool _isSearching = false;
  List<PlaceSearchResult> _searchResults = const <PlaceSearchResult>[];

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _cardPageController = PageController(viewportFraction: 0.86);
    _searchCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _mapController.dispose();
    _cardPageController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String raw) {
    _searchDebounce?.cancel();
    final generation = ++_searchGeneration;
    final q = raw.trim();
    if (q.length < 2) {
      setState(() {
        _searchResults = const <PlaceSearchResult>[];
        _isSearching = false;
      });
      return;
    }
    setState(() => _isSearching = true);
    _searchDebounce = Timer(const Duration(milliseconds: 450), () async {
      final hits = await ref.read(locationServiceProvider).searchPlaces(q);
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _searchResults = hits;
        _isSearching = false;
      });
    });
  }

  void _selectSearchResult(PlaceSearchResult hit) {
    _searchDebounce?.cancel();
    _searchGeneration++;
    _pointGeneration++;
    HapticFeedback.selectionClick();
    FocusScope.of(context).unfocus();
    final target = LatLng(hit.latitude, hit.longitude);
    setState(() {
      _droppedPoint = target;
      _droppedName = hit.shortName;
      _droppedSubtitle = hit.subtitle;
      _searchResults = const <PlaceSearchResult>[];
      _isSearching = false;
      _isResolvingDrop = false;
    });
    _mapController.move(target, 16.0);
  }

  Future<void> _onMapTap(LatLng point) async {
    final generation = ++_pointGeneration;
    _searchDebounce?.cancel();
    _searchGeneration++;
    HapticFeedback.lightImpact();
    FocusScope.of(context).unfocus();
    setState(() {
      _droppedPoint = point;
      _droppedName = 'Identificando lugar…';
      _droppedSubtitle = LocationService.formatCoordinates(
        point.latitude,
        point.longitude,
      );
      _isSearching = false;
      _isResolvingDrop = true;
      _searchResults = const <PlaceSearchResult>[];
    });
    final resolved = await ref
        .read(locationServiceProvider)
        .reverseGeocode(point.latitude, point.longitude);
    if (!mounted || generation != _pointGeneration) return;
    setState(() {
      _isResolvingDrop = false;
      if (resolved != null) {
        _droppedName = resolved.shortName;
        _droppedSubtitle = resolved.subtitle.isNotEmpty
            ? resolved.subtitle
            : LocationService.formatCoordinates(
                point.latitude,
                point.longitude,
              );
      } else {
        _droppedName = 'Rincón en el mapa';
      }
    });
  }

  Future<void> _goToMyGps() async {
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
          content: Text(res.errorMessage ?? 'No se pudo obtener el GPS.'),
        ),
      );
      return;
    }

    final point = LatLng(res.latitude!, res.longitude!);
    setState(() {
      _isResolvingDrop = false;
      _myGpsPoint = point;
      _droppedPoint = point;
      _droppedName = res.placeName ?? 'Mi ubicación actual';
      _droppedSubtitle = res.subtitle ??
          LocationService.formatCoordinates(point.latitude, point.longitude);
    });
    _mapController.move(point, 16.0);
  }

  void _fitAllNodes(List<BentoNode> geoNodes) {
    HapticFeedback.selectionClick();
    final pts = <LatLng>[
      for (final n in geoNodes)
        if (n.mapCoordinates != null)
          LatLng(n.mapCoordinates!.lat, n.mapCoordinates!.lng),
      if (_myGpsPoint != null) _myGpsPoint!,
    ];
    if (pts.isEmpty) {
      _mapController.move(_fallbackCenter, 15.0);
      return;
    }
    if (pts.length == 1) {
      _mapController.move(pts.first, 15.8);
      return;
    }
    final bounds = LatLngBounds.fromPoints(pts);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.fromLTRB(54, 110, 54, 190),
      ),
    );
  }

  void _focusGeoNode(BentoNode node, int carouselIndex) {
    _pointGeneration++;
    final coords = node.mapCoordinates;
    if (coords == null) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selectedNodeId = node.id;
      _droppedPoint = null;
    });
    _mapController.move(LatLng(coords.lat, coords.lng), 16.2);
    if (_cardPageController.hasClients && carouselIndex >= 0) {
      _cardPageController.animateToPage(
        carouselIndex,
        duration: const Duration(milliseconds: 340),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _saveDroppedPointAsPin(RochyThemeData theme) async {
    final point = _droppedPoint;
    if (point == null) return;
    final cleanName =
        _droppedName.isEmpty || _droppedName == 'Identificando lugar…'
            ? 'Rincón especial'
            : _droppedName;

    await showNodeEditorSheet(
      context,
      ref,
      type: BentoNodeType.locationPin,
      initialLocation: PickedMapLocation(
        latitude: point.latitude,
        longitude: point.longitude,
        placeName: cleanName,
        coordinatesLabel: LocationService.formatCoordinates(
          point.latitude,
          point.longitude,
        ),
      ),
    );
    if (mounted) {
      setState(() => _droppedPoint = null);
    }
  }

  Future<void> _assignRealLocationToUnplaced(
    BentoNode node,
    RochyThemeData theme,
  ) async {
    final picked = await MapLocationPickerSheet.show(
      context,
      theme: theme,
      initialPlaceName: node.mapPlaceTitle,
    );
    if (picked == null || !mounted) return;

    final current = node.payload;
    if (current is LocationPinPayload) {
      final updated = node.copyWith(
        payload: current.copyWith(
          placeName: picked.placeName,
          coordinatesLabel: picked.coordinatesLabel,
          latitude: picked.latitude,
          longitude: picked.longitude,
        ),
      );
      ref.read(bentoCanvasProvider.notifier).updateNode(updated);
      _mapController.move(LatLng(picked.latitude, picked.longitude), 16.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canvas = ref.watch(bentoCanvasProvider);
    final theme = ref.watch(activeRochyThemeProvider);

    final geoNodes = canvas.nodes
        .where((n) => n.mapCoordinates != null)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final unplacedPins = canvas.nodes
        .where(
          (n) =>
              n.type == BentoNodeType.locationPin && n.mapCoordinates == null,
        )
        .toList();

    // Escuchar saltos desde tarjetas ("Ver en Mapa").
    ref.listen<String?>(
      bentoCanvasProvider.select((s) => s.focusedMapNodeId),
      (_, nextId) {
        if (nextId == null) return;
        final idx = geoNodes.indexWhere((n) => n.id == nextId);
        if (idx != -1) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _focusGeoNode(geoNodes[idx], idx);
            ref.read(bentoCanvasProvider.notifier).clearFocusedMapNode();
          });
        } else {
          ref.read(bentoCanvasProvider.notifier).clearFocusedMapNode();
        }
      },
    );

    final initialCenter = geoNodes.isNotEmpty
        ? LatLng(
            geoNodes.first.mapCoordinates!.lat,
            geoNodes.first.mapCoordinates!.lng,
          )
        : _fallbackCenter;

    final activeId =
        _selectedNodeId ?? (geoNodes.isNotEmpty ? geoNodes.first.id : null);

    return Stack(
      children: <Widget>[
        // Mapa interactivo real a pantalla completa
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: initialCenter,
            initialZoom: 15.2,
            minZoom: 2.5,
            maxZoom: 18.5,
            onTap: (_, latLng) => _onMapTap(latLng),
          ),
          children: <Widget>[
            const OpenStreetMapTiles(),
            MarkerLayer(
              markers: <Marker>[
                for (var i = 0; i < geoNodes.length; i++)
                  _buildMemoryMarker(
                    node: geoNodes[i],
                    index: i,
                    isSelected: geoNodes[i].id == activeId,
                    theme: theme,
                  ),
                if (_myGpsPoint != null)
                  Marker(
                    point: _myGpsPoint!,
                    width: 34,
                    height: 34,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF2B7DE9).withValues(alpha: 0.22),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2B7DE9),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                        ),
                      ),
                    ),
                  ),
                if (_droppedPoint != null)
                  Marker(
                    point: _droppedPoint!,
                    width: 48,
                    height: 48,
                    alignment: Alignment.topCenter,
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: theme.terracotta,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.2),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.28),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.add_location_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),

        OpenStreetMapAttribution(
          bottom: _droppedPoint != null ? 116 : (geoNodes.isNotEmpty ? 198 : 4),
        ),

        // Barra superior: buscador real + resultados + contador
        Positioned(
          top: 12,
          left: 16,
          right: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                decoration: BoxDecoration(
                  color: theme.ivorySurface.withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: theme.borderTint),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: _onSearchChanged,
                  style: RochyTypography.sansBody(
                    theme.inkPrimary,
                    fontSize: 13.5,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Buscar calle, café o ciudad real…',
                    hintStyle: RochyTypography.sansBody(
                      theme.inkSecondary.withValues(alpha: 0.72),
                      fontSize: 13.5,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: theme.brandAccent,
                      size: 20,
                    ),
                    suffixIcon: _isSearching
                        ? Padding(
                            padding: const EdgeInsets.all(13),
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
                                  Icons.close_rounded,
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
              if (_searchResults.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  constraints: const BoxConstraints(maxHeight: 220),
                  decoration: BoxDecoration(
                    color: theme.ivorySurface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: theme.borderTint),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.14),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: _searchResults.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: theme.borderTint),
                    itemBuilder: (context, idx) {
                      final hit = _searchResults[idx];
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
                )
              else ...<Widget>[
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: theme.ivorySurface.withValues(alpha: 0.94),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: theme.borderTint),
                        ),
                        child: Text(
                          '${geoNodes.length} lugares reales · Toca el mapa para fijar',
                          style: RochyTypography.metadata(
                            theme.inkPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (unplacedPins.isNotEmpty) ...<Widget>[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _assignRealLocationToUnplaced(
                            unplacedPins.first,
                            theme,
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 11,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: theme.terracotta,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'Ubicar "${unplacedPins.first.mapPlaceTitle}"',
                              style: RochyTypography.metadata(
                                Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        // Controles flotantes a la derecha (Mi GPS + Ver todos)
        Positioned(
          right: 16,
          bottom:
              _droppedPoint != null ? 186 : (geoNodes.isNotEmpty ? 210 : 24),
          child: Column(
            children: <Widget>[
              _MapRoundAction(
                icon: Icons.fit_screen_rounded,
                tooltip: 'Ver todos',
                theme: theme,
                onTap: () => _fitAllNodes(geoNodes),
              ),
              const SizedBox(height: 10),
              _MapRoundAction(
                icon: Icons.my_location_rounded,
                tooltip: 'Mi GPS',
                theme: theme,
                isLoading: _isLocating,
                accentColor: theme.brandAccent,
                onTap: _isLocating ? () {} : _goToMyGps,
              ),
            ],
          ),
        ),

        // Banner rápido para guardar un punto tocado o buscado en el mapa
        if (_droppedPoint != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: theme.ivorySurface,
                borderRadius: BorderRadius.circular(24),
                border:
                    Border.all(color: theme.brandAccent.withValues(alpha: 0.4)),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: theme.terracotta.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.add_location_alt_rounded,
                      color: theme.terracotta,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          _isResolvingDrop
                              ? 'Identificando rincón…'
                              : _droppedName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: RochyTypography.cardSerifTitle(
                            theme.inkPrimary,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          _droppedSubtitle,
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
                  GoogleMapsButton(
                    latitude: _droppedPoint!.latitude,
                    longitude: _droppedPoint!.longitude,
                  ),
                  IconButton(
                    onPressed: () {
                      _pointGeneration++;
                      setState(() => _droppedPoint = null);
                    },
                    icon: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: theme.inkSecondary,
                    ),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.brandAccent,
                      foregroundColor: Colors.white,
                      shape: const StadiumBorder(),
                    ),
                    onPressed: _isResolvingDrop
                        ? null
                        : () => _saveDroppedPointAsPin(theme),
                    child: const Text('Guardar'),
                  ),
                ],
              ),
            ),
          )
        else if (geoNodes.isNotEmpty)
          // Carrusel inferior de lugares reales guardados
          Positioned(
            left: 0,
            right: 0,
            bottom: 16,
            height: 176,
            child: PageView.builder(
              controller: _cardPageController,
              itemCount: geoNodes.length,
              onPageChanged: (idx) {
                final node = geoNodes[idx];
                final coords = node.mapCoordinates;
                if (coords != null) {
                  setState(() => _selectedNodeId = node.id);
                  _mapController.move(LatLng(coords.lat, coords.lng), 16.0);
                }
              },
              itemBuilder: (context, idx) {
                final node = geoNodes[idx];
                final coords = node.mapCoordinates!;
                final cover = node.mapCoverImage;
                final isSelected = node.id == activeId;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: GestureDetector(
                    onTap: () => _focusGeoNode(node, idx),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: theme.ivorySurface.withValues(alpha: 0.97),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color:
                              isSelected ? theme.brandAccent : theme.borderTint,
                          width: isSelected ? 1.6 : 1.0,
                        ),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.14),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        children: <Widget>[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: SizedBox(
                              width: 78,
                              height: double.infinity,
                              child: cover.isNotEmpty
                                  ? EditorialImage(
                                      imageUrl: cover,
                                      fallbackScene:
                                          EditorialFallbackScene.handsSunday,
                                    )
                                  : Container(
                                      color: theme.sage.withValues(alpha: 0.18),
                                      child: Icon(
                                        Icons.location_on_rounded,
                                        color: theme.sage,
                                        size: 28,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  node.mapPlaceTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: RochyTypography.cardSerifTitle(
                                    theme.inkPrimary,
                                    fontSize: 16.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  LocationService.formatCoordinates(
                                    coords.lat,
                                    coords.lng,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: RochyTypography.metadata(
                                    theme.brandAccent,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Expanded(
                                  child: Text(
                                    node.mapDescription,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: RochyTypography.sansBody(
                                      theme.inkSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: <Widget>[
                                    GoogleMapsButton(
                                        latitude: coords.lat,
                                        longitude: coords.lng),
                                    _MiniMapAction(
                                      label: 'Ver en lienzo',
                                      icon: Icons.grid_view_rounded,
                                      theme: theme,
                                      onTap: () {
                                        HapticFeedback.selectionClick();
                                        final notifier = ref.read(
                                          bentoCanvasProvider.notifier,
                                        );
                                        notifier.setTabIndex(0);
                                        notifier.toggleNodeFocus(node.id);
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                    if (node.type == BentoNodeType.photoHero)
                                      _MiniMapAction(
                                        label: 'Crónica',
                                        icon: Icons.auto_stories_rounded,
                                        theme: theme,
                                        onTap: () => Navigator.of(context).push(
                                          MaterialPageRoute<void>(
                                            builder: (_) => StoryDetailView(
                                                nodeId: node.id),
                                          ),
                                        ),
                                      )
                                    else
                                      _MiniMapAction(
                                        label: 'Editar',
                                        icon: Icons.edit_rounded,
                                        theme: theme,
                                        onTap: () => showNodeEditorSheet(
                                          context,
                                          ref,
                                          type: node.type,
                                          existingNode: node,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Marker _buildMemoryMarker({
    required BentoNode node,
    required int index,
    required bool isSelected,
    required RochyThemeData theme,
  }) {
    final coords = node.mapCoordinates!;
    final color = isSelected
        ? theme.brandAccent
        : (index.isEven ? theme.sage : theme.terracotta);
    final cover = node.mapCoverImage;

    return Marker(
      point: LatLng(coords.lat, coords.lng),
      width: 158,
      height: 62,
      alignment: Alignment.topCenter,
      child: GestureDetector(
        onTap: () => _focusGeoNode(node, index),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.fromLTRB(5, 4, 10, 4),
              decoration: BoxDecoration(
                color: isSelected ? color : theme.ivorySurface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: isSelected ? Colors.white : color,
                  width: isSelected ? 2.0 : 1.5,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black
                        .withValues(alpha: isSelected ? 0.28 : 0.16),
                    blurRadius: isSelected ? 14 : 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (cover.isNotEmpty)
                    ClipOval(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: EditorialImage(
                          imageUrl: cover,
                          fallbackScene: EditorialFallbackScene.handsSunday,
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.22)
                            : color.withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.location_on_rounded,
                        size: 14,
                        color: isSelected ? Colors.white : color,
                      ),
                    ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      node.mapPlaceTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: RochyTypography.sansTitle(
                        isSelected ? Colors.white : theme.inkPrimary,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 3,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapRoundAction extends StatelessWidget {
  const _MapRoundAction({
    required this.icon,
    required this.tooltip,
    required this.theme,
    required this.onTap,
    this.isLoading = false,
    this.accentColor,
  });

  final IconData icon;
  final String tooltip;
  final RochyThemeData theme;
  final VoidCallback onTap;
  final bool isLoading;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: theme.ivorySurface.withValues(alpha: 0.96),
        shape: const CircleBorder(),
        elevation: 6,
        shadowColor: Colors.black.withValues(alpha: 0.2),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: theme.borderTint),
            ),
            alignment: Alignment.center,
            child: isLoading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: accentColor ?? theme.brandAccent,
                    ),
                  )
                : Icon(
                    icon,
                    size: 21,
                    color: accentColor ?? theme.inkPrimary,
                  ),
          ),
        ),
      ),
    );
  }
}

class _MiniMapAction extends StatelessWidget {
  const _MiniMapAction({
    required this.label,
    required this.icon,
    required this.theme,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final RochyThemeData theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: theme.brandAccent.withValues(alpha: 0.11),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 12, color: theme.brandAccent),
            const SizedBox(width: 4),
            Text(
              label,
              style: RochyTypography.metadata(
                theme.brandAccent,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
