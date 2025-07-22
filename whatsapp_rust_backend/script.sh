#!/bin/bash

# --- Start of Script ---

echo "🚀 Applying fix for Phase 9: Correcting BLoC State Management..."

# --- Frontend Modifications (Flutter) ---

# Navigate to the Flutter project directory
if [ -d "whatsapp_flutter_client" ]; then
    cd whatsapp_flutter_client
elif [ ! -f "pubspec.yaml" ]; then
    cd ../whatsapp_flutter_client || { echo "Error: Could not find 
'whatsapp_flutter_client' directory."; exit 1; }
fi

echo "-> Updating service_locator.dart..."

# -- lib/core/services/service_locator.dart (Modified) --
cat > lib/core/services/service_locator.dart << 'EOF'
import 'package:get_it/get_it.dart';
import 'package:whatsapp_flutter_client/data/datasources/auth_api_client.dart';
import 'package:whatsapp_flutter_client/data/datasources/websocket_service.dart';
import 'package:whatsapp_flutter_client/data/repositories/auth_repository.dart';
import 
'package:whatsapp_flutter_client/data/repositories/conversation_repository.dart';
import 
'package:whatsapp_flutter_client/presentation/bloc/chat_bloc/chat_bloc.dart';
import 
'package:whatsapp_flutter_client/presentation/bloc/conversation_bloc/conversation_bloc.dart';

final getIt = GetIt.instance;

void setupLocator() {
  // --- DATA SOURCES ---
  getIt.registerLazySingleton<AuthApiClient>(() => AuthApiClient());
  getIt.registerLazySingleton<WebSocketService>(() => WebSocketService());

  // --- REPOSITORIES ---
  getIt.registerLazySingleton<AuthRepository>(
    () => AuthRepository(apiClient: getIt<AuthApiClient>()),
  );
  getIt.registerLazySingleton<ConversationRepository>(() => 
ConversationRepository());

  // --- BLOCS ---
  // THE FIX: Register ChatBloc as a Lazy Singleton to ensure only one instance 
exists.
  getIt.registerLazySingleton<ChatBloc>(
    () => ChatBloc(webSocketService: getIt<WebSocketService>()),
  );
  
  // ConversationBloc is screen-specific, so it remains a factory.
  getIt.registerFactory<ConversationBloc>(
    () => ConversationBloc(conversationRepository: 
getIt<ConversationRepository>()),
  );
}
EOF

echo "-> Updating main.dart..."

# -- lib/main.dart (Modified) --
cat > lib/main.dart << 'EOF'
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:whatsapp_flutter_client/core/services/service_locator.dart';
import 'package:whatsapp_flutter_client/data/repositories/auth_repository.dart';
import 'package:whatsapp_flutter_client/presentation/bloc/auth_bloc.dart';
import 
'package:whatsapp_flutter_client/presentation/bloc/chat_bloc/chat_bloc.dart';
import 
'package:whatsapp_flutter_client/presentation/bloc/chat_bloc/chat_event.dart';
import 
'package:whatsapp_flutter_client/presentation/screens/conversations_screen.dart';
import 
'package:whatsapp_flutter_client/presentation/screens/phone_input_screen.dart';

void main() {
  setupLocator(); // Set up our service locator
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AuthBloc(authRepository: GetIt.I.get()),
      child: MaterialApp(
        title: 'Flutter Chat App',
        theme: ThemeData(
          primarySwatch: Colors.teal,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
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
          // THE FIX: Provide the singleton ChatBloc here.
          // It will be created once and used everywhere below this point.
          // We also dispatch the ConnectWebSocket event right here.
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
EOF

echo "-> Updating otp_verification_screen.dart..."

# -- lib/presentation/screens/otp_verification_screen.dart (Modified) --
cat > lib/presentation/screens/otp_verification_screen.dart << 'EOF'
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:whatsapp_flutter_client/main.dart'; // Import main to access 
AuthGate
import 'package:whatsapp_flutter_client/presentation/bloc/auth_bloc.dart';
import 'package:whatsapp_flutter_client/presentation/bloc/auth_event.dart';
import 'package:whatsapp_flutter_client/presentation/bloc/auth_state.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String phoneNumber;
  const OtpVerificationScreen({super.key, required this.phoneNumber});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _otpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify Your OTP')),
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthSuccess) {
            // THE FIX: Navigate to the AuthGate. It will find the new token
            // and correctly provide the singleton ChatBloc to the 
ConversationsScreen.
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const AuthGate()),
              (route) => false,
            );
          } else if (state is AuthFailure) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(state.error)));
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Enter the OTP sent to ${widget.phoneNumber}'),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _otpController,
                  decoration: const InputDecoration(
                    labelText: 'OTP',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.length < 6) {
                      return 'Please enter a valid 6-digit OTP';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                BlocBuilder<AuthBloc, AuthState>(
                  builder: (context, state) {
                    if (state is AuthLoading) {
                      return const CircularProgressIndicator();
                    }
                    return ElevatedButton(
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          context.read<AuthBloc>().add(AuthVerifyOtpRequested(
                                phoneNumber: widget.phoneNumber,
                                otp: _otpController.text,
                              ));
                        }
                      },
                      child: const Text('Verify OTP'),
                    );
                  },
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
EOF


