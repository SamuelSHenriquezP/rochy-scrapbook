import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

String createMediaObjectUrl(Uint8List bytes, String mime) =>
    web.URL.createObjectURL(
        web.Blob(<JSAny>[bytes.toJS].toJS, web.BlobPropertyBag(type: mime)));
void revokeMediaObjectUrl(String url) => web.URL.revokeObjectURL(url);
