import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:whatsapp_flutter_client/data/repositories/auth_repository.dart';
import 
'package:whatsapp_flutter_client/presentation/bloc/auth_bloc/auth_event.dart';
import 
'package:whatsapp_flutter_client/presentation/bloc/auth_bloc/auth_state.dart';
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _repo;
  AuthBloc({required AuthRepository authRepository}) : _repo = authRepository, 
super(AuthInitial()) {
    on<AuthSendOtpRequested>((e, emit) async {
      emit(AuthLoading());
      try { await _repo.sendOtp(e.phoneNumber); emit(AuthOtpSentSuccess()); } 
catch (err) { emit(AuthFailure(err.toString())); }
    });
    on<AuthVerifyOtpRequested>((e, emit) async {
      emit(AuthLoading());
      try { await _repo.verifyOtp(e.phoneNumber, e.otp); emit(AuthSuccess()); } 
catch (err) { emit(AuthFailure(err.toString())); }
    });
  }
}
