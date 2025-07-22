import 'package:dio/dio.dart';
class AuthApiClient {
  final Dio _dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:3000/api'));
  Future<void> sendOtp(String phoneNumber) async {
    await _dio.post('/auth/send-otp', data: {'phone_number': phoneNumber});
  }
  Future<Map<String, dynamic>> verifyOtp(String phoneNumber, String otp) async {
    final response = await _dio.post('/auth/verify-otp', data: {'phone_number': 
phoneNumber, 'otp': otp});
    return response.data;
  }
}
