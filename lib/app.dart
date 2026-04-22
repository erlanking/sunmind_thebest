import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:sunmind_thebest/core/router/app_router.dart';
import 'package:sunmind_thebest/core/theme/app_theme.dart';
import 'package:sunmind_thebest/core/theme/theme_controller.dart';

class SunMindApp extends StatelessWidget {
  final String initialLocation;

  const SunMindApp({super.key, required this.initialLocation});

  @override
  Widget build(BuildContext context) {
    final themeController = Provider.of<AppThemeController>(context);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'SunMind',
      routerConfig: AppRouter.createRouter(initialLocation: initialLocation),

      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeController.themeMode,

      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
    );
  }
}
