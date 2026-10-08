import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../app/theme/moonlight_theme.dart';
import '../../domain/pipeline/pipeline_config.dart';
import 'studio_providers.dart';

/// Right-hand panel: choose which engines run, and configure them.
///
/// The dropdowns are populated from the EngineRegistry — registering a new
/// engine in bootstrap.dart makes it appear here with no UI change. The
/// mock_* engines are hidden: they exist for tests/dev only.
///
/// Settings are locked while the studio is running, because engines are
/// initialized at Start (that's when Python workers spawn and voice models
/// load) — changing them mid-run would silently do nothing.
class EffectsPanel extends ConsumerWidget {
  const EffectsPanel({super.key});

  static const _effectLabels = {
    'none': 'None (clean)',
    'pitchUp': 'Pitch up',
    'pitchDown': 'Pitch down',
    'robot': 'Robot',
    'radio': 'Radio',
    'echo': 'Echo',
  };

  static bool _isReal(String id) => !id.startsWith('mock_');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final registry = ref.watch(engineRegistryProvider);
    final config = ref.watch(pipelineConfigProvider);
    final status = ref.watch(studioStatusProvider);
    final locked = status == StudioStatus.starting ||
        status == StudioStatus.running ||
        status == StudioStatus.stopping;

    void update(PipelineConfig Function(PipelineConfig) change) {
      final notifier = ref.read(pipelineConfigProvider.notifier);
      notifier.state = change(notifier.state);
    }

    final avatarEngines = registry.avatarEngines.where((e) => _isReal(e.id)).toList();
    final lipSyncEngines = registry.lipSyncEngines.where((e) => _isReal(e.id)).toList();
    final voiceEngines = registry.voiceEngines.where((e) => _isReal(e.id)).toList();

    final selectedAvatar = registry.getAvatarEngine(config.avatarEngineId);
    final selectedLipSync = config.lipSyncEngineId == null
        ? null
        : registry.getLipSyncEngine(config.lipSyncEngineId!);
    final selectedVoice = registry.getVoiceEngine(config.voiceEngineId);
    final voiceSettings = config.engineSettings[config.voiceEngineId] ?? const {};

    String? gpuHint(bool supportsGpu, bool supportsCpu) => (supportsGpu && !supportsCpu)
        ? 'Needs an NVIDIA GPU and downloaded model weights — see README.'
        : null;

