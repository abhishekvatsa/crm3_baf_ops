import 'package:crm3_baf_ops/features/quality/domain/issue_quality_intent.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('quality intent round-trips through local metadata', () {
    const source = IssueQualityIntent(
      assessment: IssueQualityAssessment.suspected,
      warningReason: 'Atmosphere interruption may affect the coil.',
    );

    final decoded = IssueQualityIntent.tryDecodeLocal(source.encode());

    expect(decoded?.assessment, IssueQualityAssessment.suspected);
    expect(decoded?.warningReason, source.warningReason);
    expect(decoded?.toSynchronizedFields(), <String, dynamic>{
      'qualityIntentSchemaVersion': 1,
      'qualityImpactAssessment': 'suspected',
      'qualityWarningReason': source.warningReason,
    });
  });

  test('partial synchronized quality intent fails closed', () {
    expect(
      () => IssueQualityIntent.readOptionalSynchronizedFields(
        const <String, dynamic>{
          'qualityIntentSchemaVersion': 1,
          'qualityImpactAssessment': 'suspected',
        },
        source: 'test ticket',
      ),
      throwsFormatException,
    );
  });

  test('legacy record may omit the complete quality field set', () {
    expect(
      IssueQualityIntent.readOptionalSynchronizedFields(
        const <String, dynamic>{},
        source: 'legacy ticket',
      ),
      isNull,
    );
  });

  test('malformed current quality envelope fails closed', () {
    expect(
      () => IssueQualityIntent.tryDecodeLocal(
        '{"qualityIntent":{"schemaVersion":1,"assessment":"suspected"}}',
      ),
      throwsFormatException,
    );
  });

  test('opaque pre-feature metadata remains compatible', () {
    expect(IssueQualityIntent.tryDecodeLocal('legacy opaque value'), isNull);
    expect(
      IssueQualityIntent.tryDecodeLocal('{"unrelatedLegacyField":true}'),
      isNull,
    );
  });
}
