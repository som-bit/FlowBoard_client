import 'package:dio/dio.dart'; // Add this import
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/network/api_client.dart';
import '../domain/user_model.dart';

class AuthRepository {
  final ApiClient _apiClient;
  final FlutterSecureStorage _secureStorage;
  
  static const String _tokenKey = 'jwt_token';

  AuthRepository(this._apiClient, this._secureStorage);

  // --- Register ---
  Future<User> register(String name, String email, String password) async {
    try {
      final response = await _apiClient.register({
        'name': name,
        'email': email,
        'password': password,
      });

      final data = response.data;
      await _secureStorage.write(key: _tokenKey, value: data['token']);
      return User.fromJson(data['user']);
      
    } on DioException catch (e) {
      // Extract the backend error message if available
      if (e.response != null && e.response?.data != null) {
        final serverError = e.response!.data['error'] ?? 'Registration failed';
        throw Exception(serverError);
      }
      // Fallback for network timeouts or lack of connectivity
      throw Exception(e.message ?? 'A network error occurred');
    }
  }

  // --- Login ---
  Future<User> login(String email, String password) async {
    try {
      final response = await _apiClient.login({
        'email': email,
        'password': password,
      });

      final data = response.data;
      await _secureStorage.write(key: _tokenKey, value: data['token']);
      return User.fromJson(data['user']);
      
    } on DioException catch (e) {
      if (e.response != null && e.response?.data != null) {
        final serverError = e.response!.data['error'] ?? 'Login failed';
        throw Exception(serverError);
      }
      throw Exception(e.message ?? 'A network error occurred');
    }
  }

  // --- Auto-Login Check ---
  Future<String?> getToken() async {
    return await _secureStorage.read(key: _tokenKey);
  }

  // --- Logout ---
  Future<void> logout() async {
    await _secureStorage.delete(key: _tokenKey);
  }
}