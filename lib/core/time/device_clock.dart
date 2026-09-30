import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A device wall-clock reading (ADR-023). The device clock is not trusted on
/// its own; later phases add server-offset and anomaly information. Business
/// date rules are open question Q6 (Phase 8).
final class DeviceInstant {
  const DeviceInstant({
    required this.utcMicros,
    required this.utcOffsetMinutes,
  });

  /// Microseconds since the Unix epoch, UTC.
  final int utcMicros;

  /// Device time-zone offset from UTC at that instant, in minutes.
  final int utcOffsetMinutes;
}

/// Source of device time; injected so tests are deterministic.
abstract interface class DeviceClock {
  DeviceInstant now();
}

class SystemDeviceClock implements DeviceClock {
  const SystemDeviceClock();

  @override
  DeviceInstant now() {
    final local = DateTime.now();
    return DeviceInstant(
      utcMicros: local.toUtc().microsecondsSinceEpoch,
      utcOffsetMinutes: local.timeZoneOffset.inMinutes,
    );
  }
}

final deviceClockProvider = Provider<DeviceClock>(
  (ref) => const SystemDeviceClock(),
);
