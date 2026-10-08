import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../app/theme/moonlight_theme.dart';
import '../../core/performance/metrics_collector.dart';
import '../../infrastructure/capture_pipeline.dart';
import 'effects_panel.dart';
import 'raw_frame_preview.dart';
import 'studio_providers.dart';

/// The main Studio dashboard — sources on the left, live preview center,
/// effects + status below, transport bar at the bottom.
class StudioScreen extends ConsumerWidget {
  const StudioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(studioStatusProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.nightlight_round, size: 20, color: MoonlightPalette.accentSecondary),
            const SizedBox(width: 10),
            const Text('Moonlight Studio'),
            const Spacer(),
            _StatusPill(status: status),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(width: 280, child: _SourcesPanel()),
            const SizedBox(width: 16),
            Expanded(child: _PreviewPanel(status: status)),
            const SizedBox(width: 16),
            const SizedBox(width: 290, child: EffectsPanel()),
          ],
        ),
      ),
      bottomNavigationBar: const _TransportBar(),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final StudioStatus status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      StudioStatus.idle => (MoonlightPalette.textSecondary, 'Idle'),
      StudioStatus.starting => (MoonlightPalette.warning, 'Starting'),
      StudioStatus.running => (MoonlightPalette.success, 'Live'),
      StudioStatus.stopping => (MoonlightPalette.warning, 'Stopping'),
      StudioStatus.error => (MoonlightPalette.danger, 'Error'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _SourcesPanel extends ConsumerWidget {
  const _SourcesPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cameras = ref.watch(cameraDevicesProvider);
    final microphones = ref.watch(audioDevicesProvider);
    final selectedCamera = ref.watch(selectedCameraProvider);
    final selectedMic = ref.watch(selectedMicrophoneProvider);
    final avatarPath = ref.watch(selectedAvatarPathProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('SOURCES', style: TextStyle(fontSize: 12, letterSpacing: 1.2, color: MoonlightPalette.textSecondary)),
            const SizedBox(height: 16),

            const Text('Camera', style: TextStyle(fontSize: 13, color: MoonlightPalette.textSecondary)),
            const SizedBox(height: 6),
            cameras.when(
              data: (devices) => _DeviceDropdown<dynamic>(
                items: devices,
                selected: selectedCamera,
                labelOf: (d) => d.label,
                onChanged: (d) => ref.read(selectedCameraProvider.notifier).state = d,
                emptyHint: 'No cameras found',
              ),
              loading: () => const _InlineLoading(),
              error: (e, _) => _InlineError('ffmpeg not found or failed: $e'),
            ),

            const SizedBox(height: 16),
            const Text('Microphone', style: TextStyle(fontSize: 13, color: MoonlightPalette.textSecondary)),
            const SizedBox(height: 6),
            microphones.when(
              data: (devices) => _DeviceDropdown<dynamic>(
                items: devices,
                selected: selectedMic,
                labelOf: (d) => d.label,
                onChanged: (d) => ref.read(selectedMicrophoneProvider.notifier).state = d,
                emptyHint: 'No microphones found',
              ),
              loading: () => const _InlineLoading(),
              error: (e, _) => _InlineError('ffmpeg not found or failed: $e'),
            ),

            const SizedBox(height: 16),
            const Text('Avatar', style: TextStyle(fontSize: 13, color: MoonlightPalette.textSecondary)),
            const SizedBox(height: 6),
            InkWell(
              onTap: () async {
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
                );
                final path = result?.files.single.path;
                if (path == null) return;
                ref.read(selectedAvatarPathProvider.notifier).state = path;
                // Just remember the path. The session hands it to the
                // selected avatar engine's prepareAvatar() at Start, after
                // the engine is initialized (workers spawned, etc.).
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: MoonlightPalette.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: MoonlightPalette.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        avatarPath?.split(Platform.pathSeparator).last ?? 'Choose avatar image',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: MoonlightPalette.textSecondary, fontSize: 13),
                      ),
                    ),
                    const Icon(Icons.image_outlined, size: 18, color: MoonlightPalette.textSecondary),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceDropdown<T> extends StatelessWidget {
  final List<T> items;
  final T? selected;
  final String Function(T) labelOf;
  final ValueChanged<T?> onChanged;
  final String emptyHint;

  const _DeviceDropdown({
    required this.items,
    required this.selected,
    required this.labelOf,
    required this.onChanged,
    required this.emptyHint,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: MoonlightPalette.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: MoonlightPalette.border),
        ),
        child: Text(emptyHint, style: const TextStyle(color: MoonlightPalette.textSecondary, fontSize: 13)),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: MoonlightPalette.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: MoonlightPalette.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isExpanded: true,
          value: selected != null && items.contains(selected) ? selected : null,
          hint: const Text('Select device', style: TextStyle(color: MoonlightPalette.textSecondary, fontSize: 13)),
          dropdownColor: MoonlightPalette.surfaceRaised,
          style: const TextStyle(color: MoonlightPalette.textPrimary, fontSize: 13),
          items: items
              .map((d) => DropdownMenuItem<T>(value: d, child: Text(labelOf(d))))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _InlineLoading extends StatelessWidget {
  const _InlineLoading();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2)),
      );
}

