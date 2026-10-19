// ============================================================================
// FairDrop — Zone Map Screen (Screen 8)
// Based on Stitch Design Project #1184075210986276795
// (FairDrop - Zone Map & Hub Transitions)
// ============================================================================
// Displays Kollam delivery zones on OpenStreetMap using flutter_map (FR-26).
// Features:
//   - Uses canonical parseGeoJsonPolygon() from geo_utils.dart (FR-28)
//   - Visual distinction and highlighting for rider's active zone (FR-26)
//   - Out-of-zone delivery transition banner ("Zone Changed to KLM-PLY", FR-27, FR-73)
//   - Displays last delivery destination marker if available (FR-29)
//   - Shows statutory minimum wage floor (₹70/hr) and 5.0 km radius caps (FR-32)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import '../config/theme.dart';
import '../services/core_api_service.dart';
import '../utils/format_utils.dart';
import '../utils/geo_utils.dart';

class ZoneMapScreen extends StatefulWidget {
  final List<Map<String, dynamic>>? initialZones;
  final String? zoneChangedTo;
  final String? previousZone;
  final bool? isOutOfZoneTransition;
  final LatLng? lastDeliveryPoint;
  final bool enableTileLayer;
  final bool autoFetch;

  const ZoneMapScreen({
    super.key,
    this.initialZones,
    this.zoneChangedTo,
    this.previousZone,
    this.isOutOfZoneTransition,
    this.lastDeliveryPoint,
    this.enableTileLayer = true,
    this.autoFetch = true,
  });

  @override
  State<ZoneMapScreen> createState() => _ZoneMapScreenState();
}

class _ZoneMapScreenState extends State<ZoneMapScreen> {
  final MapController _mapController = MapController();
  List<Map<String, dynamic>> _zones = [];
  bool _argsLoaded = false;

  String? _activeZoneCode;
  String? _zoneChangedTo;
  String? _previousZone;
  bool _showZoneChangedBanner = false;
  LatLng? _lastDeliveryPoint;
  String? _selectedZoneCode;

  static const _kollamCenter = LatLng(8.8932, 76.5950);

  // Canonical fallback zones matching scripts/seed.js (PRD §10.1)
  static final List<Map<String, dynamic>> _kollamFallbackZones = [
    {
      'properties': {
        'name': 'Chinnakkada Hub',
        'zone_id': 'KLM-CHK',
        'outOfZoneCapKm': 5.0,
        'wage_floor': 70.0,
        'status': 'ACTIVE',
      },
      'geometry': {
        'type': 'Polygon',
        'coordinates': [
          [
            [76.5800, 8.8800],
            [76.6000, 8.8800],
            [76.6000, 8.8950],
            [76.5800, 8.8950],
            [76.5800, 8.8800],
          ]
        ],
      },
    },
    {
      'properties': {
        'name': 'Polayathode Hub',
        'zone_id': 'KLM-PLY',
        'outOfZoneCapKm': 5.0,
        'wage_floor': 70.0,
        'status': 'HIGH_DEMAND',
      },
      'geometry': {
        'type': 'Polygon',
        'coordinates': [
          [
            [76.6000, 8.8700],
            [76.6200, 8.8700],
            [76.6200, 8.8850],
            [76.6000, 8.8850],
            [76.6000, 8.8700],
          ]
        ],
      },
    },
    {
      'properties': {
        'name': 'Kilikolloor Hub',
        'zone_id': 'KLM-KLK',
        'outOfZoneCapKm': 5.0,
        'wage_floor': 70.0,
        'status': 'ACTIVE',
      },
      'geometry': {
        'type': 'Polygon',
        'coordinates': [
          [
            [76.6100, 8.8900],
            [76.6350, 8.8900],
            [76.6350, 8.9100],
            [76.6100, 8.9100],
            [76.6100, 8.8900],
          ]
        ],
      },
    },
  ];

