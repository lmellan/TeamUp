import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../domain/entities/chat_room.dart';
import '../domain/entities/chat_message.dart';
import '../domain/entities/perfil.dart';
import '../domain/services/chat_service.dart';

class ChatScreen extends StatefulWidget {
  final ChatRoom room;
  final ChatService chatService;
  final Profile perfilActual;
  final Map<String, Profile> perfilesPorId;

  const ChatScreen({
    super.key,
    required this.room,
    required this.chatService,
    required this.perfilActual,
    required this.perfilesPorId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController controladorTexto = TextEditingController();
  late final Stream<List<ChatMessage>> _stream;

  // Scroll al final
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _stream = widget.chatService.streamMessages(widget.room.id);
  }

  @override
  void dispose() {
    controladorTexto.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _formatHeaderDate(DateTime date) {
    final local = DateUtils.dateOnly(date.toLocal());
    final today = DateUtils.dateOnly(DateTime.now());
    final yesterday =
        DateUtils.dateOnly(DateTime.now().subtract(const Duration(days: 1)));

    if (local == today) return 'Hoy';
    if (local == yesterday) return 'Ayer';

    return DateFormat("d 'de' MMMM", 'es').format(local);
  }

  @override
  Widget build(BuildContext context) {
    final amarillo = Theme.of(context).colorScheme.secondary; 
    return Scaffold(
      appBar: AppBar(title: Text(widget.room.nombre)),
      body: SafeArea(
        child: Column(
          children: [
            // ================= MENSAJES =================
            Expanded(
              child: StreamBuilder<List<ChatMessage>>(
                stream: _stream,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final mensajes = snapshot.data!;

                  final List<_ChatRow> rows = [];
                  ChatMessage? anterior;
                  for (final m in mensajes) {
                    final currDate = DateUtils.dateOnly(m.createdAt.toLocal());
                    if (anterior == null ||
                        DateUtils.dateOnly(anterior.createdAt.toLocal()) !=
                            currDate) {
                      rows.add(_ChatRow.header(currDate));
                    }
                    rows.add(_ChatRow.message(m));
                    anterior = m;
                  }

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_scrollController.hasClients) {
                      _scrollController.animateTo(
                        _scrollController.position.maxScrollExtent,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                      );
                    }
                  });

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(8),
                    itemCount: rows.length,
                    itemBuilder: (_, i) {
                      final row = rows[i];

                      if (row.isHeader) {
                        final label = _formatHeaderDate(row.date!);
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 4,
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                label,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ),
                        );
                      }

                      final m = row.message!;
                      final esMio = m.profileId == widget.perfilActual.id;

                      final perfil = widget.perfilesPorId[m.profileId];
                      final rawName = perfil?.name ?? 'Usuario';
                      final nombre =
                          rawName.trim().isEmpty ? 'Usuario' : rawName.trim();

                      final hora =
                          DateFormat('HH:mm').format(m.createdAt.toLocal());

                      return Align(
                        alignment:
                            esMio ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: esMio
                                ? amarillo.withOpacity(0.85)
                                : Colors.grey[300],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: esMio
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            children: [
                              Text(
                                nombre,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                m.content,
                                style: const TextStyle(fontSize: 14),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                hora,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            // ================= INPUT MENSAJE =================
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controladorTexto,
                      decoration: const InputDecoration(
                        hintText: 'Escribe un mensaje...',
                      ),
                      onSubmitted: (_) => _enviar(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _enviar,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _enviar() async {
    final texto = controladorTexto.text.trim();
    if (texto.isEmpty) return;

    await widget.chatService.sendMessage(
      widget.room.id,
      widget.perfilActual.id,
      texto,
    );

    controladorTexto.clear();
  }
}

class _ChatRow {
  final ChatMessage? message;
  final DateTime? date;
  final bool isHeader;

  _ChatRow._({this.message, this.date, required this.isHeader});

  factory _ChatRow.header(DateTime date) =>
      _ChatRow._(date: date, isHeader: true);

  factory _ChatRow.message(ChatMessage m) =>
      _ChatRow._(message: m, isHeader: false);
}
