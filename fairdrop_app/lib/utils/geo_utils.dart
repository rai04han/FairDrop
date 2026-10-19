// ============================================================================
// FairDrop — GeoJSON & Coordinate Utilities (FR-28, FR-70, D9)
// ============================================================================
// Canonical coordinate parsing and geometry utilities:
//   - Flips GeoJSON [longitude, latitude] to LatLng(latitude, longitude)
//   - Safely parses GeoJSON Polygons, Features, and raw coordinate arrays
//   - Computes straight-line haversine distance matching backend (FR-70)
//   - Point-in-polygon ray-casting test
// ============================================================================

import 'dart:math' as math;
import 'package:latlong2/latlong.dart';

/// Parses a GeoJSON polygon structure into a list of [LatLng] points.
///
/// Flips GeoJSON standard `[lng, lat]` coordinates into `LatLng(lat, lng)`
/// as required by `flutter_map` (FR-28).
///
/// Handles:
///   - Feature maps: `{ "type": "Feature", "geometry": { "coordinates": [...] } }`
///   - Geometry maps: `{ "type": "Polygon", "coordinates": [...] }`
///   - 3D coordinate arrays: `[[[lng, lat], [lng, lat], ...]]` (outer ring)
///   - 2D coordinate arrays: `[[lng, lat], [lng, lat], ...]`
///
/// Returns an empty list if input is invalid or malformed without throwing.
List<LatLng> parseGeoJsonPolygon(dynamic geoJson) {
  if (geoJson == null) return [];

  try {
    dynamic rawCoordinates;

    if (geoJson is Map) {
      if (geoJson.containsKey('geometry') && geoJson['geometry'] is Map) {
        rawCoordinates = geoJson['geometry']['coordinates'];
      } else if (geoJson.containsKey('coordinates')) {
        rawCoordinates = geoJson['coordinates'];
      }
    } else if (geoJson is List) {
      rawCoordinates = geoJson;
    }

    if (rawCoordinates is! List || rawCoordinates.isEmpty) {
      return [];
    }

    // Determine if nested ring (3D array) or outer ring (2D array)
    List<dynamic> ring;
    if (rawCoordinates[0] is List && rawCoordinates[0].isNotEmpty && rawCoordinates[0][0] is List) {
      // 3D array: take the outer ring [0]
      ring = rawCoordinates[0] as List<dynamic>;
    } else if (rawCoordinates[0] is List) {
      // 2D array: coordinates directly
      ring = rawCoordinates;
    } else {
      return [];
    }

    final List<LatLng> points = [];
    for (final item in ring) {
      if (item is List && item.length >= 2) {
        final lng = (item[0] as num).toDouble();
        final lat = (item[1] as num).toDouble();
        points.add(LatLng(lat, lng));
      }
    }

    return points;
  } catch (_) {
    return [];
  }
}

/// Parses coordinate representations into a single [LatLng] instance.
///
/// Accepts:
///   - List: `[lng, lat]`
///   - Map: `{"latitude": 8.88, "longitude": 76.59}` or `{"lat": 8.88, "lng": 76.59}`
LatLng? parseLatLng(dynamic coord) {
  if (coord == null) return null;

  try {
    if (coord is LatLng) return coord;

    if (coord is List && coord.length >= 2) {
      final lng = (coord[0] as num).toDouble();
      final lat = (coord[1] as num).toDouble();
      return LatLng(lat, lng);
    }

    if (coord is Map) {
      final lat = (coord['latitude'] ?? coord['lat']) as num?;
      final lng = (coord['longitude'] ?? coord['lng']) as num?;
      if (lat != null && lng != null) {
        return LatLng(lat.toDouble(), lng.toDouble());
      }
    }
  } catch (_) {
    return null;
  }
  return null;
}

/// Computes straight-line haversine distance between two coordinates in kilometers,
/// rounded to 2 decimal places (FR-70, D9).
double calculateDistanceKm(LatLng start, LatLng end) {
  const double earthRadiusKm = 6371.0;
  final dLat = _degToRad(end.latitude - start.latitude);
  final dLon = _degToRad(end.longitude - start.longitude);

  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_degToRad(start.latitude)) *
          math.cos(_degToRad(end.latitude)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);

  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  final distance = earthRadiusKm * c;
  return (distance * 100).round() / 100.0;
}

/// Tests whether [point] is inside the polygon perimeter formed by [polygonPoints]
/// using the ray-casting algorithm.
bool isPointInPolygon(LatLng point, List<LatLng> polygonPoints) {
  if (polygonPoints.length < 3) return false;

  bool inside = false;
  int j = polygonPoints.length - 1;

  for (int i = 0; i < polygonPoints.length; i++) {
    final pi = polygonPoints[i];
    final pj = polygonPoints[j];

    final intersect = ((pi.latitude > point.latitude) != (pj.latitude > point.latitude)) &&
        (point.longitude < (pj.longitude - pi.longitude) * (point.latitude - pi.latitude) /
                (pj.latitude - pi.latitude) +
            pi.longitude);

    if (intersect) inside = !inside;
    j = i;
  }

  return inside;
}

double _degToRad(double deg) => deg * (math.pi / 180.0);

/// Utility class exposing static helpers for coordinate and distance operations.
class GeoUtils {
  /// Computes straight-line haversine distance between two sets of coordinates in kilometers.
  static double haversineDistanceKm(double lat1, double lon1, double lat2, double lon2) {
    return calculateDistanceKm(LatLng(lat1, lon1), LatLng(lat2, lon2));
  }
}
