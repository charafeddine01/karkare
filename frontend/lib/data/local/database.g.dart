// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint

class VehiclesTableData extends DataClass implements Insertable<VehiclesTableData> {
  final String id;
  final String userId;
  final String vehicleType;
  final String? vin;
  final String? plateNumber;
  final String make;
  final String model;
  final int year;
  final int? engineDisplacementCc;
  final String? engineCode;
  final int? powerKw;
  final String transmissionType;
  final String fuelType;
  final int acquisitionOdometerKm;
  final int currentOdometerKm;
  final String? photoUrl;
  final String? publicShareToken;
  final bool hideCostsOnShare;
  final bool isDeleted;
  final String syncStatus;
  final DateTime updatedAt;

  const VehiclesTableData({
    required this.id,
    required this.userId,
    required this.vehicleType,
    this.vin,
    this.plateNumber,
    required this.make,
    required this.model,
    required this.year,
    this.engineDisplacementCc,
    this.engineCode,
    this.powerKw,
    required this.transmissionType,
    required this.fuelType,
    required this.acquisitionOdometerKm,
    required this.currentOdometerKm,
    this.photoUrl,
    this.publicShareToken,
    required this.hideCostsOnShare,
    required this.isDeleted,
    required this.syncStatus,
    required this.updatedAt,
  });

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['user_id'] = Variable<String>(userId);
    map['vehicle_type'] = Variable<String>(vehicleType);
    if (!nullToAbsent || vin != null) {
      map['vin'] = Variable<String>(vin);
    }
    if (!nullToAbsent || plateNumber != null) {
      map['plate_number'] = Variable<String>(plateNumber);
    }
    map['make'] = Variable<String>(make);
    map['model'] = Variable<String>(model);
    map['year'] = Variable<int>(year);
    if (!nullToAbsent || engineDisplacementCc != null) {
      map['engine_displacement_cc'] = Variable<int>(engineDisplacementCc);
    }
    if (!nullToAbsent || engineCode != null) {
      map['engine_code'] = Variable<String>(engineCode);
    }
    if (!nullToAbsent || powerKw != null) {
      map['power_kw'] = Variable<int>(powerKw);
    }
    map['transmission_type'] = Variable<String>(transmissionType);
    map['fuel_type'] = Variable<String>(fuelType);
    map['acquisition_odometer_km'] = Variable<int>(acquisitionOdometerKm);
    map['current_odometer_km'] = Variable<int>(currentOdometerKm);
    if (!nullToAbsent || photoUrl != null) {
      map['photo_url'] = Variable<String>(photoUrl);
    }
    if (!nullToAbsent || publicShareToken != null) {
      map['public_share_token'] = Variable<String>(publicShareToken);
    }
    map['hide_costs_on_share'] = Variable<bool>(hideCostsOnShare);
    map['is_deleted'] = Variable<bool>(isDeleted);
    map['sync_status'] = Variable<String>(syncStatus);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  VehiclesTableCompanion toCompanion(bool nullToAbsent) {
    return VehiclesTableCompanion(
      id: Value(id),
      userId: Value(userId),
      vehicleType: Value(vehicleType),
      vin: vin == null && nullToAbsent ? const Value.absent() : Value(vin),
      plateNumber: plateNumber == null && nullToAbsent ? const Value.absent() : Value(plateNumber),
      make: Value(make),
      model: Value(model),
      year: Value(year),
      engineDisplacementCc: engineDisplacementCc == null && nullToAbsent ? const Value.absent() : Value(engineDisplacementCc),
      engineCode: engineCode == null && nullToAbsent ? const Value.absent() : Value(engineCode),
      powerKw: powerKw == null && nullToAbsent ? const Value.absent() : Value(powerKw),
      transmissionType: Value(transmissionType),
      fuelType: Value(fuelType),
      acquisitionOdometerKm: Value(acquisitionOdometerKm),
      currentOdometerKm: Value(currentOdometerKm),
      photoUrl: photoUrl == null && nullToAbsent ? const Value.absent() : Value(photoUrl),
      publicShareToken: publicShareToken == null && nullToAbsent ? const Value.absent() : Value(publicShareToken),
      hideCostsOnShare: Value(hideCostsOnShare),
      isDeleted: Value(isDeleted),
      syncStatus: Value(syncStatus),
      updatedAt: Value(updatedAt),
    );
  }
}

class VehiclesTableCompanion extends UpdateCompanion<VehiclesTableData> {
  final Value<String> id;
  final Value<String> userId;
  final Value<String> vehicleType;
  final Value<String?> vin;
  final Value<String?> plateNumber;
  final Value<String> make;
  final Value<String> model;
  final Value<int> year;
  final Value<int?> engineDisplacementCc;
  final Value<String?> engineCode;
  final Value<int?> powerKw;
  final Value<String> transmissionType;
  final Value<String> fuelType;
  final Value<int> acquisitionOdometerKm;
  final Value<int> currentOdometerKm;
  final Value<String?> photoUrl;
  final Value<String?> publicShareToken;
  final Value<bool> hideCostsOnShare;
  final Value<bool> isDeleted;
  final Value<String> syncStatus;
  final Value<DateTime> updatedAt;

