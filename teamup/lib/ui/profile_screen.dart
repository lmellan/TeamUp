import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';  
 

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

const _activeStatuses = ['activa', 'en_curso'];

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Services
  final ProfileService _profileSvc = ProfileServiceSupabase();
  final SportService _sportSvc = SportServiceSupabase();
  final ActivityService _activitySvc = ActivityServiceSupabase();
  final ParticipantService _participantSvc = ParticipantServiceSupabase();

  bool _loading = false;

  Profile? _profile;

  // Chips: solo deportes preferidos del usuario
  List<Sport> _sportsPreferred = [];

  // Para rotular cada actividad por su deporte real:
  final Map<String, Sport> _sportById = {};

  // Datos crudos
  List<Activity> _memberRaw = [];
  List<Activity> _createdRaw = [];

  // Procesados (sin filtros de UI)
  List<Activity> _memberUpcoming = [];
  List<Activity> _memberHistory = [];
  List<Activity> _createdUpcoming = [];
  List<Activity> _createdHistory = [];

  String _trimOrEmpty(String? s) => (s ?? '').trim();

  // ======= Helpers de imágenes =======

  /// URL pública de la imagen del deporte (si existe `image_path`).
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

  /// URL para previsualización de una actividad:
  /// 1) imagen del deporte si existe,
  /// 2) si no, null (placeholder).
  String? _previewUrlFor(Activity a) {
    final sport = _sportById[a.sportId];
    return _sportPublicUrl(sport);
  }

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  // ---------- Carga ----------
  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      // Perfil
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

      // 1) Cargar actividades (miembro + creadas) primero
      final actIds = await _participantSvc.activityIdsByUser(prof.id);
      _memberRaw = actIds.isEmpty
          ? <Activity>[]
          : await _activitySvc.listByIds(actIds, ascending: true);

      _createdRaw = await _activitySvc.listByCoordinator(prof.id);

      // 2) Construir el set de TODOS los sportIds que realmente se usan
      final Set<String> sportIdsUsados = {
        ..._memberRaw.map((a) => a.sportId),
        ..._createdRaw.map((a) => a.sportId),
      }..removeWhere((e) => e.isEmpty);

      // 3) Llenar el mapa _sportById con los deportes usados en actividades
      _sportById.clear();
      if (sportIdsUsados.isNotEmpty) {
        final usados = await _sportSvc.listByIds(sportIdsUsados.toList());
        for (final s in usados) {
          _sportById[s.id] = s;
        }
      }

      // 4) Chips: cargar SOLO preferencias del usuario
      if (prof.preferredSportIds.isNotEmpty) {
        _sportsPreferred = await _sportSvc.listByIds(prof.preferredSportIds);
      } else {
        _sportsPreferred = <Sport>[];
      }

      // Procesar (sin filtros de UI, solo estado/fecha actual)
      _splitUpcomingHistory();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _splitUpcomingHistory() {
    List<Activity> _applyBase(List<Activity> src) {
      final list = src
          .where((a) => _activeStatuses.contains(a.status))
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));
      return list;
    }

    List<Activity> _up(List<Activity> src) {
      final now = DateTime.now().toUtc();
      return src.where((a) => a.date.isAfter(now)).toList();
    }

    List<Activity> _hist(List<Activity> src) {
      final now = DateTime.now().toUtc();
      return src.where((a) => !a.date.isAfter(now)).toList();
    }

    final m = _applyBase(_memberRaw);
    final c = _applyBase(_createdRaw);

    _memberUpcoming = _up(m);
    _memberHistory = _hist(m);

    _createdUpcoming = _up(c);
    _createdHistory = _hist(c);
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final muted = Theme.of(context).brightness == Brightness.dark
        ? Colors.white70
        : const Color(0xFF6B7280);
    final name = _trimOrEmpty(_profile?.name);
    final bio = _trimOrEmpty(_profile?.bio);
    final avatarUrl = _trimOrEmpty(_profile?.avatarUrl);

    return Scaffold(
    appBar: AppBar(
      automaticallyImplyLeading: false, // 👈 sin flecha de retroceso
      title: const Text('Perfil'),
      centerTitle: true,
      leading: IconButton(
        tooltip: 'Cerrar sesión',
        icon: const Icon(Icons.logout),
        onPressed: () async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Cerrar sesión'),
              content: const Text('¿Seguro que deseas cerrar tu sesión?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Cerrar sesión'),
                ),
              ],
            ),
          );

          if (confirmed == true) {
            try {
              await Supabase.instance.client.auth.signOut();
              if (mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/login',
                  (route) => false,
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error al cerrar sesión: $e')),
                );
              }
            }
          }
        },
      ),
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
              await _loadAll();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Perfil actualizado')),
                );
              }
            }
          },
          icon: const Icon(Icons.edit_outlined),
        ),
      ],
    ),

      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadAll,
          child: CustomScrollView(
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Center(
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 48,
                          backgroundColor: cs.primaryContainer,
                          child: avatarUrl.isNotEmpty
                              ? Text(avatarUrl, style: const TextStyle(fontSize: 48))
                              : Text(
                                  (name.isNotEmpty ? name[0] : 'T').toUpperCase(),
                                  style: t.headlineMedium?.copyWith(color: cs.onPrimary),
                                ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          name.isNotEmpty ? name : 'Tu nombre',
                          style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        if (bio.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              bio,
                              textAlign: TextAlign.center,
                              style: t.bodyMedium?.copyWith(color: muted),
                            ),
                          ),
                        const SizedBox(height: 16),

                        // 🎯 Deportes preferidos del usuario (chips)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _sportsPreferred.length <= 1 ? 'Deporte favorito' : 'Deportes favoritos',
                            style: t.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_loading && _sportsPreferred.isEmpty)
                          const LinearProgressIndicator()
                        else if (_sportsPreferred.isEmpty)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Aún no seleccionaste deportes.',
                              style: t.bodySmall?.copyWith(color: muted),
                            ),
                          )
                        else
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _sportsPreferred.map((s) {
                                final emoji = _trimOrEmpty(s.iconEmoji);
                                final label = [
                                  emoji.isEmpty ? '' : emoji,
                                  s.name,
                                ].where((x) => x.isNotEmpty).join('  ');
                                return Chip(
                                  label: Text(label),
                                  backgroundColor: cs.primaryContainer.withOpacity(0.6),
                                  labelStyle: t.bodyMedium?.copyWith(color: cs.onPrimaryContainer),
                                );
                              }).toList(),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              // ===== Sección: Miembro =====
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'Tus actividades',
                    style: t.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              if (_loading && _memberUpcoming.isEmpty && _memberHistory.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                )
              else if (_memberUpcoming.isEmpty && _memberHistory.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Text('No participas en actividades actualmente.',
                        style: t.bodyMedium?.copyWith(color: Colors.grey)),
                  ),
                )
              else ...[
                if (_memberUpcoming.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
                      child: _SectionLabel(texto: 'Próximas'),
                    ),
                  ),
                if (_memberUpcoming.isNotEmpty)
                  SliverList.separated(
                    itemCount: _memberUpcoming.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _activityToCard(_memberUpcoming[i], badge: 'Miembro'),
                    ),
                  ),
                if (_memberHistory.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                      child: _SectionLabel(texto: 'Historial'),
                    ),
                  ),
                if (_memberHistory.isNotEmpty)
                  SliverList.separated(
                    itemCount: _memberHistory.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _activityToCard(_memberHistory.reversed.toList()[i], badge: 'Miembro'),
                    ),
                  ),
              ],

              // ===== Sección: Coordinas =====
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'Tus actividades creadas',
                    style: t.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              if (_loading && _createdUpcoming.isEmpty && _createdHistory.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                )
              else if (_createdUpcoming.isEmpty && _createdHistory.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Text('No has creado actividades aún.',
                        style: t.bodyMedium?.copyWith(color: Colors.grey)),
                  ),
                )
              else ...[
                if (_createdUpcoming.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
                      child: _SectionLabel(texto: 'Próximas'),
                    ),
                  ),
                if (_createdUpcoming.isNotEmpty)
                  SliverList.separated(
                    itemCount: _createdUpcoming.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _activityToCard(_createdUpcoming[i], badge: 'Coordinas'),
                    ),
                  ),
                if (_createdHistory.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                      child: _SectionLabel(texto: 'Historial'),
                    ),
                  ),
                if (_createdHistory.isNotEmpty)
                  SliverList.separated(
                    itemCount: _createdHistory.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _activityToCard(_createdHistory.reversed.toList()[i], badge: 'Coordinas'),
                    ),
                  ),
              ],

              const SliverToBoxAdapter(child: SizedBox(height: 16)),
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

  // Tarjeta estilo Explore con categoría = deporte real + emoji
  Widget _activityToCard(Activity a, {String? badge}) {
    final sport = _sportById[a.sportId];
    final emoji = _trimOrEmpty(sport?.iconEmoji);
    final category = sport == null
        ? '🏷️ ${'Deporte'}'
        : '${emoji.isEmpty ? '🎯' : emoji} ${sport.name}';

    final rawTitle = _trimOrEmpty(a.title);
    final desc = _trimOrEmpty(a.description);
    final title = rawTitle.isNotEmpty ? rawTitle : (desc.isEmpty ? 'Sin título' : desc);
    final place = _trimOrEmpty(a.placeName ?? a.formattedAddress);
    final dt = a.date.toLocal();

    // 👇 imagen: usa la del deporte si existe
    final imageUrl = _previewUrlFor(a);

    return _ExploreCard(
      category: category,
      title: title,
      datetime: DateFormat('dd/MM/yyyy, h:mm a').format(dt),
      place: place.isEmpty ? null : place,
      badge: badge,
      imageUrl: imageUrl, // 👈 nuevo
      onTap: () {
        Navigator.pushNamed(context, '/detail-activity', arguments: a.id);
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String texto;
  const _SectionLabel({required this.texto});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 6,
          height: 18,
          decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(4)),
        ),
        const SizedBox(width: 8),
        Text(texto, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _ExploreCard extends StatelessWidget {
  final String category, title, datetime;
  final String? place;
  final VoidCallback? onTap;
  final String? badge; // “Miembro” / “Coordinas”
  final String? imageUrl; // 👈 nuevo

  const _ExploreCard({
    required this.category,
    required this.title,
    required this.datetime,
    this.place,
    this.onTap,
    this.badge,
    this.imageUrl, // 👈 nuevo
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final muted = Theme.of(context).brightness == Brightness.dark
        ? Colors.white70
        : const Color(0xFF6B7280);

    Widget previewBox() {
      final radius = BorderRadius.circular(12);
      if (imageUrl == null || imageUrl!.isEmpty) {
        return Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: cs.primaryContainer.withOpacity(0.5),
            borderRadius: radius,
          ),
          child: Icon(Icons.event, color: cs.onPrimaryContainer, size: 28),
        );
      }
      return ClipRRect(
        borderRadius: radius,
        child: Image.network(
          imageUrl!,
          width: 96,
          height: 96,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: cs.primaryContainer.withOpacity(0.5),
              borderRadius: radius,
            ),
            child: Icon(Icons.broken_image_outlined,
                color: cs.onPrimaryContainer, size: 28),
          ),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF2B2B2B)
                : cs.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF44473E)
                  : cs.outline.withOpacity(0.2),
            ),
            boxShadow: [
              BoxShadow(
                blurRadius: 10,
                offset: const Offset(0, 2),
                color: Colors.black.withOpacity(
                  Theme.of(context).brightness == Brightness.dark ? 0.25 : 0.06,
                ),
              )
            ],
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              previewBox(), // 👈 imagen del deporte o placeholder
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Categoría + badge (si hay)
                    Row(
                      children: [
                        Expanded(
                          child: Text(category, style: t.labelMedium?.copyWith(color: muted)),
                        ),
                        if (badge != null && badge!.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: cs.secondaryContainer,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              badge!,
                              style: t.labelSmall?.copyWith(color: cs.onSecondaryContainer),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(datetime, style: t.bodySmall?.copyWith(color: muted)),
                    if (place != null && place!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(place!, style: t.bodySmall?.copyWith(color: muted)),
                    ],
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
