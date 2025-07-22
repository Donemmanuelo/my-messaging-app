import 'package:equatable/equatable.dart';
class Conversation extends Equatable {
  final String conversationId;
  final bool isGroup;
  final String? groupName, otherUserId, otherUserName, lastMessage;
  final DateTime? lastMessageAt;
  const Conversation({required this.conversationId, required this.isGroup, 
this.groupName, this.otherUserId, this.otherUserName, this.lastMessage, 
this.lastMessageAt});
  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
      conversationId: json['conversation_id'],
      isGroup: json['is_group'],
      groupName: json['group_name'],
      otherUserId: json['other_user_id'],
      otherUserName: json['other_user_name'],
      lastMessage: json['last_message'],
      lastMessageAt: json['last_message_at'] != null ? 
DateTime.parse(json['last_message_at']) : null,
    );
  String get displayName => isGroup ? (groupName ?? 'Group') : (otherUserName ?? 
'Unknown User');
  @override List<Object?> get props => [conversationId, isGroup, groupName, 
otherUserId, otherUserName, lastMessage, lastMessageAt];
}
