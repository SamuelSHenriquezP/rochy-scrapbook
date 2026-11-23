import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:share_plus/share_plus.dart';
import '../../providers/bento_canvas_provider.dart';
import '../../services/rochy_backup_service.dart';
import '../../services/rochy_cloud_sync_service.dart';
import '../../services/rochy_google_drive_service.dart';
import '../../theme/rochy_theme.dart';

/// Hoja modal completa del Modo Pareja ("Solo Rochy y yo"):
/// - Identifica quién está usando este teléfono (`Sam` o `Rochy`)
/// - Conecta y sincroniza en vivo con Cloud Firestore + Firebase Storage (Blaze)
/// - Incluye respaldo/fusión manual por `.rochy.zip` o código rápido por WhatsApp.
Future<void> showCoupleSyncSheet(
  BuildContext context,
  WidgetRef ref,
) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => const _CoupleSyncSheetBody(),
  );
}

class _CoupleSyncSheetBody extends ConsumerStatefulWidget {
  const _CoupleSyncSheetBody();

  @override
  ConsumerState<_CoupleSyncSheetBody> createState() =>
      _CoupleSyncSheetBodyState();
}

class _CoupleSyncSheetBodyState extends ConsumerState<_CoupleSyncSheetBody> {
  bool _busyZipExport = false;
  bool _busyZipMerge = false;
  bool _busyDriveAuth = false;
  bool _busyDriveUpload = false;
  bool _busyDriveList = false;
  String? _busyDriveEntryId;
  GoogleSignInAccount? _driveAccount;
  List<DriveBackupEntry> _driveBackups = const <DriveBackupEntry>[];
  String? _driveError;

  @override
  void initState() {
    super.initState();
    Future.microtask(_restoreDriveSession);
  }

  Future<void> _restoreDriveSession() async {
    final drive = ref.read(rochyGoogleDriveServiceProvider);
    final acc = await drive.restorePreviousSession();
    if (!mounted) return;
    setState(() => _driveAccount = acc);
    if (acc != null) {
      await _refreshDriveBackups(silent: true);
    }
  }

  Future<void> _refreshDriveBackups({bool silent = false}) async {
    if (_busyDriveList) return;
    setState(() {
      _busyDriveList = true;
      if (!silent) _driveError = null;
    });
    try {
      final list = await ref.read(rochyGoogleDriveServiceProvider).listBackups();
      if (!mounted) return;
      setState(() {
        _driveBackups = list;
        _driveError = null;
      });
    } catch (e) {
      if (!mounted) return;
      if (!silent) {
        setState(() => _driveError = e.toString());
      }
    } finally {
      if (mounted) setState(() => _busyDriveList = false);
    }
  }

