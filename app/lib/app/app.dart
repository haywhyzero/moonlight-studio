import 'package:flutter/material.dart';
import 'theme/moonlight_theme.dart';
import '../features/studio/studio_screen.dart';

class MoonlightStudioApp extends StatelessWidget {
  const MoonlightStudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Moonlight Studio',
      debugShowCheckedModeBanner: false,
      theme: buildMoonlightTheme(),
      home: const StudioScreen(),
    );
  }
}
