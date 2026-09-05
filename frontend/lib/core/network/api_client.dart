// ignore_for_file: use_null_aware_elements

import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'api_exception.dart';
import 'auth_token_provider.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    config: ref.watch(appConfigProvider),
    tokenProvider: ref.watch(authTokenProvider),
  );
});

class ApiClient {
  ApiClient({
    required AppConfig config,
    required AuthTokenProvider tokenProvider,
    http.Client? httpClient,
    Duration timeout = const Duration(seconds: 12),
  }) : _config = config,
       _tokenProvider = tokenProvider,
       _httpClient = httpClient ?? http.Client(),
       _timeout = timeout;

  final AppConfig _config;
  final AuthTokenProvider _tokenProvider;
  final http.Client _httpClient;
  final Duration _timeout;

  Future<Object?> get(String path, {Map<String, String>? query}) {
    return _send('GET', path, query: query, retrySafe: true);
  }

  Future<Object?> post(
    String path, {
    Map<String, Object?>? body,
    String? idempotencyKey,
  }) {
    return _send('POST', path, body: body, idempotencyKey: idempotencyKey);
  }

  Future<Object?> patch(String path, {Map<String, Object?>? body}) {
    return _send('PATCH', path, body: body);
  }

  Future<Object?> delete(String path) {
    return _send('DELETE', path);
  }

  Future<Object?> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, Object?>? body,
    String? idempotencyKey,
    bool retrySafe = false,
  }) async {
    final uri = Uri.parse('${_config.apiBaseUrl}$path').replace(
      queryParameters: query?.isEmpty ?? true ? null : query,
    );
    Future<http.Response> once({bool useFreshToken = false}) async {
      final token = useFreshToken
          ? await _tokenProvider.forceRefresh()
          : await _tokenProvider.accessToken();
      final headers = <String, String>{
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
        if (idempotencyKey != null) 'Idempotency-Key': idempotencyKey,
      };
      final payload = body == null ? null : jsonEncode(body);
      return switch (method) {
        'GET' => _httpClient.get(uri, headers: headers).timeout(_timeout),
        'POST' => _httpClient
            .post(uri, headers: headers, body: payload)
            .timeout(_timeout),
        'PATCH' => _httpClient
            .patch(uri, headers: headers, body: payload)
            .timeout(_timeout),
        'DELETE' => _httpClient.delete(uri, headers: headers).timeout(_timeout),
        _ => throw StateError('Unsupported method $method'),
      };
    }

    try {
      var response = await once();
      // Retry on server errors (500+)
      if (retrySafe && response.statusCode >= 500) {
        response = await once();
      }
      // Retry on 401 with a fresh token (session may have expired)
      if (response.statusCode == 401) {
        final retried = await once(useFreshToken: true);
        if (retried.statusCode == 401) {
          // Even after refresh, still 401 — session is truly invalid
          return _decode(retried);
        }
        response = retried;
      }
      return _decode(response);
    } on TimeoutException catch (_) {
      throw const ApiException(code: 'TIMEOUT', message: 'Request timed out.');
    } on http.ClientException catch (_) {
      throw const ApiException(
        code: 'NETWORK_ERROR',
        message: 'Unable to reach VoltShare backend.',
      );
    } on FormatException catch (_) {
      throw const ApiException(
        code: 'MALFORMED_RESPONSE',
        message: 'VoltShare backend returned an unreadable response.',
      );
    }
  }

  Object? _decode(http.Response response) {
    final text = response.body;
    final decoded = text.isEmpty ? null : jsonDecode(text);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }
    if (decoded is Map && decoded['error'] is Map) {
      final error = decoded['error'] as Map;
      throw ApiException(
        code: error['code']?.toString() ?? 'API_ERROR',
        message: error['message']?.toString() ?? 'Request failed.',
        details: (error['details'] as Map?)?.cast<String, Object?>() ?? {},
        requestId: error['request_id']?.toString(),
        statusCode: response.statusCode,
      );
    }
    final mapped = _mappedHttpError(response.statusCode);
    if (mapped != null) {
      throw mapped;
    }
    throw ApiException(
      code: 'HTTP_${response.statusCode}',
      message: 'Request failed.',
      statusCode: response.statusCode,
    );
  }

  ApiException? _mappedHttpError(int statusCode) {
    return switch (statusCode) {
      401 => const ApiException(
        code: 'AUTH_REQUIRED',
        message: 'Your session has expired. Please sign in again.',
        statusCode: 401,
      ),
      403 => const ApiException(
        code: 'ACCESS_DENIED',
        message: 'You do not have permission to use this feature.',
        statusCode: 403,
      ),
      408 => const ApiException(
        code: 'TIMEOUT',
        message: 'The assistant took too long to respond. Please try again.',
        statusCode: 408,
      ),
      429 => const ApiException(
        code: 'RATE_LIMITED',
        message: 'AI request limit reached. Please try again later.',
        statusCode: 429,
      ),
      _ => null,
    };
  }
}
