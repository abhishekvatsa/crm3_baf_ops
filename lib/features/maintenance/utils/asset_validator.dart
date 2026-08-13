import '../data/maintenance_model.dart';

class AssetValidator {
  /// Validates an asset number for a given asset type.
  static bool isValid(AssetType type, int number) {
    switch (type) {
      case AssetType.base:
      // Bases: 101-124, 201-223
        return (number >= 101 && number <= 124) || (number >= 201 && number <= 223);
      case AssetType.furnace:
      // Furnaces: 1-26
        return number >= 1 && number <= 26;
      case AssetType.forceCooler:
      // Force coolers: 1-25
        return number >= 1 && number <= 25;
      case AssetType.innerCover:
      // No fixed range – any positive integer is accepted
        return number > 0;
      case AssetType.governedCustom:
        return number >= 1 && number <= 9999;
    }
  }

  /// Returns a user-friendly validation message if number is invalid; otherwise null.
  static String? getValidationMessage(AssetType type, int number) {
    if (isValid(type, number)) return null;
    switch (type) {
      case AssetType.base:
        return 'Base number must be 101‑124 or 201‑223';
      case AssetType.furnace:
        return 'Furnace number must be 1‑26';
      case AssetType.forceCooler:
        return 'Force cooler number must be 1‑25';
      case AssetType.innerCover:
        return null; // no validation message for inner covers
      case AssetType.governedCustom:
        return 'Governed asset number must be 1-9999';
    }
  }
}
