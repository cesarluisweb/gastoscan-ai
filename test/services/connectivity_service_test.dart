import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastoscan_ai/services/connectivity_service.dart';

void main() {
  group('ConnectivityService Tests', () {
    test('isConnected returns configured test value', () async {
      final offlineService = ConnectivityService(testConnected: false);
      expect(await offlineService.isConnected(), isFalse);

      final onlineService = ConnectivityService(testConnected: true);
      expect(await onlineService.isConnected(), isTrue);
    });

    test('onConnectivityChanged emits updates via testController', () async {
      final controller = StreamController<bool>.broadcast();
      final service = ConnectivityService(testController: controller);

      final events = <bool>[];
      final subscription = service.onConnectivityChanged.listen(events.add);

      controller.add(false);
      controller.add(true);
      await Future.delayed(const Duration(milliseconds: 10));

      expect(events, equals([false, true]));
      await subscription.cancel();
      await controller.close();
    });
  });
}
