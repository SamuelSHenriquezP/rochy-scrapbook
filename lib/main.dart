import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/bento_canvas_provider.dart';
import 'views/rochy_profile_gate.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(
    const ProviderScope(
      child: RochyApp(),
    ),
  );
}

/// Raíz de la aplicación offline-first "Rochy".
class RochyApp extends ConsumerWidget {
  const RochyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(activeRochyThemeProvider);

    return MaterialApp(
      title: 'Rochy',
      debugShowCheckedModeBanner: false,
      theme: theme.toMaterialTheme(),
      home: const RochyProfileGate(),
    );
  }
}
