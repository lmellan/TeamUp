import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
 
import '../../domain/entities/perfil.dart';
import '../../domain/entities/deportes.dart';
import '../../domain/entities/actividad.dart';
import '../../domain/services/perfil_services.dart';
import '../../domain/services/deportes_services.dart';
import '../../domain/services/actividad_services.dart';
import '../../domain/services/participante_services.dart';
 
import '../../data/perfil_data.dart';
import '../../data/deportes_data.dart';
import '../../data/actividad_data.dart';
import '../../data/participante_data.dart';
 
import '../componentes/navigate_bar.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
 
  String _trimOrEmpty(String? s) => (s ?? '').trim();

 
  final ProfileService _profileSvc = ProfileServiceSupabase();
  final SportService _sportSvc = SportServiceSupabase();
  final ActivityService _activitySvc = ActivityServiceSupabase();
  final ParticipantService _participantSvc = ParticipantServiceSupabase();

  bool _loading = false;

  Profile? _profile;
  List<Sport> _sports = [];
  Map<String, Sport> _sportById = {};

  List<Activity> _upcoming = [];
  List<Activity> _history = [];

  static const activeStatuses = {'activa', 'en_curso'};
  // static const closedStatuses = {'cancelada', 'cerrada', 'finalizada'};

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      // 1) Perfil
      final prof = await _profileSvc.getMyProfile();
      if (prof == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No hay sesión activa')),
          );
        }
        return;
      }
      _profile = prof;

      // 2) Deportes preferidos
      if (prof.preferredSportIds.isNotEmpty) {
        _sports = await _sportSvc.listByIds(prof.preferredSportIds);
        _sportById = {for (final s in _sports) s.id: s};
      } else {
        _sports = [];
        _sportById = {};
      }

      // 3) Actividades del usuario
      final actIds = await _participantSvc.activityIdsByUser(prof.id);
      if (actIds.isEmpty) {
        _upcoming = [];
        _history = [];
      } else {
        final acts = await _activitySvc.listByIds(actIds, ascending: true);

        // 4) Split upcoming/history
        final now = DateTime.now().toUtc();
        final up = <Activity>[];
        final hi = <Activity>[];
        for (final a in acts) {
          final isUpcoming = activeStatuses.contains(a.status) && a.dateUtc.isAfter(now);
          (isUpcoming ? up : hi).add(a);
        }
        _upcoming = up;
        _history = hi;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final muted = Theme.of(context).brightness == Brightness.dark
        ? Colors.white70
        : const Color(0xFF6B7280);
    final fmt = DateFormat('dd/MM/yyyy, h:mm a');

    // Usar helper null-safe
    final name = _trimOrEmpty(_profile?.name);
    final bio = _trimOrEmpty(_profile?.bio);
    final avatarUrl = _trimOrEmpty(_profile?.avatarUrl);
    final locationLabel = _trimOrEmpty(_profile?.locationLabel);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
        centerTitle: true,
        actions: [
          IconButton(
                    tooltip: 'Editar perfil',
                    onPressed: () async {
                      final result = await Navigator.pushNamed(
                        context,
                        '/edit-profile',
                        arguments: _profile,
                      );
                      if (result == true) {
                        // If the edit screen indicates a change, reload everything.
                        await _loadAll();
                        ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Perfil actualizado')), 
                        );
                      }
                    },
                    icon: const Icon(Icons.edit_outlined),
                  ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadAll,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              // Header
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                      child: avatarUrl.isEmpty
                          ? Text(
                              (name.isNotEmpty ? name.substring(0, 1) : 'T').toUpperCase(),
                              style: t.headlineMedium?.copyWith(color: cs.onPrimary),
                            )
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Text(name.isNotEmpty ? name : 'Tu nombre',
                        style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                    if (bio.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(bio, textAlign: TextAlign.center,
                            style: t.bodyMedium?.copyWith(color: muted)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Deportes
              Text('Deporte favorito',
                  style: t.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (_loading && _sports.isEmpty)
                const LinearProgressIndicator()
              else if (_sports.isEmpty)
                Text('Aún no seleccionaste deportes.',
                    style: t.bodySmall?.copyWith(color: muted))
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _sports.map((s) {
                    final label = [
                      _trimOrEmpty(s.iconEmoji),
                      s.name,
                    ].where((x) => x.isNotEmpty).join('  ');
                    return Chip(
                      label: Text(label),
                      backgroundColor: cs.primaryContainer.withOpacity(0.6),
                      labelStyle: t.bodyMedium?.copyWith(color: cs.onPrimaryContainer),
                    );
                  }).toList(),
                ),

              const SizedBox(height: 16),

              // Ubicación (si hay)
              if (locationLabel.isNotEmpty) ...[
                Text('Ubicación base',
                    style: t.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: cs.primary.withOpacity(0.2),
                      child: Icon(Icons.location_on, color: cs.primary),
                    ),
                    title: const Text('Ubicación'),
                    subtitle: Text(locationLabel, style: TextStyle(color: muted)),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Actividades vigentes
              Text('Tus actividades',
                  style: t.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (_loading && _upcoming.isEmpty)
                const LinearProgressIndicator()
              else if (_upcoming.isEmpty)
                Text('No tienes actividades activas.',
                    style: t.bodySmall?.copyWith(color: muted))
              else
                Column(
                  children: _upcoming.map((a) {
                    final sport = _sportById[a.sportId];
                    final category = sport == null
                        ? 'Actividad'
                        : '${_trimOrEmpty(sport.iconEmoji)} ${sport.name}'.trim();
                    final rawTitle = _trimOrEmpty(a.title);
                    final desc = _trimOrEmpty(a.description);
                    final title = rawTitle.isNotEmpty ? rawTitle : (desc.isEmpty ? 'Sin título' : desc);
                    final dt = a.dateUtc.toLocal();
                    final place = _trimOrEmpty(a.placeName ?? a.formattedAddress);

                    return _ActivityCard(
                      title: title,
                      category: category,
                      datetime: fmt.format(dt),
                      place: place.isEmpty ? null : place,
                    );
                  }).toList(),
                ),

              const SizedBox(height: 16),

              // Historial
              Text('Historial de actividades',
                  style: t.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (_loading && _history.isEmpty)
                const LinearProgressIndicator()
              else if (_history.isEmpty)
                Text('Aún no hay historial.',
                    style: t.bodySmall?.copyWith(color: muted))
              else
                Column(
                  children: _history.reversed.map((a) {
                    final sport = _sportById[a.sportId];
                    final category = sport == null
                        ? 'Actividad'
                        : '${_trimOrEmpty(sport.iconEmoji)} ${sport.name}'.trim();
                    final rawTitle = _trimOrEmpty(a.title);
                    final desc = _trimOrEmpty(a.description);
                    final title = rawTitle.isNotEmpty ? rawTitle : (desc.isEmpty ? 'Sin título' : desc);
                    final dt = a.dateUtc.toLocal();
                    final place = _trimOrEmpty(a.placeName ?? a.formattedAddress);

                    return _ActivityCard(
                      title: title,
                      category: category,
                      datetime: fmt.format(dt),
                      place: place.isEmpty ? null : place,
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: TeamUpBottomNav(
        currentIndex: 3,
        onTap: (i) => teamUpNavigate(context, i),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final String category, title, datetime;
  final String? place;
  const _ActivityCard({
    required this.category,
    required this.title,
    required this.datetime,
    this.place,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final muted = Theme.of(context).brightness == Brightness.dark
        ? Colors.white70
        : const Color(0xFF6B7280);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: cs.primaryContainer.withOpacity(0.35),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.image, color: cs.onPrimaryContainer),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(category, style: t.labelMedium?.copyWith(color: muted)),
                const SizedBox(height: 2),
                Text(title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: t.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(datetime, style: t.bodySmall?.copyWith(color: muted)),
                if (place != null && place!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(place!, style: t.bodySmall?.copyWith(color: muted)),
                ],
              ],
            ),
          ),
        ]),
      ),
    );
  }
}
