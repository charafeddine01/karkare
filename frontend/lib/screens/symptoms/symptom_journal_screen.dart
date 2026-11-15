// =============================================================================
// CarLog Diagnostic Symptom Journal Screen
// View pre-repair symptoms, listen to audio clips, and link resolution to maintenance logs
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../providers/carlog_providers.dart';
import '../../core/theme/carlog_theme.dart';
import '../../data/local/database.dart';
import '../../core/network/toast_service.dart';
import 'add_symptom_screen.dart';

class SymptomJournalScreen extends ConsumerStatefulWidget {
  final String? vehicleId;

  const SymptomJournalScreen({super.key, this.vehicleId});

  @override
  ConsumerState<SymptomJournalScreen> createState() => _SymptomJournalScreenState();
}

class _SymptomJournalScreenState extends ConsumerState<SymptomJournalScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _currentlyPlayingPath;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerComplete.listen((_) {
      setState(() {
        _isPlaying = false;
        _currentlyPlayingPath = null;
      });
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _toggleAudio(String path) async {
    if (_currentlyPlayingPath == path && _isPlaying) {
      await _audioPlayer.stop();
      setState(() => _isPlaying = false);
    } else {
      await _audioPlayer.play(DeviceFileSource(path));
      setState(() {
        _isPlaying = true;
        _currentlyPlayingPath = path;
      });
    }
  }

  void _showResolveDialog(DiagnosticSymptomsTableData symptom, String vehicleId) {
    showDialog(
      context: context,
      builder: (ctx) {
        return StreamBuilder<List<MaintenanceLogsTableData>>(
          stream: ref.watch(maintenanceDaoProvider).watchVehicleLogs(vehicleId),
          builder: (context, snapshot) {
            final logs = snapshot.data ?? [];
            return AlertDialog(
              backgroundColor: CarLogTheme.surfaceDark,
              title: const Text('Mark Symptom as Resolved', style: TextStyle(color: CarLogTheme.textMain)),
              content: SizedBox(
                width: double.maxFinite,
                child: logs.isEmpty
                  ? const Text(
                      'No completed maintenance logs found. Please log a service visit first to link resolution.',
                      style: TextStyle(color: CarLogTheme.textMuted),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: logs.length,
                      itemBuilder: (_, i) {
                        final log = logs[i];
                        return ListTile(
                          dense: true,
                          title: Text('Log #${log.id.substring(0, 8)} - ${log.odometerKm} km', style: const TextStyle(color: CarLogTheme.textMain)),
                          subtitle: Text(DateFormat('MMM dd, yyyy').format(log.serviceDate), style: const TextStyle(color: CarLogTheme.textMuted)),
                          trailing: const Icon(Icons.check_circle_outline, color: CarLogTheme.accentGreen),
                          onTap: () async {
                            await ref.read(symptomDaoProvider).resolveSymptom(
                              symptomId: symptom.id,
                              maintenanceLogId: log.id,
                            );
                            if (mounted) {
                              Navigator.pop(ctx);
                              ToastService.show('Symptom marked resolved and linked to log!', type: ToastType.success);
                            }
                          },
                        );
                      },
                    ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel', style: TextStyle(color: CarLogTheme.textMuted)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final vehicles = ref.watch(vehiclesStreamProvider).value ?? [];
    if (vehicles.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Diagnostic Journal')),
        body: const Center(child: Text('Add a vehicle first.')),
      );
    }

    final activeVehicle = vehicles.firstWhere(
      (v) => v.id == widget.vehicleId,
      orElse: () => vehicles.first,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('Symptoms: ${activeVehicle.make} ${activeVehicle.model}'),
      ),
      body: StreamBuilder<List<DiagnosticSymptomsTableData>>(
        stream: ref.watch(symptomDaoProvider).watchVehicleSymptoms(activeVehicle.id),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: CarLogTheme.primaryCyan));
          }

          final symptoms = snapshot.data!;
          if (symptoms.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.healing_rounded, size: 64, color: CarLogTheme.textMuted.withOpacity(0.3)),
                    const SizedBox(height: 16),
                    const Text(
                      'No Diagnostic Symptoms Logged',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: CarLogTheme.textMain),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Track strange engine noises, vibrations, or OBD fault codes before visiting the workshop.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: CarLogTheme.textMuted),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: symptoms.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (ctx, i) {
              final s = symptoms[i];
              final isThisPlaying = _currentlyPlayingPath == s.audioClipUrl && _isPlaying;

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: s.isResolved ? CarLogTheme.accentGreen.withOpacity(0.15) : CarLogTheme.accentAmber.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              s.isResolved ? 'RESOLVED' : 'ACTIVE SYMPTOM',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: s.isResolved ? CarLogTheme.accentGreen : CarLogTheme.accentAmber,
                              ),
                            ),
                          ),
                          Text(
                            DateFormat('MMM dd, yyyy').format(s.loggedDate),
                            style: const TextStyle(fontSize: 12, color: CarLogTheme.textMuted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        s.symptomDescription,
                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: CarLogTheme.textMain),
                      ),
                      const SizedBox(height: 8),

                      Row(
                        children: [
                          const Icon(Icons.speed_rounded, size: 14, color: CarLogTheme.textMuted),
                          const SizedBox(width: 4),
                          Text('${s.odometerKm} km', style: const TextStyle(fontSize: 12, color: CarLogTheme.textMuted)),
                          const SizedBox(width: 14),
                          const Icon(Icons.settings_outlined, size: 14, color: CarLogTheme.textMuted),
                          const SizedBox(width: 4),
                          Text('State: ${s.engineState.replaceAll('_', ' ')}', style: const TextStyle(fontSize: 12, color: CarLogTheme.textMuted)),
                        ],
                      ),

                      if (s.obdCode != null && s.obdCode!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: CarLogTheme.surfaceCard,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: CarLogTheme.borderDark),
                          ),
                          child: Text(
                            'OBD Fault Code: ${s.obdCode}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: CarLogTheme.primaryCyan, fontFamily: 'monospace'),
                          ),
                        ),
                      ],

                      // Audio Clip Playback Button
                      if (s.audioClipUrl != null) ...[
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: () => _toggleAudio(s.audioClipUrl!),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: CarLogTheme.primaryDarkCyan.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: CarLogTheme.primaryCyan.withOpacity(0.4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(isThisPlaying ? Icons.pause_circle_rounded : Icons.play_circle_rounded, color: CarLogTheme.primaryCyan, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  isThisPlaying ? 'Playing Audio Clip...' : 'Listen to 10s Diagnostic Audio',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: CarLogTheme.primaryCyan),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],

                      if (!s.isResolved) ...[
                        const SizedBox(height: 12),
                        const Divider(color: CarLogTheme.borderDark),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            icon: const Icon(Icons.check_circle_outline, size: 16, color: CarLogTheme.accentGreen),
                            label: const Text('Mark Resolved with Service Log', style: TextStyle(color: CarLogTheme.accentGreen, fontSize: 12, fontWeight: FontWeight.bold)),
                            onPressed: () => _showResolveDialog(s, activeVehicle.id),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: CarLogTheme.primaryCyan,
        foregroundColor: CarLogTheme.bgDark,
        icon: const Icon(Icons.add_rounded),
        label: const Text('LOG SYMPTOM', style: TextStyle(fontWeight: FontWeight.w800)),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddSymptomScreen(vehicleId: activeVehicle.id),
            ),
          );
        },
      ),
    );
  }
}
