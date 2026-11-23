import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/bento_node.dart';
import '../../providers/bento_canvas_provider.dart';
import '../../theme/rochy_theme.dart';
import 'bento_card_shell.dart';

/// Módulo de fecha especial con cálculo automático de días transcurridos o restantes.
class CountdownCardWidget extends ConsumerWidget {
  const CountdownCardWidget({
    super.key,
    required this.node,
    required this.payload,
    required this.theme,
    required this.relationHighlight,
    this.showPaperGrain = true,
  });

  final BentoNode node;
  final CountdownPayload payload;
  final RochyThemeData theme;
  final BentoRelationHighlight relationHighlight;
  final bool showPaperGrain;

  static const _months = <String>[
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(
      payload.targetDate.year,
      payload.targetDate.month,
      payload.targetDate.day,
    );

    final diffDays = payload.countMode == 'until'
        ? target.difference(today).inDays.clamp(0, 99999)
        : today.difference(target).inDays.abs();

    final dateFormatted =
        '${target.day} ${_months[(target.month - 1).clamp(0, 11)]} ${target.year}';

    final bgColor = theme.resolveNodeBackground(node);
    final primaryInk = theme.resolveNodePrimaryInk(node);
    final secondaryInk = theme.resolveNodeSecondaryInk(node);

    return BentoCardShell(
      theme: theme,
      node: node,
      backgroundColor: bgColor,
      relationHighlight: relationHighlight,
      showPaperGrain: showPaperGrain,
      padding: const EdgeInsets.all(15),
      onTap: () =>
          _openCountdownDialog(context, diffDays, dateFormatted, target, today),
      onLongPress: () =>
          ref.read(bentoCanvasProvider.notifier).toggleNodeFocus(node.id),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompactStrip = constraints.maxHeight < 118;
          if (isCompactStrip) {
            return Row(
              children: <Widget>[
                SizedBox(
                  width: constraints.maxWidth * 0.42,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '$diffDays d',
                      style: RochyTypography.cardSerifTitle(
                        primaryInk,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        payload.title,
                        maxLines: 2,
                        softWrap: true,
                        overflow: TextOverflow.ellipsis,
                        style: RochyTypography.resolveCardTitle(
                          node.fontStyle,
                          primaryInk,
                          fontSize: 14 * node.titleScale,
                        ),
                      ),
                      Text(
                        dateFormatted,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: RochyTypography.metadata(
                          secondaryInk,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    payload.countMode == 'until'
                        ? Icons.hourglass_top_rounded
                        : Icons.calendar_today_rounded,
                    size: 14,
                    color: secondaryInk,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      dateFormatted,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          RochyTypography.metadata(secondaryInk, fontSize: 11),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  '$diffDays días',
                  maxLines: 1,
                  style: RochyTypography.cardSerifTitle(
                    primaryInk,
                    fontSize: constraints.maxHeight > 210 ? 34 : 28,
                    fontWeight: FontWeight.w700,
                    height: 1.05,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                payload.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: RochyTypography.resolveCardTitle(
                  node.fontStyle,
                  primaryInk,
                  fontSize: 14.5 * node.titleScale,
                  fontWeight:
                      node.isTitleBold ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              if (payload.subtitle.isNotEmpty) ...<Widget>[
                const SizedBox(height: 2),
                Text(
                  payload.subtitle,
                  maxLines: 3,
                  softWrap: true,
                  overflow: TextOverflow.ellipsis,
                  style: RochyTypography.metadata(secondaryInk, fontSize: 11),
                ),
              ],
              const Spacer(),
            ],
          );
        },
      ),
    );
  }

  void _openCountdownDialog(
    BuildContext context,
    int diffDays,
    String dateFormatted,
    DateTime target,
    DateTime today,
  ) {
    HapticFeedback.lightImpact();
    final isUntil = payload.countMode == 'until';
    final weeks = diffDays ~/ 7;
    final remDaysAfterWeeks = diffDays % 7;

    // Desglose aproximado de años, meses y días calendario.
    final start = isUntil ? today : target;
    final end = isUntil ? target : today;
    var years = 0;
    var months = 0;
    var days = 0;
    if (!end.isBefore(start)) {
      years = end.year - start.year;
      months = end.month - start.month;
      days = end.day - start.day;
      if (days < 0) {
        final prevMonthDays = DateTime(end.year, end.month, 0).day;
        days += prevMonthDays;
        months -= 1;
      }
      if (months < 0) {
        months += 12;
        years -= 1;
      }
    }

    final breakdownParts = <String>[
      if (years > 0) '$years ${years == 1 ? 'año' : 'años'}',
      if (months > 0) '$months ${months == 1 ? 'mes' : 'meses'}',
      '$days ${days == 1 ? 'día' : 'días'}',
    ];

    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.ivorySurface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: theme.borderTint),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: theme.brandAccent.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isUntil
                          ? Icons.hourglass_top_rounded
                          : Icons.calendar_today_rounded,
                      size: 18,
                      color: theme.brandAccent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          isUntil ? 'Cuenta regresiva' : 'Fecha guardada',
                          style: RochyTypography.metadata(
                            theme.brandAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          dateFormatted,
                          style: RochyTypography.metadata(
                            theme.inkSecondary,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                isUntil ? 'Faltan $diffDays días' : 'Han pasado $diffDays días',
                style: RochyTypography.cardSerifTitle(
                  theme.inkPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                payload.title,
                style: RochyTypography.cardSerifTitle(
                  theme.brandAccent,
                  fontSize: 18,
                ),
              ),
              if (payload.subtitle.isNotEmpty) ...<Widget>[
                const SizedBox(height: 6),
                Text(
                  payload.subtitle,
                  style: RochyTypography.sansBody(
                    theme.inkSecondary,
                    fontSize: 13.5,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.sandSurface,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      breakdownParts.join(' · '),
                      style: RochyTypography.sansTitle(
                        theme.inkPrimary,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '≈ $weeks ${weeks == 1 ? 'semana' : 'semanas'} y $remDaysAfterWeeks ${remDaysAfterWeeks == 1 ? 'día' : 'días'}',
                      style: RochyTypography.metadata(
                        theme.inkSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(
                    'Cerrar',
                    style: RochyTypography.sansTitle(
                      theme.brandAccent,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
