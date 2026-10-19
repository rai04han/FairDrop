// ============================================================================
// FairDrop — Models Unit Tests
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:fairdrop_app/models/user.dart';
import 'package:fairdrop_app/models/menu_item.dart';
import 'package:fairdrop_app/models/zone.dart';
import 'package:fairdrop_app/models/order.dart';
import 'package:fairdrop_app/models/pay_result.dart';
import 'package:fairdrop_app/models/pay_config.dart';

void main() {
  group('User and RiderProfile models', () {
    test('serializes and deserializes User with RiderProfile correctly', () {
      final userJson = {
        '_id': 'user_123',
        'name': 'Rahul Rider',
        'email': 'rahul@fairdrop.com',
        'role': 'rider',
        'phone': '9876543210',
        'address': {
          'label': 'Chinnakada, Kollam',
          'latitude': 8.8860,
          'longitude': 76.5920,
        },
        'rider_profile': {
          'vehicle_type': 'motorcycle',
          'vehicle_number': 'KL-02-AB-1234',
          'zone_id': 'zone_chk_1',
          'current_zone_id': 'zone_chk_1',
          'assigned_zone_code': 'KLM-CHK',
          'current_zone_code': 'KLM-CHK',
          'is_available': true,
          'is_online': true,
          'active_hours_today': 2.5,
          'safety_checklist_acknowledged': true,
          'shift_sessions': [
            {
              'started_at': '2026-10-19T08:00:00.000Z',
              'ended_at': '2026-10-19T10:30:00.000Z',
            }
          ],
        },
      };

      final user = User.fromJson(userJson);
      expect(user.id, 'user_123');
      expect(user.name, 'Rahul Rider');
      expect(user.role, 'rider');
      expect(user.address.latitude, 8.8860);
      expect(user.riderProfile, isNotNull);
      expect(user.riderProfile!.isOnline, isTrue);
      expect(user.riderProfile!.assignedZoneCode, 'KLM-CHK');
      expect(user.riderProfile!.shiftSessions.length, 1);
      expect(user.riderProfile!.shiftSessions.first.endedAt, isNotNull);

      final backToJson = user.toJson();
      expect(backToJson['id'], 'user_123');
      expect(backToJson['rider_profile']['vehicle_number'], 'KL-02-AB-1234');
    });
  });

  group('MenuItem model', () {
    test('serializes and deserializes MenuItem correctly', () {
      final itemJson = {
        '_id': 'item_1',
        'restaurant_id': 'rest_100',
        'name': 'Chicken Biryani',
        'price': 180.0,
        'prep_time_seconds': 30,
        'is_available': true,
        'created_at': '2026-10-19T10:00:00.000Z',
      };

      final item = MenuItem.fromJson(itemJson);
      expect(item.id, 'item_1');
      expect(item.restaurantId, 'rest_100');
      expect(item.name, 'Chicken Biryani');
      expect(item.price, 180.0);
      expect(item.prepTimeSeconds, 30);
      expect(item.isAvailable, isTrue);

      final copied = item.copyWith(isAvailable: false);
      expect(copied.isAvailable, isFalse);
      expect(copied.price, 180.0);
    });
  });

  group('Zone model', () {
    test('parses GeoJSON polygon and tests containment', () {
      final zoneJson = {
        '_id': 'zone_chk_1',
        'name': 'Chinnakada Central',
        'zone_id': 'KLM-CHK',
        'outOfZoneCapKm': 5.0,
        'returnCompensationIdleWindowMins': 15,
        'isActive': true,
        'boundary': {
          'type': 'Polygon',
          'coordinates': [
            [
              [76.58, 8.88],
              [76.60, 8.88],
              [76.60, 8.90],
              [76.58, 8.90],
              [76.58, 8.88],
            ]
          ]
        }
      };

      final zone = Zone.fromJson(zoneJson);
      expect(zone.id, 'zone_chk_1');
      expect(zone.name, 'Chinnakada Central');
      expect(zone.zoneId, 'KLM-CHK');
      expect(zone.polygonPoints.length, 5);

      final inside = LatLng(8.89, 76.59);
      final outside = LatLng(8.95, 76.65);
      expect(zone.contains(inside), isTrue);
      expect(zone.contains(outside), isFalse);
    });
  });

  group('Order model', () {
    test('serializes and computes subtotal and totalItems', () {
      final orderJson = {
        '_id': 'order_mongo_1',
        'order_id': 'ORD-20261019-0001',
        'customer_id': 'cust_1',
        'restaurant_id': 'rest_1',
        'rider_id': 'rider_1',
        'items': [
          {
            'item_id': 'item_1',
            'name': 'Chicken Biryani',
            'quantity': 2,
            'price': 180.0,
            'prep_time_seconds': 30,
          },
          {
            'item_id': 'item_2',
            'name': 'Lime Juice',
            'quantity': 1,
            'price': 30.0,
            'prep_time_seconds': 15,
          }
        ],
        'delivery_address': {
          'label': 'Pin A (Chinnakada)',
          'latitude': 8.8860,
          'longitude': 76.5920,
        },
        'restaurant_address': {
          'label': 'Hotel Allseason',
          'latitude': 8.8880,
          'longitude': 76.5910,
        },
        'distance_km': 1.25,
        'status': 'assigned',
        'rider_ack': 'pending',
        'is_out_of_zone': false,
        'out_of_zone_distance_km': 0.0,
        'pay_calculation_result': {
          'order_id': 'ORD-20261019-0001',
          'base_rate': 15.0,
          'distance_pay': 7.5,
          'surge_bonus': 0.0,
          'wait_compensation': 0.0,
          'total_delivery_pay': 22.5,
          'floor_topup': 0.0,
          'hourly_earnings_so_far': 45.0,
        }
      };

      final order = Order.fromJson(orderJson);
      expect(order.id, 'order_mongo_1');
      expect(order.orderId, 'ORD-20261019-0001');
      expect(order.items.length, 2);
      expect(order.totalItems, 3);
      expect(order.subtotal, 390.0);
      expect(order.isAssigned, isTrue);
      expect(order.isDelivered, isFalse);
      expect(order.deliveryAddress.toLatLng().latitude, 8.8860);
      expect(order.payCalculationResult, isNotNull);
      expect(order.payCalculationResult!.totalDeliveryPay, 22.5);
    });
  });

  group('PayResult and PayConfig models', () {
    test('computes totalWithTopup and breakdownLineItems on PayResult', () {
      final payResult = PayResult(
        orderId: 'ORD-20261019-0002',
        baseRate: 15.0,
        distancePay: 12.0,
        surgeBonus: 20.0,
        waitCompensation: 10.0,
        totalDeliveryPay: 57.0,
        floorTopup: 15.0,
        hourlyEarningsSoFar: 70.0,
      );

      expect(payResult.totalWithTopup, 72.0);
      final items = payResult.breakdownLineItems;
      expect(items.any((it) => it.label == 'Base Rate' && it.amount == 15.0), isTrue);
      expect(items.any((it) => it.label == 'Surge Bonus' && it.amount == 20.0), isTrue);
      expect(items.any((it) => it.label == 'Wait Compensation' && it.amount == 10.0), isTrue);
      expect(items.any((it) => it.label == 'Floor Top-Up' && it.amount == 15.0), isTrue);
      expect(items.any((it) => it.label == 'Total Payout' && it.amount == 72.0), isTrue);
    });

    test('parses PayConfig and PayConfigResponse', () {
      final configResponseJson = {
        'success': true,
        'active': {
          'config_id': 1,
          'base_rate': 15.0,
          'per_km_rate': 6.0,
          'surge_bonus': 20.0,
          'wait_threshold_mins': 1,
          'wait_compensation': 10.0,
          'min_wage_per_hour': 70.0,
          'effective_from': '2026-10-01',
          'is_active': 1,
        },
        'scheduled': {
          'config_id': 2,
          'base_rate': 18.0,
          'per_km_rate': 7.0,
          'surge_bonus': 25.0,
          'wait_threshold_mins': 1,
          'wait_compensation': 12.0,
          'min_wage_per_hour': 80.0,
          'effective_from': '2026-11-01',
          'is_active': 1,
        }
      };

      final response = PayConfigResponse.fromJson(configResponseJson);
      expect(response.active.baseRate, 15.0);
      expect(response.active.waitThresholdMins, 1);
      expect(response.scheduled, isNotNull);
      expect(response.scheduled!.baseRate, 18.0);
    });
  });
}