    return Card(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionLabel('MOTION'),
            const Text(
              'Mock tracker (sine wave). Real face tracking is not built yet, '
              'so the avatar sways on its own instead of following your face.',
              style: TextStyle(fontSize: 12, color: MoonlightPalette.warning),
            ),
            const SizedBox(height: 20),

            const _SectionLabel('AVATAR ENGINE'),
            _EngineDropdown<String>(
              value: avatarEngines.any((e) => e.id == config.avatarEngineId) ? config.avatarEngineId : null,
              items: {for (final e in avatarEngines) e.id: e.name},
              enabled: !locked,
              onChanged: (id) => update((c) => c.copyWith(avatarEngineId: id)),
            ),
            if (selectedAvatar != null)
              _Hint(gpuHint(selectedAvatar.capabilities.supportsGpu, selectedAvatar.capabilities.supportsCpu)),
            const SizedBox(height: 20),

            const _SectionLabel('LIP SYNC'),
            _EngineDropdown<String?>(
              value: config.lipSyncEngineId,
              items: {
                null: 'None',
                for (final e in lipSyncEngines) e.id: e.name,
              },
              enabled: !locked,
              onChanged: (id) => update((c) => id == null
                  ? c.copyWith(clearLipSync: true)
                  : c.copyWith(lipSyncEngineId: id)),
            ),
            if (selectedLipSync != null)
              _Hint(gpuHint(selectedLipSync.capabilities.supportsGpu, selectedLipSync.capabilities.supportsCpu)),
            const SizedBox(height: 20),

            const _SectionLabel('VOICE'),
            _EngineDropdown<String>(
              value: voiceEngines.any((e) => e.id == config.voiceEngineId) ? config.voiceEngineId : null,
              items: {for (final e in voiceEngines) e.id: e.name},
              enabled: !locked,
              onChanged: (id) => update((c) => c.copyWith(voiceEngineId: id)),
            ),
            const SizedBox(height: 10),

            // Engine-specific settings. This is the one place the UI has to
            // know about individual engines, since settings are by nature
            // per-engine.
            if (config.voiceEngineId == 'realtime_effects') ...[
              const Text('Effect', style: TextStyle(fontSize: 12, color: MoonlightPalette.textSecondary)),
              const SizedBox(height: 4),
              _EngineDropdown<String>(
                value: (voiceSettings['effect'] as String?) ?? 'none',
                items: _effectLabels,
                enabled: !locked,
                onChanged: (v) => update((c) => c.withSetting('realtime_effects', 'effect', v)),
              ),
              const _Hint('Signal-processing effects — not AI voice cloning.'),
            ],

            if (selectedVoice != null && selectedVoice.capabilities.requiresReferenceAudio) ...[
              _FilePickerRow(
                label: 'Voice model (.pth)',
                path: voiceSettings['pthPath'] as String?,
                enabled: !locked,
                onPick: () async {
                  final r = await FilePicker.platform.pickFiles(
                    type: FileType.custom,
                    allowedExtensions: ['pth'],
                  );
                  final p = r?.files.single.path;
                  if (p != null) update((c) => c.withSetting(config.voiceEngineId, 'pthPath', p));
                },
              ),
              const SizedBox(height: 8),
              _FilePickerRow(
                label: 'Index (.index, optional)',
                path: voiceSettings['indexPath'] as String?,
                enabled: !locked,
                onPick: () async {
                  final r = await FilePicker.platform.pickFiles(
                    type: FileType.custom,
                    allowedExtensions: ['index'],
                  );
                  final p = r?.files.single.path;
                  if (p != null) update((c) => c.withSetting(config.voiceEngineId, 'indexPath', p));
                },
              ),
              const _Hint(
                'A voice model is a TRAINED file for one target voice — you '
                'can\'t clone from a single sample. See docs/engine-evaluation.md '
                'for how to get or train one.',
              ),
            ],

            if (locked) ...[
              const SizedBox(height: 16),
              const _Hint('Settings are locked while the studio is running.'),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(fontSize: 12, letterSpacing: 1.2, color: MoonlightPalette.textSecondary)),
      );
}

class _Hint extends StatelessWidget {
  final String? text;
  const _Hint(this.text);
  @override
  Widget build(BuildContext context) => text == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(text!, style: const TextStyle(fontSize: 11, color: MoonlightPalette.textSecondary)),
        );
}

class _EngineDropdown<T> extends StatelessWidget {
  final T? value;
  final Map<T, String> items;
  final bool enabled;
  final ValueChanged<T> onChanged;

  const _EngineDropdown({
    required this.value,
    required this.items,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: MoonlightPalette.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: MoonlightPalette.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isExpanded: true,
          value: items.containsKey(value) ? value : null,
          hint: Text(items[null] ?? 'Select', style: const TextStyle(fontSize: 13, color: MoonlightPalette.textPrimary)),
          dropdownColor: MoonlightPalette.surfaceRaised,
          style: const TextStyle(fontSize: 13, color: MoonlightPalette.textPrimary),
          items: [
            for (final e in items.entries)
              DropdownMenuItem<T>(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis)),
          ],
          onChanged: enabled ? (v) => onChanged(v as T) : null,
        ),
      ),
    );
  }
}

class _FilePickerRow extends StatelessWidget {
  final String label;
  final String? path;
  final bool enabled;
  final VoidCallback onPick;

  const _FilePickerRow({
    required this.label,
    required this.path,
    required this.enabled,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final fileName = path?.split(RegExp(r'[\\/]')).last;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: MoonlightPalette.textSecondary)),
        const SizedBox(height: 4),
        InkWell(
          onTap: enabled ? onPick : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: MoonlightPalette.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: MoonlightPalette.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    fileName ?? 'Choose file…',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: fileName == null ? MoonlightPalette.textSecondary : MoonlightPalette.textPrimary,
                    ),
                  ),
                ),
                const Icon(Icons.folder_open, size: 18, color: MoonlightPalette.textSecondary),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