  Future<void> _connectDrive() async {
    if (_busyDriveAuth) return;
    HapticFeedback.lightImpact();
    setState(() {
      _busyDriveAuth = true;
      _driveError = null;
    });
    try {
      final drive = ref.read(rochyGoogleDriveServiceProvider);
      final acc = await drive.signIn();
      if (!mounted) return;
      setState(() => _driveAccount = acc);
      if (acc != null) {
        await _refreshDriveBackups();
        if (mounted) {
          _showSnack('Google Drive conectado (${acc.email}) ✓');
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _driveError = e.toString());
    } finally {
      if (mounted) setState(() => _busyDriveAuth = false);
    }
  }

  Future<void> _disconnectDrive() async {
    HapticFeedback.selectionClick();
    await ref.read(rochyGoogleDriveServiceProvider).signOut();
    if (!mounted) return;
    setState(() {
      _driveAccount = null;
      _driveBackups = const <DriveBackupEntry>[];
      _driveError = null;
    });
    _showSnack('Cuenta de Google Drive desconectada.');
  }

  Future<void> _uploadBackupToDrive() async {
    if (_busyDriveUpload) return;
    HapticFeedback.lightImpact();
    setState(() {
      _busyDriveUpload = true;
      _driveError = null;
    });
    try {
      final canvas = ref.read(bentoCanvasProvider);
      final backup = ref.read(rochyBackupServiceProvider);
      final drive = ref.read(rochyGoogleDriveServiceProvider);
      final result = await backup.createPortableBackup(
        notebooks: canvas.notebooks,
        activeNotebookId: canvas.activeNotebookId,
        showPaperGrain: canvas.showPaperGrain,
        textScaleFactor: canvas.textScaleFactor,
        partnerAAvatarUrl: canvas.partnerAAvatarUrl,
        partnerBAvatarUrl: canvas.partnerBAvatarUrl,
        partnerAName: canvas.partnerAName,
        partnerBName: canvas.partnerBName,
        deletedNodeIds: canvas.deletedNodeIds,
      );
      final uploaded = await drive.uploadBackupZip(result.file);
      if (!mounted) return;
      await _refreshDriveBackups(silent: true);
      if (!mounted) return;
      _showSnack(
        'Respaldo subido a Drive/Rochy Backups (${_formatBytes(uploaded.sizeBytes)}) ✓',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _driveError = e.toString());
    } finally {
      if (mounted) setState(() => _busyDriveUpload = false);
    }
  }

  Future<void> _restoreOrMergeDriveEntry(
    DriveBackupEntry entry, {
    required bool mergeOnly,
    required RochyThemeData theme,
  }) async {
    if (_busyDriveEntryId != null) return;
    if (!mergeOnly) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: theme.ivorySurface,
          title: Text(
            '¿Restaurar esta copia?',
            style: RochyTypography.cardSerifTitle(theme.inkPrimary, fontSize: 18),
          ),
          content: Text(
            'Reemplazará tus tarjetas actuales por "${entry.name}". Si quieres combinar sin borrar nada, usa "Fusionar".',
            style: RochyTypography.sansBody(theme.inkSecondary, fontSize: 12.5),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: theme.brandAccent,
                foregroundColor: const Color(0xFFFAF7F2),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Restaurar'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    HapticFeedback.lightImpact();
    setState(() {
      _busyDriveEntryId = entry.id;
      _driveError = null;
    });
    RochyParsedBackup? parsed;
    try {
      final drive = ref.read(rochyGoogleDriveServiceProvider);
      final backup = ref.read(rochyBackupServiceProvider);
      final zipFile = await drive.downloadBackupZip(entry);
      if (!mounted) return;
      parsed = await backup.parseBackupFile(zipFile);
      if (!mounted) return;
      final bundle = await backup.materializeBackupMedia(parsed);
      if (!mounted) return;

      final notifier = ref.read(bentoCanvasProvider.notifier);
      if (mergeOnly) {
        final merged = notifier.mergeCoupleNotebooks(bundle.notebooks);
        if (ref.read(bentoCanvasProvider).partnerAAvatarUrl.isEmpty &&
            bundle.partnerAAvatarUrl.isNotEmpty) {
          notifier.setPartnerAvatar(
            authorId: 'samuel',
            imagePath: bundle.partnerAAvatarUrl,
          );
        }
        if (ref.read(bentoCanvasProvider).partnerBAvatarUrl.isEmpty &&
            bundle.partnerBAvatarUrl.isNotEmpty) {
          notifier.setPartnerAvatar(
            authorId: 'rochy',
            imagePath: bundle.partnerBAvatarUrl,
          );
        }
        _showSnack(
          'Fusionado desde Drive: +${merged.addedNodes} nueva(s), ${merged.updatedNodes} act. y ${bundle.restoredMediaCount} archivos.',
        );
      } else {
        notifier.restorePortableBackup(
          notebooks: bundle.notebooks,
          activeNotebookId: bundle.activeNotebookId,
          showPaperGrain: bundle.showPaperGrain,
          textScaleFactor: bundle.textScaleFactor,
          mergeWithExisting: false,
          partnerAAvatarUrl: bundle.partnerAAvatarUrl,
          partnerBAvatarUrl: bundle.partnerBAvatarUrl,
          partnerAName: bundle.partnerAName,
          partnerBName: bundle.partnerBName,
          deletedNodeIds: bundle.deletedNodeIds,
        );
        _showSnack(
          'Copia de Google Drive restaurada (${bundle.restoredMediaCount} fotos/audios) ♥',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _driveError = e.toString());
    } finally {
      await parsed?.close();
      if (mounted) setState(() => _busyDriveEntryId = null);
    }
  }

  String _formatDriveDate(DateTime? dt) {
    if (dt == null) return 'Fecha desconocida';
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$d/$m/${dt.year} · $h:$min';
  }

  String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024).ceil()} KB';
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return 'Pendiente';
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return 'Hoy · $h:$m';
  }

