import 'package:flutter/material.dart';

import 'eating_session_controller.dart';
import 'glass_receiver_service.dart';

class EatingSessionDebugCard extends StatelessWidget {
  const EatingSessionDebugCard({super.key, required this.snapshot});

  final GlassReceiverSnapshot snapshot;

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
