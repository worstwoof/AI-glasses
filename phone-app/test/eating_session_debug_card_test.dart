import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_glasses_nutrition_app/services/capture_coordinator.dart';
import 'package:ai_glasses_nutrition_app/services/capture_mode_controller.dart';
import 'package:ai_glasses_nutrition_app/services/eating_session_controller.dart';
import 'package:ai_glasses_nutrition_app/services/eating_session_debug_card.dart';
import 'package:ai_glasses_nutrition_app/services/glass_receiver_service.dart';
import 'package:ai_glasses_nutrition_app/services/phone_scene_classifier.dart';

void main() {
  testWidgets(
    'shows capture counts, coordinator status, and active-session cancel',
    (tester) async {
      var cancelCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EatingSessionDebugCard(
              snapshot: _snapshot(),
              onCancel: () => cancelCount += 1,
            ),
          ),
        ),
      );

      expect(find.text('采集模式：手动'), findsOneWidget);
      expect(find.text('已采集：餐前 0 · 餐中 0 · 餐后 0'), findsOneWidget);
      expect(find.text('Capture Coordinator'), findsOneWidget);
      expect(find.text('当前任务：meal_during'), findsOneWidget);
      expect(find.text('状态：waitingAck · 队列：1'), findsOneWidget);

      await tester.tap(find.text('取消当前进食采集'));
      expect(cancelCount, 1);
    },
  );
}

GlassReceiverSnapshot _snapshot() {
  return GlassReceiverSnapshot(
    running: false,
    port: null,
    localIps: const [],
    token: '',
    serverMessage: '',
    peerState: '',
    iceState: '',
    controlReady: false,
    remoteVideoReady: false,
    statsText: '',
    connectingGlasses: false,
    glassesMessage: '',
    glassesIp: null,
    sceneClassification: PhoneSceneClassification.waiting,
    sceneFrameCount: 0,
    lastCapture: null,
    mealBeforeCapture: null,
    mealDuringCaptures: const [],
    mealAfterCapture: null,
    captureMode: CaptureMode.manual,
    automaticCaptureAvailable: false,
    automaticCaptureUnavailableReason: '食品场景模型未加载，自动采集不可用。',
    foodProbability: 0.91,
    foodModelAvailable: true,
    foodModelMessage: '食品模型已加载',
    autoMealMessage: '进餐中，等待自动结束候选',
    autoNoHandFrames: 0,
    autoStableFrames: 0,
    mealAfterCandidateCapture: null,
    eatingSession: const EatingSessionSnapshot(
      state: EatingSessionState.eating,
      mealSessionId: 'meal_debug',
      lastCompletedSessionId: null,
      pendingScene: null,
      pendingTaskId: null,
      errorMessage: null,
    ),
    captureCoordinator: const CaptureCoordinatorSnapshot(
      state: CaptureTaskState.waitingAck,
      taskId: 'capture_debug',
      scene: 'meal_during',
      queueLength: 1,
    ),
    error: null,
  );
}
