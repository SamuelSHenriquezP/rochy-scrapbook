import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rochy/models/bento_node.dart';
import 'package:rochy/providers/bento_canvas_provider.dart';
import 'package:rochy/theme/rochy_theme.dart';
import 'package:rochy/widgets/cards/bento_card_shell.dart';
import 'package:rochy/widgets/cards/keepsake_card_widget.dart';
import 'package:rochy/widgets/editors/keepsake_entries_editor.dart';
import 'package:rochy/widgets/editors/node_editor_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rochy/services/rochy_cloud_sync_service.dart';
import 'fixtures/bento_samples.dart';

List<BentoNode> sampleKeepsakes() {
  final date = DateTime(2026, 11, 19);
  final base = BentoNode(
      id: 'passport',
      type: BentoNodeType.travelPassport,
      colSpan: 2,
      rowSpan: 3,
      colorTheme: BentoColorTheme.ivory,
      linkedNodeIds: const [],
      tags: const ['juntos'],
      createdAt: date,
      payload: TravelPassportPayload(title: 'Nuestro pasaporte', stamps: [
        PassportStamp(place: 'Getsemaní', visitedAt: date, iconKey: 'city'),
        PassportStamp(
            place: 'Barú', visitedAt: DateTime(2026, 10, 12), iconKey: 'beach'),
        PassportStamp(
            place: 'Café de la esquina',
            visitedAt: DateTime(2026, 9, 24),
            iconKey: 'coffee'),
      ]));
  return [
    base,
    base.copyWith(
        id: 'chat',
        type: BentoNodeType.savedChat,
        payload: const SavedChatPayload(title: 'Ese día nos reímos', messages: [
          SavedChatMessage(
              sender: 'Rochy', text: '¿Ya comiste?', timeLabel: '19:02'),
          SavedChatMessage(
              sender: 'Samuel',
              text: 'Sí, pero contigo cabe otro café.',
              timeLabel: '19:03',
              isRight: true),
          SavedChatMessage(
              sender: 'Rochy',
              text: 'Jajaja, nos vemos en la esquina.',
              timeLabel: '19:04'),
          SavedChatMessage(
              sender: 'Samuel',
              text: 'Llevo las ganas de verte.',
              timeLabel: '19:04',
              isRight: true),
        ])),
    base.copyWith(
        id: 'ticket',
        type: BentoNodeType.vintageTicket,
        colorTheme: BentoColorTheme.sand,
        payload: VintageTicketPayload(
            title: 'La película era la excusa',
            date: date,
            code: 'NOSOTROS-001',
            rating: 5,
            kind: 'cinema',
            note: 'Lo mejor fue caminar de regreso sin mirar la hora.')),
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('new payloads round-trip every field without changing existing modules',
      () {
    final nodes = [...sampleAllCardTypes(), ...sampleKeepsakes()];
    for (final node in nodes) {
      final serialized =
          jsonDecode(jsonEncode(node.toJson())) as Map<String, dynamic>;
      final restored = BentoNode.fromJson(serialized);
      expect(restored.toJson(), node.toJson(), reason: node.type.name);
      expect(restored.displayTitle, node.displayTitle);
    }
    expect(BentoNodeType.fromWire('planTicket'), BentoNodeType.planTicket);
    expect(
        BentoNodeType.fromWire('vintageTicket'), BentoNodeType.vintageTicket);
    expect(BentoNodeType.values, hasLength(25));
  });

  test('disk persistence retains old cards alongside all three new modules',
      () async {
    final repo = LocalBentoRepository();
    final original = sampleAllCardTypes();
    final oldJson = original.map((n) => n.toJson()).toList();
    final entity = repo.loadEntity();
    await repo.persistToDisk(
        notebooks: [
          RochyNotebook(
              entity: entity, nodes: [...original, ...sampleKeepsakes()])
        ],
        activeNotebookId: entity.id,
        biometricEnabled: false,
        showPaperGrain: true,
        textScaleFactor: 1);
    final restored = await LocalBentoRepository().hydrateFromDisk();
    expect(restored, isNotNull);
    final cards = restored!.notebooks.single.nodes;
    expect(
        cards.take(original.length).map((n) => n.toJson()).toList(), oldJson);
    expect(cards.skip(original.length).map((n) => n.toJson()).toList(),
        sampleKeepsakes().map((n) => n.toJson()).toList());
  });

  testWidgets(
      'passport adds, edits and deletes stamps while retaining date and icon',
      (tester) async {
    final initial =
        (sampleKeepsakes().first.payload as TravelPassportPayload).stamps;
    var result = initial;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
      child: PassportEntriesEditor(
          initial: initial, onChanged: (stamps) => result = stamps),
    ))));
    await tester.enterText(
        find.widgetWithText(TextField, 'Ciudad o barrio').first, 'Bogotá');
    expect(result.first.place, 'Bogotá');
    expect(result.first.visitedAt, initial.first.visitedAt);
    expect(result.first.iconKey, initial.first.iconKey);
    final add = find.byKey(const ValueKey('add_passport_stamp'));
    await tester.ensureVisible(add);
    await tester.tap(add);
    await tester.pump();
    expect(result, hasLength(4));
    await tester.ensureVisible(find.byTooltip('Eliminar sello 2'));
    await tester.tap(find.byTooltip('Eliminar sello 2'));
    await tester.pump();
    expect(result, hasLength(3));
    expect(result.first.place, 'Bogotá');
    expect(result[1].place, initial[2].place);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'chat editor allows two to four messages with editable names and text',
      (tester) async {
    var result = const [
      SavedChatMessage(sender: 'Ella', text: 'Hola', timeLabel: '10:00'),
      SavedChatMessage(
          sender: 'Yo', text: 'Voy por ti', timeLabel: '10:01', isRight: true),
    ];
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
      child: ChatMessagesEditor(
          initial: result, onChanged: (messages) => result = messages),
    ))));
    await tester.enterText(
        find.widgetWithText(TextField, 'Nombre del mensaje 1'), 'Rochy');
    await tester.enterText(
        find.widgetWithText(TextField, 'Texto del mensaje 1'), '¿Un café?');
    expect(result.first.sender, 'Rochy');
    expect(result.first.text, '¿Un café?');
    expect(result.first.timeLabel, '10:00');
    for (var i = 0; i < 2; i++) {
      final add = find.byKey(const ValueKey('add_saved_message'));
      await tester.ensureVisible(add);
      await tester.tap(add);
      await tester.pump();
    }
    expect(result, hasLength(4));
    expect(
        tester
            .widget<OutlinedButton>(
                find.byKey(const ValueKey('add_saved_message')))
            .onPressed,
        isNull);
    for (var i = 0; i < 2; i++) {
      await tester.ensureVisible(find.byTooltip('Eliminar mensaje 1'));
      await tester.tap(find.byTooltip('Eliminar mensaje 1'));
      await tester.pump();
    }
    expect(result, hasLength(2));
    expect(tester.widget<IconButton>(find.byType(IconButton).first).onPressed,
        isNull);
    expect(tester.takeException(), isNull);
  });

  for (final sample in sampleKeepsakes()) {
    testWidgets(
        '${sample.type.name} editor saves changes and retains every other field',
        (tester) async {
      tester.view.physicalSize = const Size(430, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(bentoCanvasProvider.notifier);
      notifier.updateCloudConfig(
          const FirebaseCoupleConfig(autoSyncEnabled: false));
      notifier.updateCloudConfig(
          const FirebaseCoupleConfig(autoSyncEnabled: false));
      notifier.createNotebook(name: 'Prueba', subtitle: '', startBlank: true);
      notifier.addNode(sample);
      await tester.pumpWidget(UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
              home: Scaffold(
                  body: Consumer(
                      builder: (context, ref, _) => Center(
                          child: TextButton(
                              child: const Text('Abrir editor'),
                              onPressed: () => showNodeEditorSheet(context, ref,
                                  type: sample.type,
                                  existingNode: sample))))))));
      await tester.pump();
      await tester.tap(find.text('Abrir editor'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.enterText(find.byType(TextField).first, 'Un título nuevo');
      await tester.tap(find.text('Guardar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final updated = container.read(bentoCanvasProvider).nodes.single;
      final expected = sample.toJson();
      (expected['payload'] as Map<String, dynamic>)['title'] =
          'Un título nuevo';
      expected['updatedAt'] = updated.toJson()['updatedAt'];
      expected['authorId'] = 'samuel';
      expect(updated.updatedAt, isNotNull);
      expect(updated.toJson(), expected);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'new cards fit all ten sizes and keep their complete details accessible',
      (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    for (final sample in sampleKeepsakes()) {
      for (var cols = 1; cols <= 2; cols++) {
        for (var rows = 1; rows <= 5; rows++) {
          await tester.pumpWidget(ProviderScope(
              child: MaterialApp(
                  home: Scaffold(
                      body: Center(
            child: SizedBox(
                width: cols == 1 ? 137 : 288,
                height: rows == 1 ? 82 : 160 + (rows - 2) * 72,
                child: KeepsakeCardWidget(
                    node: sample.copyWith(colSpan: cols, rowSpan: rows),
                    theme: RochyThemes.arenaCalida,
                    relationHighlight: BentoRelationHighlight.normal)),
          )))));
          await tester.pump(const Duration(milliseconds: 300));
          expect(tester.takeException(), isNull,
              reason: '${sample.type.name}: $cols x $rows');
        }
      }
      await tester.tap(find.byType(KeepsakeCardWidget));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byTooltip('Editar recuerdo'), findsOneWidget);
      await tester.tap(find.byTooltip('Cerrar recuerdo'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
    }
  });
}
