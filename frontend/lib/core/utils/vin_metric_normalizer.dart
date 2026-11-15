// =============================================================================
// CarLog 3-Step VIN Decoder & Metric Normalizer
// 1. Offline Local WMI Lookup (Instant offline Make / Country / Type)
// 2. Online NHTSA vPIC API query + Immediate Imperial-to-Metric Normalization
// 3. Fully Editable Pre-Fill Data Model
// =============================================================================

import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'imperial_metric_converter.dart';

class DecodedVinData {
  final String vin;
  final String make;
  final String model;
  final int? year;
  final String vehicleType; // car, motorcycle, truck
  final int? engineDisplacementCc;
  final String? engineCode;
  final int? powerKw;
  final String transmissionType; // manual, automatic, cvt, dct
  final String fuelType; // gasoline, diesel, hybrid, electric
  final String? countryOfOrigin;
  final String source; // 'local_wmi' | 'nhtsa_vpic' | 'hybrid'

  DecodedVinData({
    required this.vin,
    required this.make,
    this.model = '',
    this.year,
    this.vehicleType = 'car',
    this.engineDisplacementCc,
    this.engineCode,
    this.powerKw,
    this.transmissionType = 'manual',
    this.fuelType = 'gasoline',
    this.countryOfOrigin,
    required this.source,
  });

  DecodedVinData copyWith({
    String? make,
    String? model,
    int? year,
    String? vehicleType,
    int? engineDisplacementCc,
    String? engineCode,
    int? powerKw,
    String? transmissionType,
    String? fuelType,
    String? countryOfOrigin,
    String? source,
  }) {
    return DecodedVinData(
      vin: vin,
      make: make ?? this.make,
      model: model ?? this.model,
      year: year ?? this.year,
      vehicleType: vehicleType ?? this.vehicleType,
      engineDisplacementCc: engineDisplacementCc ?? this.engineDisplacementCc,
      engineCode: engineCode ?? this.engineCode,
      powerKw: powerKw ?? this.powerKw,
      transmissionType: transmissionType ?? this.transmissionType,
      fuelType: fuelType ?? this.fuelType,
      countryOfOrigin: countryOfOrigin ?? this.countryOfOrigin,
      source: source ?? this.source,
    );
  }
}

class VinMetricNormalizer {
  static Map<String, dynamic>? _wmiDatabase;

