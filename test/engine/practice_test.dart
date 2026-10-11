import 'package:flutter_test/flutter_test.dart';
import 'package:k8_study/engine/practice.dart';

void main() {
  group('allocateByWeight', () {
    test('proportional to CKA weights (largest remainder)', () {
      final alloc = allocateByWeight(
        available: {
          'troubleshooting': 100,
          'cluster-arch': 100,
          'services-networking': 100,
          'workloads-scheduling': 100,
          'storage': 100,
        },
        weights: {
          'troubleshooting': 30,
          'cluster-arch': 25,
          'services-networking': 20,
          'workloads-scheduling': 15,
          'storage': 10,
        },
        total: 25,
      );
      // Quotas 7.5, 6.25, 5, 3.75, 2.5 → floors 7,6,5,3,2 (=23); the two
      // largest remainders (.75 workloads, .5 troubleshooting/storage → tie
      // broken by id) get +1.
      expect(alloc.values.fold<int>(0, (a, b) => a + b), 25);
      expect(alloc['workloads-scheduling'], 4);
      expect(alloc['cluster-arch'], 6);
      expect(alloc['services-networking'], 5);
      expect(alloc['storage']! + alloc['troubleshooting']!, 10);
    });

    test('normalises over domains that have questions only', () {
      final alloc = allocateByWeight(
        available: {'cluster-arch': 40},
        weights: {'cluster-arch': 25, 'storage': 10},
        total: 20,
      );
      expect(alloc, {'cluster-arch': 20});
    });

    test('shortfall in one domain is filled from others', () {
      final alloc = allocateByWeight(
        available: {'a': 2, 'b': 50, 'c': 50},
        weights: {'a': 50, 'b': 25, 'c': 25},
        total: 20,
      );
      expect(alloc['a'], 2);
      expect(alloc.values.fold<int>(0, (a, b) => a + b), 20);
    });

    test('zero-weight domains only used to cover a shortfall', () {
      final alloc = allocateByWeight(
        available: {'exam': 5, 'foundations': 30},
        weights: {'exam': 25, 'foundations': 0},
        total: 10,
      );
      expect(alloc, {'exam': 5, 'foundations': 5});
    });

    test('never exceeds total supply', () {
      final alloc = allocateByWeight(
          available: {'a': 3}, weights: {'a': 1}, total: 10);
      expect(alloc, {'a': 3});
    });
  });

  group('TestTimer', () {
    final start = DateTime(2026, 10, 11, 10);

    test('counts down from wall-clock time and expires', () {
      final t = TestTimer(startedAt: start, limit: const Duration(minutes: 30));
      expect(t.remaining(start.add(const Duration(minutes: 10))),
          const Duration(minutes: 20));
      expect(t.expired(start.add(const Duration(minutes: 29, seconds: 59))),
          isFalse);
      expect(t.expired(start.add(const Duration(minutes: 30))), isTrue);
      expect(t.remaining(start.add(const Duration(hours: 2))), Duration.zero);
    });

    test('timer off never expires', () {
      final t = TestTimer(startedAt: start, limit: null);
      expect(t.remaining(start.add(const Duration(days: 1))), isNull);
      expect(t.expired(start.add(const Duration(days: 1))), isFalse);
    });
  });

}
