import 'package:flutter_test/flutter_test.dart';

import 'package:ai_glasses_nutrition_app/services/capture_upload_deduplicator.dart';

void main() {
  test('deduplicates completed and in-flight uploads by capture task ID', () {
    final deduplicator = CaptureUploadDeduplicator(completedHistoryLimit: 2);

    expect(deduplicator.begin('task_1'), CaptureUploadDisposition.firstDelivery);
    expect(deduplicator.begin('task_1'), CaptureUploadDisposition.inFlightDuplicate);
    deduplicator.complete('task_1');
    expect(deduplicator.begin('task_1'), CaptureUploadDisposition.completedDuplicate);

    expect(deduplicator.begin('task_2'), CaptureUploadDisposition.firstDelivery);
    deduplicator.fail('task_2');
    expect(deduplicator.begin('task_2'), CaptureUploadDisposition.firstDelivery);
  });

  test('keeps legacy uploads without a task ID compatible', () {
    final deduplicator = CaptureUploadDeduplicator();

    expect(deduplicator.begin(null), CaptureUploadDisposition.firstDelivery);
    expect(deduplicator.begin(''), CaptureUploadDisposition.firstDelivery);
  });

  test('keeps a committed upload deduplicated after response delivery fails', () {
    final deduplicator = CaptureUploadDeduplicator();

    expect(deduplicator.begin('task_committed'), CaptureUploadDisposition.firstDelivery);
    deduplicator.complete('task_committed');
    deduplicator.fail('task_committed');

    expect(
      deduplicator.begin('task_committed'),
      CaptureUploadDisposition.completedDuplicate,
    );
  });
}
