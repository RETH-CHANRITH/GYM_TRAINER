import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Professional API client with error handling, logging, and interceptors
class ApiClient {
  late final Dio _dio;
  final String baseUrl;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  ApiClient({
    required this.baseUrl,
    Duration connectTimeout = const Duration(seconds: 30),
    Duration receiveTimeout = const Duration(seconds: 30),
  }) {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: connectTimeout,
        receiveTimeout: receiveTimeout,
        contentType: Headers.jsonContentType,
      ),
    );

    // Add interceptors
    _dio.interceptors.add(_AuthInterceptor(_auth));
    _dio.interceptors.add(_LoggingInterceptor());
    _dio.interceptors.add(_ErrorInterceptor());
  }

  /// GET request
  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    T Function(dynamic json)? decoder,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        path,
        queryParameters: queryParameters,
      );
      return _handleResponse(response, decoder);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// POST request
  Future<T> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic json)? decoder,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        path,
        data: data,
        queryParameters: queryParameters,
      );
      return _handleResponse(response, decoder);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// PUT request
  Future<T> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic json)? decoder,
  }) async {
    try {
      final response = await _dio.put<dynamic>(
        path,
        data: data,
        queryParameters: queryParameters,
      );
      return _handleResponse(response, decoder);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// DELETE request
  Future<T> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic json)? decoder,
  }) async {
    try {
      final response = await _dio.delete<dynamic>(
        path,
        data: data,
        queryParameters: queryParameters,
      );
      return _handleResponse(response, decoder);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Handle response
  T _handleResponse<T>(
    Response<dynamic> response,
    T Function(dynamic)? decoder,
  ) {
    if (response.statusCode == null || response.statusCode! > 299) {
      throw ApiException(
        message: 'HTTP ${response.statusCode}: ${response.statusMessage}',
        statusCode: response.statusCode ?? 0,
      );
    }

    if (decoder != null) {
      return decoder(response.data);
    }

    return response.data as T;
  }

  /// Handle errors
  ApiException _handleError(DioException error) {
    String message = 'An error occurred';
    int? statusCode;

    if (error.response != null) {
      statusCode = error.response?.statusCode;
      final data = error.response?.data;

      if (data is Map<String, dynamic>) {
        message = data['error'] ?? data['message'] ?? message;
      } else {
        message = error.response?.statusMessage ?? message;
      }
    } else if (error.type == DioExceptionType.connectionTimeout) {
      message = 'Connection timeout. Please check your internet';
    } else if (error.type == DioExceptionType.receiveTimeout) {
      message = 'Request timeout. Please try again';
    } else if (error.type == DioExceptionType.unknown) {
      message = 'Network error. Please check your connection';
    }

    return ApiException(message: message, statusCode: statusCode);
  }

  void dispose() {
    _dio.close();
  }
}

/// Authentication interceptor
class _AuthInterceptor extends Interceptor {
  final FirebaseAuth _auth;

  _AuthInterceptor(this._auth);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final user = _auth.currentUser;
    if (user != null) {
      final token = await user.getIdToken();
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}

/// Logging interceptor
class _LoggingInterceptor extends Interceptor {
  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (kDebugMode) {
      debugPrint('📤 [API] ${options.method} ${options.uri}');
      if (options.data != null) {
        debugPrint('   Data: ${options.data}');
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onResponse(
    Response response,
    ResponseInterceptorHandler handler,
  ) async {
    if (kDebugMode) {
      debugPrint(
        '📥 [API] ${response.statusCode} ${response.requestOptions.uri}',
      );
    }
    handler.next(response);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (kDebugMode) {
      debugPrint('❌ [API] ${err.type}: ${err.message}');
    }
    handler.next(err);
  }
}

/// Error interceptor for handling global errors
class _ErrorInterceptor extends Interceptor {
  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // Handle 401 Unauthorized globally
    if (err.response?.statusCode == 401) {
      // Trigger logout
      debugPrint('🔐 Unauthorized access - redirecting to login');
    }
    handler.next(err);
  }
}

/// API Exception class
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException({required this.message, this.statusCode});

  @override
  String toString() => message;
}

final apiClientProvider = Provider<ApiClient>((ref) {
  // Production:
  return ApiClient(baseUrl: 'https://gym-trainer-backend-9lxr.onrender.com/api/v1');
});
