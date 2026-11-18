import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rochy/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_map/flutter_map.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets(
      'RochyApp renders Bento grid, navigates tabs, and opens module picker',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const ProviderScope(
        child: RochyApp(),
      ),
    );

    // Espera a que termine la cascada elástica de entrada
    await tester.pumpAndSettle(const Duration(milliseconds: 1400));

    expect(find.text('Rochy'), findsOneWidget);
    expect(find.text('Su café favorito'), findsOneWidget);
    expect(find.text('Detalles que amo'), findsOneWidget);

    // Abre el selector de los 13 módulos
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Añadir módulo al cuaderno'), findsOneWidget);
    expect(find.text('Video en Vivo'), findsOneWidget);

    // Cierra el sheet y navega por las pestañas inferiores
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Moments'));
    await tester.pumpAndSettle();
    expect(find.text('Momentos & Hilos'), findsOneWidget);

    await tester.tap(find.text('Map'));
    await tester.pumpAndSettle();
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.text('© OpenStreetMap contributors'), findsOneWidget);
    expect(find.byTooltip('Mi GPS'), findsOneWidget);
    expect(find.byTooltip('Cómo llegar con Google Maps'), findsWidgets);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Cuaderno & Estilo'), findsOneWidget);
  });
}
