import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';  
import '../componentes/map_preview.dart';

import '../domain/entities/actividad.dart';
import '../domain/entities/deportes.dart';
import '../domain/entities/perfil.dart';
import '../domain/entities/participante.dart';  
import '../domain/services/actividad_services.dart';
import '../domain/services/deportes_services.dart';
import '../domain/services/perfil_services.dart';
import '../domain/services/participante_services.dart';

import '../data/actividad_data.dart';
import '../data/deportes_data.dart';
import '../data/perfil_data.dart';
import '../data/participante_data.dart';


import '../domain/services/chat_service.dart';
import '../data/chat_data.dart';
import 'chat_screen.dart';  


class ActivityDetailScreen extends StatefulWidget {
  final String activityId;

  final ActivityService activitySvc;
  final SportService sportSvc;
  final ProfileService profileSvc;
  final ParticipantService participantSvc;
  final ChatService chatSvc;


  ActivityDetailScreen({
    super.key,
    required this.activityId,
    ActivityService? activitySvc,
    SportService? sportSvc,
    ProfileService? profileSvc,
    ParticipantService? participantSvc,
    ChatService? chatSvc,
  })  : activitySvc = activitySvc ?? ActivityServiceSupabase(),
        sportSvc = sportSvc ?? SportServiceSupabase(),
        profileSvc = profileSvc ?? ProfileServiceSupabase(),
        participantSvc = participantSvc ?? ParticipantServiceSupabase(),
        chatSvc = chatSvc ?? ChatServiceSupabase(Supabase.instance.client);


  @override
  State<ActivityDetailScreen> createState() => _ActivityDetailScreenState();
}

class _ActivityDetailScreenState extends State<ActivityDetailScreen> {
  final DateFormat _fmt = DateFormat("EEEE d 'de' MMMM, HH:mm");
  String _s(String? v) => (v ?? '').trim();

  String _formatDate(DateTime dt) {
    try {
      final formatted = _fmt.format(dt);
      return formatted[0].toUpperCase() + formatted.substring(1);
    } catch (_) {
      final fallback = DateFormat('dd/MM/yyyy, HH:mm').format(dt);
      return fallback[0].toUpperCase() + fallback.substring(1);
    }
  }

  Activity? _a;
  Sport? _sport;
  Profile? _me;
  Profile? _owner;
  List<Participant> _participants = [];
  Map<String, Profile> _profileById = {};

  bool _loading = true;
  bool _busy = false;

