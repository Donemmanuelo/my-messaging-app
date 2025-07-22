import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:whatsapp_flutter_client/data/datasources/auth_api_client.dart';
class AuthRepository {
  final AuthApiClient _apiClient;
  final _storage = const FlutterSecureStorage();
  AuthRepository({required AuthApiClient apiClient}) : _apiClient = apiClient;
  Future<void> sendOtp(String phoneNumber) => _apiClient.sendOtp(phoneNumber);
  Future<void> verifyOtp(String phoneNumber, String otp) async {
    final data = await _apiClient.verifyOtp(phoneNumber, otp);
    await _storage.write(key: 'jwt_token', value: data['token']);
    await _storage.write(key: 'user_id', value: data['user_id']);
  }
  Future<String?> getToken() => _storage.read(key: 'jwt_token');
}