  const VehiclesTableCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.vehicleType = const Value.absent(),
    this.vin = const Value.absent(),
    this.plateNumber = const Value.absent(),
    this.make = const Value.absent(),
    this.model = const Value.absent(),
    this.year = const Value.absent(),
    this.engineDisplacementCc = const Value.absent(),
    this.engineCode = const Value.absent(),
    this.powerKw = const Value.absent(),
    this.transmissionType = const Value.absent(),
    this.fuelType = const Value.absent(),
    this.acquisitionOdometerKm = const Value.absent(),
    this.currentOdometerKm = const Value.absent(),
    this.photoUrl = const Value.absent(),
    this.publicShareToken = const Value.absent(),
    this.hideCostsOnShare = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) map['id'] = Variable<String>(id.value);
    if (userId.present) map['user_id'] = Variable<String>(userId.value);
    if (vehicleType.present) map['vehicle_type'] = Variable<String>(vehicleType.value);
    if (vin.present) map['vin'] = Variable<String?>(vin.value);
    if (plateNumber.present) map['plate_number'] = Variable<String?>(plateNumber.value);
    if (make.present) map['make'] = Variable<String>(make.value);
    if (model.present) map['model'] = Variable<String>(model.value);
    if (year.present) map['year'] = Variable<int>(year.value);
    if (engineDisplacementCc.present) map['engine_displacement_cc'] = Variable<int?>(engineDisplacementCc.value);
    if (engineCode.present) map['engine_code'] = Variable<String?>(engineCode.value);
    if (powerKw.present) map['power_kw'] = Variable<int?>(powerKw.value);
    if (transmissionType.present) map['transmission_type'] = Variable<String>(transmissionType.value);
    if (fuelType.present) map['fuel_type'] = Variable<String>(fuelType.value);
    if (acquisitionOdometerKm.present) map['acquisition_odometer_km'] = Variable<int>(acquisitionOdometerKm.value);
    if (currentOdometerKm.present) map['current_odometer_km'] = Variable<int>(currentOdometerKm.value);
    if (photoUrl.present) map['photo_url'] = Variable<String?>(photoUrl.value);
    if (publicShareToken.present) map['public_share_token'] = Variable<String?>(publicShareToken.value);
    if (hideCostsOnShare.present) map['hide_costs_on_share'] = Variable<bool>(hideCostsOnShare.value);
    if (isDeleted.present) map['is_deleted'] = Variable<bool>(isDeleted.value);
    if (syncStatus.present) map['sync_status'] = Variable<String>(syncStatus.value);
    if (updatedAt.present) map['updated_at'] = Variable<DateTime>(updatedAt.value);
    return map;
  }
}

class VehicleQuickSpecsTableData extends DataClass implements Insertable<VehicleQuickSpecsTableData> {
  final String vehicleId;
  final String? oilViscosity;
  final double? oilCapacityL;
  final String? coolantSpec;
  final double? coolantCapacityL;
  final String? frontTireSize;
  final String? rearTireSize;
  final double? frontTirePressureBar;
  final double? rearTirePressureBar;
  final int? wiperDriverMm;
  final int? wiperPassengerMm;
  final int? wiperRearMm;
  final String? batterySpec;
  final double? sparkPlugGapMm;
  final int? wheelLugTorqueNm;
  final String? chainPitchMm;
  final String syncStatus;
  final DateTime updatedAt;

  const VehicleQuickSpecsTableData({
    required this.vehicleId,
    this.oilViscosity,
    this.oilCapacityL,
    this.coolantSpec,
    this.coolantCapacityL,
    this.frontTireSize,
    this.rearTireSize,
    this.frontTirePressureBar,
    this.rearTirePressureBar,
    this.wiperDriverMm,
    this.wiperPassengerMm,
    this.wiperRearMm,
    this.batterySpec,
    this.sparkPlugGapMm,
    this.wheelLugTorqueNm,
    this.chainPitchMm,
    required this.syncStatus,
    required this.updatedAt,
  });

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['vehicle_id'] = Variable<String>(vehicleId);
    if (!nullToAbsent || oilViscosity != null) map['oil_viscosity'] = Variable<String>(oilViscosity);
    if (!nullToAbsent || oilCapacityL != null) map['oil_capacity_l'] = Variable<double>(oilCapacityL);
    if (!nullToAbsent || coolantSpec != null) map['coolant_spec'] = Variable<String>(coolantSpec);
    if (!nullToAbsent || coolantCapacityL != null) map['coolant_capacity_l'] = Variable<double>(coolantCapacityL);
    if (!nullToAbsent || frontTireSize != null) map['front_tire_size'] = Variable<String>(frontTireSize);
    if (!nullToAbsent || rearTireSize != null) map['rear_tire_size'] = Variable<String>(rearTireSize);
    if (!nullToAbsent || frontTirePressureBar != null) map['front_tire_pressure_bar'] = Variable<double>(frontTirePressureBar);
    if (!nullToAbsent || rearTirePressureBar != null) map['rear_tire_pressure_bar'] = Variable<double>(rearTirePressureBar);
    if (!nullToAbsent || wiperDriverMm != null) map['wiper_driver_mm'] = Variable<int>(wiperDriverMm);
    if (!nullToAbsent || wiperPassengerMm != null) map['wiper_passenger_mm'] = Variable<int>(wiperPassengerMm);
    if (!nullToAbsent || wiperRearMm != null) map['wiper_rear_mm'] = Variable<int>(wiperRearMm);
    if (!nullToAbsent || batterySpec != null) map['battery_spec'] = Variable<String>(batterySpec);
    if (!nullToAbsent || sparkPlugGapMm != null) map['spark_plug_gap_mm'] = Variable<double>(sparkPlugGapMm);
    if (!nullToAbsent || wheelLugTorqueNm != null) map['wheel_lug_torque_nm'] = Variable<int>(wheelLugTorqueNm);
    if (!nullToAbsent || chainPitchMm != null) map['chain_pitch_mm'] = Variable<String>(chainPitchMm);
    map['sync_status'] = Variable<String>(syncStatus);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }
}

