import '../../maintenance/data/maintenance_model.dart';
import '../../planned_maintenance/data/job_diary_model.dart';
import '../../planned_maintenance/data/job_module_model.dart';
import 'maintenance_lane.dart';

abstract final class LegacyMaintenanceLaneAdapter {
  static MaintenanceLaneId? fromRoutedTo(RoutedTo routedTo) {
    switch (routedTo) {
      case RoutedTo.electrical: return MaintenanceLaneId.electrical;
      case RoutedTo.mechanical: return MaintenanceLaneId.mechanical;
      case RoutedTo.instrumentation: return MaintenanceLaneId.instrumentation;
      case RoutedTo.operations: return MaintenanceLaneId.operations;
      case RoutedTo.emd: return MaintenanceLaneId.emd;
      case RoutedTo.refractory: return MaintenanceLaneId.refractory;
      case RoutedTo.shiftInCharge:
        return MaintenanceLaneId.operations;
      case RoutedTo.others:
        return MaintenanceLaneId.shared;
    }
  }

  static MaintenanceLaneId? fromModuleDiscipline(JobModuleDiscipline discipline) {
    switch (discipline) {
      case JobModuleDiscipline.electrical: return MaintenanceLaneId.electrical;
      case JobModuleDiscipline.mechanical: return MaintenanceLaneId.mechanical;
      case JobModuleDiscipline.instrumentation: return MaintenanceLaneId.instrumentation;
      case JobModuleDiscipline.operations: return MaintenanceLaneId.operations;
      case JobModuleDiscipline.emd: return MaintenanceLaneId.emd;
      case JobModuleDiscipline.refractory: return MaintenanceLaneId.refractory;
      case JobModuleDiscipline.shiftInCharge: return MaintenanceLaneId.operations;
      case JobModuleDiscipline.safety:
      case JobModuleDiscipline.admin:
      case JobModuleDiscipline.shared:
      case JobModuleDiscipline.others:
        return MaintenanceLaneId.shared;
    }
  }

  static MaintenanceLaneId? fromDiaryDiscipline(JobDiaryDiscipline discipline) {
    switch (discipline) {
      case JobDiaryDiscipline.electrical: return MaintenanceLaneId.electrical;
      case JobDiaryDiscipline.mechanical: return MaintenanceLaneId.mechanical;
      case JobDiaryDiscipline.instrumentation: return MaintenanceLaneId.instrumentation;
      case JobDiaryDiscipline.operations: return MaintenanceLaneId.operations;
      case JobDiaryDiscipline.emd: return MaintenanceLaneId.emd;
      case JobDiaryDiscipline.refractory: return MaintenanceLaneId.refractory;
      case JobDiaryDiscipline.shiftInCharge: return MaintenanceLaneId.operations;
      case JobDiaryDiscipline.safety:
      case JobDiaryDiscipline.admin:
      case JobDiaryDiscipline.shared:
      case JobDiaryDiscipline.others:
        return MaintenanceLaneId.shared;
    }
  }
}
