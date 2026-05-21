import "package:dio/dio.dart";

import "../../../core/api_client.dart";
import "../../../core/secure_storage.dart";

class AuthRepository {
  static const _tokenKey = "access_token";

  Future<String> login({
    required String email,
    required String password,
  }) async {
    final response = await apiClient.post(
      "/auth/login",
      data: {"email": email, "password": password},
    );
    final token = response.data["access_token"] as String;
    await saveToken(token);
    return token;
  }

  Future<String> register({
    required String email,
    required String password,
    required String fullName,
    String? phone,
  }) async {
    final response = await apiClient.post(
      "/auth/register",
      data: {
        "email": email,
        "password": password,
        "full_name": fullName,
        "phone": phone,
      },
    );
    final token = response.data["access_token"] as String;
    await saveToken(token);
    return token;
  }

  Future<void> saveToken(String token) async {
    await secureStorage.write(key: _tokenKey, value: token);
  }

  Future<String?> getToken() async {
    return secureStorage.read(key: _tokenKey);
  }

  Future<void> logout() async {
    await secureStorage.delete(key: _tokenKey);
  }

  Future<Map<String, dynamic>> me(String token) async {
    final response = await apiClient.get(
      "/auth/me",
      options: Options(headers: {"Authorization": "Bearer $token"}),
    );
    return response.data as Map<String, dynamic>;
  }
}