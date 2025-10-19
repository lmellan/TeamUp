import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
 
import '../domain/entities/actividad.dart';
import '../domain/entities/deportes.dart';
import '../domain/services/actividad_services.dart';
import '../domain/services/deportes_services.dart';
 
import '../data/actividad_data.dart';
import '../data/deportes_data.dart';

import '../componentes/navigate_bar.dart';
 
const _activeStatuses = ['activa', 'en_curso'];

enum _DateFilter { hoy, semana, mes, ano, todo }

const _dateFilterLabel = {
  _DateFilter.hoy: 'Hoy',
  _DateFilter.semana: 'Semana',
  _DateFilter.mes: 'Mes',
  _DateFilter.ano: 'Año',
  _DateFilter.todo: 'Todo',
};

class ExploreScreen extends StatefulWidget {
  final ActivityService actividades;
  final SportService deportes;

  ExploreScreen({
    super.key,
    ActivityService? actividades,
    SportService? deportes,
  })  : actividades = actividades ?? ActivityServiceSupabase(),
        deportes    = deportes    ?? SportServiceSupabase();

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  bool _loading = false;

 
  final Set<String> _selectedSportIds = {'ALL'};
  _DateFilter _selectedDateFilter = _DateFilter.semana;

  List<Activity> _activities = [];
  List<Sport> _sports = [];
  final Map<String, Sport> _sportById = {};
 

