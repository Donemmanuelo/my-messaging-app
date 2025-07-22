import 'package:equatable/equatable.dart';
abstract class AuthEvent extends Equatable { const AuthEvent(); @override 
List<Object> get props => []; }
class AuthSendOtpRequested extends AuthEvent { final String phoneNumber; const 
AuthSendOtpRequested(this.phoneNumber); @override List<Object> get props => 
[phoneNumber]; }
class AuthVerifyOtpRequested extends AuthEvent { final String phoneNumber, otp; 
const AuthVerifyOtpRequested({required this.phoneNumber, required this.otp}); 
@override List<Object> get props => [phoneNumber, otp]; }
