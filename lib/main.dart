import 'dart:io';
import 'package:flutter/material.dart' hide Colors;
import 'package:fluent_ui/fluent_ui.dart' hide FontWeight, TextAlign;
import 'package:provider/provider.dart';
import 'template_provider.dart';
import 'home_page.dart';
import 'desktop/desktop_home.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => TemplateProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TemplateProvider>();
    final themeMode = provider.isDarkMode ? ThemeMode.dark : ThemeMode.light;

    if (Platform.isWindows || Platform.isLinux) {
      return FluentApp(
        title: 'Thermal Printer Editor',
        debugShowCheckedModeBanner: false,
        themeMode: themeMode,
        theme: FluentThemeData(
          accentColor: Colors.blue,
          visualDensity: VisualDensity.standard,
        ),
        darkTheme: FluentThemeData(
          brightness: Brightness.dark,
          accentColor: Colors.blue,
          visualDensity: VisualDensity.standard,
        ),
        home: const DesktopHomePage(),
      );
    }

    return MaterialApp(
      title: 'Thermal Printer Editor',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}
