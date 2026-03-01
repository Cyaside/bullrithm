import 'package:flutter/material.dart';

import '../../common/theme/app_theme.dart';
import '../../common/theme/theme_mode_controller.dart';
import '../screens/shell/main_shell_screen.dart';

class BullrithmApp extends StatefulWidget {
  const BullrithmApp({super.key});

  @override
  State<BullrithmApp> createState() => _BullrithmAppState();
}

class _BullrithmAppState extends State<BullrithmApp> {
  final ThemeModeController _themeModeController = ThemeModeController();

  @override
  void initState() {
    super.initState();
    _themeModeController.load();
  }

  @override
  void dispose() {
    _themeModeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _themeModeController,
      builder: (context, _) {
        return ThemeModeScope(
          controller: _themeModeController,
          child: MaterialApp(
            title: 'Bullrithm',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: _themeModeController.themeMode,
            home: const MainShellScreen(),
          ),
        );
      },
    );
  }
}
