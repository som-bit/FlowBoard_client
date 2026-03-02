import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiClient {
  late final Dio dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  ApiClient() {
    dio = Dio(
      BaseOptions(
        // Ensure this matches your Node.js server address.
        // 10.0.2.2 is for Android Emulator. Use 127.0.0.1 for iOS Simulator.
        baseUrl: 'http://10.0.2.2:3000/api',
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // 1. Add the LogInterceptor for comprehensive console output
    dio.interceptors.add(
      LogInterceptor(
        request: true,
        requestHeader: true,
        requestBody: true,
        responseHeader: true,
        responseBody: true,
        error: true,
      ),
    );

    // 2. JWT Injection Interceptor
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // You will inject the secure storage token here later
          final token = await _storage.read(key: 'jwt_token');

          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
      ),
    );
  }

  Future<Response> register(Map<String, dynamic> data) async {
    return await dio.post('/auth/register', data: data);
  }

  Future<Response> login(Map<String, dynamic> data) async {
    return await dio.post('/auth/login', data: data);
  }
}
