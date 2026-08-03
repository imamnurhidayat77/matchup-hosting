import 'package:dio/dio.dart';
import '../config/env.dart';

/// Singleton Dio client. Real auth header injection will be wired in MVP.
class ApiClient {
  ApiClient._()
      : _dio = Dio(
          BaseOptions(
            baseUrl: Env.apiBaseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 10),
            headers: {'Content-Type': 'application/json'},
          ),
        );

  static final ApiClient instance = ApiClient._();

  final Dio _dio;
  Dio get dio => _dio;
}