class VehicleQuickSpecsTableCompanion extends UpdateCompanion<VehicleQuickSpecsTableData> {
  final Value<String> vehicleId;
  final Value<String?> oilViscosity;
  final Value<double?> oilCapacityL;
  final Value<String?> coolantSpec;
  final Value<double?> coolantCapacityL;
  final Value<String?> frontTireSize;
  final Value<String?> rearTireSize;
  final Value<double?> frontTirePressureBar;
  final Value<double?> rearTirePressureBar;
  final Value<int?> wiperDriverMm;
  final Value<int?> wiperPassengerMm;
  final Value<int?> wiperRearMm;
  final Value<String?> batterySpec;
  final Value<double?> sparkPlugGapMm;
  final Value<int?> wheelLugTorqueNm;
  final Value<String?> chainPitchMm;
  final Value<String> syncStatus;
  final Value<DateTime> updatedAt;

  const VehicleQuickSpecsTableCompanion({
    this.vehicleId = const Value.absent(),
    this.oilViscosity = const Value.absent(),
    this.oilCapacityL = const Value.absent(),
    this.coolantSpec = const Value.absent(),
    this.coolantCapacityL = const Value.absent(),
    this.frontTireSize = const Value.absent(),
    this.rearTireSize = const Value.absent(),
    this.frontTirePressureBar = const Value.absent(),
    this.rearTirePressureBar = const Value.absent(),
    this.wiperDriverMm = const Value.absent(),
    this.wiperPassengerMm = const Value.absent(),
    this.wiperRearMm = const Value.absent(),
    this.batterySpec = const Value.absent(),
    this.sparkPlugGapMm = const Value.absent(),
    this.wheelLugTorqueNm = const Value.absent(),
    this.chainPitchMm = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (vehicleId.present) map['vehicle_id'] = Variable<String>(vehicleId.value);
    if (oilViscosity.present) map['oil_viscosity'] = Variable<String?>(oilViscosity.value);
    if (oilCapacityL.present) map['oil_capacity_l'] = Variable<double?>(oilCapacityL.value);
    if (coolantSpec.present) map['coolant_spec'] = Variable<String?>(coolantSpec.value);
    if (coolantCapacityL.present) map['coolant_capacity_l'] = Variable<double?>(coolantCapacityL.value);
    if (frontTireSize.present) map['front_tire_size'] = Variable<String?>(frontTireSize.value);
    if (rearTireSize.present) map['rear_tire_size'] = Variable<String?>(rearTireSize.value);
    if (frontTirePressureBar.present) map['front_tire_pressure_bar'] = Variable<double?>(frontTirePressureBar.value);
    if (rearTirePressureBar.present) map['rear_tire_pressure_bar'] = Variable<double?>(rearTirePressureBar.value);
    if (wiperDriverMm.present) map['wiper_driver_mm'] = Variable<int?>(wiperDriverMm.value);
    if (wiperPassengerMm.present) map['wiper_passenger_mm'] = Variable<int?>(wiperPassengerMm.value);
    if (wiperRearMm.present) map['wiper_rear_mm'] = Variable<int?>(wiperRearMm.value);
    if (batterySpec.present) map['battery_spec'] = Variable<String?>(batterySpec.value);
    if (sparkPlugGapMm.present) map['spark_plug_gap_mm'] = Variable<double?>(sparkPlugGapMm.value);
    if (wheelLugTorqueNm.present) map['wheel_lug_torque_nm'] = Variable<int?>(wheelLugTorqueNm.value);
    if (chainPitchMm.present) map['chain_pitch_mm'] = Variable<String?>(chainPitchMm.value);
    if (syncStatus.present) map['sync_status'] = Variable<String>(syncStatus.value);
    if (updatedAt.present) map['updated_at'] = Variable<DateTime>(updatedAt.value);
    return map;
  }
}

class ContactsDirectoryTableData extends DataClass implements Insertable<ContactsDirectoryTableData> {
  final String id;
  final String userId;
  final String shopName;
  final String specialty;
  final String? phone;
  final String? locationNotes;
  final bool isDeleted;
  final String syncStatus;
  final DateTime updatedAt;

  const ContactsDirectoryTableData({
    required this.id,
    required this.userId,
    required this.shopName,
    required this.specialty,
    this.phone,
    this.locationNotes,
    required this.isDeleted,
    required this.syncStatus,
    required this.updatedAt,
  });

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['user_id'] = Variable<String>(userId);
    map['shop_name'] = Variable<String>(shopName);
    map['specialty'] = Variable<String>(specialty);
    if (!nullToAbsent || phone != null) map['phone'] = Variable<String>(phone);
    if (!nullToAbsent || locationNotes != null) map['location_notes'] = Variable<String>(locationNotes);
    map['is_deleted'] = Variable<bool>(isDeleted);
    map['sync_status'] = Variable<String>(syncStatus);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }
}

class ContactsDirectoryTableCompanion extends UpdateCompanion<ContactsDirectoryTableData> {
  final Value<String> id;
  final Value<String> userId;
  final Value<String> shopName;
  final Value<String> specialty;
  final Value<String?> phone;
  final Value<String?> locationNotes;
  final Value<bool> isDeleted;
  final Value<String> syncStatus;
  final Value<DateTime> updatedAt;

  const ContactsDirectoryTableCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.shopName = const Value.absent(),
    this.specialty = const Value.absent(),
    this.phone = const Value.absent(),
    this.locationNotes = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) map['id'] = Variable<String>(id.value);
    if (userId.present) map['user_id'] = Variable<String>(userId.value);
    if (shopName.present) map['shop_name'] = Variable<String>(shopName.value);
    if (specialty.present) map['specialty'] = Variable<String>(specialty.value);
    if (phone.present) map['phone'] = Variable<String?>(phone.value);
    if (locationNotes.present) map['location_notes'] = Variable<String?>(locationNotes.value);
    if (isDeleted.present) map['is_deleted'] = Variable<bool>(isDeleted.value);
    if (syncStatus.present) map['sync_status'] = Variable<String>(syncStatus.value);
    if (updatedAt.present) map['updated_at'] = Variable<DateTime>(updatedAt.value);
    return map;
  }
}

