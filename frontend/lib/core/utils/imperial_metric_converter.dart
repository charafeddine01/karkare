// =============================================================================
// CarLog Imperial-to-Metric Immediate Converter
// Used in NHTSA parser and UI Inline Helper Chips
// =============================================================================

class ImperialMetricConverter {
  /// Cubic Inches to Cubic Centimeters: cc = round(ci * 16.387064)
  static int ciToCc(double ci) {
    return (ci * 16.387064).round();
  }

  /// Cubic Inches to Liters: L = round(ci * 0.016387064, 1)
  static double ciToLiters(double ci) {
    return double.parse((ci * 0.016387064).toStringAsFixed(1));
  }

  /// Horsepower to Kilowatts: kW = round(hp * 0.7457)
  static int hpToKw(double hp) {
    return (hp * 0.7457).round();
  }

  /// Inches to Millimeters: mm = round(inches * 25.4)
  static int inchesToMm(double inches) {
    return (inches * 25.4).round();
  }

  /// Pounds to Kilograms: kg = round(lbs * 0.45359237)
  static int lbsToKg(double lbs) {
    return (lbs * 0.45359237).round();
  }

  /// PSI to Bar: Bar = round(psi * 0.0689476, 2)
  static double psiToBar(double psi) {
    return double.parse((psi * 0.0689476).toStringAsFixed(2));
  }

  /// Pound-feet to Newton-meters: Nm = round(lb_ft * 1.355818)
  static int lbFtToNm(double lbFt) {
    return (lbFt * 1.355818).round();
  }

  /// US Quarts to Liters: L = round(qt * 0.946353, 2)
  static double quartsToLiters(double quarts) {
    return double.parse((quarts * 0.946353).toStringAsFixed(2));
  }

  /// Gallons (US) to Liters: L = round(gal * 3.78541, 2)
  static double gallonsToLiters(double gallons) {
    return double.parse((gallons * 3.78541).toStringAsFixed(2));
  }

  /// Miles to Kilometers: km = round(miles * 1.60934)
  static int milesToKm(double miles) {
    return (miles * 1.60934).round();
  }
}
