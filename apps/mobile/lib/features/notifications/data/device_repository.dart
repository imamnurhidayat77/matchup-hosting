import '../domain/device_record.dart';

/// Read/write contract for the current user's push-notification devices.
///
/// Both [LocalDeviceRepository] (in-memory, used while the backend is in
/// development or when Firebase isn't configured) and [RemoteDeviceRepository]
/// (calls `POST /api/devices`, `GET /api/devices/me`, `DELETE /api/devices/me/:deviceId`)
/// implement this interface, so the push-notification bootstrapper can
/// swap implementations at the provider layer.
abstract class DeviceRepository {
  /// Registers (or refreshes) a device for push notifications. Idempotent
  /// on the server: re-registering the same `deviceId` updates the stored
  /// `fcmToken` for the current user.
  Future<void> register(DeviceRecord device);

  /// Lists every device the current user has registered.
  Future<List<DeviceRecord>> list();

  /// Removes a device from the user's push-notification roster — call this
  /// on sign-out so the server stops sending notifications to a session
  /// that's no longer active.
  Future<void> delete(String deviceId);
}