class MaintenanceTasksTemplateTableData extends DataClass implements Insertable<MaintenanceTasksTemplateTableData> {
  final String id;
  final String? userId;
  final String category;
  final String taskName;
  final String applicableTo;
  final int? defaultIntervalKm;
  final int? defaultIntervalMonths;
  final bool isDeleted;
  final String syncStatus;
  final DateTime updatedAt;

  const MaintenanceTasksTemplateTableData({
    required this.id,
    this.userId,
    required this.category,
    required this.taskName,
    required this.applicableTo,
    this.defaultIntervalKm,
    this.defaultIntervalMonths,
    required this.isDeleted,
    required this.syncStatus,
    required this.updatedAt,
  });

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || userId != null) map['user_id'] = Variable<String>(userId);
    map['category'] = Variable<String>(category);
    map['task_name'] = Variable<String>(taskName);
    map['applicable_to'] = Variable<String>(applicableTo);
    if (!nullToAbsent || defaultIntervalKm != null) map['default_interval_km'] = Variable<int>(defaultIntervalKm);
    if (!nullToAbsent || defaultIntervalMonths != null) map['default_interval_months'] = Variable<int>(defaultIntervalMonths);
    map['is_deleted'] = Variable<bool>(isDeleted);
    map['sync_status'] = Variable<String>(syncStatus);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }
}

class MaintenanceTasksTemplateTableCompanion extends UpdateCompanion<MaintenanceTasksTemplateTableData> {
  final Value<String> id;
  final Value<String?> userId;
  final Value<String> category;
  final Value<String> taskName;
  final Value<String> applicableTo;
  final Value<int?> defaultIntervalKm;
  final Value<int?> defaultIntervalMonths;
  final Value<bool> isDeleted;
  final Value<String> syncStatus;
  final Value<DateTime> updatedAt;

  const MaintenanceTasksTemplateTableCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.category = const Value.absent(),
    this.taskName = const Value.absent(),
    this.applicableTo = const Value.absent(),
    this.defaultIntervalKm = const Value.absent(),
    this.defaultIntervalMonths = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) map['id'] = Variable<String>(id.value);
    if (userId.present) map['user_id'] = Variable<String?>(userId.value);
    if (category.present) map['category'] = Variable<String>(category.value);
    if (taskName.present) map['task_name'] = Variable<String>(taskName.value);
    if (applicableTo.present) map['applicable_to'] = Variable<String>(applicableTo.value);
    if (defaultIntervalKm.present) map['default_interval_km'] = Variable<int?>(defaultIntervalKm.value);
    if (defaultIntervalMonths.present) map['default_interval_months'] = Variable<int?>(defaultIntervalMonths.value);
    if (isDeleted.present) map['is_deleted'] = Variable<bool>(isDeleted.value);
    if (syncStatus.present) map['sync_status'] = Variable<String>(syncStatus.value);
    if (updatedAt.present) map['updated_at'] = Variable<DateTime>(updatedAt.value);
    return map;
  }
}

class ServiceVisitsTableData extends DataClass implements Insertable<ServiceVisitsTableData> {
  final String id;
  final String vehicleId;
  final String? contactId;
  final DateTime serviceDate;
  final int odometerKm;
  final String? visitTitle;
  final String? receiptPhotoUrl;
  final String? notes;
  final bool isDeleted;
  final String syncStatus;
  final DateTime updatedAt;

  const ServiceVisitsTableData({
    required this.id,
    required this.vehicleId,
    this.contactId,
    required this.serviceDate,
    required this.odometerKm,
    this.visitTitle,
    this.receiptPhotoUrl,
    this.notes,
    required this.isDeleted,
    required this.syncStatus,
    required this.updatedAt,
  });

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['vehicle_id'] = Variable<String>(vehicleId);
    if (!nullToAbsent || contactId != null) map['contact_id'] = Variable<String>(contactId);
    map['service_date'] = Variable<DateTime>(serviceDate);
    map['odometer_km'] = Variable<int>(odometerKm);
    if (!nullToAbsent || visitTitle != null) map['visit_title'] = Variable<String>(visitTitle);
    if (!nullToAbsent || receiptPhotoUrl != null) map['receipt_photo_url'] = Variable<String>(receiptPhotoUrl);
    if (!nullToAbsent || notes != null) map['notes'] = Variable<String>(notes);
    map['is_deleted'] = Variable<bool>(isDeleted);
    map['sync_status'] = Variable<String>(syncStatus);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }
}

class ServiceVisitsTableCompanion extends UpdateCompanion<ServiceVisitsTableData> {
  final Value<String> id;
  final Value<String> vehicleId;
  final Value<String?> contactId;
  final Value<DateTime> serviceDate;
  final Value<int> odometerKm;
  final Value<String?> visitTitle;
  final Value<String?> receiptPhotoUrl;
  final Value<String?> notes;
  final Value<bool> isDeleted;
  final Value<String> syncStatus;
  final Value<DateTime> updatedAt;

  const ServiceVisitsTableCompanion({
    this.id = const Value.absent(),
    this.vehicleId = const Value.absent(),
    this.contactId = const Value.absent(),
    this.serviceDate = const Value.absent(),
    this.odometerKm = const Value.absent(),
    this.visitTitle = const Value.absent(),
    this.receiptPhotoUrl = const Value.absent(),
    this.notes = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) map['id'] = Variable<String>(id.value);
    if (vehicleId.present) map['vehicle_id'] = Variable<String>(vehicleId.value);
    if (contactId.present) map['contact_id'] = Variable<String?>(contactId.value);
    if (serviceDate.present) map['service_date'] = Variable<DateTime>(serviceDate.value);
    if (odometerKm.present) map['odometer_km'] = Variable<int>(odometerKm.value);
    if (visitTitle.present) map['visit_title'] = Variable<String?>(visitTitle.value);
    if (receiptPhotoUrl.present) map['receipt_photo_url'] = Variable<String?>(receiptPhotoUrl.value);
    if (notes.present) map['notes'] = Variable<String?>(notes.value);
    if (isDeleted.present) map['is_deleted'] = Variable<bool>(isDeleted.value);
    if (syncStatus.present) map['sync_status'] = Variable<String>(syncStatus.value);
    if (updatedAt.present) map['updated_at'] = Variable<DateTime>(updatedAt.value);
    return map;
  }
}

