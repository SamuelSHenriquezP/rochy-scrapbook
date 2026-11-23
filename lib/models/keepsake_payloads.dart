part of 'bento_node.dart';

@immutable
class PassportStamp {
  const PassportStamp(
      {required this.place, required this.visitedAt, this.iconKey = 'city'});

  final String place;
  final DateTime visitedAt;
  final String iconKey;

  Map<String, dynamic> toJson() => {
        'place': place,
        'visitedAt': visitedAt.toIso8601String(),
        'iconKey': iconKey,
      };

  factory PassportStamp.fromJson(Map<String, dynamic> json) => PassportStamp(
        place: json['place'] as String? ?? '',
        visitedAt: DateTime.tryParse(json['visitedAt'] as String? ?? '') ??
            DateTime(2000),
        iconKey: json['iconKey'] as String? ?? 'city',
      );
}

@immutable
class TravelPassportPayload extends BentoPayload {
  const TravelPassportPayload({required this.title, this.stamps = const []});

  final String title;
  final List<PassportStamp> stamps;

  TravelPassportPayload copyWith(
          {String? title, List<PassportStamp>? stamps}) =>
      TravelPassportPayload(
          title: title ?? this.title, stamps: stamps ?? this.stamps);

  @override
  Map<String, dynamic> toJson() => {
        'title': title,
        'stamps': stamps.map((s) => s.toJson()).toList(),
      };

  factory TravelPassportPayload.fromJson(Map<String, dynamic> json) =>
      TravelPassportPayload(
        title: json['title'] as String? ?? 'Nuestro pasaporte',
        stamps: (json['stamps'] as List<dynamic>? ?? const [])
            .map((s) =>
                PassportStamp.fromJson(Map<String, dynamic>.from(s as Map)))
            .toList(),
      );
}

@immutable
class SavedChatMessage {
  const SavedChatMessage(
      {required this.sender,
      required this.text,
      required this.timeLabel,
      this.isRight = false});

  final String sender;
  final String text;
  final String timeLabel;
  final bool isRight;

  Map<String, dynamic> toJson() => {
        'sender': sender,
        'text': text,
        'timeLabel': timeLabel,
        'isRight': isRight,
      };

  factory SavedChatMessage.fromJson(Map<String, dynamic> json) =>
      SavedChatMessage(
        sender: json['sender'] as String? ?? '',
        text: json['text'] as String? ?? '',
        timeLabel: json['timeLabel'] as String? ?? '',
        isRight: json['isRight'] as bool? ?? false,
      );
}

@immutable
class SavedChatPayload extends BentoPayload {
  const SavedChatPayload({required this.title, required this.messages});

  final String title;
  final List<SavedChatMessage> messages;

  SavedChatPayload copyWith(
          {String? title, List<SavedChatMessage>? messages}) =>
      SavedChatPayload(
          title: title ?? this.title, messages: messages ?? this.messages);

  @override
  Map<String, dynamic> toJson() => {
        'title': title,
        'messages': messages.map((m) => m.toJson()).toList(),
      };

  factory SavedChatPayload.fromJson(Map<String, dynamic> json) =>
      SavedChatPayload(
        title: json['title'] as String? ?? 'Esto nos dio risa',
        messages: (json['messages'] as List<dynamic>? ?? const [])
            .map((m) =>
                SavedChatMessage.fromJson(Map<String, dynamic>.from(m as Map)))
            .toList(),
      );
}

@immutable
class VintageTicketPayload extends BentoPayload {
  const VintageTicketPayload(
      {required this.title,
      required this.date,
      required this.code,
      this.rating = 5,
      this.note = '',
      this.kind = 'cinema'});

  final String title;
  final DateTime date;
  final String code;
  final int rating;
  final String note;
  final String kind;

  VintageTicketPayload copyWith(
          {String? title,
          DateTime? date,
          String? code,
          int? rating,
          String? note,
          String? kind}) =>
      VintageTicketPayload(
        title: title ?? this.title,
        date: date ?? this.date,
        code: code ?? this.code,
        rating: rating ?? this.rating,
        note: note ?? this.note,
        kind: kind ?? this.kind,
      );

  @override
  Map<String, dynamic> toJson() => {
        'title': title,
        'date': date.toIso8601String(),
        'code': code,
        'rating': rating,
        'note': note,
        'kind': kind,
      };

  factory VintageTicketPayload.fromJson(Map<String, dynamic> json) =>
      VintageTicketPayload(
        title: json['title'] as String? ?? 'Una noche para guardar',
        date:
            DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime(2000),
        code: json['code'] as String? ?? 'AMOR-001',
        rating: (json['rating'] as num?)?.toInt().clamp(1, 5) ?? 5,
        note: json['note'] as String? ?? '',
        kind: json['kind'] as String? ?? 'cinema',
      );
}
