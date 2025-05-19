import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class GoogleHttpClient extends http.BaseClient {
  final String _accessToken;
  final http.Client _inner;

  GoogleHttpClient(this._accessToken) : _inner = http.Client();

  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Authorization'] = 'Bearer $_accessToken';
    return _inner.send(request);
  }
} 