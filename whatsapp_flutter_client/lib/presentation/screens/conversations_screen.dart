import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:whatsapp_flutter_client/data/models/conversation.dart';
import 'package:whatsapp_flutter_client/presentation/bloc/chat_bloc/chat_bloc.dart';
import 'package:whatsapp_flutter_client/presentation/bloc/chat_bloc/chat_state.dart';
import 'package:whatsapp_flutter_client/presentation/bloc/conversation_bloc/conversation_bloc.dart';
import 'package:whatsapp_flutter_client/presentation/bloc/conversation_bloc/conversation_event.dart';
import 'package:whatsapp_flutter_client/presentation/bloc/conversation_bloc/conversation_state.dart';
import 'package:whatsapp_flutter_client/presentation/screens/chat_screen.dart';

class ConversationsScreen extends StatelessWidget {
  const ConversationsScreen({super.key});
  @override
  Widget build(BuildContext context) => MultiBlocProvider(
      providers: [
          BlocProvider(create: (_) => GetIt.I.get<ConversationBloc>()..add(FetchConversations())),
        BlocProvider.value(value: BlocProvider.of<ChatBloc>(context)),
      ],
      child: const ConversationsView(),
    );
}

class ConversationsView extends StatelessWidget {
  const ConversationsView({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: BlocBuilder<ChatBloc, ChatState>(
            builder: (context, state) {
              String title = "Conversations";
              Color indicatorColor = Colors.grey;
        switch(state.status) {
                case ChatStatus.connected:
                  title = "Connected";
                  indicatorColor = Colors.green;
                  break;
                case ChatStatus.disconnected:
                  title = "Disconnected";
                  indicatorColor = Colors.red;
                  break;
                case ChatStatus.failure:
                  title = "Connection Error";
                  indicatorColor = Colors.orange;
                  break;
                default:
                  break;
        }
              return Row(children: [
                Text(title),
                const SizedBox(width: 8),
                CircleAvatar(backgroundColor: indicatorColor, radius: 5),
              ]);
            },
          ),
        ),
        body: BlocBuilder<ConversationBloc, ConversationState>(
          builder: (context, state) {
        switch (state.status) {
              case ConversationStatus.failure:
                return Center(child: Text('Failed to load conversations: ${state.error}'));
          case ConversationStatus.success:
                if (state.conversations.isEmpty) {
                  return const Center(child: Text('No conversations yet.'));
                }
                return ListView.builder(
                  itemCount: state.conversations.length,
itemBuilder: (context, index) {
              final convo = state.conversations[index];
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(convo.displayName),
                      subtitle: Text(convo.lastMessage ?? 'No messages yet', maxLines: 1, overflow: TextOverflow.ellipsis),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => BlocProvider.value(
                            value: BlocProvider.of<ChatBloc>(context),
                            child: ChatScreen(conversation: convo),
                          ),
                        ),
                      ),
              );
                  },
                );
              default:
                return const Center(child: CircularProgressIndicator());
        }
          },
        ),
    );
}
