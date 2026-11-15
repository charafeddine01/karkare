// =============================================================================
// CarLog App Constants
// Platform: Offline-First Vehicle & Motorcycle Maintenance Platform
// Constraints: Strictly USD ($), Strictly 100% Metric Units
// =============================================================================

class AppConstants {
  static const String appName = 'CarLog';
  static const String apiBaseUrl = 'https://charafeddine.xyz/karkare/api';

  // Strict Global Currency
  static const String currencyCode = 'USD';
  static const String currencySymbol = r'$';

  // Strict Global Metric Units
  static const String unitDistance = 'km';
  static const String unitVolume = 'L';
  static const String unitVolumeMilli = 'mL';
  static const String unitDisplacement = 'cc';
  static const String unitPower = 'kW';
  static const String unitTorque = 'Nm';
  static const String unitPressure = 'Bar';
  static const String unitLength = 'mm';
  static const String unitWeight = 'kg';
  static const String unitTemp = '°C';
  static const String unitConsumption = 'L / 100 km';
  static const String unitEconomy = 'km / L';
  static const String unitCostPerDistance = r'$ / km';

  // Vehicle Types
  static const List<String> vehicleTypes = ['car', 'motorcycle', 'truck'];

  // Transmission Types
  static const List<String> transmissionTypes = ['manual', 'automatic', 'cvt', 'dct'];

  // Fuel Types
  static const List<String> fuelTypes = ['gasoline', 'diesel', 'hybrid', 'electric'];

  // Engine States for Symptoms
  static const List<String> engineStates = [
    'cold_start',
    'idle',
    'acceleration',
    'cruising',
    'braking',
    'other',
  ];

  // Workshop Specialties
  static const List<String> specialties = [
    'mechanic',
    'electrician',
    'parts_store',
    'tire_shop',
    'body_shop',
    'other',
  ];
}
