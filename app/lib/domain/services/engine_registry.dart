import '../interfaces/motion_tracker.dart';
import '../interfaces/avatar_engine.dart';
import '../interfaces/lip_sync_engine.dart';
import '../interfaces/voice_engine.dart';
import '../interfaces/virtual_camera_provider.dart';
import '../interfaces/virtual_microphone_provider.dart';

/// Single source of truth for "which engines exist". The Studio UI and
/// StudioSession query this registry by id — they must never contain a
/// switch/if-chain on a concrete engine name (e.g. `if (id == 'liveportrait')`).
///
/// To add a new engine: implement the interface, then call the matching
/// register*() once at startup (see lib/app/bootstrap.dart). Nothing else
/// needs to change. See docs/adding-an-engine.md.
class EngineRegistry {
  final Map<String, MotionTracker> _motionTrackers = {};
  final Map<String, AvatarEngine> _avatarEngines = {};
  final Map<String, LipSyncEngine> _lipSyncEngines = {};
  final Map<String, VoiceEngine> _voiceEngines = {};
  final Map<String, VirtualCameraProvider> _virtualCameras = {};
  final Map<String, VirtualMicrophoneProvider> _virtualMicrophones = {};

  void registerMotionTracker(MotionTracker tracker) =>
      _motionTrackers[tracker.id] = tracker;
  void registerAvatarEngine(AvatarEngine engine) =>
      _avatarEngines[engine.id] = engine;
  void registerLipSyncEngine(LipSyncEngine engine) =>
      _lipSyncEngines[engine.id] = engine;
  void registerVoiceEngine(VoiceEngine engine) =>
      _voiceEngines[engine.id] = engine;
  void registerVirtualCamera(VirtualCameraProvider provider) =>
      _virtualCameras[provider.id] = provider;
  void registerVirtualMicrophone(VirtualMicrophoneProvider provider) =>
      _virtualMicrophones[provider.id] = provider;

  MotionTracker? getMotionTracker(String id) => _motionTrackers[id];
  AvatarEngine? getAvatarEngine(String id) => _avatarEngines[id];
  LipSyncEngine? getLipSyncEngine(String id) => _lipSyncEngines[id];
  VoiceEngine? getVoiceEngine(String id) => _voiceEngines[id];
  VirtualCameraProvider? getVirtualCamera(String id) => _virtualCameras[id];
  VirtualMicrophoneProvider? getVirtualMicrophone(String id) =>
      _virtualMicrophones[id];

  List<MotionTracker> get motionTrackers => List.unmodifiable(_motionTrackers.values);
  List<AvatarEngine> get avatarEngines => List.unmodifiable(_avatarEngines.values);
  List<LipSyncEngine> get lipSyncEngines => List.unmodifiable(_lipSyncEngines.values);
  List<VoiceEngine> get voiceEngines => List.unmodifiable(_voiceEngines.values);
  List<VirtualCameraProvider> get virtualCameras => List.unmodifiable(_virtualCameras.values);
  List<VirtualMicrophoneProvider> get virtualMicrophones => List.unmodifiable(_virtualMicrophones.values);
}
