import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../maintenance_workflow/providers/workflow_providers.dart';
import '../../maintenance/providers/maintenance_provider.dart';
import '../domain/plant_asset_overview.dart';
import 'asset_availability_provider.dart';
import 'asset_hierarchy_provider.dart';

final plantAssetOverviewProvider = Provider<AsyncValue<PlantAssetOverview>>((
  ref,
) {
  final classes = ref.watch(assetClassesProvider);
  final assets = ref.watch(allAssetInstancesProvider);
  final conditions = ref.watch(assetOperationalConditionsProvider);
  final workflow = ref.watch(equipmentStatusProvider(null));
  final availability = ref.watch(assetAvailabilityProvider);
  final tickets = ref.watch(plantConditionTicketsProvider);

  final error =
      classes.asError ??
      assets.asError ??
      conditions.asError ??
      workflow.asError ??
      availability.asError ??
      tickets.asError;
  if (error != null) {
    return AsyncError(error.error, error.stackTrace);
  }
  if (classes.isLoading ||
      assets.isLoading ||
      conditions.isLoading ||
      workflow.isLoading ||
      availability.isLoading ||
      tickets.isLoading) {
    return const AsyncLoading();
  }
  try {
    return AsyncData(
      PlantAssetOverview.build(
        assetClasses: classes.requireValue,
        assetInstances: assets.requireValue,
        operationalConditions: conditions.requireValue,
        workflowStatuses: workflow.requireValue,
        availabilityProjections: availability.requireValue,
        maintenanceTickets: tickets.requireValue,
      ),
    );
  } catch (error, stackTrace) {
    return AsyncError(error, stackTrace);
  }
});
