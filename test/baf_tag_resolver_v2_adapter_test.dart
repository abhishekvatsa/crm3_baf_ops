import 'package:flutter_test/flutter_test.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/domain/baf_tag_resolver_v2.dart';

void main() {
  group('BafTagResolverV2.resolveToMap', () {
    test('preserves legacy exact tag coverage without asset context', () {
      final fit45 = BafTagResolverV2.resolveToMap('FIT45');
      final zt31 = BafTagResolverV2.resolveToMap('ZT31');
      final pit13 = BafTagResolverV2.resolveToMap('PIT13');
      final pcv77 = BafTagResolverV2.resolveToMap('PCV77');

      expect(fit45['isAutoResolved'], isTrue);
      expect(fit45['component'], 'Hydrogen Flow Meter');
      expect(fit45['asset'], isNotNull);
      expect(
        fit45['resolutionSource'],
        contains('legacyDomainRegistryExactTag'),
      );

      expect(zt31['isAutoResolved'], isTrue);
      expect(zt31['component'], 'Air Control Valve');
      expect(zt31['asset'], 'Furnace');

      expect(pit13['isAutoResolved'], isTrue);
      expect(pit13['component'], 'Nitrogen Pressure Transmitter');
      expect(pit13['asset'], isNotNull);

      expect(pcv77['isAutoResolved'], isTrue);
      expect(pcv77['component'], 'Back Pressure Valve');
      expect(
        pcv77['resolutionSource'],
        contains('legacyDomainRegistryExactTag'),
      );
    });

    test('keeps V1 display keys while exposing V2 safety metadata', () {
      final result = BafTagResolverV2.resolveToMap(
        'PSL13',
        assetContext: AssetType.base,
      );

      expect(result['isAutoResolved'], isTrue);
      expect(result['asset'], 'Base');
      expect(result['component'], 'Pressure Switch');
      expect(result['confidence'], isA<double>());
      expect(result['requiresReview'], isA<bool>());
      expect(result['safetyClasses'], isA<List<String>>());
      expect(result['safetyClasses'] as List<String>, isNotEmpty);
      expect(
        result['resolutionSource'],
        contains('legacyDomainRegistryExactTag'),
      );
    });

    test(
      'can resolve V2 prefix-inferred tags when asset context is supplied',
      () {
        final result = BafTagResolverV2.resolveToMap(
          'VT101',
          assetContext: AssetType.base,
        );

        expect(result['isAutoResolved'], isTrue);
        expect(result['asset'], 'Base');
        expect(result['component'], contains('Vibration'));
        expect(result['resolutionSource'], 'instrumentPrefixInference');
        expect(
          result['safetyClasses'] as List<String>,
          contains('safetyInterlock'),
        );
      },
    );

    test('does not auto-resolve unknown or empty tags', () {
      final unknown = BafTagResolverV2.resolveToMap('UNKNOWN999');
      final empty = BafTagResolverV2.resolveToMap('   ');

      expect(unknown['isAutoResolved'], isFalse);
      expect(unknown['asset'], isNull);
      expect(unknown['resolutionSource'], 'unresolved');

      expect(empty['isAutoResolved'], isFalse);
      expect(empty['asset'], isNull);
      expect(empty['resolutionSource'], 'empty');
    });
  });
}