class MaintenanceLogsTableData extends DataClass implements Insertable<MaintenanceLogsTableData> {
  final String id;
  final String? visitId;
  final String vehicleId;
  final String taskId;
  final String? contactId;
  final DateTime serviceDate;
  final int odometerKm;
  final double costPartsUsd;
  final double costLaborUsd;
  final String? partBrand;
  final String? partNumber;
  final double? fluidVolumeL;
  final String? wheelPositions;
  final String? tireDotCode;
  final double? measurementMm;
  final DateTime? warrantyExpiresDate;
  final String? notes;
  final String? receiptPhotoUrl;
  final int? nextDueKm;
  final DateTime? nextDueDate;
  final bool isDeleted;
  final String syncStatus;
  final DateTime updatedAt;

  const MaintenanceLogsTableData({
    required this.id,
    this.visitId,
    required this.vehicleId,
    required this.taskId,
    this.contactId,
    required this.serviceDate,
    required this.odometerKm,
    required this.costPartsUsd,
    required this.costLaborUsd,
    this.partBrand,
    this.partNumber,
    this.fluidVolumeL,
    this.wheelPositions,
    this.tireDotCode,
    this.measurementMm,
    this.warrantyExpiresDate,
    this.notes,
    this.receiptPhotoUrl,
    this.nextDueKm,
    this.nextDueDate,
    required this.isDeleted,
    required this.syncStatus,
    required this.updatedAt,
  });

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || visitId != null) map['visit_id'] = Variable<String>(visitId);
    map['vehicle_id'] = Variable<String>(vehicleId);
    map['task_id'] = Variable<String>(taskId);
    if (!nullToAbsent || contactId != null) map['contact_id'] = Variable<String>(contactId);
    map['service_date'] = Variable<DateTime>(serviceDate);
    map['odometer_km'] = Variable<int>(odometerKm);
    map['cost_parts_usd'] = Variable<double>(costPartsUsd);
    map['cost_labor_usd'] = Variable<double>(costLaborUsd);
    if (!nullToAbsent || partBrand != null) map['part_brand'] = Variable<String>(partBrand);
    if (!nullToAbsent || partNumber != null) map['part_number'] = Variable<String>(partNumber);
    if (!nullToAbsent || fluidVolumeL != null) map['fluid_volume_l'] = Variable<double>(fluidVolumeL);
    if (!nullToAbsent || wheelPositions != null) map['wheel_positions'] = Variable<String>(wheelPositions);
    if (!nullToAbsent || tireDotCode != null) map['tire_dot_code'] = Variable<String>(tireDotCode);
    if (!nullToAbsent || measurementMm != null) map['measurement_mm'] = Variable<double>(measurementMm);
    if (!nullToAbsent || warrantyExpiresDate != null) map['warranty_expires_date'] = Variable<DateTime>(warrantyExpiresDate);
    if (!nullToAbsent || notes != null) map['notes'] = Variable<String>(notes);
    if (!nullToAbsent || receiptPhotoUrl != null) map['receipt_photo_url'] = Variable<String>(receiptPhotoUrl);
    if (!nullToAbsent || nextDueKm != null) map['next_due_km'] = Variable<int>(nextDueKm);
    if (!nullToAbsent || nextDueDate != null) map['next_due_date'] = Variable<DateTime>(nextDueDate);
    map['is_deleted'] = Variable<bool>(isDeleted);
    map['sync_status'] = Variable<String>(syncStatus);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }
}

class MaintenanceLogsTableCompanion extends UpdateCompanion<MaintenanceLogsTableData> {
  final Value<String> id;
  final Value<String?> visitId;
  final Value<String> vehicleId;
  final Value<String> taskId;
  final Value<String?> contactId;
  final Value<DateTime> serviceDate;
  final Value<int> odometerKm;
  final Value<double> costPartsUsd;
  final Value<double> costLaborUsd;
  final Value<String?> partBrand;
  final Value<String?> partNumber;
  final Value<double?> fluidVolumeL;
  final Value<String?> wheelPositions;
  final Value<String?> tireDotCode;
  final Value<double?> measurementMm;
  final Value<DateTime?> warrantyExpiresDate;
  final Value<String?> notes;
  final Value<String?> receiptPhotoUrl;
  final Value<int?> nextDueKm;
  final Value<DateTime?> nextDueDate;
  final Value<bool> isDeleted;
  final Value<String> syncStatus;
  final Value<DateTime> updatedAt;

