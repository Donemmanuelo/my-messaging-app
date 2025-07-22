import 'package:flutter/material.dart';
import 'package:whatsapp_flutter_client/data/models/chat_message.dart';
class ChatMessageBubble extends StatelessWidget {
  final ChatMessage message; final bool isMe;
  const ChatMessageBubble({super.key, required this.message, required this.isMe});
  @override Widget build(BuildContext context) => Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        decoration: BoxDecoration(
          color: isMe ? Colors.teal[400] : Colors.grey[300],
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16), topRight: const 
Radius.circular(16),
            bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
            bottomRight: isMe ? Radius.zero : const Radius.circular(16),
          ),
        ),
        child: Text(message.content, style: TextStyle(color: isMe ? Colors.white : 
Colors.black87)),
      ),
    );
}
