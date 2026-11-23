import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/bento_node.dart';
import '../../providers/bento_canvas_provider.dart';
import '../../theme/rochy_theme.dart';
import '../editorial_image.dart';
import 'bento_card_shell.dart';

/// Tarjeta mini-álbum / carrete fotográfico que soporta modo collage (hasta 4 fotos)
/// o modo deslizable con visor ampliado al tocar.
class PhotoStripCardWidget extends ConsumerStatefulWidget {
  const PhotoStripCardWidget({
    super.key,
    required this.node,
    required this.payload,
    required this.theme,
    required this.relationHighlight,
    this.showPaperGrain = true,
  });

  final BentoNode node;
  final PhotoStripPayload payload;
  final RochyThemeData theme;
  final BentoRelationHighlight relationHighlight;
  final bool showPaperGrain;

  @override
  ConsumerState<PhotoStripCardWidget> createState() =>
      _PhotoStripCardWidgetState();
}

class _PhotoStripCardWidgetState extends ConsumerState<PhotoStripCardWidget> {
  final PageController _pageCtrl = PageController();
  int _pageIndex = 0;

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _openGalleryModal(List<String> images) {
    HapticFeedback.lightImpact();
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.88),
      builder: (dialogContext) => _PhotoStripModal(
        payload: widget.payload,
        images: images,
        initialIndex: _pageIndex,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.theme.resolveNodeBackground(widget.node);
    final primaryInk = widget.theme.resolveNodePrimaryInk(widget.node);
    final secondaryInk = widget.theme.resolveNodeSecondaryInk(widget.node);
    final images =
        widget.payload.imageUrls.where((u) => u.trim().isNotEmpty).take(4).toList();

    return BentoCardShell(
      theme: widget.theme,
      node: widget.node,
      backgroundColor: bgColor,
      relationHighlight: widget.relationHighlight,
      showPaperGrain: widget.showPaperGrain,
      padding: const EdgeInsets.all(11),
      onTap: images.isEmpty ? null : () => _openGalleryModal(images),
      onLongPress: () => ref
          .read(bentoCanvasProvider.notifier)
          .toggleNodeFocus(widget.node.id),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxHeight < 120;
          final isCarousel = widget.payload.layoutMode == 'carousel';

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (!compact || images.isEmpty) ...<Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        widget.payload.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: RochyTypography.toFlutterTextAlign(
                          widget.node.textAlign,
                        ),
                        style: RochyTypography.resolveCardTitle(
                          widget.node.fontStyle,
                          primaryInk,
                          fontSize: 15 * widget.node.titleScale,
                          fontWeight: widget.node.isTitleBold
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                    if (images.length > 1)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: primaryInk.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${images.length}',
                          style: RochyTypography.metadata(
                            primaryInk,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: images.isEmpty
                      ? Container(
                          color: primaryInk.withValues(alpha: 0.06),
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(
                                Icons.photo_library_outlined,
                                color: secondaryInk,
                                size: 24,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Añade fotos',
                                style: RochyTypography.metadata(
                                  secondaryInk,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        )
                      : isCarousel
                          ? Stack(
                              fit: StackFit.expand,
                              children: <Widget>[
                                PageView.builder(
                                  controller: _pageCtrl,
                                  itemCount: images.length,
                                  onPageChanged: (i) =>
                                      setState(() => _pageIndex = i),
                                  itemBuilder: (context, idx) => EditorialImage(
                                    imageUrl: images[idx],
                                    fallbackScene:
                                        EditorialFallbackScene.cafeSunlit,
                                  ),
                                ),
                                if (images.length > 1)
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    bottom: 7,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children:
                                          List<Widget>.generate(images.length,
                                              (i) {
                                        final active = i == _pageIndex;
                                        return AnimatedContainer(
                                          duration:
                                              const Duration(milliseconds: 200),
                                          width: active ? 14 : 6,
                                          height: 6,
                                          margin: const EdgeInsets.symmetric(
                                              horizontal: 2.5),
                                          decoration: BoxDecoration(
                                            color: active
                                                ? Colors.white
                                                : Colors.white
                                                    .withValues(alpha: 0.45),
                                            borderRadius:
                                                BorderRadius.circular(999),
                                          ),
                                        );
                                      }),
                                    ),
                                  ),
                              ],
                            )
                          : _PhotoCollageGrid(
                              images: images,
                              wide: constraints.maxWidth > 220,
                            ),
                ),
              ),
              if (!compact && widget.payload.caption.isNotEmpty) ...<Widget>[
                const SizedBox(height: 6),
                Text(
                  widget.payload.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: RochyTypography.metadata(secondaryInk, fontSize: 10.5),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _PhotoCollageGrid extends StatelessWidget {
  const _PhotoCollageGrid({
    required this.images,
    required this.wide,
  });

  final List<String> images;
  final bool wide;

  Widget _tile(String url) => ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: EditorialImage(
          imageUrl: url,
          fallbackScene: EditorialFallbackScene.cafeSunlit,
        ),
      );

  @override
  Widget build(BuildContext context) {
    const gap = 4.0;
    if (images.length == 1) {
      return _tile(images.first);
    }
    if (images.length == 2) {
      return wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(child: _tile(images[0])),
                const SizedBox(width: gap),
                Expanded(child: _tile(images[1])),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(child: _tile(images[0])),
                const SizedBox(height: gap),
                Expanded(child: _tile(images[1])),
              ],
            );
    }
    if (images.length == 3) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(child: _tile(images[0])),
          const SizedBox(width: gap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(child: _tile(images[1])),
                const SizedBox(height: gap),
                Expanded(child: _tile(images[2])),
              ],
            ),
          ),
        ],
      );
    }
    return Column(
      children: <Widget>[
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(child: _tile(images[0])),
              const SizedBox(width: gap),
              Expanded(child: _tile(images[1])),
            ],
          ),
        ),
        const SizedBox(height: gap),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(child: _tile(images[2])),
              const SizedBox(width: gap),
              Expanded(child: _tile(images[3])),
            ],
          ),
        ),
      ],
    );
  }
}

