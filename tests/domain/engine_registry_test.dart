import 'package:flutter_test/flutter_test.dart';
import 'package:moonlight_studio/domain/services/engine_registry.dart';
import 'package:moonlight_studio/engines/motion/mock/mock_motion_tracker.dart';
import 'package:moonlight_studio/engines/avatar/mock/mock_avatar_engine.dart';
import 'package:moonlight_studio/engines/voice/mock/mock_voice_engine.dart';

void main() {
  group('EngineRegistry', () {
    test('registers and retrieves engines by id', () {
      final registry = EngineRegistry();
      registry.registerMotionTracker(MockMotionTracker());
      registry.registerAvatarEngine(MockAvatarEngine());
      registry.registerVoiceEngine(MockVoiceEngine());

      expect(registry.getMotionTracker('mock_motion'), isNotNull);
      expect(registry.getAvatarEngine('mock_avatar'), isNotNull);
      expect(registry.getVoiceEngine('mock_voice'), isNotNull);
      expect(registry.getAvatarEngine('does_not_exist'), isNull);
    });

    test('lists are unmodifiable snapshots', () {
      final registry = EngineRegistry();
      registry.registerAvatarEngine(MockAvatarEngine());
      expect(() => registry.avatarEngines.add(MockAvatarEngine()), throwsUnsupportedError);
    });
  });
}
