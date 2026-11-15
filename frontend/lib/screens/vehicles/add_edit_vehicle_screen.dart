// =============================================================================
// CarLog Add / Edit Vehicle Screen
// 3-Step VIN Decoder, Camera OCR Scanner & Metric Quick-Specs Editor
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/carlog_providers.dart';
import '../../core/theme/carlog_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/vin_metric_normalizer.dart';
import '../../core/network/connectivity_guard.dart';
import '../../core/network/toast_service.dart';
import '../../widgets/ocr_scan_button.dart';
import '../../widgets/metric_helper_chip.dart';

class AddEditVehicleScreen extends ConsumerStatefulWidget {
  final String? vehicleIdToEdit;

  const AddEditVehicleScreen({super.key, this.vehicleIdToEdit});

  @override
  ConsumerState<AddEditVehicleScreen> createState() => _AddEditVehicleScreenState();
}

class _AddEditVehicleScreenState extends ConsumerState<AddEditVehicleScreen> {
  final _formKey = GlobalKey<FormState>();

  // Core Controllers
  final _vinController = TextEditingController();
  final _plateController = TextEditingController();
  final _makeController = TextEditingController();
  final _modelController = TextEditingController();
  final _yearController = TextEditingController();
  final _displacementCcController = TextEditingController();
  final _engineCodeController = TextEditingController();
  final _powerKwController = TextEditingController();
  final _acqOdoController = TextEditingController(text: '0');
  final _currentOdoController = TextEditingController(text: '0');

  String _vehicleType = 'car';
  String _transmission = 'manual';
  String _fuelType = 'gasoline';

  // Quick Specs Controllers
  final _oilViscosityController = TextEditingController();
  final _oilCapacityLController = TextEditingController();
  final _coolantSpecController = TextEditingController();
  final _coolantCapacityLController = TextEditingController();
  final _frontTireSizeController = TextEditingController();
  final _rearTireSizeController = TextEditingController();
  final _frontTireBarController = TextEditingController();
  final _rearTireBarController = TextEditingController();
  final _wiperDriverMmController = TextEditingController();
  final _wiperPassengerMmController = TextEditingController();
  final _wiperRearMmController = TextEditingController();
  final _batterySpecController = TextEditingController();
  final _sparkPlugGapMmController = TextEditingController();
  final _lugTorqueNmController = TextEditingController();
  final _chainPitchController = TextEditingController();

