import "package:dio/dio.dart";

import "../../../core/api_client.dart";

class CardRepository {
  Future<Map<String, dynamic>> getMyCard(String token) async {
    final response = await apiClient.get(
      "/cards/my",
      options: Options(headers: {"Authorization": "Bearer $token"}),
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createCard(String token) async {
    final response = await apiClient.post(
      "/cards/create",
      options: Options(headers: {"Authorization": "Bearer $token"}),
    );
    return response.data as Map<String, dynamic>;
  }
}