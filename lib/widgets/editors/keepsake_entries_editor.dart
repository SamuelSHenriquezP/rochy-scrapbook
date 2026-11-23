import 'package:flutter/material.dart';
import '../../models/bento_node.dart';

String keepsakeDateLabel(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

const passportIcons = <String, (String, IconData)>{
  'city': ('Ciudad', Icons.location_city_rounded),
  'coffee': ('Café', Icons.local_cafe_rounded),
  'beach': ('Playa', Icons.beach_access_rounded),
  'mountain': ('Montaña', Icons.landscape_rounded),
  'heart': ('Especial', Icons.favorite_rounded),
  'plane': ('Viaje', Icons.flight_rounded),
};

class PassportEntriesEditor extends StatefulWidget {
  const PassportEntriesEditor(
      {super.key, required this.initial, required this.onChanged});
  final List<PassportStamp> initial;
  final ValueChanged<List<PassportStamp>> onChanged;

  @override
  State<PassportEntriesEditor> createState() => _PassportEntriesEditorState();
}

class _StampDraft {
  _StampDraft(PassportStamp stamp)
      : place = TextEditingController(text: stamp.place),
        date = stamp.visitedAt,
        icon = stamp.iconKey;
  final key = UniqueKey();
  final TextEditingController place;
  DateTime date;
  String icon;
  PassportStamp get value => PassportStamp(
        place: place.text.trim(),
        visitedAt: date,
        iconKey: icon,
      );
}

class _PassportEntriesEditorState extends State<PassportEntriesEditor> {
  late final List<_StampDraft> _stamps;

  @override
  void initState() {
    super.initState();
    _stamps = widget.initial.map(_StampDraft.new).toList();
    for (final stamp in _stamps) {
      stamp.place.addListener(_emit);
    }
  }

  void _emit() => widget.onChanged(_stamps.map((s) => s.value).toList());

  @override
  void dispose() {
    for (final stamp in _stamps) {
      stamp.place.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        for (var i = 0; i < _stamps.length; i++)
          Card(
            key: _stamps[i].key,
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                          child: Text('Sello ${i + 1}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600))),
                      IconButton(
                        tooltip: 'Eliminar sello ${i + 1}',
                        onPressed: () {
                          final removed = _stamps[i];
                          setState(() => _stamps.removeAt(i));
                          removed.place.dispose();
                          _emit();
                        },
                        icon:
                            const Icon(Icons.delete_outline_rounded, size: 20),
                      ),
                    ]),
                    TextField(
                      controller: _stamps[i].place,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                          labelText: 'Ciudad o barrio',
                          hintText: 'Ej. Getsemaní, Cartagena'),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: passportIcons.containsKey(_stamps[i].icon)
                          ? _stamps[i].icon
                          : 'city',
                      decoration:
                          const InputDecoration(labelText: 'Ícono del sello'),
                      items: passportIcons.entries
                          .map((entry) => DropdownMenuItem(
                                value: entry.key,
                                child: Row(children: [
                                  Icon(entry.value.$2, size: 18),
                                  const SizedBox(width: 8),
                                  Text(entry.value.$1)
                                ]),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setState(() => _stamps[i].icon = value ?? 'city');
                        _emit();
                      },
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        final chosen = await showDatePicker(
                            context: context,
                            initialDate: _stamps[i].date,
                            firstDate: DateTime(1900),
                            lastDate: DateTime(2200, 12, 31));
                        if (chosen == null || !mounted) return;
                        setState(() => _stamps[i].date = chosen);
                        _emit();
                      },
                      icon: const Icon(Icons.calendar_month_rounded, size: 18),
                      label: Text(
                          'Fecha del sello: ${keepsakeDateLabel(_stamps[i].date)}'),
                    ),
                  ]),
            ),
          ),
        OutlinedButton.icon(
          key: const ValueKey('add_passport_stamp'),
          onPressed: () {
            final stamp = _StampDraft(
                PassportStamp(place: '', visitedAt: DateTime.now()));
            stamp.place.addListener(_emit);
            setState(() => _stamps.add(stamp));
            _emit();
          },
          icon: const Icon(Icons.add_location_alt_outlined),
          label: const Text('Añadir sello'),
        ),
        const SizedBox(height: 12),
      ]);
}

