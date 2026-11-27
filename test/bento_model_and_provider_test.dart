import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rochy/models/bento_node.dart';
import 'package:rochy/providers/bento_canvas_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Memory Graph Serialization & Disk Persistence', () {
    test('round-trips BentoEntity and starter nodes', () {
      final repo = LocalBentoRepository();
      final snapshot = repo.exportJsonSnapshot();
      final decoded = jsonDecode(snapshot) as Map<String, dynamic>;

      final entity = BentoEntity.fromJson(
        Map<String, dynamic>.from(decoded['entity'] as Map<dynamic, dynamic>),
      );
      expect(entity.id, 'entity_rochy');
      expect(entity.name, 'Rochy');

      final rawNodes = decoded['nodes'] as List<dynamic>;
      final restored = rawNodes
          .map(
            (item) => BentoNode.fromJson(
              Map<String, dynamic>.from(item as Map<dynamic, dynamic>),
            ),
          )
          .toList();

      expect(restored, isEmpty);
    });

    test('round-trips VideoMemoryPayload, BentoFontStyle and new modules', () {
      final now = DateTime(2026, 1, 15);
      final samples = <BentoNode>[
        BentoNode(
          id: 'vid_1',
          type: BentoNodeType.videoMemory,
          colSpan: 2,
          rowSpan: 2,
          colorTheme: BentoColorTheme.espresso,
          fontStyle: BentoFontStyle.handwritten,
          linkedNodeIds: const <String>[],
          tags: const <String>['video'],
          createdAt: now,
          payload: const VideoMemoryPayload(
            title: 'Bailando bajo la lluvia',
            videoSource: '/tmp/rain.mp4',
            dateLabel: '18 nov',
            locationLabel: 'Balcón',
            caption: 'Risas sin parar',
          ),
        ),
        BentoNode(
          id: 'n1',
          type: BentoNodeType.countdown,
          colSpan: 1,
          rowSpan: 2,
          colorTheme: BentoColorTheme.terracotta,
          fontStyle: BentoFontStyle.cleanSans,
          linkedNodeIds: const <String>[],
          tags: const <String>['fecha'],
          createdAt: now,
          payload: CountdownPayload(
            title: 'Aniversario',
            targetDate: DateTime(2023, 10, 14),
            subtitle: 'Desde aquel café',
          ),
        ),
        BentoNode(
          id: 'n2',
          type: BentoNodeType.paletteMood,
          colSpan: 1,
          rowSpan: 2,
          colorTheme: BentoColorTheme.ivory,
          linkedNodeIds: const <String>[],
          tags: const <String>['colores'],
          createdAt: now,
          payload: const PaletteMoodPayload(
            title: 'Su esencia',
            scentNote: 'Vainilla y lluvia',
            swatchHexes: <int>[0xFFA85338, 0xFF5B6E58],
            moodWords: <String>['Serena', 'Luminosa'],
          ),
        ),
        BentoNode(
          id: 'n3',
          type: BentoNodeType.bookMovie,
          colSpan: 1,
          rowSpan: 2,
          colorTheme: BentoColorTheme.espresso,
          linkedNodeIds: const <String>[],
          tags: const <String>['libros'],
          createdAt: now,
          payload: const BookMoviePayload(
            title: 'El Principito',
            creator: 'Saint-Exupéry',
            kind: 'book',
            personalNote: 'Lo relee cada otoño',
          ),
        ),
        BentoNode(
          id: 'n4',
          type: BentoNodeType.giftWish,
          colSpan: 1,
          rowSpan: 3,
          colorTheme: BentoColorTheme.ivory,
          linkedNodeIds: const <String>[],
          tags: const <String>['deseos'],
          createdAt: now,
          payload: const GiftWishPayload(
            title: 'Ideas de regalo',
            items: <CheckListItem>[
              CheckListItem(id: 'g1', text: 'Girasoles'),
            ],
          ),
        ),
        BentoNode(
          id: 'n5',
          type: BentoNodeType.loveLetter,
          colSpan: 1,
          rowSpan: 2,
          colorTheme: BentoColorTheme.sand,
          linkedNodeIds: const <String>[],
          tags: const <String>['carta'],
          createdAt: now,
          payload: const LoveLetterPayload(
            title: 'Nota para un día gris',
            previewLine: 'Ábrela cuando llueva…',
            letterBody: 'Siempre estás en mis mañanas.',
            signature: 'Tuyo',
          ),
        ),
        BentoNode(
          id: 'n6',
          type: BentoNodeType.habitChips,
          colSpan: 1,
          rowSpan: 2,
          colorTheme: BentoColorTheme.sage,
          linkedNodeIds: const <String>[],
          tags: const <String>['hábitos'],
          createdAt: now,
          payload: const HabitChipsPayload(
            title: 'Pequeñas manías',
            habits: <String>['Canta bajito', 'Toma café tibio'],
          ),
        ),
      ];

      for (final node in samples) {
        final restored = BentoNode.fromJson(node.toJson());
        expect(restored.type, node.type);
        expect(restored.fontStyle, node.fontStyle);
        expect(restored.displayTitle, node.displayTitle);
      }
    });

    test('persists and hydrates notebooks via SharedPreferences', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final repo = LocalBentoRepository();
      final customEntity = repo.loadEntity().copyWith(name: 'Sofía');

      await repo.persistToDisk(
        notebooks: <RochyNotebook>[
          RochyNotebook(entity: customEntity, nodes: const <BentoNode>[]),
        ],
        activeNotebookId: customEntity.id,
        biometricEnabled: true,
        showPaperGrain: false,
        textScaleFactor: 1.05,
      );

      final hydratedRepo = LocalBentoRepository();
      final restored = await hydratedRepo.hydrateFromDisk();
      expect(restored, isNotNull);
      expect(restored!.notebooks.first.entity.name, 'Sofía');
      expect(restored.biometricEnabled, isTrue);
      expect(restored.showPaperGrain, isFalse);
      expect(restored.textScaleFactor, 1.05);
    });
  });

  group('BentoCanvasNotifier multi-notebook, undo, drag & graph', () {
    test('supports add, reorderNode, delete with undo, and multi-notebook', () {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(bentoCanvasProvider.notifier);

      notifier.createNotebook(
        name: 'Camila',
        subtitle: 'Viaje al sur',
        startBlank: true,
      );
      expect(container.read(bentoCanvasProvider).notebooks.length, 3);
      expect(container.read(bentoCanvasProvider).entity.name, 'Camila');
      expect(container.read(bentoCanvasProvider).nodes, isEmpty);

      final first = BentoNode(
        id: 'c_1',
        type: BentoNodeType.habitChips,
        colSpan: 1,
        rowSpan: 2,
        colorTheme: BentoColorTheme.sage,
        linkedNodeIds: const <String>[],
        tags: const <String>['ella'],
        createdAt: DateTime(2026, 1, 1),
        payload: const HabitChipsPayload(
          title: 'Cosas suyas',
          habits: <String>['Sonríe al despertar'],
        ),
      );
      final second = first.copyWith(
        id: 'c_2',
        linkedNodeIds: const <String>['c_1'],
      );

      notifier.addNode(first);
      notifier.addNode(second);
      notifier.reorderNode('c_2', 'c_1');
      expect(container.read(bentoCanvasProvider).nodes.first.id, 'c_2');

      final removed = notifier.deleteNode('c_1');
      expect(removed, isNotNull);
      expect(container.read(bentoCanvasProvider).nodes.length, 1);

      notifier.restoreDeletedNode(removed!.node, removed.index);
      expect(container.read(bentoCanvasProvider).nodes.length, 2);
    });
  });
}