  void _showSnack(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.clearSnackBars();
    messenger?.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _editCoupleNames(
    String currentA,
    String currentB,
    RochyThemeData theme,
  ) async {
    final ctrlA = TextEditingController(text: currentA);
    final ctrlB = TextEditingController(text: currentB);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: theme.ivorySurface,
        title: Text(
          'Nombres de la pareja',
          style: RochyTypography.cardSerifTitle(theme.inkPrimary, fontSize: 19),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: ctrlB,
              decoration: const InputDecoration(
                labelText: 'Ella',
                hintText: 'Rochy',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: ctrlA,
              decoration: const InputDecoration(
                labelText: 'Él',
                hintText: 'Sam',
              ),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: theme.brandAccent,
              foregroundColor: const Color(0xFFFAF7F2),
            ),
            onPressed: () {
              ref.read(bentoCanvasProvider.notifier).updateCoupleNames(
                    partnerAName: ctrlA.text,
                    partnerBName: ctrlB.text,
                  );
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    ctrlA.dispose();
    ctrlB.dispose();
  }

  Future<void> _openFirebaseConfigDialog(
    FirebaseCoupleConfig current,
    RochyThemeData theme,
  ) async {
    final pasteCtrl = TextEditingController();
    final projectCtrl = TextEditingController(text: current.projectId);
    final bucketCtrl = TextEditingController(text: current.storageBucket);
    final apiKeyCtrl = TextEditingController(text: current.apiKey);
    final roomCtrl = TextEditingController(
      text: current.coupleRoomId.isEmpty
          ? 'rochy-y-samuel'
          : current.coupleRoomId,
    );
    String? parseHint;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: theme.ivorySurface,
            title: Text(
              'Conectar Firebase (Blaze)',
              style: RochyTypography.cardSerifTitle(
                theme.inkPrimary,
                fontSize: 19,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Pega tu archivo google-services.json o firebaseConfig para autocompletar, o escribe los campos:',
                    style: RochyTypography.sansBody(
                      theme.inkSecondary,
                      fontSize: 12.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: pasteCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Pegar google-services.json o firebaseConfig',
                      hintText: '{ "project_info": ... } o apiKey: "..."',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (raw) {
                      final parsed = FirebaseCoupleConfig.tryParseFromRaw(
                        raw,
                        currentRoomId: roomCtrl.text.trim().isEmpty
                            ? 'rochy-y-samuel'
                            : roomCtrl.text.trim(),
                      );
                      setDialogState(() {
                        if (parsed != null) {
                          projectCtrl.text = parsed.projectId;
                          bucketCtrl.text = parsed.storageBucket;
                          apiKeyCtrl.text = parsed.apiKey;
                          parseHint = '✓ Credenciales detectadas';
                        } else {
                          parseHint = null;
                        }
                      });
                    },
                  ),
                  if (parseHint != null) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(
                      parseHint!,
                      style: RochyTypography.metadata(
                        theme.sage,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  TextField(
                    controller: projectCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Project ID',
                      hintText: 'ej. rochy-app-1234',
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: bucketCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Storage Bucket',
                      hintText: 'ej. rochy-app-1234.firebasestorage.app',
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: apiKeyCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Web / Android API Key',
                      hintText: 'AIzaSy…',
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: roomCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Código secreto de pareja (igual en ambos)',
                      hintText: 'rochy-y-samuel',
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.brandAccent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Tip Firebase Console: crea Firestore en modo test o permite la colección rochy_couples, y Storage en us-central1 / us-east1 para usar los 5 GB gratis de Blaze.',
                      style: RochyTypography.metadata(
                        theme.inkSecondary,
                        fontSize: 10.5,
                      ).copyWith(height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              if (current.isConfigured)
                TextButton(
                  onPressed: () {
                    ref.read(bentoCanvasProvider.notifier).disconnectCloud();
                    Navigator.of(dialogContext).pop();
                    _showSnack('Nube Firebase desconectada.');
                  },
                  child: Text(
                    'Desconectar',
                    style: TextStyle(color: theme.terracotta),
                  ),
                ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: theme.brandAccent,
                  foregroundColor: const Color(0xFFFAF7F2),
                ),
                onPressed: () {
                  var bucket = bucketCtrl.text.trim();
                  final pid = projectCtrl.text.trim();
                  if (bucket.isEmpty && pid.isNotEmpty) {
                    bucket = '$pid.firebasestorage.app';
                  }
                  final next = FirebaseCoupleConfig(
                    projectId: pid,
                    storageBucket: bucket,
                    apiKey: apiKeyCtrl.text.trim(),
                    coupleRoomId: roomCtrl.text.trim().isEmpty
                        ? 'rochy-y-samuel'
                        : roomCtrl.text.trim(),
                    autoSyncEnabled: current.autoSyncEnabled,
                  );
                  if (!next.isConfigured) {
                    _showSnack('Completa Project ID, Storage Bucket y API Key.');
                    return;
                  }
                  ref.read(bentoCanvasProvider.notifier).updateCloudConfig(next);
                  Navigator.of(dialogContext).pop();
                  _runManualFirebaseSync();
                },
                child: const Text('Conectar y sincronizar'),
              ),
            ],
          );
        },
      ),
    );
    pasteCtrl.dispose();
    projectCtrl.dispose();
    bucketCtrl.dispose();
    apiKeyCtrl.dispose();
    roomCtrl.dispose();
  }

  Future<void> _runManualFirebaseSync() async {
    HapticFeedback.lightImpact();
    try {
      final res = await ref
          .read(bentoCanvasProvider.notifier)
          .syncNowWithFirebase(silent: false);
      if (!mounted || res == null) return;
      _showSnack(
        'Nube al día: +${res.addedNodes} nueva(s), ${res.updatedNodes} act., ${res.uploadedMedia} subidas y ${res.downloadedMedia} descargadas.',
      );
    } catch (e) {
      _showSnack(e.toString());
    }
  }

  Future<void> _copyRoomCode(String roomCode) async {
    HapticFeedback.selectionClick();
    final upper = roomCode.trim().toUpperCase();
    await Clipboard.setData(ClipboardData(text: upper));
    if (!mounted) return;
    _showSnack('Código de sala copiado: $upper');
  }

  Future<void> _shareRoomInvite(BentoCanvasState canvas) async {
    HapticFeedback.lightImpact();
    final code = canvas.cloudConfig.coupleRoomId.trim().toUpperCase();
    final msg =
        '♥ Únete a nuestra sala en Rochy (${canvas.partnerBName} & ${canvas.partnerAName})\n\n'
        'Abre Rochy → Ajustes / Modo Pareja → "Unirme con código" y pega:\n'
        'Código: $code';
    await SharePlus.instance.share(
      ShareParams(
        text: msg,
        subject: 'Invitación a nuestra sala en Rochy',
      ),
    );
  }

  Future<void> _openCreateRoomDialog(
    BentoCanvasState canvas,
    RochyThemeData theme,
  ) async {
    final generated = RochyCloudSyncService.generateRoomCode(
      canvas.partnerAName,
      canvas.partnerBName,
    );
    final codeCtrl = TextEditingController(text: generated);
    var creating = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: theme.ivorySurface,
          title: Text(
            'Crear nueva sala de pareja',
            style: RochyTypography.cardSerifTitle(theme.inkPrimary, fontSize: 19),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Se creará una sala privada en la nube con este código para que invites a ${canvas.otherPartnerDisplayName}:',
                style: RochyTypography.sansBody(
                  theme.inkSecondary,
                  fontSize: 12.2,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: codeCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'Código de la sala',
                  border: const OutlineInputBorder(),
                  isDense: true,
                  suffixIcon: IconButton(
                    tooltip: 'Generar otro código',
                    icon: const Icon(Icons.casino_outlined, size: 18),
                    onPressed: () {
                      codeCtrl.text = RochyCloudSyncService.generateRoomCode(
                        canvas.partnerAName,
                        canvas.partnerBName,
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: creating ? null : () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: theme.terracotta,
                foregroundColor: const Color(0xFFFAF7F2),
              ),
              onPressed: creating
                  ? null
                  : () async {
                      final raw = codeCtrl.text.trim();
                      if (raw.isEmpty) return;
                      setDialogState(() => creating = true);
                      try {
                        await ref
                            .read(bentoCanvasProvider.notifier)
                            .createCoupleRoom(raw);
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                        }
                        if (mounted) {
                          final slug = RochyCloudSyncService.normalizeRoomCode(raw)
                              .toUpperCase();
                          _showSnack('Sala "$slug" creada y conectada ♥');
                        }
                      } catch (e) {
                        setDialogState(() => creating = false);
                        _showSnack(e.toString());
                      }
                    },
              child: Text(creating ? 'Creando…' : 'Crear y activar'),
            ),
          ],
        ),
      ),
    );
    codeCtrl.dispose();
  }

  Future<void> _openJoinRoomDialog(
    BentoCanvasState canvas,
    RochyThemeData theme,
  ) async {
    final clip = await Clipboard.getData('text/plain');
    final extractedClip =
        RochyCloudSyncService.extractRoomCode(clip?.text ?? '');
    if (!mounted) return;
    final codeCtrl = TextEditingController(
      text: extractedClip.isNotEmpty && extractedClip != 'rochy-y-samuel'
          ? extractedClip.toUpperCase()
          : '',
    );
    var joining = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: theme.ivorySurface,
          title: Text(
            'Unirme a una sala',
            style: RochyTypography.cardSerifTitle(theme.inkPrimary, fontSize: 19),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Pega el código o el mensaje de invitación que te envió ${canvas.otherPartnerDisplayName}:',
                style: RochyTypography.sansBody(
                  theme.inkSecondary,
                  fontSize: 12.2,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: codeCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Código de invitación',
                  hintText: 'Ej. ROCHY-SAM-4821',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: joining ? null : () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: theme.sage,
                foregroundColor: const Color(0xFFFAF7F2),
              ),
              onPressed: joining
                  ? null
                  : () async {
                      final raw = codeCtrl.text.trim();
                      if (raw.isEmpty) {
                        _showSnack('Escribe o pega el código de la sala.');
                        return;
                      }
                      setDialogState(() => joining = true);
                      try {
                        final res = await ref
                            .read(bentoCanvasProvider.notifier)
                            .joinCoupleRoom(raw);
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                        }
                        if (mounted) {
                          final added = res?.addedNodes ?? 0;
                          _showSnack(
                            '¡Conectado a la sala! (+$added recuerdo(s) sincronizados) ♥',
                          );
                        }
                      } catch (e) {
                        setDialogState(() => joining = false);
                        _showSnack(e.toString());
                      }
                    },
              child: Text(joining ? 'Conectando…' : 'Unirme ahora'),
            ),
          ],
        ),
      ),
    );
    codeCtrl.dispose();
  }

  Future<void> _sendCoupleZipPackage() async {
    if (_busyZipExport || _busyZipMerge) return;
    HapticFeedback.lightImpact();
    setState(() => _busyZipExport = true);
    try {
      final canvas = ref.read(bentoCanvasProvider);
      final backup = ref.read(rochyBackupServiceProvider);
      final result = await backup.createPortableBackup(
        notebooks: canvas.notebooks,
        activeNotebookId: canvas.activeNotebookId,
        showPaperGrain: canvas.showPaperGrain,
        textScaleFactor: canvas.textScaleFactor,
        partnerAAvatarUrl: canvas.partnerAAvatarUrl,
        partnerBAvatarUrl: canvas.partnerBAvatarUrl,
        partnerAName: canvas.partnerAName,
        partnerBName: canvas.partnerBName,
        deletedNodeIds: canvas.deletedNodeIds,
      );
      if (!mounted) return;
      await backup.shareBackupFile(result.file);
      _showSnack(
        'Paquete listo para enviar (${_formatBytes(result.sizeBytes)} · ${result.mediaCount} fotos/audios).',
      );
    } catch (_) {
      _showSnack('No se pudo preparar el paquete .rochy.zip.');
    } finally {
      if (mounted) setState(() => _busyZipExport = false);
    }
  }

  Future<void> _mergeCoupleZipPackage() async {
    if (_busyZipExport || _busyZipMerge) return;
    HapticFeedback.lightImpact();
    setState(() => _busyZipMerge = true);
    RochyParsedBackup? parsed;
    try {
      final backup = ref.read(rochyBackupServiceProvider);
      final picked = await backup.pickBackupFile();
      if (picked == null || !mounted) return;

      parsed = await backup.parseBackupPlatformFile(picked);
      if (!mounted) return;
      final bundle = await backup.materializeBackupMedia(parsed);
      if (!mounted) return;

      final notifier = ref.read(bentoCanvasProvider.notifier);
      final merged = notifier.mergeCoupleNotebooks(bundle.notebooks);
      if (ref.read(bentoCanvasProvider).partnerAAvatarUrl.isEmpty &&
          bundle.partnerAAvatarUrl.isNotEmpty) {
        notifier.setPartnerAvatar(
          authorId: 'samuel',
          imagePath: bundle.partnerAAvatarUrl,
        );
      }
      if (ref.read(bentoCanvasProvider).partnerBAvatarUrl.isEmpty &&
          bundle.partnerBAvatarUrl.isNotEmpty) {
        notifier.setPartnerAvatar(
          authorId: 'rochy',
          imagePath: bundle.partnerBAvatarUrl,
        );
      }
      _showSnack(
        'Sincronizado: +${merged.addedNodes} nuevo(s), ${merged.updatedNodes} actualizado(s) y ${bundle.restoredMediaCount} archivos multimedia.',
      );
    } catch (_) {
      _showSnack('No se pudo leer el archivo .rochy.zip recibido.');
    } finally {
      await parsed?.close();
      if (mounted) setState(() => _busyZipMerge = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canvas = ref.watch(bentoCanvasProvider);
    final theme = ref.watch(activeRochyThemeProvider);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final busyZip = _busyZipExport || _busyZipMerge;
    final cloud = canvas.cloudConfig;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.88,
      ),
      padding: EdgeInsets.fromLTRB(18, 10, 18, 20 + bottomInset),
      decoration: BoxDecoration(
        color: theme.canvasBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: theme.borderTint),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.inkSecondary.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Encabezado compacto: Sam y Rochy
            Row(
              children: <Widget>[
                Icon(
                  Icons.favorite_rounded,
                  color: theme.terracotta,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${canvas.partnerAName} y ${canvas.partnerBName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: RochyTypography.brandTitle(theme.brandAccent)
                        .copyWith(fontSize: 20),
                  ),
                ),
                IconButton(
                  tooltip: 'Editar nombres',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _editCoupleNames(
                    canvas.partnerAName,
                    canvas.partnerBName,
                    theme,
                  ),
                  icon: Icon(
                    Icons.edit_outlined,
                    size: 18,
                    color: theme.inkSecondary,
                  ),
                ),
                if (cloud.isConfigured)
                  IconButton(
                    tooltip: 'Ajustes de nube',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _openFirebaseConfigDialog(cloud, theme),
                    icon: Icon(
                      Icons.settings_outlined,
                      size: 18,
                      color: theme.inkSecondary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // 1. Sala compartida y sincronización en vivo
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.ivorySurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: theme.borderTint),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (cloud.isConfigured) ...<Widget>[
                    Row(
                      children: <Widget>[
                        Icon(
                          Icons.key_rounded,
                          size: 16,
                          color: theme.terracotta,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Código de sala',
                          style: RochyTypography.metadata(
                            theme.inkSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => _copyRoomCode(cloud.coupleRoomId),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Icon(
                                  Icons.copy_rounded,
                                  size: 13,
                                  color: theme.brandAccent,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Copiar',
                                  style: RochyTypography.metadata(
                                    theme.brandAccent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: theme.terracotta.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.terracotta.withValues(alpha: 0.22),
                        ),
                      ),
                      child: SelectableText(
                        cloud.coupleRoomId.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: RochyTypography.cardSerifTitle(
                          theme.inkPrimary,
                          fontSize: 16,
                        ).copyWith(letterSpacing: 0.6),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: theme.terracotta,
                              foregroundColor: const Color(0xFFFAF7F2),
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              visualDensity: VisualDensity.compact,
                              shape: const StadiumBorder(),
                            ),
                            onPressed: () => _shareRoomInvite(canvas),
                            icon: const Icon(Icons.share_rounded, size: 14),
                            label: const Text(
                              'Invitar',
                              style: TextStyle(fontSize: 12.5),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: theme.inkPrimary,
                              side: BorderSide(color: theme.borderTint),
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              visualDensity: VisualDensity.compact,
                              shape: const StadiumBorder(),
                            ),
                            onPressed: () =>
                                _openCreateRoomDialog(canvas, theme),
                            child: const Text(
                              'Nueva sala',
                              style: TextStyle(fontSize: 12.2),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: theme.espresso,
                              side: BorderSide(
                                color: theme.espresso.withValues(alpha: 0.4),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              visualDensity: VisualDensity.compact,
                              shape: const StadiumBorder(),
                            ),
                            onPressed: () => _openJoinRoomDialog(canvas, theme),
                            child: const Text(
                              'Unirme',
                              style: TextStyle(fontSize: 12.2),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    Row(
                      children: <Widget>[
                        Icon(
                          Icons.cloud_done_rounded,
                          size: 16,
                          color: theme.sage,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            canvas.isCloudSyncing
                                ? 'Sincronizando…'
                                : 'Al día · ${_formatTime(canvas.lastCloudSyncAt)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: RochyTypography.metadata(
                              theme.sage,
                              fontSize: 11.2,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        SizedBox(
                          height: 28,
                          child: Switch.adaptive(
                            activeTrackColor: theme.sage,
                            value: cloud.autoSyncEnabled,
                            onChanged: (v) {
                              HapticFeedback.selectionClick();
                              ref
                                  .read(bentoCanvasProvider.notifier)
                                  .updateCloudConfig(
                                    cloud.copyWith(autoSyncEnabled: v),
                                  );
                            },
                          ),
                        ),
                        const SizedBox(width: 4),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: theme.sage,
                            foregroundColor: const Color(0xFFFAF7F2),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            visualDensity: VisualDensity.compact,
                            shape: const StadiumBorder(),
                          ),
                          onPressed: canvas.isCloudSyncing
                              ? null
                              : _runManualFirebaseSync,
                          child: const Text(
                            'Sincronizar',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ] else ...<Widget>[
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: theme.brandAccent,
                          foregroundColor: const Color(0xFFFAF7F2),
                          shape: const StadiumBorder(),
                        ),
                        onPressed: () =>
                            _openFirebaseConfigDialog(cloud, theme),
                        icon: const Icon(Icons.bolt_rounded, size: 17),
                        label: const Text('Conectar nube'),
                      ),
                    ),
                  ],
                  if (canvas.lastCloudSyncError != null) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      canvas.lastCloudSyncError!,
                      style: RochyTypography.metadata(
                        theme.terracotta,
                        fontSize: 10.8,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 2. Respaldo .ZIP en Google Drive
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.ivorySurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: theme.borderTint),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(
                        Icons.add_to_drive_rounded,
                        size: 18,
                        color: _driveAccount != null
                            ? theme.sage
                            : theme.brandAccent,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Google Drive (.zip)',
                              style: RochyTypography.sansTitle(
                                theme.inkPrimary,
                                fontSize: 13.5,
                              ),
                            ),
                            if (_driveAccount != null)
                              Text(
                                _driveAccount!.email,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: RochyTypography.metadata(
                                  theme.sage,
                                  fontSize: 10.8,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (_driveAccount != null)
                        IconButton(
                          tooltip: 'Actualizar lista',
                          visualDensity: VisualDensity.compact,
                          onPressed: _busyDriveList
                              ? null
                              : () => _refreshDriveBackups(),
                          icon: Icon(
                            Icons.refresh_rounded,
                            size: 17,
                            color: theme.inkSecondary,
                          ),
                        ),
                      if (_driveAccount != null)
                        TextButton(
                          onPressed: _disconnectDrive,
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                          ),
                          child: Text(
                            'Salir',
                            style: RochyTypography.metadata(
                              theme.terracotta,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (_driveError != null) ...<Widget>[
                    const SizedBox(height: 6),
                    Text(
                      _driveError!,
                      style: RochyTypography.metadata(
                        theme.terracotta,
                        fontSize: 10.8,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  if (_driveAccount == null)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.espresso,
                          side: BorderSide(color: theme.borderTint),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: const StadiumBorder(),
                        ),
                        onPressed: _busyDriveAuth ? null : _connectDrive,
                        icon: _busyDriveAuth
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.login_rounded, size: 16),
                        label: Text(
                          _busyDriveAuth
                              ? 'Conectando…'
                              : 'Conectar Google Drive',
                        ),
                      ),
                    )
                  else ...<Widget>[
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: theme.brandAccent,
                          foregroundColor: const Color(0xFFFAF7F2),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: const StadiumBorder(),
                        ),
                        onPressed:
                            _busyDriveUpload ? null : _uploadBackupToDrive,
                        icon: _busyDriveUpload
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFFFAF7F2),
                                ),
                              )
                            : const Icon(Icons.backup_rounded, size: 16),
                        label: Text(
                          _busyDriveUpload
                              ? 'Subiendo .zip…'
                              : 'Subir copia .zip a Drive',
                        ),
                      ),
                    ),
                    if (_busyDriveList) ...<Widget>[
                      const SizedBox(height: 8),
                      const LinearProgressIndicator(minHeight: 2),
                    ] else if (_driveBackups.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 8),
                      ..._driveBackups.take(4).map((entry) {
                        final isBusyEntry = _busyDriveEntryId == entry.id;
                        return Container(
                          margin: const EdgeInsets.only(top: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: theme.canvasBackground.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: theme.borderTint),
                          ),
                          child: Row(
                            children: <Widget>[
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      entry.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: RochyTypography.sansTitle(
                                        theme.inkPrimary,
                                        fontSize: 11.5,
                                      ),
                                    ),
                                    Text(
                                      '${_formatDriveDate(entry.createdTime)} · ${_formatBytes(entry.sizeBytes)}',
                                      style: RochyTypography.metadata(
                                        theme.inkSecondary,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              TextButton(
                                style: TextButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                  ),
                                ),
                                onPressed: _busyDriveEntryId != null
                                    ? null
                                    : () => _restoreOrMergeDriveEntry(
                                          entry,
                                          mergeOnly: true,
                                          theme: theme,
                                        ),
                                child: const Text(
                                  'Fusionar',
                                  style: TextStyle(fontSize: 11.5),
                                ),
                              ),
                              FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: theme.sage,
                                  foregroundColor: const Color(0xFFFAF7F2),
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                  shape: const StadiumBorder(),
                                ),
                                onPressed: _busyDriveEntryId != null
                                    ? null
                                    : () => _restoreOrMergeDriveEntry(
                                          entry,
                                          mergeOnly: false,
                                          theme: theme,
                                        ),
                                child: Text(
                                  isBusyEntry ? '…' : 'Restaurar',
                                  style: const TextStyle(fontSize: 11.2),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),

            // 3. Archivo .zip local compacto
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.inkPrimary,
                      side: BorderSide(color: theme.borderTint),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: const StadiumBorder(),
                    ),
                    onPressed: busyZip ? null : _sendCoupleZipPackage,
                    icon: const Icon(Icons.upload_file_rounded, size: 16),
                    label: Text(
                      _busyZipExport ? 'Creando…' : 'Exportar .zip',
                      style: const TextStyle(fontSize: 12.2),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.inkPrimary,
                      side: BorderSide(color: theme.borderTint),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: const StadiumBorder(),
                    ),
                    onPressed: busyZip ? null : _mergeCoupleZipPackage,
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: Text(
                      _busyZipMerge ? 'Leyendo…' : 'Importar .zip',
                      style: const TextStyle(fontSize: 12.2),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
