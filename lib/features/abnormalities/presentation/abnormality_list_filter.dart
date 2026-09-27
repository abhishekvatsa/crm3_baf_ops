import '../data/abnormality_model.dart';

/// Abnormality logs carry an RA decision, not the separate Quality warning's
/// adjudication/closure state. Keep the list labels explicit about that scope.
enum AbnormalityListFilter {
  open,
  all,
  notApplicable,
  pendingDecision,
  required,
  notRequired,
  completed,
}

extension AbnormalityListFilterX on AbnormalityListFilter {
  String get label => switch (this) {
    AbnormalityListFilter.open => 'Open / RA pending',
    AbnormalityListFilter.all => 'All',
    AbnormalityListFilter.notApplicable => 'RA not applicable',
    AbnormalityListFilter.pendingDecision => 'RA decision pending',
    AbnormalityListFilter.required => 'RA required',
    AbnormalityListFilter.notRequired => 'RA not required',
    AbnormalityListFilter.completed => 'RA completed',
  };

  bool includes(ChargeAbnormality record) => switch (this) {
    AbnormalityListFilter.open =>
      record.reannealingStatus == ReannealingStatus.pendingDecision ||
          record.reannealingStatus == ReannealingStatus.required,
    AbnormalityListFilter.all => true,
    AbnormalityListFilter.notApplicable =>
      record.reannealingStatus == ReannealingStatus.notApplicable,
    AbnormalityListFilter.pendingDecision =>
      record.reannealingStatus == ReannealingStatus.pendingDecision,
    AbnormalityListFilter.required =>
      record.reannealingStatus == ReannealingStatus.required,
    AbnormalityListFilter.notRequired =>
      record.reannealingStatus == ReannealingStatus.notRequired,
    AbnormalityListFilter.completed =>
      record.reannealingStatus == ReannealingStatus.completed,
  };
}
