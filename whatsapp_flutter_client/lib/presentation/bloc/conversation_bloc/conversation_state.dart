import 'package:equatable/equatable.dart';

enum ConversationStatus { initial, loading, success, failure }

abstract class ConversationState extends Equatable {
  const ConversationState();
  ConversationStatus get status => ConversationStatus.initial;
  List<dynamic> get conversations => const [];
  String get error => '';
  @override
  List<Object?> get props => [];
}

class ConversationInitial extends ConversationState {}

class ConversationLoading extends ConversationState {
  @override
  ConversationStatus get status => ConversationStatus.loading;
}

class ConversationLoadSuccess extends ConversationState {
  final List<dynamic> _conversations;
  const ConversationLoadSuccess(this._conversations);
  @override
  ConversationStatus get status => ConversationStatus.success;
  @override
  List<dynamic> get conversations => _conversations;
  @override
  List<Object?> get props => [_conversations];
}

class ConversationFailure extends ConversationState {
  final String _error;
  const ConversationFailure(this._error);
  @override
  ConversationStatus get status => ConversationStatus.failure;
  @override
  String get error => _error;
  @override
  List<Object?> get props => [_error];
} 