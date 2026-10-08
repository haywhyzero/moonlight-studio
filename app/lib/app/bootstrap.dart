import '../domain/services/engine_registry.dart';
import '../engines/motion/mock/mock_motion_tracker.dart';
import '../engines/avatar/mock/mock_avatar_engine.dart';
import '../engines/avatar/simple/simple_avatar_engine.dart';
import '../engines/avatar/live_portrait/live_portrait_engine.dart';
import '../engines/lipsync/mock/mock_lipsync_engine.dart';
import '../engines/lipsync/musetalk/musetalk_engine.dart';
import '../engines/lipsync/wav2lip/wav2lip_engine.dart';
import '../engines/voice/mock/mock_voice_engine.dart';
import '../engines/voice/realtime_effects/realtime_voice_effect_engine.dart';
import '../engines/voice/clone/voice_clone_engine.dart';
import '../infrastructure/virtual_camera/obs_virtual_camera_provider.dart';
import '../infrastructure/virtual_microphone/virtual_audio_cable_provider.dart';

/// The ONE place every engine gets registered. Adding a new engine means
/// adding one line here — see docs/adding-an-engine.md. No other file in
/// the app should ever construct an engine directly.
EngineRegistry buildEngineRegistry() {
  final registry = EngineRegistry();

  registry.registerMotionTracker(MockMotionTracker());

  registry.registerAvatarEngine(MockAvatarEngine());
  registry.registerAvatarEngine(SimpleAvatarEngine());
  registry.registerAvatarEngine(LivePortraitEngine());

  registry.registerLipSyncEngine(MockLipSyncEngine());
  registry.registerLipSyncEngine(MuseTalkEngine());
  registry.registerLipSyncEngine(Wav2LipEngine());

  registry.registerVoiceEngine(MockVoiceEngine());
  registry.registerVoiceEngine(RealtimeVoiceEffectEngine());
  registry.registerVoiceEngine(VoiceCloneEngine());

  registry.registerVirtualCamera(ObsVirtualCameraProvider());
  registry.registerVirtualMicrophone(VirtualAudioCableProvider());

  return registry;
}