class ChatMessagesEditor extends StatefulWidget {
  const ChatMessagesEditor(
      {super.key, required this.initial, required this.onChanged});
  final List<SavedChatMessage> initial;
  final ValueChanged<List<SavedChatMessage>> onChanged;

  @override
  State<ChatMessagesEditor> createState() => _ChatMessagesEditorState();
}

class _MessageDraft {
  _MessageDraft(SavedChatMessage message)
      : sender = TextEditingController(text: message.sender),
        text = TextEditingController(text: message.text),
        time = message.timeLabel,
        right = message.isRight;
  final key = UniqueKey();
  final TextEditingController sender, text;
  String time;
  bool right;
  SavedChatMessage get value => SavedChatMessage(
      sender: sender.text.trim(),
      text: text.text.trim(),
      timeLabel: time,
      isRight: right);
  void dispose() {
    sender.dispose();
    text.dispose();
  }
}

class _ChatMessagesEditorState extends State<ChatMessagesEditor> {
  late final List<_MessageDraft> _messages;

  @override
  void initState() {
    super.initState();
    _messages = widget.initial.map(_MessageDraft.new).toList();
    for (final message in _messages) {
      _listen(message);
    }
  }

  void _listen(_MessageDraft message) {
    message.sender.addListener(_emit);
    message.text.addListener(_emit);
  }

  void _emit() => widget.onChanged(_messages.map((m) => m.value).toList());

  @override
  void dispose() {
    for (final message in _messages) {
      message.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        for (var i = 0; i < _messages.length; i++)
          Card(
            key: _messages[i].key,
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                Row(children: [
                  Expanded(
                      child: Text('Mensaje ${i + 1}',
                          style: const TextStyle(fontWeight: FontWeight.w600))),
                  IconButton(
                    tooltip: 'Eliminar mensaje ${i + 1}',
                    onPressed: _messages.length <= 2
                        ? null
                        : () {
                            final removed = _messages[i];
                            setState(() => _messages.removeAt(i));
                            removed.dispose();
                            _emit();
                          },
                    icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  ),
                ]),
                TextField(
                    controller: _messages[i].sender,
                    decoration: InputDecoration(
                        labelText: 'Nombre del mensaje ${i + 1}')),
                TextField(
                    controller: _messages[i].text,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 400,
                    decoration: InputDecoration(
                        labelText: 'Texto del mensaje ${i + 1}')),
                Wrap(
                    spacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ChoiceChip(
                          label: const Text('Izquierda'),
                          selected: !_messages[i].right,
                          onSelected: (_) {
                            setState(() => _messages[i].right = false);
                            _emit();
                          }),
                      ChoiceChip(
                          label: const Text('Derecha'),
                          selected: _messages[i].right,
                          onSelected: (_) {
                            setState(() => _messages[i].right = true);
                            _emit();
                          }),
                      TextButton.icon(
                        onPressed: () async {
                          final parts = _messages[i].time.split(':');
                          final chosen = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay(
                                  hour:
                                      int.tryParse(parts.first)?.clamp(0, 23) ??
                                          12,
                                  minute: parts.length > 1
                                      ? int.tryParse(parts[1])?.clamp(0, 59) ??
                                          0
                                      : 0));
                          if (chosen == null || !mounted) return;
                          setState(() => _messages[i].time =
                              '${chosen.hour.toString().padLeft(2, '0')}:${chosen.minute.toString().padLeft(2, '0')}');
                          _emit();
                        },
                        icon: const Icon(Icons.schedule_rounded, size: 16),
                        label: Text(_messages[i].time),
                      ),
                    ]),
              ]),
            ),
          ),
        OutlinedButton.icon(
          key: const ValueKey('add_saved_message'),
          onPressed: _messages.length >= 4
              ? null
              : () {
                  final message = _MessageDraft(SavedChatMessage(
                      sender: '',
                      text: '',
                      timeLabel: '12:00',
                      isRight: _messages.length.isOdd));
                  _listen(message);
                  setState(() => _messages.add(message));
                  _emit();
                },
          icon: const Icon(Icons.add_comment_outlined),
          label: Text('Añadir mensaje (${_messages.length}/4)'),
        ),
        const SizedBox(height: 12),
      ]);
}