  @override
  void initState() {
    super.initState();
    _zones = widget.initialZones ?? _kollamFallbackZones;
    _activeZoneCode = widget.zoneChangedTo ?? 'KLM-CHK';
    _zoneChangedTo = widget.zoneChangedTo;
    _previousZone = widget.previousZone;
    _showZoneChangedBanner = widget.isOutOfZoneTransition ?? (_zoneChangedTo != null);
    _lastDeliveryPoint = widget.lastDeliveryPoint;
    _selectedZoneCode = _activeZoneCode;

    if (widget.autoFetch && widget.initialZones == null) {
      _loadZones();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_argsLoaded) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic>) {
        final to = args['zoneChangedTo'] as String? ??
            args['newZone'] as String? ??
            args['zone_id'] as String?;
        final from = args['previousZone'] as String?;
        final isTransition = (args['isOutOfZoneTransition'] as bool?) ?? (to != null);

        if (to != null) {
          _zoneChangedTo = to;
          _activeZoneCode = to;
          _selectedZoneCode = to;
          _showZoneChangedBanner = isTransition;
        }
        if (from != null) {
          _previousZone = from;
        }
        if (args['lastDeliveryPoint'] is LatLng) {
          _lastDeliveryPoint = args['lastDeliveryPoint'] as LatLng;
        }
      } else if (args is String) {
        _zoneChangedTo = args;
        _activeZoneCode = args;
        _selectedZoneCode = args;
        _showZoneChangedBanner = true;
      }
      _argsLoaded = true;
    }
  }

  Future<void> _loadZones() async {
    try {
      final response = await CoreApiService.getZoneMap().timeout(const Duration(seconds: 2));
      final data = response['data'] as Map<String, dynamic>?;
      final features = data?['features'] as List<dynamic>? ?? [];

      if (features.isNotEmpty && mounted) {
        setState(() {
          _zones = features.cast<Map<String, dynamic>>();
        });
      }
    } catch (_) {
      // In offline/test mode, fallback zones remain
    }

    try {
      final me = await CoreApiService.getMe().timeout(const Duration(seconds: 2));
      final user = me['user'] as Map<String, dynamic>? ??
          me['data']?['user'] as Map<String, dynamic>?;

      if (user != null && mounted) {
        final assigned = user['assigned_zone']?.toString();
        final current = user['current_zone']?.toString() ??
            user['rider_profile']?['current_zone_code']?.toString();

        setState(() {
          if (_zoneChangedTo == null) {
            _activeZoneCode = current ?? assigned ?? _activeZoneCode;
            _selectedZoneCode = _activeZoneCode;
          }

          if (current != null && assigned != null && current != assigned && _zoneChangedTo == null) {
            _zoneChangedTo = current;
            _previousZone = assigned;
            _showZoneChangedBanner = true;
            _activeZoneCode = current;
            _selectedZoneCode = current;
          }
        });
      }
    } catch (_) {
      // In offline/test mode, fallback retained
    }
  }

  LatLng _calculateCentroid(List<LatLng> points) {
    if (points.isEmpty) return _kollamCenter;
    double sumLat = 0.0;
    double sumLng = 0.0;
    for (final p in points) {
      sumLat += p.latitude;
      sumLng += p.longitude;
    }
    return LatLng(sumLat / points.length, sumLng / points.length);
  }

  void _focusZone(String zoneId, List<LatLng> points) {
    setState(() {
      _selectedZoneCode = zoneId;
    });
    if (points.isNotEmpty) {
      final centroid = _calculateCentroid(points);
      _mapController.move(centroid, 14.2);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FairDropColors.mintBg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Bar ──────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.white,
              child: Row(
                children: [
                  IconButton(
                    key: const Key('zone_map_back_button'),
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_rounded, color: FairDropColors.brandNavy),
                  ),
                  const FairDropLogo(fontSize: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Kollam Zones',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: FairDropColors.brandNavy,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    key: const Key('active_zone_pill'),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: FairDropColors.brandGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: FairDropColors.brandGreen.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: FairDropColors.brandGreen,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _activeZoneCode ?? 'KLM-CHK',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: FairDropColors.brandGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Out of Zone Transition Banner (FR-27, FR-73, Demo Step 11) ───
            if (_showZoneChangedBanner)
              Container(
                key: const Key('zone_changed_banner'),
                margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
                  boxShadow: FairDropColors.cardShadow,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.swap_horiz_rounded,
                        color: Color(0xFFB45309),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFB45309),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'OUT-OF-ZONE TRANSITION',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Zone Changed: Your active zone is now ${_zoneChangedTo ?? _activeZoneCode ?? "KLM-PLY"}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF92400E),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Automatically updated from ${_previousZone ?? "KLM-CHK"} following your out-of-zone delivery. Statutory wage protection (₹70/hr floor) and 5.0 km cap remain active.',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF78350F),
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      key: const Key('dismiss_zone_banner_button'),
                      icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF92400E)),
                      onPressed: () {
                        setState(() {
                          _showZoneChangedBanner = false;
                        });
                      },
                    ),
                  ],
                ),
              ),

            // ── Map View & Bottom Sheet ──────────────────────────────────────
            Expanded(
              child: Stack(
                      children: [
                        FlutterMap(
                          mapController: _mapController,
                          options: const MapOptions(
                            initialCenter: _kollamCenter,
                            initialZoom: 13.5,
                          ),
                          children: [
                            if (widget.enableTileLayer)
                              TileLayer(
                                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'in.fairdrop.app',
                              ),

                            // Zone Polygons (FR-26, FR-28)
                            PolygonLayer(
                              polygons: _zones.map((zone) {
                                final points = parseGeoJsonPolygon(zone['geometry'] ?? zone['boundary']);
                                if (points.isEmpty) return null;

                                final props = zone['properties'] as Map<String, dynamic>? ?? {};
                                final zoneId = (props['zone_id'] ?? props['code'] ?? zone['zone_id'] ?? '').toString();
                                final name = props['name'] as String? ?? 'Zone';

                                final isActiveZone = _activeZoneCode != null &&
                                    zoneId.toUpperCase() == _activeZoneCode!.toUpperCase();

                                final Color color = isActiveZone
                                    ? FairDropColors.brandGreen
                                    : (zoneId == 'KLM-PLY'
                                        ? FairDropColors.brandOrange
                                        : FairDropColors.brandNavy);

                                return Polygon(
                                  points: points,
                                  color: isActiveZone
                                      ? FairDropColors.brandGreen.withValues(alpha: 0.32)
                                      : color.withValues(alpha: 0.15),
                                  borderColor: color,
                                  borderStrokeWidth: isActiveZone ? 3.5 : 2.0,
                                  label: isActiveZone ? '$name\n(ACTIVE: $zoneId)' : '$name ($zoneId)',
                                  labelStyle: TextStyle(
                                    color: color,
                                    fontWeight: isActiveZone ? FontWeight.w900 : FontWeight.w700,
                                    fontSize: isActiveZone ? 12 : 11,
                                  ),
                                );
                              }).whereType<Polygon>().toList(),
                            ),

                            // Last Delivery Endpoint Marker (FR-29)
                            if (_lastDeliveryPoint != null)
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: _lastDeliveryPoint!,
                                    width: 150,
                                    height: 80,
                                    child: Column(
                                      key: const Key('last_delivery_marker'),
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: FairDropColors.brandNavy,
                                            borderRadius: BorderRadius.circular(6),
                                            boxShadow: FairDropColors.cardShadow,
                                          ),
                                          child: Text(
                                            'Last Delivery (Pin B)',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                        const Icon(
                                          Icons.location_on_rounded,
                                          color: FairDropColors.brandOrange,
                                          size: 30,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),

                        // Bottom Floating Active Zones Sheet
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: 16,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: FairDropColors.floatingShadow,
                              border: Border.all(color: FairDropColors.mintBorder),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.explore_rounded,
                                          color: FairDropColors.brandGreen,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${_zones.length} Active Kollam Zones',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            color: FairDropColors.brandNavy,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: FairDropColors.mintBg,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: FairDropColors.mintBorder),
                                      ),
                                      child: Text(
                                        '₹70/hr Floor Protected',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: FairDropColors.brandGreen,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                SizedBox(
                                  height: 104,
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: _zones.length,
                                    itemBuilder: (ctx, i) {
                                      final z = _zones[i];
                                      final props = z['properties'] as Map<String, dynamic>? ?? {};
                                      final name = props['name'] as String? ?? 'Hub';
                                      final zoneId = (props['zone_id'] ?? props['code'] ?? z['zone_id'] ?? 'KLM-$i').toString();
                                      final capKm = (props['outOfZoneCapKm'] ?? z['outOfZoneCapKm'] ?? 5.0) as num;
                                      final points = parseGeoJsonPolygon(z['geometry'] ?? z['boundary']);

                                      final isActive = _activeZoneCode != null &&
                                          zoneId.toUpperCase() == _activeZoneCode!.toUpperCase();
                                      final isSelected = _selectedZoneCode != null &&
                                          zoneId.toUpperCase() == _selectedZoneCode!.toUpperCase();

                                      final color = isActive
                                          ? FairDropColors.brandGreen
                                          : (zoneId == 'KLM-PLY'
                                              ? FairDropColors.brandOrange
                                              : FairDropColors.brandNavy);

                                      return GestureDetector(
                                        key: Key('zone_card_$zoneId'),
                                        onTap: () => _focusZone(zoneId, points),
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 200),
                                          width: 220,
                                          margin: const EdgeInsets.only(right: 10),
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? color.withValues(alpha: 0.08)
                                                : FairDropColors.surfaceLow,
                                            borderRadius: BorderRadius.circular(14),
                                            border: Border.all(
                                              color: isSelected ? color : FairDropColors.mintBorder,
                                              width: isSelected ? 2.0 : 1.0,
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                    decoration: BoxDecoration(
                                                      color: color.withValues(alpha: 0.15),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Text(
                                                      zoneId,
                                                      style: GoogleFonts.plusJakartaSans(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.w800,
                                                        color: color,
                                                      ),
                                                    ),
                                                  ),
                                                  if (isActive)
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                      decoration: BoxDecoration(
                                                        color: FairDropColors.brandGreen,
                                                        borderRadius: BorderRadius.circular(6),
                                                      ),
                                                      child: Text(
                                                        'ACTIVE HUB',
                                                        style: GoogleFonts.plusJakartaSans(
                                                          fontSize: 8,
                                                          fontWeight: FontWeight.w900,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(height: 5),
                                              Text(
                                                name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: FairDropColors.brandNavy,
                                                ),
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                '${formatCurrency(70)}/hr floor • ${capKm}km cap',
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w500,
                                                  color: FairDropColors.slateMuted,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
