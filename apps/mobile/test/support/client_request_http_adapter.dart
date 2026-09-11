import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

Map<String, Object?> requestDetailsJson(Map<String, Object?> payload) => {
  'id': 'd5784cb8-6bf8-493a-9036-151ca0d75c5d',
  'reference': 'WEY-TEST',
  'origin': 'MOBILE_APP',
  'status': 'PENDING',
  'locationLabel': 'Selected service location',
  'clientName': 'Amina Test',
  'createdAt': '2026-09-11T00:00:00Z',
  'updatedAt': '2026-09-11T00:00:00Z',
  'locationKind': payload['locationKind'],
  'location': payload['location'],
  'toiletType': payload['toiletType'],
  'scheduleMode': payload['scheduleMode'],
};

/// Captures actual Dio-transformed wire bytes without a network or credentials.
class ClientRequestHttpAdapter implements HttpClientAdapter {
  final payloads = <Map<String, Object?>>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final bytes = await requestStream!.expand((chunk) => chunk).toList();
    final payload = (jsonDecode(utf8.decode(bytes)) as Map)
        .cast<String, Object?>();
    payloads.add(payload);
    if (options.method != 'POST' || options.path != '/v1/client/requests') {
      throw StateError('Unexpected test endpoint');
    }
    return ResponseBody.fromString(
      jsonEncode(requestDetailsJson(payload)),
      201,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
