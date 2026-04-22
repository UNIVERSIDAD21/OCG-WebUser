import 'package:go_router/go_router.dart';

import '../../features/notifications/data/models/app_notification_model.dart';
import 'fcm_payload_router.dart';

class NotificationNavigationService {
  const NotificationNavigationService({
    FcmPayloadRouter? payloadRouter,
  }) : _payloadRouter = payloadRouter ?? const FcmPayloadRouter();

  final FcmPayloadRouter _payloadRouter;

  void openFromStoredNotification(
    GoRouter router,
    AppNotificationModel notification, {
    String? userRole,
  }) {
    _payloadRouter.routeFromPayload(
      router,
      notification.toRoutingPayload(),
      userRole: userRole,
    );
  }
}