  const MaintenanceLogsTableCompanion({
    this.id = const Value.absent(),
    this.visitId = const Value.absent(),
    this.vehicleId = const Value.absent(),
    this.taskId = const Value.absent(),
    this.contactId = const Value.absent(),
    this.serviceDate = const Value.absent(),
    this.odometerKm = const Value.absent(),
    this.costPartsUsd = const Value.absent(),
    this.costLaborUsd = const Value.absent(),
    this.partBrand = const Value.absent(),
    this.partNumber = const Value.absent(),
    this.fluidVolumeL = const Value.absent(),
    this.wheelPositions = const Value.absent(),
    this.tireDotCode = const Value.absent(),
    this.measurementMm = const Value.absent(),
    this.warrantyExpiresDate = const Value.absent(),
    this.notes = const Value.absent(),
    this.receiptPhotoUrl = const Value.absent(),
    this.nextDueKm = const Value.absent(),
    this.nextDueDate = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) map['id'] = Variable<String>(id.value);
    if (visitId.present) map['visit_id'] = Variable<String?>(visitId.value);
    if (vehicleId.present) map['vehicle_id'] = Variable<String>(vehicleId.value);
    if (taskId.present) map['task_id'] = Variable<String>(taskId.value);
    if (contactId.present) map['contact_id'] = Variable<String?>(contactId.value);
    if (serviceDate.present) map['service_date'] = Variable<DateTime>(serviceDate.value);
    if (odometerKm.present) map['odometer_km'] = Variable<int>(odometerKm.value);
    if (costPartsUsd.present) map['cost_parts_usd'] = Variable<double>(costPartsUsd.value);
    if (costLaborUsd.present) map['cost_labor_usd'] = Variable<double>(costLaborUsd.value);
    if (partBrand.present) map['part_brand'] = Variable<String?>(partBrand.value);
    if (partNumber.present) map['part_number'] = Variable<String?>(partNumber.value);
    if (fluidVolumeL.present) map['fluid_volume_l'] = Variable<double?>(fluidVolumeL.value);
    if (wheelPositions.present) map['wheel_positions'] = Variable<String?>(wheelPositions.value);
    if (tireDotCode.present) map['tire_dot_code'] = Variable<String?>(tireDotCode.value);
    if (measurementMm.present) map['measurement_mm'] = Variable<double?>(measurementMm.value);
    if (warrantyExpiresDate.present) map['warranty_expires_date'] = Variable<DateTime?>(warrantyExpiresDate.value);
    if (notes.present) map['notes'] = Variable<String?>(notes.value);
    if (receiptPhotoUrl.present) map['receipt_photo_url'] = Variable<String?>(receiptPhotoUrl.value);
    if (nextDueKm.present) map['next_due_km'] = Variable<int?>(nextDueKm.value);
    if (nextDueDate.present) map['next_due_date'] = Variable<DateTime?>(nextDueDate.value);
    if (isDeleted.present) map['is_deleted'] = Variable<bool>(isDeleted.value);
    if (syncStatus.present) map['sync_status'] = Variable<String>(syncStatus.value);
    if (updatedAt.present) map['updated_at'] = Variable<DateTime>(updatedAt.value);
    return map;
  }
}

class DiagnosticSymptomsTableData extends DataClass implements Insertable<DiagnosticSymptomsTableData> {
  final String id;
  final String vehicleId;
  final String? resolvedByLogId;
  final DateTime loggedDate;
  final int odometerKm;
  final String? obdCode;
  final String engineState;
  final String symptomDescription;
  final String? audioClipUrl;
  final bool isResolved;
  final bool isDeleted;
  final String syncStatus;
  final DateTime updatedAt;

  const DiagnosticSymptomsTableData({
    required this.id,
    required this.vehicleId,
    this.resolvedByLogId,
    required this.loggedDate,
    required this.odometerKm,
    this.obdCode,
    required this.engineState,
    required this.symptomDescription,
    this.audioClipUrl,
    required this.isResolved,
    required this.isDeleted,
    required this.syncStatus,
    required this.updatedAt,
  });

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['vehicle_id'] = Variable<String>(vehicleId);
    if (!nullToAbsent || resolvedByLogId != null) map['resolved_by_log_id'] = Variable<String>(resolvedByLogId);
    map['logged_date'] = Variable<DateTime>(loggedDate);
    map['odometer_km'] = Variable<int>(odometerKm);
    if (!nullToAbsent || obdCode != null) map['obd_code'] = Variable<String>(obdCode);
    map['engine_state'] = Variable<String>(engineState);
    map['symptom_description'] = Variable<String>(symptomDescription);
    if (!nullToAbsent || audioClipUrl != null) map['audio_clip_url'] = Variable<String>(audioClipUrl);
    map['is_resolved'] = Variable<bool>(isResolved);
    map['is_deleted'] = Variable<bool>(isDeleted);
    map['sync_status'] = Variable<String>(syncStatus);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }
}

class DiagnosticSymptomsTableCompanion extends UpdateCompanion<DiagnosticSymptomsTableData> {
  final Value<String> id;
  final Value<String> vehicleId;
  final Value<String?> resolvedByLogId;
  final Value<DateTime> loggedDate;
  final Value<int> odometerKm;
  final Value<String?> obdCode;
  final Value<String> engineState;
  final Value<String> symptomDescription;
  final Value<String?> audioClipUrl;
  final Value<bool> isResolved;
  final Value<bool> isDeleted;
  final Value<String> syncStatus;
  final Value<DateTime> updatedAt;

  const DiagnosticSymptomsTableCompanion({
    this.id = const Value.absent(),
    this.vehicleId = const Value.absent(),
    this.resolvedByLogId = const Value.absent(),
    this.loggedDate = const Value.absent(),
    this.odometerKm = const Value.absent(),
    this.obdCode = const Value.absent(),
    this.engineState = const Value.absent(),
    this.symptomDescription = const Value.absent(),
    this.audioClipUrl = const Value.absent(),
    this.isResolved = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) map['id'] = Variable<String>(id.value);
    if (vehicleId.present) map['vehicle_id'] = Variable<String>(vehicleId.value);
    if (resolvedByLogId.present) map['resolved_by_log_id'] = Variable<String?>(resolvedByLogId.value);
    if (loggedDate.present) map['logged_date'] = Variable<DateTime>(loggedDate.value);
    if (odometerKm.present) map['odometer_km'] = Variable<int>(odometerKm.value);
    if (obdCode.present) map['obd_code'] = Variable<String?>(obdCode.value);
    if (engineState.present) map['engine_state'] = Variable<String>(engineState.value);
    if (symptomDescription.present) map['symptom_description'] = Variable<String>(symptomDescription.value);
    if (audioClipUrl.present) map['audio_clip_url'] = Variable<String?>(audioClipUrl.value);
    if (isResolved.present) map['is_resolved'] = Variable<bool>(isResolved.value);
    if (isDeleted.present) map['is_deleted'] = Variable<bool>(isDeleted.value);
    if (syncStatus.present) map['sync_status'] = Variable<String>(syncStatus.value);
    if (updatedAt.present) map['updated_at'] = Variable<DateTime>(updatedAt.value);
    return map;
  }
}

