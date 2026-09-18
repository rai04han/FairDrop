// ============================================================================
// FairDrop — Zone Map Screen
// ============================================================================
// Owner: Hari (25MCA025)
//
// Displays Kollam delivery zones on an OpenStreetMap using flutter_map.
// Fetches GeoJSON FeatureCollection from GET /api/zones/map and renders
// each zone as a colored polygon with a label.

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/core_api_service.dart';

class ZoneMapScreen extends StatefulWidget {
  const ZoneMapScreen({super.key});

  @override
  State<ZoneMapScreen> createState() => _ZoneMapScreenState();
}

class _ZoneMapScreenState extends State<ZoneMapScreen> {
  List<Map<String, dynamic>> _zones = [];
  bool _isLoading = true;
  String? _error;

  // Kollam city center coordinates
  static const _kollamCenter = LatLng(8.8932, 76.5950);

  // Colors for each zone polygon
  final _zoneColors = [
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.red,
    Colors.teal,
  ];

  @override
  void initState() {
    super.initState();
    _loadZones();
  }

  Future<void> _loadZones() async {
    try {
      final response = await CoreApiService.getZoneMap();
      final features = response['data']['features'] as List<dynamic>;

      setState(() {
        _zones = features.cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _error = e.body['message'] ?? 'Failed to load zones';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Cannot connect to server. Is it running on port 3003?';
        _isLoading = false;
      });
    }
  }

  /// Convert GeoJSON coordinates [lng, lat] to LatLng objects for flutter_map
  List<LatLng> _parsePolygon(Map<String, dynamic> geometry) {
    // GeoJSON Polygon: coordinates[0] = outer ring as [[lng, lat], ...]
    final coords = geometry['coordinates'][0] as List<dynamic>;
    return coords.map<LatLng>((point) {
      final p = point as List<dynamic>;
      return LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery Zones — Kollam'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _isLoading = true);
              _loadZones();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
                      const SizedBox(height: 16),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () {
                          setState(() {
                            _isLoading = true;
                            _error = null;
                          });
                          _loadZones();
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // ── Map ─────────────────────────────────────────────
                    Expanded(
                      child: FlutterMap(
                        options: MapOptions(
                          initialCenter: _kollamCenter,
                          initialZoom: 13.5,
                        ),
                        children: [
                          // OpenStreetMap tile layer
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'in.fairdrop.app',
                          ),

                          // Zone polygons
                          PolygonLayer(
                            polygons: _zones.asMap().entries.map((entry) {
                              final index = entry.key;
                              final zone = entry.value;
                              final color = _zoneColors[index % _zoneColors.length];
                              final points = _parsePolygon(zone['geometry']);
                              final name = zone['properties']['name'] as String;

                              return Polygon(
                                points: points,
                                color: color.withAlpha(51),  // 20% opacity fill
                                borderColor: color,
                                borderStrokeWidth: 2.5,
                                label: name,
                                labelStyle: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),

                    // ── Zone list ───────────────────────────────────────
                    Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerLow,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                            child: Row(
                              children: [
                                Icon(Icons.map, color: theme.colorScheme.primary),
                                const SizedBox(width: 8),
                                Text(
                                  '${_zones.length} Active Zones',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            height: 100,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              itemCount: _zones.length,
                              itemBuilder: (context, index) {
                                final props = _zones[index]['properties'];
                                final color = _zoneColors[index % _zoneColors.length];
                                return Card(
                                  margin: const EdgeInsets.all(4),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              width: 12, height: 12,
                                              decoration: BoxDecoration(
                                                color: color,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              props['name'] as String,
                                              style: theme.textTheme.titleSmall?.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Cap: ${props['outOfZoneCapKm']} km',
                                          style: theme.textTheme.bodySmall,
                                        ),
                                        Text(
                                          'Return window: ${props['returnCompensationIdleWindowMins']} min',
                                          style: theme.textTheme.bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}
