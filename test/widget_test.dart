import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rochy/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_map/flutter_map.dart';
import 'dart:convert';
import 'package:rochy/models/bento_node.dart';
import 'package:rochy/providers/bento_canvas_provider.dart';
import 'package:rochy/services/rochy_account_service.dart';
import 'fixtures/bento_samples.dart';
import 'fixtures/device_identity.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues(<String, Object>{
      'rochy_couple_prefs_v1': jsonEncode({
        'viewerAuthor': 'samuel',
        'cloudConfig': {'autoSyncEnabled': false}
      }),
    });
  });

  testWidgets(
      'RochyApp renders Bento grid, navigates tabs, and opens module picker',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final repo = LocalBentoRepository();
    final entity = repo.loadEntity();
    final samples = sampleAllCardTypes();
    final photo = samples.firstWhere((n) => n.type == BentoNodeType.photoHero);
    final checklist =
        samples.firstWhere((n) => n.type == BentoNodeType.checkList);
    final pin = samples.firstWhere((n) => n.type == BentoNodeType.locationPin);
    await repo.persistToDisk(
        notebooks: [
          RochyNotebook(entity: entity, nodes: [
            photo.copyWith(
                payload: (photo.payload as PhotoHeroPayload)
                    .copyWith(title: 'Su café favorito')),
            checklist.copyWith(
                payload: (checklist.payload as CheckListPayload)
                    .copyWith(title: 'Detalles que amo')),
            pin.copyWith(
                payload: (pin.payload as LocationPinPayload)
                    .copyWith(latitude: 10.4236, longitude: -75.5512)),
          ])
        ],
        activeNotebookId: entity.id,
        biometricEnabled: false,
        showPaperGrain: true,
        textScaleFactor: 1);
    final identity = fixtureDevice();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [rochyAccountProvider.overrideWith((ref) => identity)],
        child: const RochyApp(),
      ),
    );

    // Espera a que termine la cascada elástica de entrada
    await tester.pumpAndSettle(const Duration(milliseconds: 1400));

    expect(find.text('Rochy'), findsOneWidget);
    expect(find.text('Su café favorito'), findsOneWidget);
    expect(find.text('Detalles que amo'), findsOneWidget);

    // Abre el selector de los 13 módulos
    await tester.tap(find.byTooltip('Añadir módulo'));
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
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
