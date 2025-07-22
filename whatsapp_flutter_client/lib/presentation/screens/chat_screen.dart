import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:whatsapp_flutter_client/data/models/conversation.dart';
import 
'package:whatsapp_flutter_client/presentation/bloc/chat_bloc/chat_bloc.dart';
import 
'package:whatsapp_flutter_client/presentation/bloc/chat_bloc/chat_event.dart';
import 
'package:whatsapp_flutter_client/presentation/bloc/chat_bloc/chat_state.dart';
import 
'package:whatsapp_flutter_client/presentation/widgets/chat_message_bubble.dart';

class ChatScreen extends StatefulWidget { final Conversation conversation; const 
ChatScreen({super.key, required this.conversation}); @override State<ChatScreen> 
createState() => _ChatScreenState(); }

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController(); String? _currentUserId; Timer? 
_typingTimer;
  
  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    // --- FETCH HISTORY WHEN THE SCREEN LOADS ---
    
context.read<ChatBloc>().add(FetchMessageHistory(widget.conversation.conversationId));
    _controller.addListener(_onTyping);
  }

  Future<void> _loadCurrentUser() async { _currentUserId = await const 
FlutterSecureStorage().read(key: 'user_id'); if (mounted) setState(() {}); }
  
  void _onTyping() {
    _typingTimer?.cancel();
    context.read<ChatBloc>().add(SendTypingIndicator(isTyping: true, 
conversationId: widget.conversation.conversationId));
    _typingTimer = Timer(const Duration(seconds: 2), () => 
context.read<ChatBloc>().add(SendTypingIndicator(isTyping: false, conversationId: 
widget.conversation.conversationId)));
  }

  void _sendMessage() {
    if (_controller.text.isNotEmpty) {
      _typingTimer?.cancel();
      context.read<ChatBloc>().add(SendTypingIndicator(isTyping: false, 
conversationId: widget.conversation.conversationId));
      context.read<ChatBloc>().add(SendMessage(content: _controller.text, 
conversationId: widget.conversation.conversationId));
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: Text(widget.conversation.displayName)),
      body: Column(children: [
        Expanded(child: BlocBuilder<ChatBloc, ChatState>(builder: (context, state) 
{
          if (state.status == ChatStatus.loadingHistory) return const 
Center(child: CircularProgressIndicator());
          if (_currentUserId == null) return const Center(child: 
CircularProgressIndicator());
          
          final messages = state.messages.where((m) => m.conversationId == 
widget.conversation.conversationId).toList();
          if (messages.isEmpty) return const Center(child: Text('No messages yet.'));
          
          return ListView.builder(
            padding: const EdgeInsets.all(8), reverse: true, itemCount: 
messages.length,
            itemBuilder: (context, index) {
            final message = messages[messages.length - 1 - index];
            return ChatMessageBubble(message: message, isMe: message.senderId == 
_currentUserId);
            }
          );
        })),
        // ... message input widget ...
      ]),
    );
  
  @override void dispose() { _controller.removeListener(_onTyping); 
_controller.dispose(); _typingTimer?.cancel(); super.dispose(); }
}