  String _trimOrEmpty(String? s) => (s ?? '').trim();

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await Future.wait([_fetchSports(), _fetchActivities()]);
  }

  Future<void> _fetchSports() async {
    try {
      _sports = await widget.deportes.listAll();
      _sportById
        ..clear()
        ..addEntries(_sports.map((s) => MapEntry(s.id, s)));
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error cargando deportes: $e');
    }
  }

  (DateTime? startUtc, DateTime? endUtc) _dateRangeForFilter(_DateFilter f) {
    final now = DateTime.now();
    final startLocal = DateTime(now.year, now.month, now.day);
    DateTime? start, end;
    switch (f) {
      case _DateFilter.hoy:
        start = startLocal; end = startLocal.add(const Duration(days: 1)); break;
      case _DateFilter.semana:
        start = startLocal; end = startLocal.add(const Duration(days: 7)); break;
      case _DateFilter.mes:
        start = startLocal; end = startLocal.add(const Duration(days: 30)); break;
      case _DateFilter.ano:
        start = startLocal; end = startLocal.add(const Duration(days: 365)); break;
      case _DateFilter.todo:
        return (null, null);
    }
    return (start.toUtc(), end.toUtc());
  }

  Future<void> _fetchActivities() async {
    setState(() => _loading = true);
    try {
      final selected = Set<String>.from(_selectedSportIds);
      final (startUtc, endUtc) = _dateRangeForFilter(_selectedDateFilter);

      final deportesFiltro =
          (selected.isEmpty || selected.contains('ALL')) ? null : selected.toList();

      _activities = await widget.actividades.list(
        startUtc: startUtc,
        endUtc: endUtc,
        estados: _activeStatuses,
        sportIds: deportesFiltro,
        limit: 200,
      );
    } catch (e) {
      debugPrint('Error cargando actividades: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudieron cargar las actividades')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openSportSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (ctx) {
        final t = Theme.of(ctx).textTheme;
        final cs = Theme.of(ctx).colorScheme;

        final tempSelected = Set<String>.from(_selectedSportIds);

        return StatefulBuilder(
          builder: (context, setModalState) {
            void toggleAll() {
              setModalState(() {
                tempSelected
                  ..clear()
                  ..add('ALL');
              });
            }

            void toggleOne(String id) {
              setModalState(() {
                if (tempSelected.contains(id)) {
                  tempSelected.remove(id);
                  if (tempSelected.isEmpty) tempSelected.add('ALL');
                } else {
                  tempSelected.add(id);
                  tempSelected.remove('ALL');
                }
              });
            }

            Widget circleTile({
              required bool selected,
              required Widget title,
              Widget? leading,
              VoidCallback? onTap,
            }) {
              return ListTile(
                leading: leading,
                title: title,
                trailing: Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: selected ? cs.primary : null,
                ),
                onTap: onTap,
              );
            }

            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: Text('Filtrar por deportes', style: t.titleMedium),
                    trailing: TextButton(
                      onPressed: () {
                        setState(() => _selectedSportIds
                          ..clear()
                          ..add('ALL'));
                        Navigator.pop(ctx);
                        _fetchActivities();
                      },
                      child: const Text('Limpiar'),
                    ),
                  ),
                  const Divider(height: 1),

                  circleTile(
                    selected: tempSelected.contains('ALL'),
                    title: const Text('Todos'),
                    onTap: toggleAll,
                  ),
                  const Divider(height: 1),

                  Expanded(
                    child: ListView.separated(
                      itemCount: _sports.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final s = _sports[i];
                        final id = s.id;
                        final emoji = _trimOrEmpty(s.iconEmoji);
                        final name = s.name;
                        final selected = tempSelected.contains(id);

                        return circleTile(
                          selected: selected,
                          onTap: () => toggleOne(id),
                          leading: CircleAvatar(
                            radius: 14,
                            backgroundColor: cs.primary.withOpacity(0.15),
                            child: Text(emoji.isEmpty ? '🎯' : emoji,
                                style: const TextStyle(fontSize: 16)),
                          ),
                          title: Text(name),
                        );
                      },
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancelar'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              setState(() {
                                _selectedSportIds
                                  ..clear()
                                  ..addAll(tempSelected);
                              });
                              Navigator.pop(ctx);
                              _fetchActivities();
                            },
                            child: const Text('Aplicar'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openDateFilterSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (ctx) {
        final t = Theme.of(ctx).textTheme;
        _DateFilter temp = _selectedDateFilter;

        return StatefulBuilder(
          builder: (context, setModalState) {
            Widget tile(_DateFilter f) {
              return RadioListTile<_DateFilter>(
                value: f,
                groupValue: temp,
                onChanged: (v) => setModalState(() => temp = v!),
                title: Text(_dateFilterLabel[f]!),
              );
            }

            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: Text('Filtrar por fecha', style: t.titleMedium),
                    trailing: TextButton(
                      onPressed: () {
                        setState(() => _selectedDateFilter = _DateFilter.todo);
                        Navigator.pop(ctx);
                        _fetchActivities();
                      },
                      child: const Text('Limpiar'),
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView(
                      children: [
                        tile(_DateFilter.hoy),
                        tile(_DateFilter.semana),
                        tile(_DateFilter.mes),
                        tile(_DateFilter.ano),
                        tile(_DateFilter.todo),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancelar'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              setState(() => _selectedDateFilter = temp);
                              Navigator.pop(ctx);
                              _fetchActivities();
                            },
                            child: const Text('Aplicar'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _notReady(String what) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$what: próximamente')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
 
    final muted = Theme.of(context).brightness == Brightness.dark
        ? Colors.white70
        : const Color(0xFF6B7280);

    final isAllSports = _selectedSportIds.contains('ALL');
    final sportsLabel = isAllSports
        ? 'Deportes: Todos'
        : 'Deportes (${_selectedSportIds.length})';
    final dateLabel = 'Fecha: ${_dateFilterLabel[_selectedDateFilter]}';

    return Scaffold(
      appBar: AppBar(title: const Text('Explorar'), centerTitle: true),
      body: RefreshIndicator(
        onRefresh: () async {
          await _fetchSports();
          await _fetchActivities();
        },
        child: CustomScrollView(
          slivers: [
            // Filtros
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterPill(
                        label: sportsLabel,
                        icon: Icons.sports_soccer_outlined,
                        onTap: _openSportSheet,
                      ),
                      const SizedBox(width: 8),
                      _FilterPill(
                        label: dateLabel,
                        icon: Icons.filter_alt_outlined,
                        onTap: _openDateFilterSheet,
                      ),
                      const SizedBox(width: 8),
                      _FilterPill(
                        label: 'Lugar',
                        icon: Icons.place_outlined,
                        onTap: () => _notReady('Filtro por lugar'),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Título
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text(
                  'Próximas actividades',
                  style: t.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ),

            // Lista
            if (_loading && _activities.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (_activities.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  child: Text(
                    'No hay actividades activas con estos filtros.',
                    style: t.bodyMedium?.copyWith(color: muted),
                  ),
                ),
              )
            else
              SliverList.separated(
                itemCount: _activities.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final a = _activities[i];

                  final sport = _sportById[a.sportId];
                  final sportLabel = sport == null
                      ? 'Actividad'
                      : '${_trimOrEmpty(sport.iconEmoji).isEmpty ? '🎯' : _trimOrEmpty(sport.iconEmoji)} ${sport.name}';

                  final rawTitle = _trimOrEmpty(a.title);
                  final desc = _trimOrEmpty(a.description);
                  final title = rawTitle.isNotEmpty
                      ? rawTitle
                      : (desc.isEmpty ? 'Sin título' : desc);

                  final place = _trimOrEmpty(a.placeName ?? a.formattedAddress);
                  final dt = a.date.toLocal();

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _ExploreCard(
                      category: sportLabel,
                      title: title,
                      datetime: DateFormat('dd/MM/yyyy, h:mm a').format(dt),
                      place: place.isEmpty ? null : place,
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          '/detail-activity',
                          arguments: a.id, // 👈 pasamos el id
                        );
                      },
                    ),
                  );
                },
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
          ],
        ),
      ),

      bottomNavigationBar: TeamUpBottomNav(
        currentIndex: 0,
        onTap: (i) => teamUpNavigate(context, i),
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _FilterPill({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 260),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? cs.primary.withValues(alpha: 0.15)
              : cs.primaryContainer.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: cs.onPrimaryContainer),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: t.labelLarge?.copyWith(
                  color: cs.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.expand_more, size: 18, color: cs.onPrimaryContainer),
          ],
        ),
      ),
    );
  }
}

class _ExploreCard extends StatelessWidget {
  final String category, title, datetime;
  final String? place;
  final VoidCallback? onTap; // 👈 nuevo

  const _ExploreCard({
    required this.category,
    required this.title,
    required this.datetime,
    this.place,
    this.onTap, // 👈 nuevo
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final muted = Theme.of(context).brightness == Brightness.dark
        ? Colors.white70
        : const Color(0xFF6B7280);

    // Usamos Material + InkWell para ripple y bordes redondeados
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap, // 👈 navega cuando se toca
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
                spreadRadius: 0,
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
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.image, color: cs.onPrimaryContainer, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(category, style: t.labelMedium?.copyWith(color: muted)),
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
