// ============================================================================
// FairDrop — Geo Utils Unit Tests
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:fairdrop_app/utils/geo_utils.dart';

void main() {
  group('parseGeoJsonPolygon', () {
    test('handles null and invalid inputs gracefully', () {
      expect(parseGeoJsonPolygon(null), isEmpty);
      expect(parseGeoJsonPolygon({}), isEmpty);
      expect(parseGeoJsonPolygon([]), isEmpty);
      expect(parseGeoJsonPolygon('invalid'), isEmpty);
    });

    test('flips GeoJSON [lng, lat] to LatLng(lat, lng) from 3D array (outer ring)', () {
      final rawCoords = [
        [
          [76.58, 8.88],
          [76.60, 8.88],
          [76.60, 8.90],
          [76.58, 8.90],
          [76.58, 8.88],
        ]
      ];

      final points = parseGeoJsonPolygon(rawCoords);
      expect(points.length, 5);
      expect(points.first.latitude, 8.88);
      expect(points.first.longitude, 76.58);
      expect(points[2].latitude, 8.90);
      expect(points[2].longitude, 76.60);
    });

    test('parses Geometry object with coordinates', () {
      final geometry = {
        'type': 'Polygon',
        'coordinates': [
          [
            [76.5920, 8.8860],
            [76.5950, 8.8860],
            [76.5950, 8.8900],
            [76.5920, 8.8860],
          ]
        ]
      };

      final points = parseGeoJsonPolygon(geometry);
      expect(points.length, 4);
      expect(points.first.latitude, 8.8860);
      expect(points.first.longitude, 76.5920);
    });

    test('parses Feature object with geometry', () {
      final feature = {
        'type': 'Feature',
        'geometry': {
          'type': 'Polygon',
          'coordinates': [
            [
              [76.5920, 8.8860],
              [76.6000, 8.8860],
              [76.5920, 8.8860],
            ]
          ]
        }
      };

      final points = parseGeoJsonPolygon(feature);
      expect(points.length, 3);
      expect(points[1].latitude, 8.8860);
      expect(points[1].longitude, 76.6000);
    });
  });

  group('parseLatLng', () {
    test('parses [lng, lat] list and flips to LatLng(lat, lng)', () {
      final result = parseLatLng([76.5920, 8.8860]);
      expect(result, isNotNull);
      expect(result!.latitude, 8.8860);
      expect(result.longitude, 76.5920);
    });

    test('parses Map with latitude and longitude keys', () {
      final result = parseLatLng({'latitude': 8.8860, 'longitude': 76.5920});
      expect(result, isNotNull);
      expect(result!.latitude, 8.8860);
      expect(result.longitude, 76.5920);
    });

    test('parses Map with lat and lng keys', () {
      final result = parseLatLng({'lat': 8.8860, 'lng': 76.5920});
      expect(result, isNotNull);
      expect(result!.latitude, 8.8860);
      expect(result.longitude, 76.5920);
    });

    test('handles null and invalid inputs gracefully', () {
      expect(parseLatLng(null), isNull);
      expect(parseLatLng([]), isNull);
      expect(parseLatLng({}), isNull);
      expect(parseLatLng('invalid'), isNull);
    });
  });

  group('calculateDistanceKm', () {
    test('computes straight-line haversine distance matching backend (FR-70)', () {
      // Pin A: [76.5920, 8.8860] (lng, lat) -> lat 8.8860, lng 76.5920
      // Pin B: [76.6050, 8.8800] (lng, lat) -> lat 8.8800, lng 76.6050
      final pinA = LatLng(8.8860, 76.5920);
      final pinB = LatLng(8.8800, 76.6050);

      final distance = calculateDistanceKm(pinA, pinB);
      // Expected distance is approximately 1.58 km
      expect(distance, greaterThan(1.4));
      expect(distance, lessThan(1.8));
    });

    test('returns 0 for identical points', () {
      final p = LatLng(8.8860, 76.5920);
      expect(calculateDistanceKm(p, p), 0.0);
    });
  });

  group('isPointInPolygon', () {
    final squarePolygon = [
      LatLng(8.88, 76.58),
      LatLng(8.88, 76.60),
      LatLng(8.90, 76.60),
      LatLng(8.90, 76.58),
      LatLng(8.88, 76.58),
    ];

    test('identifies point inside polygon', () {
      final insidePoint = LatLng(8.89, 76.59);
      expect(isPointInPolygon(insidePoint, squarePolygon), isTrue);
    });

    test('identifies point outside polygon', () {
      final outsidePoint = LatLng(8.95, 76.65);
      expect(isPointInPolygon(outsidePoint, squarePolygon), isFalse);
    });

    test('returns false for polygons with fewer than 3 vertices', () {
      expect(isPointInPolygon(LatLng(8.89, 76.59), []), isFalse);
      expect(isPointInPolygon(LatLng(8.89, 76.59), [LatLng(8.88, 76.58)]), isFalse);
    });
  });
}