class FuelLogsTableData extends DataClass implements Insertable<FuelLogsTableData> {
  final String id;
  final String vehicleId;
  final DateTime fillDate;
  final int odometerKm;
  final double fuelLiters;
  final double pricePerLiterUsd;
  final double totalCostUsd;
  final bool isFullTank;
  final double? calculatedLPer100km;
  final bool isDeleted;
  final String syncStatus;
  final DateTime updatedAt;

  const FuelLogsTableData({
    required this.id,
    required this.vehicleId,
    required this.fillDate,
    required this.odometerKm,
    required this.fuelLiters,
    required this.pricePerLiterUsd,
    required this.totalCostUsd,
    required this.isFullTank,
    this.calculatedLPer100km,
    required this.isDeleted,
    required this.syncStatus,
    required this.updatedAt,
  });

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['vehicle_id'] = Variable<String>(vehicleId);
    map['fill_date'] = Variable<DateTime>(fillDate);
    map['odometer_km'] = Variable<int>(odometerKm);
    map['fuel_liters'] = Variable<double>(fuelLiters);
    map['price_per_liter_usd'] = Variable<double>(pricePerLiterUsd);
    map['total_cost_usd'] = Variable<double>(totalCostUsd);
    map['is_full_tank'] = Variable<bool>(isFullTank);
    if (!nullToAbsent || calculatedLPer100km != null) map['calculated_l_per_100km'] = Variable<double>(calculatedLPer100km);
    map['is_deleted'] = Variable<bool>(isDeleted);
    map['sync_status'] = Variable<String>(syncStatus);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }
}

class FuelLogsTableCompanion extends UpdateCompanion<FuelLogsTableData> {
  final Value<String> id;
  final Value<String> vehicleId;
  final Value<DateTime> fillDate;
  final Value<int> odometerKm;
  final Value<double> fuelLiters;
  final Value<double> pricePerLiterUsd;
  final Value<double> totalCostUsd;
  final Value<bool> isFullTank;
  final Value<double?> calculatedLPer100km;
  final Value<bool> isDeleted;
  final Value<String> syncStatus;
  final Value<DateTime> updatedAt;

  const FuelLogsTableCompanion({
    this.id = const Value.absent(),
    this.vehicleId = const Value.absent(),
    this.fillDate = const Value.absent(),
    this.odometerKm = const Value.absent(),
    this.fuelLiters = const Value.absent(),
    this.pricePerLiterUsd = const Value.absent(),
    this.totalCostUsd = const Value.absent(),
    this.isFullTank = const Value.absent(),
    this.calculatedLPer100km = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) map['id'] = Variable<String>(id.value);
    if (vehicleId.present) map['vehicle_id'] = Variable<String>(vehicleId.value);
    if (fillDate.present) map['fill_date'] = Variable<DateTime>(fillDate.value);
    if (odometerKm.present) map['odometer_km'] = Variable<int>(odometerKm.value);
    if (fuelLiters.present) map['fuel_liters'] = Variable<double>(fuelLiters.value);
    if (pricePerLiterUsd.present) map['price_per_liter_usd'] = Variable<double>(pricePerLiterUsd.value);
    if (totalCostUsd.present) map['total_cost_usd'] = Variable<double>(totalCostUsd.value);
    if (isFullTank.present) map['is_full_tank'] = Variable<bool>(isFullTank.value);
    if (calculatedLPer100km.present) map['calculated_l_per_100km'] = Variable<double?>(calculatedLPer100km.value);
    if (isDeleted.present) map['is_deleted'] = Variable<bool>(isDeleted.value);
    if (syncStatus.present) map['sync_status'] = Variable<String>(syncStatus.value);
    if (updatedAt.present) map['updated_at'] = Variable<DateTime>(updatedAt.value);
    return map;
  }
}

class GarageInventoryTableData extends DataClass implements Insertable<GarageInventoryTableData> {
  final String id;
  final String userId;
  final String? vehicleId;
  final String? taskId;
  final String itemName;
  final String? partBrand;
  final String? partNumber;
  final double quantity;
  final String unitLabel;
  final double? purchasePriceUsd;
  final bool isDeleted;
  final String syncStatus;
  final DateTime updatedAt;

  const GarageInventoryTableData({
    required this.id,
    required this.userId,
    this.vehicleId,
    this.taskId,
    required this.itemName,
    this.partBrand,
    this.partNumber,
    required this.quantity,
    required this.unitLabel,
    this.purchasePriceUsd,
    required this.isDeleted,
    required this.syncStatus,
    required this.updatedAt,
  });

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['user_id'] = Variable<String>(userId);
    if (!nullToAbsent || vehicleId != null) map['vehicle_id'] = Variable<String>(vehicleId);
    if (!nullToAbsent || taskId != null) map['task_id'] = Variable<String>(taskId);
    map['item_name'] = Variable<String>(itemName);
    if (!nullToAbsent || partBrand != null) map['part_brand'] = Variable<String>(partBrand);
    if (!nullToAbsent || partNumber != null) map['part_number'] = Variable<String>(partNumber);
    map['quantity'] = Variable<double>(quantity);
    map['unit_label'] = Variable<String>(unitLabel);
    if (!nullToAbsent || purchasePriceUsd != null) map['purchase_price_usd'] = Variable<double>(purchasePriceUsd);
    map['is_deleted'] = Variable<bool>(isDeleted);
    map['sync_status'] = Variable<String>(syncStatus);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }
}

