// =============================================================================
// CarLog Add Diagnostic Symptom Screen
// 10s Audio Recorder (.m4a), Offline OBD-II Code Lookup & Engine State
// =============================================================================

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../providers/carlog_providers.dart';
import '../../core/theme/carlog_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../data/local/daos/symptom_dao.dart';
import '../../core/network/toast_service.dart';

class AddSymptomScreen extends ConsumerStatefulWidget {
  final String vehicleId;

  const AddSymptomScreen({super.key, required this.vehicleId});

  @override
  ConsumerState<AddSymptomScreen> createState() => _AddSymptomScreenState();
}

class _AddSymptomScreenState extends ConsumerState<AddSymptomScreen> {
  final _formKey = GlobalKey<FormState>();
  final _odometerController = TextEditingController();
  final _obdController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _engineState = 'other';
  List<ObdCodeEntry> _obdSuggestions = [];

  // Audio Recording (Max 10 seconds)
  late final AudioRecorder _audioRecorder;
  late final AudioPlayer _audioPlayer;
  bool _isRecording = false;
  bool _isPlaying = false;
  String? _recordedAudioPath;
  int _recordSeconds = 0;
  Timer? _recordTimer;

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();
    _audioPlayer = AudioPlayer();
    _audioPlayer.onPlayerComplete.listen((_) => setState(() => _isPlaying = false));
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _odometerController.dispose();
    _obdController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getApplicationDocumentsDirectory();
        final path = '${dir.path}/symptom_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000, sampleRate: 44100),
          path: path,
        );

        setState(() {
          _isRecording = true;
          _recordSeconds = 0;
          _recordedAudioPath = null;
        });

        _recordTimer?.cancel();
        _recordTimer = Timer.periodic(const Duration(seconds: 1), (t) async {
          setState(() => _recordSeconds++);
          if (_recordSeconds >= 10) {
            await _stopRecording();
          }
        });
      }
    } catch (e) {
      ToastService.show('Audio recording error: $e', type: ToastType.error);
    }
  }

  Future<void> _stopRecording() async {
    _recordTimer?.cancel();
    try {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
        _recordedAudioPath = path;
      });
      ToastService.show('10-second diagnostic audio recorded!', type: ToastType.success);
    } catch (e) {
      setState(() => _isRecording = false);
    }
  }

  Future<void> _playAudio() async {
    if (_recordedAudioPath == null) return;
    if (_isPlaying) {
      await _audioPlayer.stop();
      setState(() => _isPlaying = false);
    } else {
      await _audioPlayer.play(DeviceFileSource(_recordedAudioPath!));
      setState(() => _isPlaying = true);
    }
  }

  Future<void> _searchObdCodes(String query) async {
    final results = await SymptomDao.searchOfflineObd(query);
    setState(() => _obdSuggestions = results);
  }

  Future<void> _saveSymptom() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final odo = int.parse(_odometerController.text.trim());
      await ref.read(symptomDaoProvider).addSymptom(
        vehicleId: widget.vehicleId,
        loggedDate: DateTime.now(),
        odometerKm: odo,
        obdCode: _obdController.text.trim().isNotEmpty ? _obdController.text.trim().toUpperCase() : null,
        engineState: _engineState,
        symptomDescription: _descriptionController.text.trim(),
        audioClipUrl: _recordedAudioPath,
      );

      if (mounted) {
        ToastService.show('Diagnostic symptom logged offline!', type: ToastType.success);
        Navigator.pop(context);
      }
    } catch (e) {
      ToastService.show('Failed to save symptom: $e', type: ToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log Diagnostic Symptom'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check_rounded, color: CarLogTheme.primaryCyan),
            onPressed: _saveSymptom,
            tooltip: 'Save Symptom',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Odometer Reading
              TextFormField(
                controller: _odometerController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Odometer Reading when noticed *', suffixText: 'km'),
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              // Engine State Selector
              const Text('Engine Operational State', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: CarLogTheme.textMain)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: AppConstants.engineStates.map((state) {
                  final isSelected = _engineState == state;
                  return ChoiceChip(
                    label: Text(state.replaceAll('_', ' ').toUpperCase()),
                    selected: isSelected,
                    onSelected: (val) {
                      if (val) setState(() => _engineState = state);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Offline OBD-II Lookup
              TextFormField(
                controller: _obdController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'OBD-II Fault Code (Optional)',
                  hintText: 'e.g. P0300, P0420, C0035',
                  prefixIcon: Icon(Icons.qr_code_scanner_rounded, color: CarLogTheme.primaryCyan),
                ),
                onChanged: _searchObdCodes,
              ),
              if (_obdSuggestions.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxHeight: 180),
                  decoration: BoxDecoration(
                    color: CarLogTheme.surfaceDark,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: CarLogTheme.borderDark),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _obdSuggestions.length,
                    separatorBuilder: (_, __) => const Divider(color: CarLogTheme.borderDark, height: 1),
                    itemBuilder: (ctx, i) {
                      final item = _obdSuggestions[i];
                      return ListTile(
                        dense: true,
                        title: Text('${item.code}: ${item.description}', style: const TextStyle(fontSize: 12.5, color: CarLogTheme.textMain)),
                        subtitle: Text('Category: ${item.category} | Severity: ${item.severity}', style: const TextStyle(fontSize: 11, color: CarLogTheme.textMuted)),
                        onTap: () {
                          setState(() {
                            _obdController.text = item.code;
                            _obdSuggestions.clear();
                          });
                        },
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // Symptom Description
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Symptom Description & Sound *',
                  hintText: 'Describe noise (grinding, clicking, squealing), vibration speed, or smells...',
                  alignLabelWithHint: true,
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 20),

              // 10-Second Diagnostic Audio Clip Recorder
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: CarLogTheme.surfaceDark,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: CarLogTheme.borderDark),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.mic_none_rounded, color: CarLogTheme.primaryCyan, size: 20),
                        SizedBox(width: 8),
                        Text(
                          '10-Second Diagnostic Audio Clip (.m4a)',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: CarLogTheme.textMain),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Record engine clicks, squeals, or exhaust noises so you or your mechanic can listen later.',
                      style: TextStyle(fontSize: 12, color: CarLogTheme.textMuted),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isRecording ? CarLogTheme.accentRed : CarLogTheme.primaryCyan,
                            foregroundColor: Colors.white,
                          ),
                          icon: Icon(_isRecording ? Icons.stop_rounded : Icons.fiber_manual_record_rounded),
                          label: Text(_isRecording ? 'STOP ($_recordSeconds s / 10s)' : 'RECORD AUDIO'),
                          onPressed: _isRecording ? _stopRecording : _startRecording,
                        ),
                        const SizedBox(width: 12),
                        if (_recordedAudioPath != null)
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: CarLogTheme.primaryCyan),
                            ),
                            icon: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: CarLogTheme.primaryCyan),
                            label: Text(_isPlaying ? 'PAUSE' : 'PLAY CLIP', style: const TextStyle(color: CarLogTheme.primaryCyan)),
                            onPressed: _playAudio,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              ElevatedButton(
                onPressed: _saveSymptom,
                child: const Text('LOG SYMPTOM TO JOURNAL'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
