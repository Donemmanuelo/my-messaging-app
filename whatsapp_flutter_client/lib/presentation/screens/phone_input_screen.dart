import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:whatsapp_flutter_client/main.dart';
import 'package:whatsapp_flutter_client/presentation/bloc/auth_bloc/auth_bloc.dart';
import 'package:whatsapp_flutter_client/presentation/bloc/auth_bloc/auth_event.dart';
import 'package:whatsapp_flutter_client/presentation/bloc/auth_bloc/auth_state.dart';
import 'package:whatsapp_flutter_client/presentation/screens/otp_verification_screen.dart';

class PhoneInputScreen extends StatefulWidget {
  const PhoneInputScreen({super.key});
  @override
  State<PhoneInputScreen> createState() => _PhoneInputScreenState();
}

class _PhoneInputScreenState extends State<PhoneInputScreen> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Enter Phone Number')),
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
            if (state is AuthOtpSentSuccess) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => BlocProvider.value(
                    value: context.read<AuthBloc>(),
                    child: OtpVerificationScreen(phoneNumber: _controller.text),
                  ),
                ),
              );
            }
            if (state is AuthFailure) {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text(state.error)));
            }
        },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextFormField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.phone,
                    validator: (v) => v == null || v.isEmpty ? 'Please enter a phone number' : null,
                  ),
          const SizedBox(height: 20),
                  BlocBuilder<AuthBloc, AuthState>(
                    builder: (context, state) => state is AuthLoading
                        ? const CircularProgressIndicator()
                        : ElevatedButton(
                            onPressed: () {
                              if (_formKey.currentState!.validate()) {
                                context.read<AuthBloc>().add(AuthSendOtpRequested(_controller.text));
                              }
                            },
                            child: const Text('Send OTP'),
                          ),
                  ),
                ],
              ),
            ),
          ),
      ),
    );
}
