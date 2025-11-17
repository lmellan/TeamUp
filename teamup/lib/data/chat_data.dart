// lib/data/chat_data.dart

import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/entities/chat_room.dart';
import '../domain/entities/chat_message.dart';
import '../domain/services/chat_service.dart';

class ChatServiceSupabase implements ChatService {
  final SupabaseClient _client;

  ChatServiceSupabase(this._client);

  // ---------------------------------------------------------------------------
  //  Obtener el chat asociado a una actividad
  // ---------------------------------------------------------------------------
  @override
  Future<ChatRoom> getRoomForActivity(String activityId) async {
    final data = await _client
        .from('chat_rooms')
        .select()
        .eq('activity_id', activityId)
        .single();

    return ChatRoom(
      id: data['id'] as String,
      activityId: data['activity_id'] as String,
      nombre: (data['nombre'] as String?) ?? '',
    );
  }

  // ---------------------------------------------------------------------------
  //  Unirse a una sala de chat (chat_members)
  // ---------------------------------------------------------------------------
  @override
  Future<void> joinRoom(String roomId, String profileId) async {
    await _client.from('chat_members').upsert({
      'room_id': roomId,
      'profile_id': profileId,
    });
  }

  // ---------------------------------------------------------------------------
  //  Enviar mensaje
  // ---------------------------------------------------------------------------
  @override
  Future<void> sendMessage(
    String roomId,
    String profileId,
    String content,
  ) async {
    await _client.from('chat_messages').insert({
      'room_id': roomId,
      'profile_id': profileId,
      'content': content,
    });
  }

  // ---------------------------------------------------------------------------
  //  Stream en tiempo real de mensajes de una sala
  // ---------------------------------------------------------------------------
@override
Stream<List<ChatMessage>> streamMessages(String roomId) {
  final controlador = StreamController<List<ChatMessage>>();
  final supabase = _client;

  List<ChatMessage> mensajes = [];

  // 1) Cargar historial inicial (orden antiguo → nuevo)
  Future<void> cargarInicial() async {
    final data = await supabase
        .from('chat_messages')
        .select()
        .eq('room_id', roomId)
        .order('created_at', ascending: true);   // 👈 IMPORTANTE

    mensajes = (data as List<dynamic>)
        .map((row) => ChatMessage.fromRow(row as Map<String, dynamic>))
        .toList();

    // por si acaso, ordenar igual
    mensajes.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    if (!controlador.isClosed) {
      controlador.add(List.unmodifiable(mensajes));
    }
  }

  cargarInicial();

  // 2) Suscripción realtime
  final channel = supabase
      .channel('chat_room_$roomId')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'chat_messages',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'room_id',
          value: roomId,
        ),
        callback: (payload) {
          final row = payload.newRecord;
          if (row == null) return;

          final nuevo = ChatMessage.fromRow(row as Map<String, dynamic>);
          mensajes.add(nuevo);

          // aseguramos orden antiguo → nuevo
          mensajes.sort((a, b) => a.createdAt.compareTo(b.createdAt));

          if (!controlador.isClosed) {
            controlador.add(List.unmodifiable(mensajes));
          }
        },
      )
      .subscribe();

  controlador.onCancel = () async {
    await supabase.removeChannel(channel);
    await controlador.close();
  };

  return controlador.stream;
}

}