class GarageInventoryTableCompanion extends UpdateCompanion<GarageInventoryTableData> {
  final Value<String> id;
  final Value<String> userId;
  final Value<String?> vehicleId;
  final Value<String?> taskId;
  final Value<String> itemName;
  final Value<String?> partBrand;
  final Value<String?> partNumber;
  final Value<double> quantity;
  final Value<String> unitLabel;
  final Value<double?> purchasePriceUsd;
  final Value<bool> isDeleted;
  final Value<String> syncStatus;
  final Value<DateTime> updatedAt;

  const GarageInventoryTableCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.vehicleId = const Value.absent(),
    this.taskId = const Value.absent(),
    this.itemName = const Value.absent(),
    this.partBrand = const Value.absent(),
    this.partNumber = const Value.absent(),
    this.quantity = const Value.absent(),
    this.unitLabel = const Value.absent(),
    this.purchasePriceUsd = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) map['id'] = Variable<String>(id.value);
    if (userId.present) map['user_id'] = Variable<String>(userId.value);
    if (vehicleId.present) map['vehicle_id'] = Variable<String?>(vehicleId.value);
    if (taskId.present) map['task_id'] = Variable<String?>(taskId.value);
    if (itemName.present) map['item_name'] = Variable<String>(itemName.value);
    if (partBrand.present) map['part_brand'] = Variable<String?>(partBrand.value);
    if (partNumber.present) map['part_number'] = Variable<String?>(partNumber.value);
    if (quantity.present) map['quantity'] = Variable<double>(quantity.value);
    if (unitLabel.present) map['unit_label'] = Variable<String>(unitLabel.value);
    if (purchasePriceUsd.present) map['purchase_price_usd'] = Variable<double?>(purchasePriceUsd.value);
    if (isDeleted.present) map['is_deleted'] = Variable<bool>(isDeleted.value);
    if (syncStatus.present) map['sync_status'] = Variable<String>(syncStatus.value);
    if (updatedAt.present) map['updated_at'] = Variable<DateTime>(updatedAt.value);
    return map;
  }
}

class VehiclePartCatalogTableData extends DataClass implements Insertable<VehiclePartCatalogTableData> {
  final String id;
  final String make;
  final String model;
  final int yearStart;
  final int yearEnd;
  final int engineDisplacementCc;
  final String taskId;
  final String partBrand;
  final String partNumber;
  final String? specsNote;
  final int usageCount;
  final bool verifiedByAdmin;
  final DateTime updatedAt;

  const VehiclePartCatalogTableData({
    required this.id,
    required this.make,
    required this.model,
    required this.yearStart,
    required this.yearEnd,
    required this.engineDisplacementCc,
    required this.taskId,
    required this.partBrand,
    required this.partNumber,
    this.specsNote,
    required this.usageCount,
    required this.verifiedByAdmin,
    required this.updatedAt,
  });

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['make'] = Variable<String>(make);
    map['model'] = Variable<String>(model);
    map['year_start'] = Variable<int>(yearStart);
    map['year_end'] = Variable<int>(yearEnd);
    map['engine_displacement_cc'] = Variable<int>(engineDisplacementCc);
    map['task_id'] = Variable<String>(taskId);
    map['part_brand'] = Variable<String>(partBrand);
    map['part_number'] = Variable<String>(partNumber);
    if (!nullToAbsent || specsNote != null) map['specs_note'] = Variable<String>(specsNote);
    map['usage_count'] = Variable<int>(usageCount);
    map['verified_by_admin'] = Variable<bool>(verifiedByAdmin);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }
}

class SyncMetaTableData extends DataClass implements Insertable<SyncMetaTableData> {
  final String metaKey;
  final String metaValue;

  const SyncMetaTableData({required this.metaKey, required this.metaValue});

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['meta_key'] = Variable<String>(metaKey);
    map['meta_value'] = Variable<String>(metaValue);
    return map;
  }
}

class SyncMetaTableCompanion extends UpdateCompanion<SyncMetaTableData> {
  final Value<String> metaKey;
  final Value<String> metaValue;

  const SyncMetaTableCompanion({
    this.metaKey = const Value.absent(),
    this.metaValue = const Value.absent(),
  });

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (metaKey.present) map['meta_key'] = Variable<String>(metaKey.value);
    if (metaValue.present) map['meta_value'] = Variable<String>(metaValue.value);
    return map;
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  late final VehiclesTable vehiclesTable = VehiclesTable();
  late final VehicleQuickSpecsTable vehicleQuickSpecsTable = VehicleQuickSpecsTable();
  late final ContactsDirectoryTable contactsDirectoryTable = ContactsDirectoryTable();
  late final MaintenanceTasksTemplateTable maintenanceTasksTemplateTable = MaintenanceTasksTemplateTable();
  late final ServiceVisitsTable serviceVisitsTable = ServiceVisitsTable();
  late final MaintenanceLogsTable maintenanceLogsTable = MaintenanceLogsTable();
  late final DiagnosticSymptomsTable diagnosticSymptomsTable = DiagnosticSymptomsTable();
  late final FuelLogsTable fuelLogsTable = FuelLogsTable();
  late final GarageInventoryTable garageInventoryTable = GarageInventoryTable();
  late final VehiclePartCatalogTable vehiclePartCatalogTable = VehiclePartCatalogTable();
  late final SyncMetaTable syncMetaTable = SyncMetaTable();

  @override
  Iterable<TableInfo<Table, Object?>> get allTables => allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        vehiclesTable,
        vehicleQuickSpecsTable,
        contactsDirectoryTable,
        maintenanceTasksTemplateTable,
        serviceVisitsTable,
        maintenanceLogsTable,
        diagnosticSymptomsTable,
        fuelLogsTable,
        garageInventoryTable,
        vehiclePartCatalogTable,
        syncMetaTable,
      ];
}
