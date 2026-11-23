import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/bento_node.dart';
import '../../providers/bento_canvas_provider.dart';
import '../../theme/rochy_theme.dart';
import '../editors/keepsake_entries_editor.dart';
import '../editors/node_editor_sheet.dart';
import 'bento_card_shell.dart';

/// Three additional keepsakes; existing card designs stay independent.
class KeepsakeCardWidget extends ConsumerWidget {
  const KeepsakeCardWidget(
      {super.key,
      required this.node,
      required this.theme,
      required this.relationHighlight,
      this.showPaperGrain = true});

  final BentoNode node;
  final RochyThemeData theme;
  final BentoRelationHighlight relationHighlight;
  final bool showPaperGrain;

  IconData get _icon => switch (node.payload) {
        TravelPassportPayload() => Icons.public_rounded,
        SavedChatPayload() => Icons.forum_outlined,
        _ => Icons.confirmation_number_outlined,
      };

  String get _subtitle => switch (node.payload) {
        final TravelPassportPayload p =>
          '${p.stamps.length} sellos · nuestros rincones',
        final SavedChatPayload p => '${p.messages.length} mensajes para guardar',
        final VintageTicketPayload p => keepsakeDateLabel(p.date),
        _ => '',
      };

  void _openDetails(BuildContext context, WidgetRef ref) {
    final canvas = ref.read(bentoCanvasProvider);
    final authorLabel = canvas.authorLabelFor(node.authorId);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => SizedBox(
        height: MediaQuery.sizeOf(sheetContext).height * 0.78,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
            child: Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      node.displayTitle,
                      style: RochyTypography.cardSerifTitle(
                        theme.inkPrimary,
                        fontSize: 21,
                      ),
                    ),
                    if (authorLabel.isNotEmpty)
                      Text(
                        'Guardado por $authorLabel',
                        style: RochyTypography.metadata(
                          theme.inkSecondary,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                  tooltip: 'Editar recuerdo',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    showNodeEditorSheet(context, ref,
                        type: node.type, existingNode: node);
                  }),
              IconButton(
                  tooltip: 'Cerrar recuerdo',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(sheetContext).pop()),
            ]),
          ),
          Expanded(
              child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            child: _content(theme.inkPrimary, isDetail: true),
          )),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ink = theme.resolveNodePrimaryInk(node);
    final isChat = node.payload is SavedChatPayload;
    final card = BentoCardShell(
      theme: theme,
      node: node,
      backgroundColor: theme.resolveNodeBackground(node),
      relationHighlight: relationHighlight,
      showPaperGrain: showPaperGrain,
      padding: EdgeInsets.fromLTRB(
        isChat ? 12 : 14,
        isChat ? 11 : 14,
        isChat ? 12 : 14,
        isChat ? 10 : 14,
      ),
      onTap: () => _openDetails(context, ref),
      onLongPress: () =>
          ref.read(bentoCanvasProvider.notifier).toggleNodeFocus(node.id),
      child: LayoutBuilder(builder: (context, constraints) {
        final compact = constraints.maxHeight < 112;
        final header =
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              _icon,
              size: isChat ? 15 : 18,
              color: ink.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
              child: Text(node.displayTitle,
                  maxLines: 2,
                  softWrap: true,
                  overflow: TextOverflow.ellipsis,
                  style: RochyTypography.resolveCardTitle(
                    node.fontStyle,
                    ink,
                    fontSize: (isChat ? 13.4 : 15.5) * node.titleScale,
                    fontWeight: node.isTitleBold
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ).copyWith(height: 1.18))),
        ]);
        if (compact) {
          return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                header,
                if (constraints.maxHeight >= 68) ...[
                  const SizedBox(height: 4),
                  Text(_subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: RochyTypography.metadata(
                          ink.withValues(alpha: 0.65),
                          fontSize: 10)),
                ],
              ]);
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          header,
          if (isChat) ...[
            const SizedBox(height: 6),
            Divider(height: 1, color: ink.withValues(alpha: 0.12)),
            const SizedBox(height: 7),
          ] else
            const SizedBox(height: 8),
          Expanded(child: SingleChildScrollView(child: _content(ink))),
        ]);
      }),
    );
    return node.payload is VintageTicketPayload
        ? ClipPath(clipper: const _TicketPaperClipper(), child: card)
        : card;
  }

  Widget _content(Color ink, {bool isDetail = false}) => switch (node.payload) {
        final TravelPassportPayload p => _passport(p, ink),
        final SavedChatPayload p => _chat(p, ink, isDetail: isDetail),
        final VintageTicketPayload p => _ticket(p, ink),
        _ => const SizedBox.shrink(),
      };

  Widget _passport(TravelPassportPayload passport, Color ink) {
    if (passport.stamps.isEmpty) {
      return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(children: [
            Icon(Icons.explore_outlined,
                size: 38, color: ink.withValues(alpha: 0.35)),
            const SizedBox(height: 10),
            Text('Aquí empieza nuestro próximo rincón.',
                textAlign: TextAlign.center,
                style: RochyTypography.sansBody(ink.withValues(alpha: 0.7),
                    fontSize: 12)),
          ]));
    }
    return LayoutBuilder(builder: (context, constraints) {
      final columns = math.max(1, (constraints.maxWidth / 130).floor());
      final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('PASAPORTE DE NOSOTROS · ${passport.stamps.length} SELLOS',
            style: RochyTypography.metadata(ink.withValues(alpha: 0.6),
                fontSize: 9)),
        const SizedBox(height: 14),
        Wrap(spacing: 10, runSpacing: 16, children: [
          for (var i = 0; i < passport.stamps.length; i++)
            Transform.rotate(
                angle: i.isEven ? -0.045 : 0.04,
                child: SizedBox(
                    width: width, child: _stamp(passport.stamps[i], ink, i))),
        ]),
      ]);
    });
  }

  Widget _stamp(PassportStamp stamp, Color ink, int index) {
    final color = theme.nodeUsesLightInk(node)
        ? ink.withValues(alpha: 0.9)
        : [theme.sage, theme.terracotta, theme.brandAccent][index % 3];
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.65), width: 1.4),
        borderRadius: BorderRadius.circular(index.isEven ? 12 : 32),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.45)),
          borderRadius: BorderRadius.circular(index.isEven ? 8 : 28),
        ),
        child: Column(children: [
          Icon(passportIcons[stamp.iconKey]?.$2 ?? Icons.location_city_rounded,
              color: color, size: 23),
          const SizedBox(height: 4),
          Text(
              stamp.place.isEmpty
                  ? 'Tu lugar especial'
                  : stamp.place.toUpperCase(),
              textAlign: TextAlign.center,
              style: RochyTypography.resolveCardTitle(
                  BentoFontStyle.monoTypewriter, color,
                  fontSize: 11, fontWeight: FontWeight.w700)),
          const SizedBox(height: 5),
          Text(keepsakeDateLabel(stamp.visitedAt),
              style: RochyTypography.metadata(color, fontSize: 9)),
          const SizedBox(height: 3),
          Text('VISITADO JUNTOS',
              style: RochyTypography.metadata(color.withValues(alpha: 0.7),
                  fontSize: 7.5)),
        ]),
      ),
    );
  }

  Widget _chat(SavedChatPayload chat, Color ink, {bool isDetail = false}) {
    final accent = theme.nodeUsesLightInk(node)
        ? ink.withValues(alpha: 0.16)
        : theme.terracotta.withValues(alpha: 0.13);
    final leftBg = ink.withValues(alpha: 0.055);
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxBubbleWidth =
            constraints.maxWidth * (isDetail ? 0.84 : 0.86);
        return Column(
          children: [
            for (final message in chat.messages)
              Padding(
                padding: EdgeInsets.only(bottom: isDetail ? 9 : 6),
                child: Align(
                  alignment: message.isRight
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxBubbleWidth),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isDetail ? 12 : 9,
                        vertical: isDetail ? 8 : 5.5,
                      ),
                      decoration: BoxDecoration(
                        color: message.isRight ? accent : leftBg,
                        border: Border.all(
                          color: ink.withValues(
                            alpha: message.isRight ? 0.14 : 0.08,
                          ),
                        ),
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(13),
                          topRight: const Radius.circular(13),
                          bottomLeft:
                              Radius.circular(message.isRight ? 13 : 3),
                          bottomRight:
                              Radius.circular(message.isRight ? 3 : 13),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  message.sender.isEmpty
                                      ? 'Nombre'
                                      : message.sender,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: RochyTypography.sansTitle(
                                    ink.withValues(alpha: 0.68),
                                    fontSize: isDetail ? 10.5 : 9.2,
                                  ),
                                ),
                              ),
                              if (message.timeLabel.trim().isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Text(
                                  message.timeLabel,
                                  style: RochyTypography.metadata(
                                    ink.withValues(alpha: 0.48),
                                    fontSize: isDetail ? 9.5 : 8.2,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            message.text.isEmpty
                                ? 'Ese mensaje que vale guardar…'
                                : message.text,
                            style: RochyTypography.sansBody(
                              ink,
                              fontSize: isDetail ? 13.0 : 11.2,
                              height: 1.28,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _ticket(VintageTicketPayload ticket, Color ink) => Column(children: [
        Text(
            switch (ticket.kind) {
              'concert' => 'ENTRADA · CONCIERTO',
              'receipt' => 'RECIBO DE UN BUEN DÍA',
              _ => 'BOLETO · CINE',
            },
            textAlign: TextAlign.center,
            style: RochyTypography.resolveCardTitle(
                BentoFontStyle.monoTypewriter, ink,
                fontSize: 10, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Divider(color: ink.withValues(alpha: 0.3)),
        Text(keepsakeDateLabel(ticket.date),
            style: RochyTypography.metadata(ink, fontSize: 12)),
        const SizedBox(height: 10),
        Wrap(alignment: WrapAlignment.center, children: [
          for (var i = 0; i < 5; i++)
            Icon(
                i < ticket.rating
                    ? Icons.star_rounded
                    : Icons.star_outline_rounded,
                size: 17,
                color: ink.withValues(alpha: i < ticket.rating ? 0.9 : 0.3)),
        ]),
        const SizedBox(height: 10),
        if (ticket.note.isNotEmpty) ...[
          Text(ticket.note,
              textAlign: TextAlign.center,
              style: RochyTypography.sansBody(ink, fontSize: 12, height: 1.4)),
          const SizedBox(height: 12),
        ],
        SizedBox(
            height: 30,
            width: double.infinity,
            child: CustomPaint(
                painter: _SymbolicBarcodePainter(ticket.code, ink))),
        const SizedBox(height: 6),
        Text(ticket.code,
            textAlign: TextAlign.center,
            style: RochyTypography.resolveCardTitle(
                BentoFontStyle.monoTypewriter, ink,
                fontSize: 11)),
        const SizedBox(height: 5),
        Text('CÓDIGO SIMBÓLICO · RECUERDO REAL',
            textAlign: TextAlign.center,
            style: RochyTypography.metadata(ink.withValues(alpha: 0.55),
                fontSize: 8)),
      ]);
}

class _SymbolicBarcodePainter extends CustomPainter {
  const _SymbolicBarcodePainter(this.code, this.color);
  final String code;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final bars = code.runes.isEmpty ? [65] : code.runes.toList();
    final paint = Paint()..color = color.withValues(alpha: 0.8);
    final unit = size.width / 96;
    for (var i = 0; i < 48; i++) {
      if ((bars[i % bars.length] + i) % 3 != 0) {
        canvas.drawRect(
            Rect.fromLTWH(
                i * unit * 2, 0, unit * (i.isEven ? 1 : 1.5), size.height),
            paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SymbolicBarcodePainter oldDelegate) =>
      oldDelegate.code != code || oldDelegate.color != color;
}

class _TicketPaperClipper extends CustomClipper<Path> {
  const _TicketPaperClipper();

  @override
  Path getClip(Size size) {
    final path = Path()..moveTo(0, 0);
    for (var x = 0.0; x < size.width; x += 10) {
      path
        ..lineTo(math.min(x + 5, size.width), 4)
        ..lineTo(math.min(x + 10, size.width), 0);
    }
    path.lineTo(size.width, size.height / 2 - 6);
    path.arcToPoint(Offset(size.width, size.height / 2 + 6),
        radius: const Radius.circular(6), clockwise: false);
    path.lineTo(size.width, size.height);
    for (var x = size.width; x > 0; x -= 10) {
      path
        ..lineTo(math.max(x - 5, 0), size.height - 4)
        ..lineTo(math.max(x - 10, 0), size.height);
    }
    path.lineTo(0, size.height / 2 + 6);
    path.arcToPoint(Offset(0, size.height / 2 - 6),
        radius: const Radius.circular(6), clockwise: false);
    return path..close();
  }

  @override
  bool shouldReclip(covariant _TicketPaperClipper oldClipper) => false;
}
