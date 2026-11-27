import 'package:rochy/models/bento_node.dart';

List<BentoNode> sampleAllCardTypes() => BentoNodeType.values
    .map((type) => BentoNode(
          id: 'fixture_${type.name}',
          type: type,
          colSpan: 1,
          rowSpan: 2,
          colorTheme: BentoColorTheme.ivory,
          linkedNodeIds: const [],
          tags: const ['recuerdo'],
          createdAt: DateTime(2026, 11, 27),
          payload: BentoPayload.fromJson(type, const {
            'title': 'Un recuerdo',
            'microText': 'Un detalle de los dos',
            'quoteText': 'Una frase nuestra',
            'placeName': 'Nuestro lugar',
            'targetDate': '2026-12-24T00:00:00.000',
            'items': [
              {'id': 'item', 'text': 'Un detalle', 'isHighlighted': false}
            ],
            'swatchHexes': [0xFFA85338, 0xFFFAF6F0],
            'moodWords': ['Calma'],
            'habits': ['Sonreír'],
          }),
        ))
    .toList();
