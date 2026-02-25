import 'package:flutter/material.dart';

import '../../common/theme/app_theme.dart';
import '../screens/stock_list/stock_list_screen.dart';

class BullrithmApp extends StatelessWidget {
  const BullrithmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bullrithm',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: const StockListScreen(),
    );
  }
}
