import '../packaging_models.dart';

/// Shares in-flight, successful and failed work across route changes.
/// A retry requires a new capture identity, never a second billable OCR call.
class PackagingAnalysisJobs {
  final Map<String, Future<PackagingAnalysisResult>> _jobs = {};

  Future<PackagingAnalysisResult> runOnce(
    String id,
    Future<PackagingAnalysisResult> Function() analyze,
  ) => _jobs.putIfAbsent(
    id,
    () => Future<PackagingAnalysisResult>.sync(analyze),
  );
}
