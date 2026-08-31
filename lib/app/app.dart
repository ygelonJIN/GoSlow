import 'package:flutter/material.dart';

import 'app_shell.dart';
import 'theme.dart';

/// 应用根 Widget。
class GoSlowApp extends StatelessWidget {
  const GoSlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GoSlow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const AppShell(),
    );
  }
}
