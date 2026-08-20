import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/inspection_campaign.dart';
import '../repositories/inspection_repository.dart';

final inspectionRepositoryProvider = Provider<InspectionRepository>((ref) {
  return InspectionRepository();
});

final inspectionDefinitionsProvider =
    StreamProvider<List<InspectionDefinition>>((ref) {
      return ref.watch(inspectionRepositoryProvider).watchDefinitions();
    });

final inspectionCampaignsProvider = StreamProvider<List<InspectionCampaign>>((
  ref,
) {
  return ref.watch(inspectionRepositoryProvider).watchCampaigns();
});

final inspectionObservationsProvider = StreamProvider.family<
  List<InspectionObservation>,
  String
>((ref, campaignId) {
  return ref.watch(inspectionRepositoryProvider).watchObservations(campaignId);
});
