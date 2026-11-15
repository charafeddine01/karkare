// =============================================================================
// CarLog On-Device Camera OCR Scanner Button
// Offline text recognition using google_mlkit_text_recognition on Android
// =============================================================================

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../core/theme/carlog_theme.dart';
import '../core/network/toast_service.dart';

enum OcrScanType { vin, odometer, partNumber }

class OcrScanButton extends StatefulWidget {
  final OcrScanType scanType;
  final ValueChanged<String> onTextRecognized;

  const OcrScanButton({
    super.key,
    required this.scanType,
    required this.onTextRecognized,
  });

  @override
  State<OcrScanButton> createState() => _OcrScanButtonState();
}

class _OcrScanButtonState extends State<OcrScanButton> {
  final ImagePicker _picker = ImagePicker();
  bool _isProcessing = false;

  String get _title {
    switch (widget.scanType) {
      case OcrScanType.vin:
        return 'Scan 17-Char VIN';
      case OcrScanType.odometer:
        return 'Scan Odometer (km)';
      case OcrScanType.partNumber:
        return 'Scan Part Box / Number';
    }
  }

  Future<void> _startScan() async {
    setState(() => _isProcessing = true);
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
      );

      if (image == null) {
        setState(() => _isProcessing = false);
        return;
      }

      final inputImage = InputImage.fromFilePath(image.path);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      final List<String> extractedCandidates = [];
      for (final block in recognizedText.blocks) {
        for (final line in block.lines) {
          final trimmed = line.text.trim();
          if (trimmed.isNotEmpty) {
            extractedCandidates.add(trimmed);
          }
        }
      }

      setState(() => _isProcessing = false);

      if (extractedCandidates.isEmpty) {
        ToastService.show('No legible text recognized in camera frame.', type: ToastType.warning);
        return;
      }

      if (!mounted) return;

      // Show bottom sheet with detected text candidates
      showModalBottomSheet(
        context: context,
        backgroundColor: CarLogTheme.surfaceDark,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Detected Text (${widget.scanType.name.toUpperCase()})',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: CarLogTheme.textMain),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: CarLogTheme.textMuted),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Tap the matching recognized text block to auto-fill the field:',
                  style: TextStyle(fontSize: 12.5, color: CarLogTheme.textMuted),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: extractedCandidates.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, index) {
                      final candidate = extractedCandidates[index];
                      return InkWell(
                        onTap: () {
                          widget.onTextRecognized(candidate);
                          Navigator.pop(ctx);
                          ToastService.show('Populated field with: $candidate', type: ToastType.success);
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: CarLogTheme.surfaceCard,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: CarLogTheme.borderDark),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.text_fields_rounded, size: 18, color: CarLogTheme.primaryCyan),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  candidate,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: CarLogTheme.textMain,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: CarLogTheme.textMuted),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      );
    } catch (e) {
      setState(() => _isProcessing = false);
      ToastService.show('OCR scan error: ${e.toString()}', type: ToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: _isProcessing
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: CarLogTheme.primaryCyan),
            )
          : const Icon(Icons.camera_alt_outlined, color: CarLogTheme.primaryCyan),
      tooltip: _title,
      onPressed: _isProcessing ? null : _startScan,
    );
  }
}
