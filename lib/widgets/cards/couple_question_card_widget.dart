import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/bento_node.dart';
import '../../providers/bento_canvas_provider.dart';
import '../../theme/rochy_theme.dart';
import '../editorial_image.dart';
import 'bento_card_shell.dart';

/// Tarjeta editorial "Pregunta para los dos":
/// diseño romántico con medallones de ambos y revelación mutua cuando los dos responden.
class CoupleQuestionCardWidget extends ConsumerWidget {
  const CoupleQuestionCardWidget({
    super.key,
    required this.node,
    required this.payload,
    required this.theme,
    required this.relationHighlight,
    this.showPaperGrain = true,
  });

  final BentoNode node;
  final CoupleQuestionPayload payload;
  final RochyThemeData theme;
  final BentoRelationHighlight relationHighlight;
  final bool showPaperGrain;

  Future<void> _openAnswerDialog(
    BuildContext context,
    WidgetRef ref,
    BentoCanvasState canvas,
  ) async {
    final isRochy = canvas.viewerAuthor == 'rochy';
    final initial = isRochy ? payload.answerRochy : payload.answerSamuel;
    final ctrl = TextEditingController(text: initial);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: theme.ivorySurface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: theme.borderTint),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.terracotta.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    payload.bothAnswered
                        ? 'REVELADO ENTRE LOS DOS ♥'
                        : 'PREGUNTA PARA LOS DOS',
                    style: RochyTypography.metadata(
                      theme.terracotta,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ).copyWith(letterSpacing: 0.6),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  payload.question.trim().isNotEmpty
                      ? payload.question.trim()
                      : 'Pregunta para los dos',
                  style: RochyTypography.cardSerifTitle(
                    theme.inkPrimary,
                    fontSize: 20,
                  ).copyWith(height: 1.25),
                ),
                const SizedBox(height: 14),
                Text(
                  'Tu respuesta (${canvas.viewerDisplayName})',
                  style: RochyTypography.metadata(
                    theme.brandAccent,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: ctrl,
                  maxLines: 4,
                  autofocus: true,
                  style: RochyTypography.sansBody(
                    theme.inkPrimary,
                    fontSize: 13.5,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Escribe lo que sientes o piensas…',
                    filled: true,
                    fillColor: theme.canvasBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: theme.borderTint),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: theme.borderTint),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  payload.bothAnswered
                      ? 'Ambos respondieron: sus respuestas están abiertas.'
                      : 'La respuesta de ${canvas.otherPartnerDisplayName} se abrirá automáticamente cuando ambos respondan.',
                  style: RochyTypography.metadata(
                    theme.inkSecondary,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text('Cerrar'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.brandAccent,
                        foregroundColor: const Color(0xFFFAF7F2),
                        shape: const StadiumBorder(),
                      ),
                      onPressed: () {
                        ref
                            .read(bentoCanvasProvider.notifier)
                            .saveCoupleQuestionAnswer(node.id, ctrl.text);
                        Navigator.of(dialogContext).pop();
                      },
                      child: const Text('Guardar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    ctrl.dispose();
  }

  Widget _avatarDot({
    required String name,
    required String avatarUrl,
    required Color accent,
  }) {
    final initial = name.trim().isNotEmpty
        ? name.trim().substring(0, 1).toUpperCase()
        : '?';
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.16),
        shape: BoxShape.circle,
        border: Border.all(color: accent.withValues(alpha: 0.4), width: 1),
      ),
      child: avatarUrl.trim().isNotEmpty
          ? ClipOval(
              child: SizedBox.expand(
                child: EditorialImage(
                  imageUrl: avatarUrl,
                  fallbackScene: EditorialFallbackScene.handsSunday,
                  fit: BoxFit.cover,
                ),
              ),
            )
          : Center(
              child: Text(
                initial,
                style: RochyTypography.cardSerifTitle(accent, fontSize: 11),
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canvas = ref.watch(bentoCanvasProvider);
    final bgColor = theme.resolveNodeBackground(node);
    final primaryInk = theme.resolveNodePrimaryInk(node);
    final secondaryInk = theme.resolveNodeSecondaryInk(node);
    final usesLight = theme.nodeUsesLightInk(node);
    final accent = usesLight ? const Color(0xFFF3C69F) : theme.terracotta;
    final accentB = usesLight ? const Color(0xFFD8E4D4) : theme.espresso;

    final isRochy = canvas.viewerAuthor == 'rochy';
    final bothAnswered = payload.bothAnswered;
    final myAnswer = isRochy ? payload.answerRochy : payload.answerSamuel;
    final hasMyAnswer = myAnswer.trim().isNotEmpty;

    Widget buildAnswerPane({
      required String name,
      required String avatarUrl,
      required String rawAnswer,
      required bool isMine,
      required Color paneAccent,
      required bool sideBySide,
    }) {
      final hasAnswer = rawAnswer.trim().isNotEmpty;
      final bool isSealed = !isMine && !bothAnswered;

      return Container(
        padding: EdgeInsets.fromLTRB(
          10,
          sideBySide ? 10 : 8,
          10,
          sideBySide ? 10 : 8,
        ),
        decoration: BoxDecoration(
          color: isSealed
              ? primaryInk.withValues(alpha: 0.045)
              : paneAccent.withValues(alpha: usesLight ? 0.16 : 0.085),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSealed
                ? primaryInk.withValues(alpha: 0.12)
                : paneAccent.withValues(alpha: usesLight ? 0.34 : 0.24),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                _avatarDot(
                  name: name,
                  avatarUrl: avatarUrl,
                  accent: paneAccent,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: RochyTypography.sansTitle(
                      paneAccent,
                      fontSize: 11,
                    ),
                  ),
                ),
                if (isSealed)
                  Icon(
                    hasAnswer
                        ? Icons.lock_rounded
                        : Icons.hourglass_bottom_rounded,
                    size: 13,
                    color: secondaryInk.withValues(alpha: 0.65),
                  )
                else if (hasAnswer)
                  Icon(
                    Icons.favorite_rounded,
                    size: 12,
                    color: paneAccent.withValues(alpha: 0.8),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            if (isSealed)
              Text(
                hasAnswer
                    ? 'Respuesta sellada.\nEscribe la tuya para abrirla.'
                    : 'Aún no ha respondido.',
                maxLines: sideBySide ? 3 : 2,
                overflow: TextOverflow.ellipsis,
                style: RochyTypography.sansBody(
                  secondaryInk.withValues(alpha: 0.8),
                  fontSize: 11.2,
                  height: 1.32,
                ).copyWith(fontStyle: FontStyle.italic),
              )
            else if (hasAnswer)
              Text(
                '“${rawAnswer.trim()}”',
                maxLines: sideBySide ? 4 : 2,
                overflow: TextOverflow.ellipsis,
                style: RochyTypography.cardSerifTitle(
                  primaryInk,
                  fontSize: 12.6,
                ).copyWith(
                  fontWeight: FontWeight.w500,
                  fontStyle: FontStyle.italic,
                  height: 1.32,
                ),
              )
            else
              Text(
                'Toca aquí para escribir tu respuesta…',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: RochyTypography.sansBody(
                  secondaryInk.withValues(alpha: 0.78),
                  fontSize: 11.2,
                  height: 1.3,
                ),
              ),
          ],
        ),
      );
    }

    return BentoCardShell(
      theme: theme,
      node: node,
      backgroundColor: bgColor,
      relationHighlight: relationHighlight,
      showPaperGrain: showPaperGrain,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
      onTap: () {
        HapticFeedback.selectionClick();
        _openAnswerDialog(context, ref, canvas);
      },
      onLongPress: () =>
          ref.read(bentoCanvasProvider.notifier).toggleNodeFocus(node.id),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxHeight < 135;
          final sideBySide = constraints.maxWidth >= 235 && !isCompact;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: usesLight ? 0.2 : 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          bothAnswered
                              ? Icons.favorite_rounded
                              : Icons.forum_outlined,
                          size: 11,
                          color: accent,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          bothAnswered
                              ? 'REVELADO'
                              : (constraints.maxWidth < 160
                                  ? 'PREGUNTA'
                                  : 'PREGUNTA PARA LOS DOS'),
                          style: RochyTypography.metadata(
                            accent,
                            fontSize: 9.2,
                            fontWeight: FontWeight.w700,
                          ).copyWith(letterSpacing: 0.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              Text(
                payload.question.trim().isNotEmpty
                    ? payload.question.trim()
                    : '¿Qué pregunta quieren hacerse hoy?',
                maxLines: isCompact ? 2 : 3,
                overflow: TextOverflow.ellipsis,
                style: RochyTypography.resolveCardTitle(
                  node.fontStyle,
                  primaryInk,
                  fontSize: (isCompact ? 13.8 : 15.8) * node.titleScale,
                  fontWeight:
                      node.isTitleBold ? FontWeight.w700 : FontWeight.w500,
                ).copyWith(height: 1.2),
              ),
              if (!isCompact) ...<Widget>[
                const SizedBox(height: 10),
                Expanded(
                  child: SingleChildScrollView(
                    primary: false,
                    child: sideBySide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Expanded(
                                child: buildAnswerPane(
                                  name: canvas.partnerBName,
                                  avatarUrl: canvas.partnerBAvatarUrl,
                                  rawAnswer: payload.answerRochy,
                                  isMine: isRochy,
                                  paneAccent: accent,
                                  sideBySide: true,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: buildAnswerPane(
                                  name: canvas.partnerAName,
                                  avatarUrl: canvas.partnerAAvatarUrl,
                                  rawAnswer: payload.answerSamuel,
                                  isMine: !isRochy,
                                  paneAccent: accentB,
                                  sideBySide: true,
                                ),
                              ),
                            ],
                          )
                        : Column(
                            children: <Widget>[
                              buildAnswerPane(
                                name: canvas.partnerBName,
                                avatarUrl: canvas.partnerBAvatarUrl,
                                rawAnswer: payload.answerRochy,
                                isMine: isRochy,
                                paneAccent: accent,
                                sideBySide: false,
                              ),
                              const SizedBox(height: 7),
                              buildAnswerPane(
                                name: canvas.partnerAName,
                                avatarUrl: canvas.partnerAAvatarUrl,
                                rawAnswer: payload.answerSamuel,
                                isMine: !isRochy,
                                paneAccent: accentB,
                                sideBySide: false,
                              ),
                            ],
                          ),
                  ),
                ),
                if (!hasMyAnswer) ...<Widget>[
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'Toca para responder →',
                      style: RochyTypography.metadata(
                        accent,
                        fontSize: 10.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}