echo "-> Updating conversations_screen.dart..."

# -- lib/presentation/screens/conversations_screen.dart (Modified) --
cat > lib/presentation/screens/conversations_screen.dart << 'EOF'
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:whatsapp_flutter_client/data/models/conversation.dart';
import 
'package:whatsapp_flutter_client/presentation/bloc/chat_bloc/chat_bloc.dart';
import 
'package:whatsapp_flutter_client/presentation/bloc/chat_bloc/chat_state.dart';
import 
'package:whatsapp_flutter_client/presentation/bloc/conversation_bloc/conversation_bloc.dart';
import 
'package:whatsapp_flutter_client/presentation/bloc/conversation_bloc/conversation_event.dart';
import 
'package:whatsapp_flutter_client/presentation/bloc/conversation_bloc/conversation_state.dart';
import 'package:whatsapp_flutter_client/presentation/screens/chat_screen.dart';

class ConversationsScreen extends StatelessWidget {
  const ConversationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // THE FIX: Only the ConversationBloc is provided here.
    // The ChatBloc is inherited from the AuthGate widget.
    return BlocProvider(
      create: (context) => 
GetIt.I.get<ConversationBloc>()..add(FetchConversations()),
      child: const ConversationsView(),
    );
  }
}

class ConversationsView extends StatelessWidget {
  const ConversationsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: BlocBuilder<ChatBloc, ChatState>(
          builder: (context, state) {
            String title = "Conversations";
            Color indicatorColor = Colors.grey;
            switch(state.status) {
              case ConnectionStatus.connected:
                title = "Connected";
                indicatorColor = Colors.green;
                break;
              case ConnectionStatus.disconnected:
                title = "Disconnected";
                indicatorColor = Colors.red;
                break;
              case ConnectionStatus.error:
                 title = "Connection Error";
                 indicatorColor = Colors.orange;
                 break;
              default:
                 break;
            }
            return Row(
              children: [
                Text(title),
                const SizedBox(width: 8),
                CircleAvatar(backgroundColor: indicatorColor, radius: 5),
              ],
            );
          },
        ),
      ),
      body: BlocBuilder<ConversationBloc, ConversationState>(
        builder: (context, state) {
          switch (state.status) {
            case ConversationStatus.loading:
            case ConversationStatus.initial:
              return const Center(child: CircularProgressIndicator());
            case ConversationStatus.failure:
              return Center(child: Text('Failed to load conversations: 
${state.error}'));
            case ConversationStatus.success:
              if (state.conversations.isEmpty) {
                return const Center(child: Text('No conversations yet.'));
              }
              return ListView.builder(
                itemCount: state.conversations.length,
                itemBuilder: (context, index) {
                  final conversation = state.conversations[index];
                  return ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(conversation.displayName),
                    subtitle: Text(conversation.lastMessage ?? 'No messages yet', 
maxLines: 1, overflow: TextOverflow.ellipsis),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => BlocProvider.value(
                            // This is now correct, as it passes the SINGLETON 
instance.
                            value: BlocProvider.of<ChatBloc>(context),
                            child: ChatScreen(conversation: conversation),
                          ),
                        ),
                      );
                    },
                  );
                },
              );
          }
        },
      ),
    );
  }
}
EOF

# --- End of Script ---
echo "✅ Flutter client successfully upgraded with singleton BLoC management!"
echo ""
echo "--- Next Steps ---"
echo "1. Stop your Flutter app completely."
echo "2. Run 'flutter run' to launch with the new widget structure."
echo "3. You may need to log out and log back in to ensure the flow is correct."
echo "4. After logging in, the app should connect to the WebSocket immediately."
echo "5. Navigate to the chat screen and send a message. It should now be sent 
successfully."
echo "------------------"
