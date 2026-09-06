final class InspectionEvidenceSnapshot<T> {
  const InspectionEvidenceSnapshot({
    required this.records,
    required this.isServerVerified,
  });

  final List<T> records;
  final bool isServerVerified;
}
