import 'package:flutter/material.dart';

import 'eating_session_controller.dart';
import 'glass_receiver_service.dart';

class EatingSessionDebugCard extends StatelessWidget {
  const EatingSessionDebugCard({
    super.key,
    required this.snapshot,
    this.onCancel,
  });

  final GlassReceiverSnapshot snapshot;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final session = snapshot.eatingSession;
    final scheme = Theme.of(context).colorScheme;
    final color = switch (session.state) {
      EatingSessionState.idle => scheme.primary,
      EatingSessionState.starting => const Color(0xFFE39B64),
      EatingSessionState.eating => const Color(0xFF2A9D76),
      EatingSessionState.ending => const Color(0xFFE57E67),
    };
    final sessionId = session.mealSessionId ?? session.lastCompletedSessionId;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.restaurant_rounded, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Eating Session · ${session.displayState}',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: color),
                ),
              ),
              if (session.pendingScene != null)
                Text(
                  session.pendingScene!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          if (sessionId != null) ...[
            const SizedBox(height: 8),
            SelectableText(
              'mealSessionId  $sessionId',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 8),
          Text(
            '采集模式：${_captureModeLabel(snapshot.captureMode.name)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Text(
            '已采集：餐前 ${snapshot.mealBeforeCapture == null ? 0 : 1} · '
            '餐中 ${snapshot.mealDuringCaptures.length} · '
            '餐后 ${snapshot.mealAfterCapture == null ? 0 : 1}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (session.errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              session.errorMessage!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFFE57E67),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const Divider(height: 24),
          Row(
            children: [
              Icon(Icons.tune_rounded, color: scheme.secondary, size: 18),
              const SizedBox(width: 8),
              Text(
                'Capture Coordinator',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            '当前任务：${snapshot.captureCoordinator.scene ?? '无'}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Text(
            '状态：${snapshot.captureCoordinator.state?.name ?? 'idle'} · '
            '队列：${snapshot.captureCoordinator.queueLength}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (snapshot.captureCoordinator.taskId != null) ...[
            const SizedBox(height: 2),
            SelectableText(
              'taskId  ${snapshot.captureCoordinator.taskId}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (session.state != EatingSessionState.idle && onCancel != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: onCancel,
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('取消当前进食采集'),
              ),
            ),
          ],
          if (snapshot.mealBeforeCapture != null ||
              snapshot.mealAfterCapture != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _CaptureThumb(
                    label: 'meal_before',
                    capture: snapshot.mealBeforeCapture,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _CaptureThumb(
                    label: 'meal_after',
                    capture: snapshot.mealAfterCapture,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

String _captureModeLabel(String mode) => switch (mode) {
  'manual' => '手动',
  'automatic' => '自动',
  'hybrid' => '混合',
  _ => mode,
};

class _CaptureThumb extends StatelessWidget {
  const _CaptureThumb({required this.label, required this.capture});

  final String label;
  final GlassCapture? capture;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 5),
        AspectRatio(
          aspectRatio: 4 / 3,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: capture == null
                ? ColoredBox(
                    color: scheme.surfaceContainerHighest,
                    child: Icon(Icons.photo_outlined, color: scheme.outline),
                  )
                : Image.file(capture!.imageFile, fit: BoxFit.cover),
          ),
        ),
      ],
    );
  }
}
