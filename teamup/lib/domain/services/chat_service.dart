import '../entities/chat_room.dart';
import '../entities/chat_message.dart';

abstract class ChatService {
  Future<ChatRoom> getRoomForActivity(String activityId);

  Future<void> joinRoom(String roomId, String profileId);

  Future<void> sendMessage(
    String roomId,
    String profileId,
    String content,
  );

  /// Stream en tiempo real de los mensajes ordenados por fecha
  Stream<List<ChatMessage>> streamMessages(String roomId);
}
