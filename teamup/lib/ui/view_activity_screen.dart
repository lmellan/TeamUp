import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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

class ActivityDetailScreen extends StatefulWidget {
  final String activityId;

  final ActivityService activitySvc;
  final SportService sportSvc;
  final ProfileService profileSvc;
  final ParticipantService participantSvc;

  ActivityDetailScreen({
    super.key,
    required this.activityId,
    ActivityService? activitySvc,
    SportService? sportSvc,
    ProfileService? profileSvc,
    ParticipantService? participantSvc,
  })  : activitySvc = activitySvc ?? ActivityServiceSupabase(),
        sportSvc = sportSvc ?? SportServiceSupabase(),
        profileSvc = profileSvc ?? ProfileServiceSupabase(),
        participantSvc = participantSvc ?? ParticipantServiceSupabase();

  @override
  State<ActivityDetailScreen> createState() => _ActivityDetailScreenState();
}

class _ActivityDetailScreenState extends State<ActivityDetailScreen> {
  final DateFormat _fmt = DateFormat("EEEE d 'de' MMMM, HH:mm");
  String _s(String? v) => (v ?? '').trim();

  String _formatDate(DateTime dt) {
    try {
      return _fmt.format(dt);
    } catch (_) {
      return DateFormat('dd/MM/yyyy, HH:mm').format(dt);
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

      final userIds = parts.map((p) => p.userId).toSet().toList();
      if (a.creatorId != null) userIds.add(a.creatorId!);
      final profiles = await widget.profileSvc.listByIds(userIds);
      _profileById = {for (final p in profiles) p.id: p};
      _owner = a.creatorId == null ? null : _profileById[a.creatorId!];

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
    final sportLabel =
        s == null ? 'Actividad' : '${_s(s.iconEmoji).isEmpty ? '🎯' : _s(s.iconEmoji)} ${s.name}';
    final place = _s(a.placeName ?? a.formattedAddress);
    final dateText = _formatDate(a.date.toLocal());
    final max = a.maxPlayers ?? 0;
    final disableReason = _joinDisableReason();

    final showJoin = !_iAmOwner;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalles de la actividad'),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: [
            Container(
              height: 180,
              color: cs.primaryContainer.withOpacity(0.35),
              alignment: Alignment.center,
              child: Icon(Icons.image, size: 48, color: cs.onPrimaryContainer),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(sportLabel, style: t.bodyMedium?.copyWith(color: cs.primary)),
                  const SizedBox(height: 14),

                  if (owner != null) ...[
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: cs.primary.withOpacity(0.2),
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

                  if (place.isNotEmpty) ...[
                    _IconRow(icon: Icons.location_on, text: place),
                    const SizedBox(height: 10),
                  ],
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

                  const SizedBox(height: 16),

                  if (showJoin)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: (_busy || (_iAmJoined == false && disableReason != null))
                            ? null
                            : _toggleJoin,
                        child: Text(_iAmJoined
                            ? (_busy ? 'Saliendo...' : 'Salir')
                            : (_busy
                                ? 'Uniendo...'
                                : (disableReason == null ? 'Unirme' : disableReason))),
                      ),
                    ),

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

                      // 👇 etiqueta según enum + owner
                      final roleLabel = isOwner
                          ? 'Organizador'
                          : (p.role == ParticipantRole.coordinador ? 'Organizador' : 'Miembro');

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: cs.primary.withOpacity(0.2),
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
