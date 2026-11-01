import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import '../lib/services/packaging_analysis_jobs.dart';
import '../lib/packaging_models.dart';

void main() {
  const result = PackagingAnalysisResult(
    rawOcrText: '牛奶',
    ingredients: [],
    nutrition: NutritionFacts(basis: NutritionBasis.unknown),
    allergens: [],
    cautionIngredients: [],
    risks: [],
    suggestions: [],
    analysisSource: PackagingAnalysisSource.qwenVisionOcrDeterministic,
  );
  test('route reopen shares the same pending and completed OCR', () async {
    final jobs = PackagingAnalysisJobs();
    final completion = Completer<PackagingAnalysisResult>();
    var calls = 0;
    Future<PackagingAnalysisResult> analyze() {
      calls++;
      return completion.future;
    }

    final first = jobs.runOnce('capture', analyze);
    final reopened = jobs.runOnce('capture', analyze);
    expect(identical(first, reopened), isTrue);
    completion.complete(result);
    expect(await reopened, same(result));
    expect(await jobs.runOnce('capture', analyze), same(result));
    expect(calls, 1);
  });
  test('failed capture stays failed without a duplicate charge', () async {
    final jobs = PackagingAnalysisJobs();
    var calls = 0;
    Future<PackagingAnalysisResult> analyze() async {
      calls++;
      throw StateError('offline');
    }

    await expectLater(jobs.runOnce('failed', analyze), throwsStateError);
    await expectLater(jobs.runOnce('failed', analyze), throwsStateError);
    expect(calls, 1);
  });
}