class _PhotoStripModal extends StatefulWidget {
  const _PhotoStripModal({
    required this.payload,
    required this.images,
    required this.initialIndex,
  });

  final PhotoStripPayload payload;
  final List<String> images;
  final int initialIndex;

  @override
  State<_PhotoStripModal> createState() => _PhotoStripModalState();
}

class _PhotoStripModalState extends State<_PhotoStripModal> {
  late final PageController _ctrl;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex.clamp(0, widget.images.length - 1);
    _ctrl = PageController(initialPage: _current);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1F1713),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AspectRatio(
              aspectRatio: 0.9,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  PageView.builder(
                    controller: _ctrl,
                    itemCount: widget.images.length,
                    onPageChanged: (i) => setState(() => _current = i),
                    itemBuilder: (context, i) => EditorialImage(
                      imageUrl: widget.images[i],
                      fallbackScene: EditorialFallbackScene.cafeSunlit,
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: IconButton.filled(
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black.withValues(alpha: 0.5),
                        foregroundColor: const Color(0xFFFAF7F2),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, size: 18),
                    ),
                  ),
                  Positioned(
                    top: 14,
                    left: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.52),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${_current + 1} / ${widget.images.length}',
                        style: RochyTypography.metadata(
                          const Color(0xFFFAF7F2),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    widget.payload.title,
                    style: RochyTypography.cardSerifTitle(
                      const Color(0xFFFAF7F2),
                      fontSize: 18,
                    ),
                  ),
                  if (widget.payload.caption.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(
                      widget.payload.caption,
                      style: RochyTypography.sansBody(
                        const Color(0xFFD8C8BE),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
