class ConversationMessage {
  const ConversationMessage({
    required this.isMe,
    required this.text,
    this.signal,
    this.isSystem = false,
  });

  final bool isMe;
  final String text;
  final String? signal;
  final bool isSystem;

  factory ConversationMessage.fromJson(Map<String, dynamic> json) {
    return ConversationMessage(
      isMe: json['isMe'] as bool? ?? false,
      text: json['text'] as String? ?? '',
      signal: json['signal'] as String?,
      isSystem: json['isSystem'] as bool? ?? false,
    );
  }
}