  /// Load bundled offline WMI database
  static Future<void> _loadWmiDatabase() async {
    if (_wmiDatabase != null) return;
    try {
      final jsonStr = await rootBundle.loadString('assets/wmi_manufacturers.json');
      _wmiDatabase = jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (e) {
      _wmiDatabase = {};
    }
  }

  /// Step 1: Offline Local WMI Lookup (Instant)
  static Future<DecodedVinData?> lookupOfflineWmi(String vin) async {
    final cleanVin = vin.trim().toUpperCase();
    if (cleanVin.length < 3) return null;

    await _loadWmiDatabase();
    final wmiPrefix = cleanVin.substring(0, 3);
    final entry = _wmiDatabase?[wmiPrefix];

    if (entry != null) {
      return DecodedVinData(
        vin: cleanVin,
        make: entry['make'] ?? '',
        vehicleType: entry['type'] ?? 'car',
        countryOfOrigin: entry['country'],
        source: 'local_wmi',
      );
    }

    return null;
  }

  /// Step 2 & 3: Online NHTSA API + Metric Normalization + Editable Pre-fill
  static Future<DecodedVinData> decodeVinOnline(String vin, {Dio? dioClient}) async {
    final cleanVin = vin.trim().toUpperCase();
    final dio = dioClient ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 10), receiveTimeout: const Duration(seconds: 10)));

    // First do local WMI as fallback baseline
    final offlineBaseline = await lookupOfflineWmi(cleanVin);

    final url = 'https://vpic.nhtsa.dot.gov/api/vehicles/DecodeVinValues/$cleanVin?format=json';
    final response = await dio.get(url);

    if (response.statusCode != 200 || response.data == null) {
      throw Exception('NHTSA API returned invalid response status: ${response.statusCode}');
    }

    final results = response.data['Results'];
    if (results == null || results is! List || results.isEmpty) {
      throw Exception('No decoding records returned for VIN');
    }

    final item = results[0] as Map<String, dynamic>;

    // 1. Make
    String make = (item['Make'] ?? '').toString().trim();
    if (make.isEmpty && offlineBaseline != null) {
      make = offlineBaseline.make;
    }

    // 2. Model & Year
    final model = (item['Model'] ?? '').toString().trim();
    final yearStr = (item['ModelYear'] ?? '').toString().trim();
    final year = int.tryParse(yearStr);

    // 3. Vehicle Type
    String vehicleType = 'car';
    final nhtsaType = (item['VehicleType'] ?? '').toString().toUpperCase();
    if (nhtsaType.contains('MOTORCYCLE')) {
      vehicleType = 'motorcycle';
    } else if (nhtsaType.contains('TRUCK')) {
      vehicleType = 'truck';
    } else if (offlineBaseline != null) {
      vehicleType = offlineBaseline.vehicleType;
    }

    // 4. Metric Engine Displacement (cc)
    int? displacementCc;
    final ciStr = item['DisplacementCI']?.toString();
    final lStr = item['DisplacementL']?.toString();
    final ccStr = item['DisplacementCC']?.toString();

    if (ccStr != null && int.tryParse(ccStr) != null && int.parse(ccStr) > 0) {
      displacementCc = int.parse(ccStr);
    } else if (ciStr != null && double.tryParse(ciStr) != null && double.parse(ciStr) > 0) {
      // Immediate conversion: cc = round(ci * 16.387064)
      displacementCc = ImperialMetricConverter.ciToCc(double.parse(ciStr));
    } else if (lStr != null && double.tryParse(lStr) != null && double.parse(lStr) > 0) {
      displacementCc = (double.parse(lStr) * 1000).round();
    }

    // 5. Metric Power (kW)
    int? powerKw;
    final kwStr = item['EngineKW']?.toString();
    final hpStr = item['EngineHP']?.toString();

    if (kwStr != null && int.tryParse(kwStr) != null && int.parse(kwStr) > 0) {
      powerKw = int.parse(kwStr);
    } else if (hpStr != null && double.tryParse(hpStr) != null && double.parse(hpStr) > 0) {
      // Immediate conversion: kW = round(hp * 0.7457)
      powerKw = ImperialMetricConverter.hpToKw(double.parse(hpStr));
    }

    // 6. Transmission Type Normalization
    String transmission = 'manual';
    final transStr = (item['TransmissionStyle'] ?? '').toString().toUpperCase();
    if (transStr.contains('AUTO')) {
      transmission = 'automatic';
    } else if (transStr.contains('CVT')) {
      transmission = 'cvt';
    } else if (transStr.contains('DUAL') || transStr.contains('DCT') || transStr.contains('DSG')) {
      transmission = 'dct';
    }

    // 7. Fuel Type Normalization
    String fuelType = 'gasoline';
    final fuelStr = (item['FuelTypePrimary'] ?? '').toString().toUpperCase();
    if (fuelStr.contains('DIESEL')) {
      fuelType = 'diesel';
    } else if (fuelStr.contains('HYBRID')) {
      fuelType = 'hybrid';
    } else if (fuelStr.contains('ELECTRIC')) {
      fuelType = 'electric';
    }

    return DecodedVinData(
      vin: cleanVin,
      make: make,
      model: model,
      year: year,
      vehicleType: vehicleType,
      engineDisplacementCc: displacementCc,
      engineCode: (item['EngineModel'] ?? item['EngineConfiguration'] ?? '').toString().trim(),
      powerKw: powerKw,
      transmissionType: transmission,
      fuelType: fuelType,
      countryOfOrigin: item['PlantCountry']?.toString() ?? offlineBaseline?.countryOfOrigin,
      source: 'nhtsa_vpic',
    );
  }
}