  bool _isDecodingVin = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.vehicleIdToEdit != null) {
      _loadVehicleData(widget.vehicleIdToEdit!);
    }
  }

  Future<void> _loadVehicleData(String id) async {
    setState(() => _isLoading = true);
    final vehicle = await ref.read(vehicleDaoProvider).getVehicleById(id);
    final specs = await ref.read(vehicleDaoProvider).getQuickSpecs(id);

    if (vehicle != null) {
      _vinController.text = vehicle.vin ?? '';
      _plateController.text = vehicle.plateNumber ?? '';
      _makeController.text = vehicle.make;
      _modelController.text = vehicle.model;
      _yearController.text = vehicle.year.toString();
      _displacementCcController.text = vehicle.engineDisplacementCc?.toString() ?? '';
      _engineCodeController.text = vehicle.engineCode ?? '';
      _powerKwController.text = vehicle.powerKw?.toString() ?? '';
      _acqOdoController.text = vehicle.acquisitionOdometerKm.toString();
      _currentOdoController.text = vehicle.currentOdometerKm.toString();
      _vehicleType = vehicle.vehicleType;
      _transmission = vehicle.transmissionType;
      _fuelType = vehicle.fuelType;
    }

    if (specs != null) {
      _oilViscosityController.text = specs.oilViscosity ?? '';
      _oilCapacityLController.text = specs.oilCapacityL?.toString() ?? '';
      _coolantSpecController.text = specs.coolantSpec ?? '';
      _coolantCapacityLController.text = specs.coolantCapacityL?.toString() ?? '';
      _frontTireSizeController.text = specs.frontTireSize ?? '';
      _rearTireSizeController.text = specs.rearTireSize ?? '';
      _frontTireBarController.text = specs.frontTirePressureBar?.toString() ?? '';
      _rearTireBarController.text = specs.rearTirePressureBar?.toString() ?? '';
      _wiperDriverMmController.text = specs.wiperDriverMm?.toString() ?? '';
      _wiperPassengerMmController.text = specs.wiperPassengerMm?.toString() ?? '';
      _wiperRearMmController.text = specs.wiperRearMm?.toString() ?? '';
      _batterySpecController.text = specs.batterySpec ?? '';
      _sparkPlugGapMmController.text = specs.sparkPlugGapMm?.toString() ?? '';
      _lugTorqueNmController.text = specs.wheelLugTorqueNm?.toString() ?? '';
      _chainPitchController.text = specs.chainPitchMm ?? '';
    }

    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _vinController.dispose();
    _plateController.dispose();
    _makeController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _displacementCcController.dispose();
    _engineCodeController.dispose();
    _powerKwController.dispose();
    _acqOdoController.dispose();
    _currentOdoController.dispose();
    _oilViscosityController.dispose();
    _oilCapacityLController.dispose();
    _coolantSpecController.dispose();
    _coolantCapacityLController.dispose();
    _frontTireSizeController.dispose();
    _rearTireSizeController.dispose();
    _frontTireBarController.dispose();
    _rearTireBarController.dispose();
    _wiperDriverMmController.dispose();
    _wiperPassengerMmController.dispose();
    _wiperRearMmController.dispose();
    _batterySpecController.dispose();
    _sparkPlugGapMmController.dispose();
    _lugTorqueNmController.dispose();
    _chainPitchController.dispose();
    super.dispose();
  }

  /// 3-Step VIN Decoder Execution
  Future<void> _decodeVin() async {
    final vin = _vinController.text.trim().toUpperCase();
    if (vin.length < 3) {
      ToastService.show('Enter at least 3 VIN characters for WMI lookup', type: ToastType.warning);
      return;
    }

    setState(() => _isDecodingVin = true);

    // Step 1: Instant Offline Local WMI
    final wmiResult = await VinMetricNormalizer.lookupOfflineWmi(vin);
    if (wmiResult != null && mounted) {
      setState(() {
        if (_makeController.text.isEmpty) _makeController.text = wmiResult.make;
        _vehicleType = wmiResult.vehicleType;
      });
    }

    // Step 2 & 3: Online NHTSA vPIC + Metric Conversion
    if (vin.length == 17) {
      await ConnectivityGuard.run(
        featureName: 'NHTSA VIN Decoder',
        action: () async {
          final decoded = await VinMetricNormalizer.decodeVinOnline(vin);
          if (!mounted) return;
          setState(() {
            if (decoded.make.isNotEmpty) _makeController.text = decoded.make;
            if (decoded.model.isNotEmpty) _modelController.text = decoded.model;
            if (decoded.year != null) _yearController.text = decoded.year.toString();
            if (decoded.engineDisplacementCc != null) {
              _displacementCcController.text = decoded.engineDisplacementCc.toString();
            }
            if (decoded.engineCode != null && decoded.engineCode!.isNotEmpty) {
              _engineCodeController.text = decoded.engineCode!;
            }
            if (decoded.powerKw != null) _powerKwController.text = decoded.powerKw.toString();
            _vehicleType = decoded.vehicleType;
            _transmission = decoded.transmissionType;
            _fuelType = decoded.fuelType;
          });
          ToastService.show('VIN successfully decoded & normalized to Metric units!', type: ToastType.success);
        },
      );
    } else {
      ToastService.show('WMI: Auto-filled Make as ${_makeController.text} (Offline)', type: ToastType.info);
    }

    setState(() => _isDecodingVin = false);
  }

  Future<void> _saveVehicle() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = ref.read(authProvider);
    final userId = auth.id ?? 'default_user';

    setState(() => _isLoading = true);

    try {
      final vehicleId = await ref.read(vehicleDaoProvider).upsertVehicle(
        id: widget.vehicleIdToEdit,
        userId: userId,
        vehicleType: _vehicleType,
        vin: _vinController.text.trim().isNotEmpty ? _vinController.text.trim().toUpperCase() : null,
        plateNumber: _plateController.text.trim().isNotEmpty ? _plateController.text.trim().toUpperCase() : null,
        make: _makeController.text.trim(),
        model: _modelController.text.trim(),
        year: int.parse(_yearController.text.trim()),
        displacementCc: int.tryParse(_displacementCcController.text.trim()),
        engineCode: _engineCodeController.text.trim().isNotEmpty ? _engineCodeController.text.trim() : null,
        powerKw: int.tryParse(_powerKwController.text.trim()),
        transmissionType: _transmission,
        fuelType: _fuelType,
        acquisitionOdometerKm: int.tryParse(_acqOdoController.text.trim()) ?? 0,
        currentOdometerKm: int.tryParse(_currentOdoController.text.trim()) ?? 0,
      );

      // Save Quick Specs
      await ref.read(vehicleDaoProvider).saveQuickSpecs(
        vehicleId: vehicleId,
        oilViscosity: _oilViscosityController.text.trim().isNotEmpty ? _oilViscosityController.text.trim() : null,
        oilCapacityL: double.tryParse(_oilCapacityLController.text.trim()),
        coolantSpec: _coolantSpecController.text.trim().isNotEmpty ? _coolantSpecController.text.trim() : null,
        coolantCapacityL: double.tryParse(_coolantCapacityLController.text.trim()),
        frontTireSize: _frontTireSizeController.text.trim().isNotEmpty ? _frontTireSizeController.text.trim() : null,
        rearTireSize: _rearTireSizeController.text.trim().isNotEmpty ? _rearTireSizeController.text.trim() : null,
        frontTirePressureBar: double.tryParse(_frontTireBarController.text.trim()),
        rearTirePressureBar: double.tryParse(_rearTireBarController.text.trim()),
        wiperDriverMm: int.tryParse(_wiperDriverMmController.text.trim()),
        wiperPassengerMm: int.tryParse(_wiperPassengerMmController.text.trim()),
        wiperRearMm: int.tryParse(_wiperRearMmController.text.trim()),
        batterySpec: _batterySpecController.text.trim().isNotEmpty ? _batterySpecController.text.trim() : null,
        sparkPlugGapMm: double.tryParse(_sparkPlugGapMmController.text.trim()),
        wheelLugTorqueNm: int.tryParse(_lugTorqueNmController.text.trim()),
        chainPitchMm: _chainPitchController.text.trim().isNotEmpty ? _chainPitchController.text.trim() : null,
      );

      ref.read(selectedVehicleIdProvider.notifier).state = vehicleId;
      ref.invalidate(vehiclesStreamProvider);

      if (mounted) {
        ToastService.show('Vehicle & Metric Quick-Specs saved locally!', type: ToastType.success);
        Navigator.pop(context);
      }
    } catch (e) {
      ToastService.show('Failed to save vehicle: $e', type: ToastType.error);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.vehicleIdToEdit != null;
    final isMoto = _vehicleType == 'motorcycle';

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Vehicle & Specs' : 'Add Vehicle to Garage'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check_rounded, color: CarLogTheme.primaryCyan),
            onPressed: _isLoading ? null : _saveVehicle,
            tooltip: 'Save Vehicle',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: CarLogTheme.primaryCyan))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section 1: Vehicle Type Selector
                    Row(
                      children: AppConstants.vehicleTypes.map((type) {
                        final isSelected = _vehicleType == type;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(type.toUpperCase()),
                            selected: isSelected,
                            onSelected: (val) {
                              if (val) setState(() => _vehicleType = type);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Section 2: 3-Step VIN Decoder with OCR Button
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _vinController,
                            textCapitalization: TextCapitalization.characters,
                            decoration: InputDecoration(
                              labelText: 'VIN (17 Characters)',
                              hintText: 'e.g. 1HGCR2F83HA...',
                              suffixIcon: OcrScanButton(
                                scanType: OcrScanType.vin,
                                onTextRecognized: (text) {
                                  _vinController.text = text.replaceAll(' ', '').toUpperCase();
                                  _decodeVin();
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _isDecodingVin ? null : _decodeVin,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                          child: _isDecodingVin
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text('DECODE'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Make, Model, Year
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _makeController,
                            decoration: const InputDecoration(labelText: 'Make *'),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _modelController,
                            decoration: const InputDecoration(labelText: 'Model *'),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 1,
                          child: TextFormField(
                            controller: _yearController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Year *'),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Plate Number & Engine Code
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _plateController,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(labelText: 'Plate Number'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _engineCodeController,
                            decoration: const InputDecoration(labelText: 'Engine Code / Variant'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Engine Displacement (cc) & Power (kW) + Inline Helper Chips
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextFormField(
                                controller: _displacementCcController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(labelText: 'Displacement (cc)', suffixText: 'cc'),
                              ),
                              const SizedBox(height: 6),
                              MetricHelperChip(
                                controller: _displacementCcController,
                                type: MetricConversionType.ciToCc,
                                label: 'ci -> cc',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextFormField(
                                controller: _powerKwController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(labelText: 'Power (kW)', suffixText: 'kW'),
                              ),
                              const SizedBox(height: 6),
                              MetricHelperChip(
                                controller: _powerKwController,
                                type: MetricConversionType.hpToKw,
                                label: 'HP -> kW',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Transmission & Fuel Type
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _transmission,
                            decoration: const InputDecoration(labelText: 'Transmission'),
                            items: AppConstants.transmissionTypes.map((t) => DropdownMenuItem(value: t, child: Text(t.toUpperCase()))).toList(),
                            onChanged: (val) => setState(() => _transmission = val!),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _fuelType,
                            decoration: const InputDecoration(labelText: 'Fuel Type'),
                            items: AppConstants.fuelTypes.map((f) => DropdownMenuItem(value: f, child: Text(f.toUpperCase()))).toList(),
                            onChanged: (val) => setState(() => _fuelType = val!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Acquisition Odometer & Current Odometer (km) with OCR
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _acqOdoController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Acquisition Odometer', suffixText: 'km'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _currentOdoController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Current Odometer *',
                              suffixText: 'km',
                              suffixIcon: OcrScanButton(
                                scanType: OcrScanType.odometer,
                                onTextRecognized: (text) {
                                  final numOnly = text.replaceAll(RegExp(r'[^0-9]'), '');
                                  if (numOnly.isNotEmpty) _currentOdoController.text = numOnly;
                                },
                              ),
                            ),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // Section 3: Glovebox Quick-Specs Form
                    const Row(
                      children: [
                        Icon(Icons.menu_book_rounded, color: CarLogTheme.primaryCyan, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Glovebox Quick-Specs (100% Metric)',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: CarLogTheme.textMain),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Oil Viscosity & Capacity (L)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _oilViscosityController,
                            decoration: const InputDecoration(labelText: 'Engine Oil Viscosity', hintText: 'e.g. 5W-30 / 10W-40'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextFormField(
                                controller: _oilCapacityLController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(labelText: 'Oil Capacity (L)', suffixText: 'L'),
                              ),
                              const SizedBox(height: 6),
                              MetricHelperChip(
                                controller: _oilCapacityLController,
                                type: MetricConversionType.quartsToLiters,
                                label: 'Qt -> L',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Coolant Spec & Capacity (L)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _coolantSpecController,
                            decoration: const InputDecoration(labelText: 'Coolant Spec', hintText: 'e.g. G12+ / G13'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextFormField(
                                controller: _coolantCapacityLController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(labelText: 'Coolant Capacity (L)', suffixText: 'L'),
                              ),
                              const SizedBox(height: 6),
                              MetricHelperChip(
                                controller: _coolantCapacityLController,
                                type: MetricConversionType.quartsToLiters,
                                label: 'Qt -> L',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Tire Pressure (Bar) + PSI Helper Chips
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextFormField(
                                controller: _frontTireBarController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(labelText: 'Front Tire Pressure', suffixText: 'Bar'),
                              ),
                              const SizedBox(height: 6),
                              MetricHelperChip(
                                controller: _frontTireBarController,
                                type: MetricConversionType.psiToBar,
                                label: 'PSI -> Bar',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextFormField(
                                controller: _rearTireBarController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(labelText: 'Rear Tire Pressure', suffixText: 'Bar'),
                              ),
                              const SizedBox(height: 6),
                              MetricHelperChip(
                                controller: _rearTireBarController,
                                type: MetricConversionType.psiToBar,
                                label: 'PSI -> Bar',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Wheel Lug Torque (Nm) & Spark Plug Gap (mm)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextFormField(
                                controller: _lugTorqueNmController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(labelText: 'Lug Torque (Nm)', suffixText: 'Nm'),
                              ),
                              const SizedBox(height: 6),
                              MetricHelperChip(
                                controller: _lugTorqueNmController,
                                type: MetricConversionType.lbFtToNm,
                                label: 'lb-ft -> Nm',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _sparkPlugGapMmController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'Spark Plug Gap', suffixText: 'mm'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    if (isMoto)
                      TextFormField(
                        controller: _chainPitchController,
                        decoration: const InputDecoration(labelText: 'Drive Chain Pitch', hintText: 'e.g. 520, 525, 530'),
                      )
                    else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextFormField(
                                  controller: _wiperDriverMmController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(labelText: 'Driver Wiper', suffixText: 'mm'),
                                ),
                                const SizedBox(height: 6),
                                MetricHelperChip(
                                  controller: _wiperDriverMmController,
                                  type: MetricConversionType.inchesToMm,
                                  label: 'in -> mm',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextFormField(
                                  controller: _wiperPassengerMmController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(labelText: 'Passenger Wiper', suffixText: 'mm'),
                                ),
                                const SizedBox(height: 6),
                                MetricHelperChip(
                                  controller: _wiperPassengerMmController,
                                  type: MetricConversionType.inchesToMm,
                                  label: 'in -> mm',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                    const SizedBox(height: 36),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _saveVehicle,
                      child: Text(isEditing ? 'UPDATE VEHICLE & SPECS' : 'SAVE VEHICLE TO GARAGE'),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }
}
