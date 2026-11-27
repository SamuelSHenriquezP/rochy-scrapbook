import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../providers/bento_canvas_provider.dart';
import '../services/rochy_account_service.dart';
import '../services/rochy_cloud_sync_service.dart';
import '../services/rochy_secure_api.dart';
import 'bento_scrapbook_view.dart';

/// One-time device linking. Subsequent launches restore the same profile.
class RochyProfileGate extends ConsumerStatefulWidget {
  const RochyProfileGate({super.key});
  @override
  ConsumerState<RochyProfileGate> createState() => _RochyProfileGateState();
}

class _RochyProfileGateState extends ConsumerState<RochyProfileGate> {
  final _code = TextEditingController();
  String _selected = 'samuel';
  bool _busy = true, _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_restore);
  }

  Future<void> _restore() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final notifier = ref.read(bentoCanvasProvider.notifier);
      await notifier.whenHydrated;
      final account = ref.read(rochyAccountProvider);
      final config = ref.read(bentoCanvasProvider).cloudConfig;
      final api = RochySecureApi(
          config.isConfigured ? config : const FirebaseCoupleConfig(), account);
      String? profile;
      try {
        profile = await api.restoreBinding();
      } on http.ClientException {
        if (account.isLinked) {
          profile = account.authorId;
        } else {
          rethrow;
        }
      } on TimeoutException {
        if (account.isLinked) {
          profile = account.authorId;
        } else {
          rethrow;
        }
      }
      if (profile != null) {
        notifier.setViewerAuthor(profile);
        if (mounted) setState(() => _ready = true);
        notifier.syncNowWithFirebase(silent: true);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'No se pudo comprobar el dispositivo. Revisa tu conexión e inténtalo de nuevo.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _link() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final config = ref.read(bentoCanvasProvider).cloudConfig;
      await RochySecureApi(
              config.isConfigured ? config : const FirebaseCoupleConfig(),
              ref.read(rochyAccountProvider))
          .linkDevice(_selected, _code.text);
      final notifier = ref.read(bentoCanvasProvider.notifier);
      notifier.setViewerAuthor(_selected);
      _code.clear();
      if (mounted) setState(() => _ready = true);
      notifier.syncNowWithFirebase(silent: true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(rochyAccountProvider).isLinked) _ready = false;
    if (_ready) return const BentoScrapbookView();
    return Scaffold(
        body: SafeArea(
            child: Center(
                child: SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.favorite_rounded,
                size: 42, color: Color(0xFFA85338)),
            const SizedBox(height: 18),
            Text('Nuestro Rochy',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 10),
            const Text(
                'Elige tu perfil e introduce tu código de acceso. Este dispositivo quedará vinculado y se sincronizará automáticamente.',
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            SizedBox(
                width: 280,
                child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'samuel', label: Text('Sam')),
                      ButtonSegment(value: 'rochy', label: Text('Rochy')),
                    ],
                    selected: {
                      _selected
                    },
                    onSelectionChanged: _busy
                        ? null
                        : (values) =>
                            setState(() => _selected = values.single))),
            const SizedBox(height: 18),
            TextField(
                controller: _code,
                enabled: !_busy,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                    labelText: 'Código de acceso',
                    border: OutlineInputBorder()),
                onSubmitted: (_) {
                  if (!_busy) _link();
                }),
            const SizedBox(height: 16),
            if (_busy)
              const CircularProgressIndicator()
            else
              FilledButton(
                  onPressed: _link, child: const Text('Abrir mi cuaderno')),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(_error!, textAlign: TextAlign.center),
              TextButton(
                  onPressed: _busy ? null : _restore,
                  child: const Text('Reintentar')),
            ],
          ])),
    ))));
  }
}
