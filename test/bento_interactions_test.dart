import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rochy/models/bento_node.dart';
import 'package:rochy/providers/bento_canvas_provider.dart';
import 'package:rochy/widgets/staggered_bento_grid.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<ProviderContainer> mountCanvas(WidgetTester tester,
      {double width = 390, int count = 4}) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(bentoCanvasProvider.notifier);
    notifier.createNotebook(name: 'Gestos', subtitle: '', startBlank: true);
    for (var i = 0; i < count; i++) {
      notifier.addNode(BentoNode(
        id: 'test_$i',
        type: BentoNodeType.habitChips,
        colSpan: 1,
        rowSpan: 2,
        colorTheme: BentoColorTheme.sage,
        linkedNodeIds: const [],
        tags: const [],
        createdAt: DateTime(2026),
        payload:
            HabitChipsPayload(title: 'Tarjeta $i', habits: const ['Recuerdo']),
      ));
    }
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
          home: Scaffold(
              body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Consumer(
                builder: (_, ref, __) => StaggeredBentoGrid(
                      nodes: ref.watch(bentoCanvasProvider).nodes,
                    )),
          ),
        ),
      ))),
    ));
    await tester.pump(const Duration(seconds: 2));
    return container;
  }

  testWidgets(
      'two fingers cannot create two drag avatars, even on separate cards',
      (tester) async {
    final container = await mountCanvas(tester);
    final firstRect =
        tester.getRect(find.byKey(const ValueKey('bento_pos_test_0')));
    final secondRect =
        tester.getRect(find.byKey(const ValueKey('bento_pos_test_1')));
    final first = await tester.startGesture(firstRect.center, pointer: 1);
    await tester.pump(const Duration(milliseconds: 300));
    await first.moveBy(const Offset(0, 35));
    await tester.pump(const Duration(milliseconds: 20));
    expect(find.byKey(const ValueKey('drag_feedback_test_0')), findsOneWidget);

    final second = await tester.startGesture(secondRect.center, pointer: 2);
    await tester.pump(const Duration(milliseconds: 300));
    await second.moveBy(const Offset(0, 40));
    await tester.pump(const Duration(milliseconds: 20));
    expect(find.byKey(const ValueKey('drag_feedback_test_0')), findsOneWidget);
    expect(find.byKey(const ValueKey('drag_feedback_test_1')), findsNothing);
    expect(container.read(bentoCanvasProvider).nodes, hasLength(4));
    await second.up();
    await first.up();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byKey(const ValueKey('drag_feedback_test_0')), findsNothing);
    expect(find.text('Tarjeta 0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'vertical menu fits either screen edge and sizes apply immediately',
      (tester) async {
    final container = await mountCanvas(tester, width: 320);
    final notifier = container.read(bentoCanvasProvider.notifier);
    for (final id in ['test_0', 'test_1']) {
      notifier.activateWidget(id);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      final menu =
          tester.getRect(find.byKey(ValueKey('bento_action_menu_$id')));
      expect(menu.left, greaterThanOrEqualTo(0));
      expect(menu.right, lessThanOrEqualTo(320));
      expect(menu.top, greaterThanOrEqualTo(0));
      expect(menu.bottom, lessThanOrEqualTo(844));
    }
    await tester.tap(find.byTooltip('Cambiar tamaño'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Tamaño de la tarjeta'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('bento_size_2x3')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    var node = container
        .read(bentoCanvasProvider)
        .nodes
        .firstWhere((n) => n.id == 'test_1');
    expect((node.colSpan, node.rowSpan), (2, 3));
    final wideRect =
        tester.getRect(find.byKey(const ValueKey('bento_pos_test_1')));
    await tester.tap(find.byKey(const ValueKey('bento_size_1x1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    node = container
        .read(bentoCanvasProvider)
        .nodes
        .firstWhere((n) => n.id == 'test_1');
    expect((node.colSpan, node.rowSpan), (1, 1));
    await tester.tap(find.byTooltip('Listo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    final smallRect =
        tester.getRect(find.byKey(const ValueKey('bento_pos_test_1')));
    expect(smallRect.width, lessThan(wideRect.width));
    expect(smallRect.height, lessThan(wideRect.height));
    expect(tester.takeException(), isNull);
  });

  testWidgets('resizing height keeps the handle alive across multiple reflows',
      (tester) async {
    final container = await mountCanvas(tester);
    container.read(bentoCanvasProvider.notifier).activateWidget('test_0');
    await tester.pump();
    final handle = find.byKey(const ValueKey('resize_height_test_0'));
    final drag = await tester.startGesture(tester.getCenter(handle));
    await drag.moveBy(const Offset(0, 25));
    await tester.pump();
    for (var i = 0; i < 4; i++) {
      await drag.moveBy(const Offset(0, 35));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await drag.up();
    await tester.pump(const Duration(milliseconds: 350));
    final node = container.read(bentoCanvasProvider).nodes.first;
    expect(node.rowSpan, greaterThan(2));
    expect(find.byKey(const ValueKey('drag_feedback_test_0')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'corner accepts a held finger near its outer hit area without moving the card',
      (tester) async {
    final container = await mountCanvas(tester);
    container.read(bentoCanvasProvider.notifier).activateWidget('test_0');
    await tester.pump();
    final rect = tester.getRect(find.byKey(const ValueKey('bento_pos_test_0')));
    final finger =
        await tester.startGesture(rect.bottomRight - const Offset(58, 58));
    await tester.pump(const Duration(milliseconds: 350));
    await finger.moveBy(const Offset(45, 45));
    await tester.pump();
    final node = container
        .read(bentoCanvasProvider)
        .nodes
        .firstWhere((n) => n.id == 'test_0');
    expect((node.colSpan, node.rowSpan), (2, 3));
    expect(find.byKey(const ValueKey('drag_feedback_test_0')), findsNothing);
    await tester.pump(const Duration(milliseconds: 350));
    await finger.moveBy(const Offset(0, 60));
    await tester.pump();
    expect(
        container
            .read(bentoCanvasProvider)
            .nodes
            .firstWhere((n) => n.id == 'test_0')
            .rowSpan,
        4);
    await finger.up();
    await tester.pump(const Duration(milliseconds: 350));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'corner counts the first small movement instead of losing it to touch slop',
      (tester) async {
    final container = await mountCanvas(tester);
    container.read(bentoCanvasProvider.notifier).activateWidget('test_0');
    await tester.pump();
    final corner = find.byKey(const ValueKey('resize_corner_test_0'));
    final finger = await tester.startGesture(
        tester.getRect(corner).bottomRight - const Offset(20, 20));
    await finger.moveBy(const Offset(34, 0));
    await tester.pump();
    expect(container.read(bentoCanvasProvider).nodes.first.colSpan, 2);
    expect(find.byKey(const ValueKey('drag_feedback_test_0')), findsNothing);
    await finger.up();
    await tester.pump(const Duration(milliseconds: 350));
    expect(tester.takeException(), isNull);
  });

  testWidgets('corner resizing takes priority over scrolling the notebook',
      (tester) async {
    final container = await mountCanvas(tester, count: 20);
    container.read(bentoCanvasProvider.notifier).activateWidget('test_0');
    await tester.pump();
    final corner = find.byKey(const ValueKey('resize_corner_test_0'));
    final finger = await tester.startGesture(
        tester.getRect(corner).bottomRight - const Offset(20, 20));
    await finger.moveBy(const Offset(0, -60));
    await tester.pump(const Duration(milliseconds: 40));
    expect(container.read(bentoCanvasProvider).nodes.first.rowSpan, 1);
    final scroll =
        Scrollable.of(tester.element(find.byType(StaggeredBentoGrid))).position;
    expect(scroll.pixels, 0);
    expect(find.byKey(const ValueKey('drag_feedback_test_0')), findsNothing);
    await finger.up();
    await tester.pump(const Duration(milliseconds: 350));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'resizing ignores a second finger and releases ownership on cancel',
      (tester) async {
    final container = await mountCanvas(tester);
    container.read(bentoCanvasProvider.notifier).activateWidget('test_0');
    await tester.pump();
    final corner = find.byKey(const ValueKey('resize_corner_test_0'));
    final first = await tester.startGesture(
        tester.getRect(corner).bottomRight - const Offset(20, 20),
        pointer: 1);
    await first.moveBy(const Offset(0, 60));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(container.read(bentoCanvasProvider).nodes.first.rowSpan, 3);
    final second = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('resize_height_test_0'))),
        pointer: 2);
    await second.moveBy(const Offset(0, 100));
    await tester.pump();
    expect(container.read(bentoCanvasProvider).nodes.first.rowSpan, 3);
    await second.cancel();
    await first.cancel();
    await tester.pump();
    final next = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('bento_pos_test_0'))),
        pointer: 3);
    await tester.pump(const Duration(milliseconds: 300));
    await next.moveBy(const Offset(0, 35));
    await tester.pump();
    expect(find.byKey(const ValueKey('drag_feedback_test_0')), findsOneWidget);
    await next.up();
    await tester.pump(const Duration(milliseconds: 350));
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping the visible corner still opens the size picker',
      (tester) async {
    final container = await mountCanvas(tester);
    container.read(bentoCanvasProvider.notifier).activateWidget('test_0');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('resize_corner_test_0')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Tamaño de la tarjeta'), findsOneWidget);
    await tester.tap(find.byTooltip('Listo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'removing a card during a grab releases the canvas for the next card',
      (tester) async {
    final container = await mountCanvas(tester);
    final notifier = container.read(bentoCanvasProvider.notifier);
    notifier.activateWidget('test_0');
    await tester.pump();
    final corner = find.byKey(const ValueKey('resize_corner_test_0'));
    final finger = await tester.startGesture(
        tester.getRect(corner).bottomRight - const Offset(20, 20));
    await tester.pump();
    notifier.deleteNode('test_0');
    await tester.pump();
    await tester.pump();
    notifier.activateWidget('test_1');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(
        find.byKey(const ValueKey('bento_action_menu_test_1')), findsOneWidget);
    await finger.cancel();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('holding a card after scrolling opens a menu inside the viewport',
      (tester) async {
    await mountCanvas(tester, count: 20);
    final last = find.byKey(const ValueKey('bento_pos_test_19'));
    await tester.ensureVisible(last);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.longPress(last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    final menu =
        tester.getRect(find.byKey(const ValueKey('bento_action_menu_test_19')));
    expect(menu.top, greaterThanOrEqualTo(0));
    expect(menu.bottom, lessThanOrEqualTo(844));
    expect(menu.left, greaterThanOrEqualTo(0));
    expect(menu.right, lessThanOrEqualTo(390));
    expect(find.text('Tarjeta 19'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('all ten sizes render all card types without overflowing',
      (tester) async {
    final container = await mountCanvas(tester, width: 320, count: 0);
    final notifier = container.read(bentoCanvasProvider.notifier);
    final nodes = LocalBentoRepository().starterTemplateNodes();
    nodes.addAll([
      nodes.first.copyWith(
          id: 'test_book',
          type: BentoNodeType.bookMovie,
          payload: const BookMoviePayload(
              title: 'Nuestro libro favorito',
              creator: 'Una autora',
              kind: 'book',
              personalNote: 'Lo leímos juntos de vacaciones.')),
      nodes.first.copyWith(
          id: 'test_gifts',
          type: BentoNodeType.giftWish,
          payload: const GiftWishPayload(title: 'Ideas de regalos', items: [
            CheckListItem(
                id: 'gift_1', text: 'Un viaje especial', isHighlighted: false),
            CheckListItem(id: 'gift_2', text: 'Un libro', isHighlighted: false),
            CheckListItem(id: 'gift_3', text: 'Un ramo', isHighlighted: false),
            CheckListItem(id: 'gift_4', text: 'Una cena', isHighlighted: false),
          ])),
      nodes.first.copyWith(
          id: 'test_video',
          type: BentoNodeType.videoMemory,
          payload: const VideoMemoryPayload(
              title: 'Bailando bajo la lluvia',
              videoSource: '',
              dateLabel: '18 nov',
              locationLabel: 'Cartagena')),
    ]);
    for (final node in nodes) {
      notifier.addNode(node);
    }
    for (var cols = 1; cols <= 2; cols++) {
      for (var rows = 1; rows <= 5; rows++) {
        for (final node in nodes) {
          notifier.resizeNode(node.id, colSpan: cols, rowSpan: rows);
        }
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        expect(tester.takeException(), isNull, reason: 'Preset $cols × $rows');
      }
    }
  });
}
