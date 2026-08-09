import 'package:flutter_test/flutter_test.dart';

import '../lib/services/eating_session_controller.dart';

void main() {
  group('EatingSessionController', () {
    test(
      'requires two open palms, waits, and acknowledges a matching meal-before capture',
      () async {
        final commands = <MealCaptureCommand>[];
        final controller = EatingSessionController(
          settleDelay: Duration.zero,
          acknowledgementTimeout: const Duration(milliseconds: 100),
          sessionIdGenerator: () => 'meal_test_1',
          sendCapture: (command) async {
            commands.add(command);
            return true;
          },
        );
        addTearDown(controller.dispose);

        controller.onGesture('open_palm');
        expect(controller.state, EatingSessionState.idle);
        controller.onGesture('open_palm');
        expect(controller.state, EatingSessionState.starting);

        await _pumpTimers();
        expect(commands, hasLength(1));
        expect(commands.single.trigger, 'meal_start');
        expect(commands.single.scene, 'meal_before');
        expect(commands.single.mealSessionId, 'meal_test_1');

        expect(
          controller.onCaptureReceived(
            const MealCaptureAcknowledgement(
              captureType: 'food',
              scene: 'wrong_scene',
              mealSessionId: 'meal_test_1',
            ),
          ),
          isFalse,
        );
        expect(controller.state, EatingSessionState.starting);
        expect(
          controller.onCaptureReceived(
            const MealCaptureAcknowledgement(
              captureType: 'food',
              scene: 'meal_before',
              mealSessionId: 'meal_test_1',
            ),
          ),
          isTrue,
        );
        expect(controller.state, EatingSessionState.eating);
      },
    );

    test(
      'locks eating through unknown, no-hand, open-palm, and OK gestures',
      () async {
        final commands = <MealCaptureCommand>[];
        final controller = EatingSessionController(
          settleDelay: Duration.zero,
          sessionIdGenerator: () => 'meal_locked',
          sendCapture: (command) async {
            commands.add(command);
            return true;
          },
        );
        addTearDown(controller.dispose);

        controller.onGesture('open_palm');
        controller.onGesture('open_palm');
        await _pumpTimers();
        controller.onCaptureReceived(
          const MealCaptureAcknowledgement(
            captureType: 'food',
            scene: 'meal_before',
            mealSessionId: 'meal_locked',
          ),
        );
        expect(controller.state, EatingSessionState.eating);

        for (final gesture in const ['unknown', 'no_hand', 'open_palm', 'ok']) {
          controller.onGesture(gesture);
          expect(controller.state, EatingSessionState.eating);
        }
        expect(commands, hasLength(1));
      },
    );

    test(
      'requires two fists and pairs meal-after with the active session',
      () async {
        final commands = <MealCaptureCommand>[];
        final controller = EatingSessionController(
          settleDelay: Duration.zero,
          acknowledgementTimeout: const Duration(milliseconds: 100),
          sessionIdGenerator: () => 'meal_pair',
          sendCapture: (command) async {
            commands.add(command);
            return true;
          },
        );
        addTearDown(controller.dispose);

        controller.onGesture('open_palm');
        controller.onGesture('open_palm');
        await _pumpTimers();
        controller.onCaptureReceived(
          const MealCaptureAcknowledgement(
            captureType: 'food',
            scene: 'meal_before',
            mealSessionId: 'meal_pair',
          ),
        );

        controller.onGesture('fist');
        expect(controller.state, EatingSessionState.eating);
        controller.onGesture('fist');
        expect(controller.state, EatingSessionState.ending);
        await _pumpTimers();
        expect(commands, hasLength(2));
        expect(commands.last.trigger, 'meal_end');
        expect(commands.last.scene, 'meal_after');
        expect(commands.last.mealSessionId, 'meal_pair');

        expect(
          controller.onCaptureReceived(
            const MealCaptureAcknowledgement(
              captureType: 'food',
              scene: 'meal_after',
              mealSessionId: 'other_session',
            ),
          ),
          isFalse,
        );
        expect(controller.state, EatingSessionState.ending);
        expect(
          controller.onCaptureReceived(
            const MealCaptureAcknowledgement(
              captureType: 'food',
              scene: 'meal_after',
              mealSessionId: 'meal_pair',
            ),
          ),
          isTrue,
        );
        expect(controller.state, EatingSessionState.idle);
        expect(controller.lastCompletedSessionId, 'meal_pair');
      },
    );

    test(
      'send failure and acknowledgement timeout recover to the correct stable state',
      () async {
        var shouldSend = false;
        final controller = EatingSessionController(
          settleDelay: Duration.zero,
          acknowledgementTimeout: const Duration(milliseconds: 10),
          sessionIdGenerator: () => 'meal_failure',
          sendCapture: (_) async => shouldSend,
        );
        addTearDown(controller.dispose);

        controller.onGesture('open_palm');
        controller.onGesture('open_palm');
        await _pumpTimers();
        expect(controller.state, EatingSessionState.idle);
        expect(controller.errorMessage, '餐前抓拍失败，请重新张手开始');

        shouldSend = true;
        controller.onGesture('open_palm');
        controller.onGesture('open_palm');
        await _pumpTimers();
        await Future<void>.delayed(const Duration(milliseconds: 30));
        expect(controller.state, EatingSessionState.idle);

        controller.onGesture('open_palm');
        controller.onGesture('open_palm');
        await _pumpTimers();
        controller.onCaptureReceived(
          const MealCaptureAcknowledgement(
            captureType: 'food',
            scene: 'meal_before',
            mealSessionId: 'meal_failure',
          ),
        );
        controller.onGesture('fist');
        controller.onGesture('fist');
        await _pumpTimers();
        shouldSend = false;
        await Future<void>.delayed(const Duration(milliseconds: 30));
        expect(controller.state, EatingSessionState.eating);
      },
    );

    test('does not duplicate captures while starting or ending', () async {
      final commands = <MealCaptureCommand>[];
      final controller = EatingSessionController(
        settleDelay: Duration.zero,
        sessionIdGenerator: () => 'meal_single_command',
        sendCapture: (command) async {
          commands.add(command);
          return true;
        },
      );
      addTearDown(controller.dispose);

      controller.onGesture('open_palm');
      controller.onGesture('open_palm');
      controller.onGesture('open_palm');
      await _pumpTimers();
      expect(commands, hasLength(1));

      controller.onCaptureReceived(
        const MealCaptureAcknowledgement(
          captureType: 'food',
          scene: 'meal_before',
          mealSessionId: 'meal_single_command',
        ),
      );
      controller.onGesture('fist');
      controller.onGesture('fist');
      controller.onGesture('fist');
      await _pumpTimers();
      expect(commands, hasLength(2));
    });

    test('recovers to a stable state when connection is lost', () async {
      final controller = EatingSessionController(
        settleDelay: Duration.zero,
        sessionIdGenerator: () => 'meal_disconnect',
        sendCapture: (_) async => true,
      );
      addTearDown(controller.dispose);

      controller.onGesture('open_palm');
      controller.onGesture('open_palm');
      expect(controller.state, EatingSessionState.starting);
      controller.onConnectionLost();
      expect(controller.state, EatingSessionState.idle);
      expect(controller.errorMessage, '餐前抓拍失败，请重新张手开始');

      controller.onGesture('open_palm');
      controller.onGesture('open_palm');
      await _pumpTimers();
      controller.onCaptureReceived(
        const MealCaptureAcknowledgement(
          captureType: 'food',
          scene: 'meal_before',
          mealSessionId: 'meal_disconnect',
        ),
      );
      controller.onGesture('fist');
      controller.onGesture('fist');
      expect(controller.state, EatingSessionState.ending);
      controller.onConnectionLost();
      expect(controller.state, EatingSessionState.eating);
      expect(controller.errorMessage, '餐后抓拍失败，请再次握拳结束');
    });

    test('returns to eating when meal-after send fails', () async {
      var allowSend = true;
      final controller = EatingSessionController(
        settleDelay: Duration.zero,
        sessionIdGenerator: () => 'meal_end_send_failure',
        sendCapture: (_) async => allowSend,
      );
      addTearDown(controller.dispose);

      controller.onGesture('open_palm');
      controller.onGesture('open_palm');
      await _pumpTimers();
      controller.onCaptureReceived(
        const MealCaptureAcknowledgement(
          captureType: 'food',
          scene: 'meal_before',
          mealSessionId: 'meal_end_send_failure',
        ),
      );
      allowSend = false;
      controller.onGesture('fist');
      controller.onGesture('fist');
      await _pumpTimers();
      expect(controller.state, EatingSessionState.eating);
      expect(controller.errorMessage, '餐后抓拍失败，请再次握拳结束');
    });

    test('does not start on one open palm or an OK gesture', () {
      final commands = <MealCaptureCommand>[];
      final controller = EatingSessionController(
        sendCapture: (command) async {
          commands.add(command);
          return true;
        },
      );
      addTearDown(controller.dispose);

      controller.onGesture('open_palm');
      controller.onGesture('ok');
      expect(controller.state, EatingSessionState.idle);
      expect(commands, isEmpty);
    });
  });
}

Future<void> _pumpTimers() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}
