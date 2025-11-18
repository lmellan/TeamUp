class ChatMessage {
  final int id;
  final String roomId;
  final String profileId;
  final String content;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.roomId,
    required this.profileId,
    required this.content,
    required this.createdAt,
  });

  factory ChatMessage.fromRow(Map<String, dynamic> row) {
    return ChatMessage(
      id: row['id'] as int,
      roomId: row['room_id'] as String,
      profileId: row['profile_id'] as String,
      content: row['content'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }
}
