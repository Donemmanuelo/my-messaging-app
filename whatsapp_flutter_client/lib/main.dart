import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:whatsapp_flutter_client/core/services/service_locator.dart';
import 'package:whatsapp_flutter_client/data/repositories/auth_repository.dart';
import 
'package:whatsapp_flutter_client/presentation/bloc/auth_bloc/auth_bloc.dart';
import 
'package:whatsapp_flutter_client/presentation/bloc/chat_bloc/chat_bloc.dart';
import 
'package:whatsapp_flutter_client/presentation/bloc/chat_bloc/chat_event.dart';
import 
'package:whatsapp_flutter_client/presentation/screens/conversations_screen.dart';
import 
'package:whatsapp_flutter_client/presentation/screens/phone_input_screen.dart';

void main() {
  setupLocator();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => GetIt.I.get<AuthBloc>(),
      child: MaterialApp(
        title: 'Flutter Chat App',
        theme: ThemeData(primarySwatch: Colors.teal, useMaterial3: true),
        home: const AuthGate(),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: GetIt.I.get<AuthRepository>().getToken(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasData && snapshot.data != null) {
          return BlocProvider(
            create: (context) => GetIt.I.get<ChatBloc>()..add(ConnectWebSocket()),
            child: const ConversationsScreen(),
          );
        } else {
          return const PhoneInputScreen();
        }
      },
    );
  }
}
