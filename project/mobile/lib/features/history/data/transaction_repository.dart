import "package:dio/dio.dart";

import "../../../core/api_client.dart";

class TransactionRepository {
  Future<List<dynamic>> getTransactions({
    required String token,
    required String cardId,
    int limit = 20,
    int offset = 0,
  }) async {
    final response = await apiClient.get(
      "/cards/$cardId/transactions",
      queryParameters: {"limit": limit, "offset": offset},
      options: Options(headers: {"Authorization": "Bearer $token"}),
    );
    return response.data as List<dynamic>;
  }
}