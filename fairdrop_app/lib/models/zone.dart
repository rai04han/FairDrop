// ============================================================================
// FairDrop — Zone Model (FR-28, FR-73, D3, D9)
// ============================================================================
// Represents geographical delivery zones with GeoJSON boundaries.
// Automatically flips GeoJSON [lng, lat] to LatLng(lat, lng) for flutter_map.
// ============================================================================

import 'package:latlong2/latlong.dart';
import '../utils/geo_utils.dart';

class Zone {
  final String id;
  final String name;
  final String? zoneId; // e.g., 'KLM-CHK', 'KLM-PLY', 'KLM-EVD'
  final dynamic boundary; // Raw GeoJSON polygon
  final List<LatLng> polygonPoints;
  final double outOfZoneCapKm;
  final int returnCompensationIdleWindowMins;
  final bool isActive;
  final List<String> adjacentZones;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Zone({
    required this.id,
    required this.name,
    this.zoneId,
    this.boundary,
    List<LatLng>? polygonPoints,
    this.outOfZoneCapKm = 5.0,
    this.returnCompensationIdleWindowMins = 15,
    this.isActive = true,
    this.adjacentZones = const [],
    this.createdAt,
    this.updatedAt,
  }) : polygonPoints = polygonPoints ?? parseGeoJsonPolygon(boundary);

  factory Zone.fromJson(Map<String, dynamic> json) {
    final rawBoundary = json['boundary'];
    final parsedPoints = parseGeoJsonPolygon(rawBoundary);

    final rawAdj = json['adjacentZones'] as List<dynamic>? ?? [];
    final adjList = rawAdj.map((e) => e.toString()).toList();

    return Zone(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      name: json['name'] as String? ?? '',
      zoneId: json['zone_id'] as String?,
      boundary: rawBoundary,
      polygonPoints: parsedPoints,
      outOfZoneCapKm: (json['outOfZoneCapKm'] as num?)?.toDouble() ?? 5.0,
      returnCompensationIdleWindowMins:
          (json['returnCompensationIdleWindowMins'] as num?)?.toInt() ?? 15,
      isActive: json['isActive'] as bool? ?? true,
      adjacentZones: adjList,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      '_id': id,
      'name': name,
      if (zoneId != null) 'zone_id': zoneId,
      if (boundary != null) 'boundary': boundary,
      'outOfZoneCapKm': outOfZoneCapKm,
      'returnCompensationIdleWindowMins': returnCompensationIdleWindowMins,
      'isActive': isActive,
      'adjacentZones': adjacentZones,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  /// Checks if [point] is inside this zone boundary.
  bool contains(LatLng point) {
    return isPointInPolygon(point, polygonPoints);
  }
}
