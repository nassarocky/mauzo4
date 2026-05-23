/// Physical shop address on `businesses/{id}` for marketplace / discovery.
///
/// Separate from [ProductModel.location] (shelf / store aisle labels).
/// Future product search indexes should denormalize [displayLine] from the
/// business document onto each searchable product row for snippet UI.
class BusinessShopLocation {
  BusinessShopLocation._();

  static const String defaultCountry = 'Tanzania';

  static const String firestoreCountryKey = 'shopCountry';
  static const String firestoreCityKey = 'shopCity';
  static const String firestoreStreetKey = 'shopStreet';

  static Map<String, dynamic> firestoreFields({
    required String country,
    required String city,
    required String street,
  }) {
    final c =
        country.trim().isEmpty ? defaultCountry : country.trim();
    return {
      firestoreCountryKey: c,
      firestoreCityKey: city.trim(),
      firestoreStreetKey: street.trim(),
    };
  }

  /// Banner hides when both city and street are non-empty.
  static bool isComplete(Map<String, dynamic> business) {
    final city = business[firestoreCityKey]?.toString().trim() ?? '';
    final street = business[firestoreStreetKey]?.toString().trim() ?? '';
    return city.isNotEmpty && street.isNotEmpty;
  }

  /// One line for search results / product cards (subtitle).
  static String displayLine(Map<String, dynamic> business) {
    final country = business[firestoreCountryKey]?.toString().trim() ?? '';
    final city = business[firestoreCityKey]?.toString().trim() ?? '';
    final street = business[firestoreStreetKey]?.toString().trim() ?? '';
    if (city.isEmpty && street.isEmpty) return '';
    final parts = <String>[];
    if (street.isNotEmpty) parts.add(street);
    if (city.isNotEmpty) parts.add(city);
    final place = parts.join(', ');
    if (country.isEmpty || country == defaultCountry) {
      return place;
    }
    return '$place, $country';
  }
}
