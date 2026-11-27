import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rochy/main.dart';
import 'package:rochy/providers/bento_canvas_provider.dart';
import 'package:rochy/services/rochy_account_service.dart';
import 'package:rochy/services/rochy_cloud_sync_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'fixtures/device_identity.dart';

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({
      'rochy_couple_prefs_v1': jsonEncode({
        'viewerAuthor': 'samuel',
        'cloudConfig': {'autoSyncEnabled': false},
      })
    });
  });
  testWidgets(
      'new device selects Sam or Rochy without emails or exposing private data',
      (tester) async {
    final identity = fixtureDevice(linked: false);
    await tester.pumpWidget(ProviderScope(
        overrides: [rochyAccountProvider.overrideWith((ref) => identity)],
        child: const RochyApp()));
    await tester.pumpAndSettle();
    expect(find.text('Sam'), findsOneWidget);
    expect(find.text('Rochy'), findsOneWidget);
    expect(find.text('Código de acceso'), findsOneWidget);
    expect(find.text('Cuaderno & Estilo'), findsNothing);
    expect(find.textContaining('correo'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
  testWidgets(
      'disabling cloud sync does not prevent reopening the linked notebook',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'rochy_couple_prefs_v1': jsonEncode({
        'viewerAuthor': 'samuel',
        'cloudConfig': {
          'projectId': '',
          'apiKey': '',
          'storageBucket': '',
          'autoSyncEnabled': false
        },
      })
    });
    FlutterSecureStorage.setMockInitialValues({});
    final identity = RochyAccountService(client: MockClient((request) async {
      expect(request.url.queryParameters['key'],
          FirebaseCoupleConfig.defaultApiKey);
      if (request.url.host == 'identitytoolkit.googleapis.com') {
        return http.Response(
            jsonEncode({
              'localId': 'disconnected',
              'idToken': 'token',
              'refreshToken': 'refresh',
              'expiresIn': '3600'
            }),
            200);
      }
      expect(request.url.path,
          contains('/projects/${FirebaseCoupleConfig.defaultProjectId}/'));
      return http.Response(
          jsonEncode({
            'name':
                'projects/${FirebaseCoupleConfig.defaultProjectId}/databases/(default)/documents/profileDevices/disconnected',
            'fields': {
              'profileId': {'stringValue': 'samuel'},
              'invitationId': {'stringValue': 'fixture'}
            },
          }),
          200);
    }));
    await tester.pumpWidget(ProviderScope(
        overrides: [rochyAccountProvider.overrideWith((ref) => identity)],
        child: const RochyApp()));
    await tester.pumpAndSettle();
    expect(find.text('Código de acceso'), findsNothing);
    expect(find.text('Elegir primer módulo'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
  testWidgets(
      'linked device restores automatically and cannot impersonate the other profile',
      (tester) async {
    final identity = fixtureDevice();
    await tester.pumpWidget(ProviderScope(
        overrides: [rochyAccountProvider.overrideWith((ref) => identity)],
        child: const RochyApp()));
    await tester.pumpAndSettle();
    expect(find.text('Elegir primer módulo'), findsOneWidget);
    final container =
        ProviderScope.containerOf(tester.element(find.byType(RochyApp)));
    container.read(bentoCanvasProvider.notifier).setViewerAuthor('rochy');
    expect(container.read(bentoCanvasProvider).viewerAuthor, 'samuel');
    await identity.initialize(
        projectId: 'unlinked-project', apiKey: 'fixture-key');
    await tester.pumpAndSettle();
    expect(find.text('Código de acceso'), findsOneWidget);
    expect(find.text('Cuaderno & Estilo'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