  // ===== Helpers de imágenes (deporte) =====
  String? _sportPublicUrl(Sport? s) {
    if (s == null) return null;
    final path = s.imagePath?.trim();
    if (path == null || path.isEmpty) return null;

    // Acepta "deportes/futbol.jpg" o "futbol.jpg"
    final clean = path.startsWith('deportes/')
        ? path.replaceFirst('deportes/', '')
        : path;

    return Supabase.instance.client
        .storage
        .from('deportes')
        .getPublicUrl(clean);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final me = await widget.profileSvc.getMyProfile();
      _me = me;

      final a = await widget.activitySvc.getById(widget.activityId);
      if (a == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Actividad no encontrada')),
          );
          Navigator.pop(context);
        }
        return;
      }
      _a = a;

      final sports = await widget.sportSvc.listByIds([a.sportId]);
      _sport = sports.isNotEmpty ? sports.first : null;

      final parts = await widget.participantSvc.listByActivity(a.id!);
      _participants = parts;

      final userIds = parts.map((p) => p.userId).toSet();
      userIds.add(a.creatorId); // a.creatorId es no-null

      final profiles = await widget.profileSvc.listByIds(userIds.toList());
      _profileById = { for (final p in profiles) p.id: p };

      _owner = _profileById[a.creatorId];

      if (mounted) setState(() {});
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _iAmOwner =>
      _me != null && _a?.creatorId != null && _me!.id == _a!.creatorId;

  bool get _iAmJoined =>
      _me != null && _participants.any((p) => p.userId == _me!.id);

  int get _joinedCount => _participants.length;

  String? _joinDisableReason() {
    if (_a == null) return 'Cargando...';
    final now = DateTime.now().toUtc();
    if (!['activa', 'en_curso'].contains(_a!.status)) return 'No está activa';
    if (now.isAfter(_a!.date)) return 'Ya ocurrió';
    final max = _a!.maxPlayers ?? 0;
    if (max > 0 && _joinedCount >= max) return 'Cupos completos';
    return null;
  }

  Future<void> _toggleJoin() async {
    if (_me == null || _a == null) return;
    if (_iAmOwner) return;
    setState(() => _busy = true);
    try {
      if (_iAmJoined) {
        await widget.participantSvc.leave(_a!.id!, _me!.id);
      } else {
        final reason = _joinDisableReason();
        if (reason != null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(reason)),
            );
          }
          return;
        }
        await widget.participantSvc.join(
          _a!.id!,
          _me!.id,
          role: ParticipantRole.miembro,
        );
      }
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo actualizar tu participación: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmDelete() async {
    if (_a == null) return;
    final theme = Theme.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar actividad'),
        content: const Text(
          '¿Seguro que deseas eliminar esta actividad? Esta acción no se puede deshacer.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    setState(() => _busy = true);
    try {
      await widget.activitySvc.delete(widget.activityId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Actividad eliminada'))
        );
        _goToExplore();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo eliminar: $e'))
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _goToEdit() {
    if (_a == null) return;
    Navigator.of(context).pushNamed(
      '/activity/edit',
      arguments: {'activityId': _a!.id},
    );
  }

  void _goToExplore() {
    Navigator.of(context).pushNamedAndRemoveUntil('/explore', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final a = _a!;
    final s = _sport;
    final owner = _owner;
    final title = _s(a.title).isEmpty
        ? (_s(a.description).isEmpty ? 'Actividad' : _s(a.description))
        : _s(a.title);
    final place = _s(a.placeName ?? a.formattedAddress);
    final dateText = _formatDate(a.date.toLocal());
    final max = a.maxPlayers ?? 0;
    final disableReason = _joinDisableReason();

    final level = _s(a.level);                        
    final locNote = _s(a.activityLocation);            
    final Map<String, dynamic> fields = a.fields;

    final showJoin = !_iAmOwner;
    final canSeeChatButton = _iAmOwner || _iAmJoined;  // 👈 AQUÍ

    // 👇 URL pública de imagen del deporte (si existe)
    final sportImg = _sportPublicUrl(s);


    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _goToExplore();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Detalles de la actividad'),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _goToExplore,
          ),
        ),
        body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            children: [
              // ===== Cabecera con imagen del deporte o emoji =====
              SizedBox(
                height: 200,
                child: (sportImg != null && sportImg.isNotEmpty)
                    ? ClipRRect(
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(16),
                          bottomRight: Radius.circular(16),
                        ),
                        child: Image.network(
                          sportImg,
                          width: double.infinity,
                          height: 200,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _EmojiHeader(
                            emoji: _s(s?.iconEmoji).isNotEmpty ? _s(s?.iconEmoji) : '🎯',
                          ),
                        ),
                      )
                    : _EmojiHeader(
                        emoji: _s(s?.iconEmoji).isNotEmpty ? _s(s?.iconEmoji) : '🎯',
                      ),
              ),

              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(_s(s?.name), style: t.bodyMedium?.copyWith(color: cs.primary)),
                    const SizedBox(height: 16),
                    if (owner != null) ...[
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: cs.primary.withValues(alpha: 0.2),
                            child: Text(
                              _s(owner.name).isNotEmpty
                                  ? _s(owner.name).substring(0, 1).toUpperCase()
                                  : 'U',
                              style: t.titleSmall?.copyWith(color: cs.primary),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('Organiza ${_s(owner.name).isEmpty ? 'alguien' : _s(owner.name)}',
                              style: t.bodySmall),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],
                    _IconRow(icon: Icons.emoji_events, text: level),
                    const SizedBox(height: 10),
                    _IconRow(
                      icon: Icons.location_on,
                      text: locNote.isNotEmpty ? '$place ($locNote)' : place,
                    ),
                    const SizedBox(height: 10),
                    _IconRow(icon: Icons.calendar_today, text: dateText),
                    const SizedBox(height: 10),
                    _IconRow(
                      icon: Icons.groups,
                      text: max > 0 ? '$_joinedCount/$max participantes' : '$_joinedCount participantes',
                    ),
                    if (_s(a.description).isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _IconRow(icon: Icons.notes, text: _s(a.description)),
                    ],
                    if (fields.isNotEmpty) ...[
                      Theme(
                        data: Theme.of(context).copyWith(
                          dividerColor: Colors.transparent,
                          listTileTheme: ListTileThemeData(
                            dense: true,
                            minLeadingWidth: 0, 
                            iconColor: Theme.of(context).brightness == Brightness.dark
                                ? Colors.white70
                                : const Color(0xFF6B7280),
                            textColor: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        child: ExpansionTile(
                          tilePadding: EdgeInsets.zero, 
                          childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
                          leading: Icon(
                            Icons.tune,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.white70
                                : const Color(0xFF6B7280),
                          ),
                          title: Text(
                            'Detalles adicionales',
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(color: Theme.of(context).colorScheme.onSurface),
                          ),
                          children: [
                            _FieldsList(fields: fields, sportCode: _s(s?.name)),
                          ],
                        ),
                      ),
                    ],
                    if (place.isNotEmpty && a.lat != null && a.lng != null) ...[
                      MapPreview(
                        lat: a.lat!,
                        lng: a.lng!,
                        label: place,
                        placeId: a.googlePlaceId,
                      ),
                    ],
                    const SizedBox(height: 16),

                    if (_iAmOwner) ...[
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _busy ? null : _goToEdit,
                              icon: const Icon(Icons.edit),
                              label: const Text('Editar actividad'),
                              style: FilledButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.primary,
                                side: BorderSide(color: Theme.of(context).colorScheme.primary),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(50),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                minimumSize: const Size(0, 48),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _busy ? null : _confirmDelete,
                              icon: const Icon(Icons.delete),
                              label: const Text('Eliminar'),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Theme.of(context).colorScheme.error),
                                foregroundColor: Theme.of(context).colorScheme.error,
                                backgroundColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(vertical: 14), 
                                minimumSize: const Size(0, 48),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: (_busy || (_iAmJoined == false && disableReason != null))
                              ? null
                              : _toggleJoin,
                          child: Text(
                            _iAmJoined
                              ? (_busy ? 'Saliendo...' : 'Salir')
                              : (_busy ? 'Uniendo...' : (disableReason ?? 'Unirme')),
                          ),
                        ),
                      ),
                    ],
 
                    if (canSeeChatButton) ...[
                      const SizedBox(height: 20),

                      // ===========================
                      // BOTÓN IR AL CHAT DE ESTA ACTIVIDAD
                      // ===========================
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          icon: const Icon(Icons.chat_bubble_outline),
                          label: const Text('Ir al chat de la convocatoria'),
                          onPressed: () async {
                            if (_a == null || _me == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Falta información de actividad o perfil')),
                              );
                              return;
                            }

                            try {
                              // 1) obtener el chat_room asociado
                              final room = await widget.chatSvc.getRoomForActivity(_a!.id!);

                              // 2) unirse por si no está
                              await widget.chatSvc.joinRoom(room.id, _me!.id);

                              if (!mounted) return;

                              // 3) navegar al chat
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ChatScreen(
                                    room: room,
                                    chatService: widget.chatSvc,
                                    perfilActual: _me!,
                                    perfilesPorId: _profileById,
                                  ),
                                ),
                              );
                            } catch (e) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('No se pudo abrir el chat: $e')),
                              );
                            }
                          },
                        ),
                      ),

 
                    ],


                    const SizedBox(height: 24),


                    Text('Participantes',
                        style: t.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),

                    if (_participants.isEmpty)
                      Text('Aún no hay participantes.',
                          style: t.bodySmall?.copyWith(color: cs.outline))
                    else
                      ..._participants.map((p) {
                        final prof = _profileById[p.userId];
                        final name = _s(prof?.name);
                        final avatar = _s(prof?.avatarUrl);
                        final isOwner = p.userId == a.creatorId;

                        final roleLabel = isOwner
                            ? 'Organizador'
                            : (p.role == ParticipantRole.coordinador ? 'Organizador' : 'Miembro');

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: cs.primary.withValues(alpha: 0.2),
                            backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                            child: avatar.isEmpty
                                ? Text(
                                    name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'U',
                                    style: t.titleMedium?.copyWith(color: cs.primary),
                                  )
                                : null,
                          ),
                          title: Text(name.isNotEmpty ? name : 'Usuario'),
                          subtitle: Text(roleLabel),
                          dense: true,
                        );
                      }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmojiHeader extends StatelessWidget {
  final String emoji;
  const _EmojiHeader({required this.emoji});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 200,
      width: double.infinity,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Text(
        emoji,
        style: TextStyle(
          fontSize: 48,
          color: cs.onPrimaryContainer,
        ),
      ),
    );
  }
}

