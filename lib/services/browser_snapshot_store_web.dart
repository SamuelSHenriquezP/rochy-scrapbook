// IndexedDB keeps pending uploads out of localStorage's small quota.
import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

Future<JSAny?> _result(web.IDBRequest request) {
  final completer = Completer<JSAny?>();
  request.addEventListener(
      'success',
      ((web.Event _) {
        completer.complete(request.result);
      }).toJS);
  request.addEventListener(
      'error',
      ((web.Event _) {
        completer.completeError(
            StateError(request.error?.message ?? 'IndexedDB request failed'));
      }).toJS);
  return completer.future;
}

Future<web.IDBDatabase> _openStore() async {
  final request = web.window.indexedDB.open('rochy_local_media_v1', 1);
  request.addEventListener(
      'upgradeneeded',
      ((web.Event _) {
        (request.result as web.IDBDatabase).createObjectStore('snapshots');
      }).toJS);
  return (await _result(request)) as web.IDBDatabase;
}

Future<void> _finished(web.IDBTransaction transaction) {
  final completer = Completer<void>();
  transaction.addEventListener(
      'complete',
      ((web.Event _) {
        if (!completer.isCompleted) completer.complete();
      }).toJS);
  void fail(web.Event _) {
    if (!completer.isCompleted) {
      completer.completeError(StateError(
          transaction.error?.message ?? 'IndexedDB transaction failed'));
    }
  }

  transaction.addEventListener('error', fail.toJS);
  transaction.addEventListener('abort', fail.toJS);
  return completer.future;
}

Future<String?> readBrowserSnapshot(String key) async {
  final db = await _openStore();
  try {
    final transaction = db.transaction('snapshots'.toJS, 'readonly');
    final finished = _finished(transaction);
    final result =
        await _result(transaction.objectStore('snapshots').get(key.toJS));
    await finished;
    return (result as JSString?)?.toDart;
  } finally {
    db.close();
  }
}

Future<void> writeBrowserSnapshot(String key, String value) async {
  final db = await _openStore();
  try {
    final transaction = db.transaction('snapshots'.toJS, 'readwrite');
    final finished = _finished(transaction);
    transaction.objectStore('snapshots').put(value.toJS, key.toJS);
    await finished;
  } finally {
    db.close();
  }
}