class _InlineError extends StatelessWidget {
  final String message;
  const _InlineError(this.message);
  @override
  Widget build(BuildContext context) => Text(
        message,
        style: const TextStyle(color: MoonlightPalette.danger, fontSize: 11),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
}

class _PreviewPanel extends ConsumerWidget {
  final StudioStatus status;
  const _PreviewPanel({required this.status});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Pass the session's own stream straight to RawFramePreview, which
    // manages its own subscription + decode + setState internally.
    // Deliberately NOT using previewFrameProvider (a Riverpod
    // StreamProvider) here too — that would rebuild this whole panel on
    // every single frame IN ADDITION to RawFramePreview's own internal
    // update, which is pure waste.
    final session = ref.watch(studioSessionProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('LIVE PREVIEW', style: TextStyle(fontSize: 12, letterSpacing: 1.2, color: MoonlightPalette.textSecondary)),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: MoonlightPalette.border),
                ),
                alignment: Alignment.center,
                child: RawFramePreview(frames: session.previewController.stream),
              ),
            ),
            const SizedBox(height: 12),
            const _StatusBar(),
          ],
        ),
      ),
    );
  }
}

class _StatusBar extends ConsumerWidget {
  const _StatusBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perf = ref.watch(performanceProvider).asData?.value ?? PerformanceSample.empty;

    String fmt(double? v, String suffix, {int decimals = 0}) =>
        v == null ? 'N/A' : '${v.toStringAsFixed(decimals)}$suffix';

    Widget stat(String label, String value) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: MoonlightPalette.textSecondary)),
            Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ],
        );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        stat('FPS', fmt(perf.fps, '')),
        stat('Latency', fmt(perf.latencyMs, 'ms')),
        stat('CPU', fmt(perf.cpuPercent, '%')),
        stat('RAM', perf.usedMemoryMb == null || perf.totalMemoryMb == null
            ? 'N/A'
            : '${perf.usedMemoryMb!.toStringAsFixed(0)}/${perf.totalMemoryMb!.toStringAsFixed(0)}MB'),
      ],
    );
  }
}

class _TransportBar extends ConsumerWidget {
  const _TransportBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(studioStatusProvider);
    final isRunning = status == StudioStatus.running;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: MoonlightPalette.surface,
        border: Border(top: BorderSide(color: MoonlightPalette.border)),
      ),
      child: Row(
        children: [
          ElevatedButton.icon(
            onPressed: () async {
              final session = ref.read(studioSessionProvider);
              if (isRunning) {
                ref.read(studioStatusProvider.notifier).state = StudioStatus.stopping;
                await ref.read(capturePipelineProvider)?.stop();
                ref.read(capturePipelineProvider.notifier).state = null;
                await session.stop();
                ref.read(studioStatusProvider.notifier).state = StudioStatus.idle;
              } else {
                final camera = ref.read(selectedCameraProvider);
                final mic = ref.read(selectedMicrophoneProvider);
                if (camera == null || mic == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Select a camera and microphone first.')),
                  );
                  return;
                }
                final avatarPath = ref.read(selectedAvatarPathProvider);
                // Every non-mock avatar engine works from your avatar image;
                // without one it would silently show the raw camera, which is
                // exactly the confusion we want to avoid.
                if (avatarPath == null && ref.read(pipelineConfigProvider).avatarEngineId != 'mock_avatar') {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Choose an avatar image first.')),
                  );
                  return;
                }
                ref.read(studioStatusProvider.notifier).state = StudioStatus.starting;
                CapturePipeline? capture;
                try {
                  await session.start(avatarImagePath: avatarPath);
                  capture = CapturePipeline(
                    session: session,
                    cameraDeviceName: camera.id,
                    microphoneDeviceName: mic.id,
                  );
                  await capture.start();
                  ref.read(capturePipelineProvider.notifier).state = capture;
                  ref.read(studioStatusProvider.notifier).state = StudioStatus.running;
                } catch (e) {
                  await capture?.stop();
                  await session.stop();
                  ref.read(studioStatusProvider.notifier).state = StudioStatus.error;
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        duration: const Duration(seconds: 12),
                        content: Text('Could not start: $e'),
                      ),
                    );
                  }
                }
              }
            },
            icon: Icon(isRunning ? Icons.stop : Icons.play_arrow),
            label: Text(isRunning ? 'Stop Studio' : 'Start Studio'),
          ),
          const SizedBox(width: 16),
          _DeviceIndicator(icon: Icons.videocam_outlined, label: ref.watch(selectedCameraProvider)?.label ?? 'No camera'),
          const SizedBox(width: 12),
          _DeviceIndicator(icon: Icons.mic_none, label: ref.watch(selectedMicrophoneProvider)?.label ?? 'No mic'),
          const Spacer(),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.settings_outlined, color: MoonlightPalette.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _DeviceIndicator extends StatelessWidget {
  final IconData icon;
  final String label;
  const _DeviceIndicator({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: MoonlightPalette.textSecondary),
        const SizedBox(width: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 140),
          child: Text(label, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: MoonlightPalette.textSecondary)),
        ),
      ],
    );
  }
}
