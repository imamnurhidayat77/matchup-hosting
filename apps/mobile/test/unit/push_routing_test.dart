import 'package:flutter_test/flutter_test.dart';
import 'package:matchup_mobile/features/notifications/services/push_routing.dart';

void main() {
  group('PushPayload.parse', () {
    test('parses type + activityId', () {
      final p = PushPayload.parse(
        {'type': 'chat_message', 'activityId': 'a-1'},
        title: 'Hi',
      );
      expect(p, isNotNull);
      expect(p!.type, 'chat_message');
      expect(p.activityId, 'a-1');
      expect(p.title, 'Hi');
    });

    test('returns null without a type', () {
      expect(PushPayload.parse({}), isNull);
      expect(PushPayload.parse({'type': '  '}), isNull);
    });

    test('trims values and drops empty activityId', () {
      final p = PushPayload.parse({'type': ' system ', 'activityId': '  '});
      expect(p, isNotNull);
      expect(p!.type, 'system');
      expect(p.activityId, isNull);
    });
  });

  group('routeForPush', () {
    test('chat_message goes to the chat', () {
      expect(
        routeForPush(const PushPayload(type: 'chat_message', activityId: 'a-1')),
        '/chat/a-1',
      );
    });

    test('activity_completed goes to the review screen', () {
      expect(
        routeForPush(
            const PushPayload(type: 'activity_completed', activityId: 'a-2')),
        '/past-activity/a-2/review',
      );
    });

    test('join_request goes to manage', () {
      expect(
        routeForPush(const PushPayload(type: 'join_request', activityId: 'a-3')),
        '/manage-activity/a-3',
      );
    });

    test('activity events go to detail', () {
      expect(
        routeForPush(const PushPayload(type: 'activity_joined', activityId: 'a-4')),
        '/activity/a-4',
      );
    });

    test('missing activityId falls back to notifications feed', () {
      expect(routeForPush(const PushPayload(type: 'chat_message')), '/notifications');
      expect(routeForPush(const PushPayload(type: 'system')), '/notifications');
    });
  });
  group('dm_message routing', () {
    test('parses senderUid', () {
      final p = PushPayload.parse(
        {'type': 'dm_message', 'senderUid': 'u-9'},
        title: 'New message from Sam',
      );
      expect(p, isNotNull);
      expect(p!.senderUid, 'u-9');
    });

    test('dm_message goes to the DM thread', () {
      expect(
        routeForPush(const PushPayload(type: 'dm_message', senderUid: 'u-9')),
        '/dm/u-9',
      );
    });

    test('dm_message without sender falls back to feed', () {
      expect(
        routeForPush(const PushPayload(type: 'dm_message')),
        '/notifications',
      );
    });
  });
}