class _IconRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _IconRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final muted = Theme.of(context).brightness == Brightness.dark
        ? Colors.white70
        : const Color(0xFF6B7280);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: muted),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: t.bodyLarge?.copyWith(color: cs.onSurface))),
      ],
    );
  }
}

class _FieldsList extends StatelessWidget {
  final Map<String, dynamic> fields;
  final String? sportCode; // por si quieres ordenar/renombrar por deporte

  const _FieldsList({required this.fields, this.sportCode});

  String _labelize(String raw) {
    final r = raw.replaceAll('_', ' ');
    final withSpaces = RegExp(r'(?<=[a-z])([A-Z])').hasMatch(r)
        ? r.replaceAllMapped(RegExp(r'(?<=[a-z])([A-Z])'), (m) => ' ${m.group(1)}')
        : r;
    return withSpaces.split(' ').map((w) {
      if (w.isEmpty) return w;
      return w[0].toUpperCase() + w.substring(1);
    }).join(' ');
  }

  String _valueToText(dynamic v) {
    if (v == null) return '—';
    if (v is bool) return v ? 'Sí' : 'No';
    return v.toString();
  }

  @override
  Widget build(BuildContext context) {
    final entries = fields.entries.toList();
    return Column(
      children: entries.map((e) {
        return ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(_labelize(e.key)),
          trailing: Text(
            _valueToText(e.value),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        );
      }).toList(),
    );
  }
}
