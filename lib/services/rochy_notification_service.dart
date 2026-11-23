import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final rochyNotificationServiceProvider =
    Provider<RochyNotificationService>((ref) {
  return RochyNotificationService();
});

/// Notificaciones locales en Android/iOS para avisar al instante
/// cuando tu pareja agrega o actualiza recuerdos en la sala compartida.
class RochyNotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const String _channelId = 'rochy_couple_updates';
  static const String _channelName = 'Cambios de tu pareja';
  static const String _channelDesc =
      'Avisos cuando tu pareja agrega o edita tarjetas en Rochy.';

  Future<void> ensureInitialized({bool requestPermission = false}) async {
    if (kIsWeb) return;
    try {
      if (!_initialized) {
        const androidInit =
            AndroidInitializationSettings('@mipmap/ic_launcher');
        const iosInit = DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        );
        await _plugin.initialize(
          const InitializationSettings(
            android: androidInit,
            iOS: iosInit,
          ),
        );
        _initialized = true;
      }

      if (requestPermission) {
        final androidImpl = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        await androidImpl?.requestNotificationsPermission();

        final iosImpl = _plugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
        await iosImpl?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
      }
    } on MissingPluginException {
      // Entorno sin canal nativo.
    } catch (_) {}
  }

  Future<void> showPartnerChangeNotification({
    required String partnerName,
    required int addedNodes,
    required int updatedNodes,
    String? roomLabel,
  }) async {
    if (kIsWeb) return;
    try {
      await ensureInitialized();
      final who = partnerName.trim().isEmpty ? 'Tu pareja' : partnerName.trim();

      final String body;
      if (addedNodes > 0 && updatedNodes > 0) {
        body =
            'Agregó $addedNodes recuerdo(s) nuevo(s) y actualizó $updatedNodes en su cuaderno compartido.';
      } else if (addedNodes > 0) {
        body = addedNodes == 1
            ? 'Agregó un recuerdo nuevo en su cuaderno compartido.'
            : 'Agregó $addedNodes recuerdos nuevos en su cuaderno compartido.';
      } else if (updatedNodes > 0) {
        body = updatedNodes == 1
            ? 'Editó o respondió una tarjeta en su cuaderno compartido.'
            : 'Actualizó $updatedNodes tarjetas en su cuaderno compartido.';
      } else {
        body = 'Hizo un cambio en su espacio compartido de Rochy.';
      }

      const androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.high,
        priority: Priority.high,
        ticker: 'Rochy',
      );
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final notificationId =
          DateTime.now().millisecondsSinceEpoch.remainder(100000);
      await _plugin.show(
        notificationId,
        '$who actualizó Rochy ♥',
        body,
        const NotificationDetails(android: androidDetails, iOS: iosDetails),
      );
    } on MissingPluginException {
      // Ignorado sin canal nativo.
    } catch (_) {}
  }
}
