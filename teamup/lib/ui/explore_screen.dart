import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/entities/actividad.dart';
import '../domain/entities/deportes.dart';
import '../domain/services/actividad_services.dart';
import '../domain/services/deportes_services.dart';

import '../data/actividad_data.dart';
import '../data/deportes_data.dart';

// 👇 Catálogos de regiones/comunas (ids int)
import '../domain/entities/localidades/region.dart';
import '../domain/entities/localidades/comuna.dart';
import '../domain/services/localidades_service.dart';
import '../data/localidad.dart';

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
        deportes = deportes ?? SportServiceSupabase();

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  bool _loading = false;

  final Set<String> _selectedSportIds = {'ALL'};
  _DateFilter _selectedDateFilter = _DateFilter.semana;

  // ======== Región/Comuna (id int) ========
  final CatalogoLocalidadesService _locSvc = CatalogoLocalidadesSupabase();
  List<RegionCL> _regiones = [];
  List<ComunaCL> _comunas = [];
  RegionCL? _selectedRegion;

  // 👉 ahora soporta múltiples comunas y “todas las comunas”
  final Set<int> _selectedComunaIds = <int>{};
  bool _todasComunasDeRegion = false;
  String _comunaQuery = '';

  List<Activity> _activities = [];
  List<Sport> _sports = [];
  final Map<String, Sport> _sportById = {};

  String _trimOrEmpty(String? s) => (s ?? '').trim();

  // ========= Helpers imágenes (solo para cards) =========
  String? _sportPublicUrl(Sport? s) {
    if (s == null) return null;
    final path = s.imagePath?.trim();
    if (path == null || path.isEmpty) return null;
    final clean = path.startsWith('deportes/')
        ? path.replaceFirst('deportes/', '')
        : path;
    return Supabase.instance.client.storage.from('deportes').getPublicUrl(clean);
  }

  String? _previewUrlFor(Activity a) {
    final sport = _sportById[a.sportId];
    return _sportPublicUrl(sport);
  }

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await Future.wait([
      _fetchSports(),
      _fetchRegiones(),
      _fetchActivities(),
    ]);
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

  Future<void> _fetchRegiones() async {
    try {
      _regiones = await _locSvc.listarRegiones();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error cargando regiones: $e');
    }
  }

  Future<void> _fetchComunas(int regionId) async {
    try {
      _comunas = await _locSvc.listarComunasPorRegion(regionId);
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error cargando comunas: $e');
    }
  }

  (DateTime? startUtc, DateTime? endUtc) _dateRangeForFilter(_DateFilter f) {
    final now = DateTime.now();
    final startLocal = DateTime(now.year, now.month, now.day);
    DateTime? start, end;
    switch (f) {
      case _DateFilter.hoy:
        start = startLocal;
        end = startLocal.add(const Duration(days: 1));
        break;
      case _DateFilter.semana:
        start = startLocal;
        end = startLocal.add(const Duration(days: 7));
        break;
      case _DateFilter.mes:
        start = startLocal;
        end = startLocal.add(const Duration(days: 30));
        break;
      case _DateFilter.ano:
        start = startLocal;
        end = startLocal.add(const Duration(days: 365));
        break;
      case _DateFilter.todo:
        return (null, null);
    }
    return (start.toUtc(), end.toUtc());
  }

  // ======== Coincidencia por texto en dirección/lugar (región/comuna múltiple) ========
  bool _matchesRegionComuna(Activity a) {
    final direccion = _trimOrEmpty(a.formattedAddress ?? a.placeName);
    if (direccion.isEmpty) return false;
    final p = direccion.toLowerCase();

    final hayRegion = _selectedRegion != null;
    final hayComunas = _selectedComunaIds.isNotEmpty;
    final usarTodas = _todasComunasDeRegion && hayRegion;

    // Si no hay filtros de lugar, pasa.
    if (!hayRegion && !hayComunas) return true;

    // Verificar región
    final regionOk = !hayRegion
        ? true
        : p.contains(_selectedRegion!.nombre.toLowerCase());

    // Si están “todas las comunas” activas, basta con que coincida la región
    if (usarTodas) return regionOk;

    // Si hay comunas específicas seleccionadas
    if (hayComunas) {
      final nombresSeleccionadas = _comunas
          .where((c) => _selectedComunaIds.contains(c.id))
          .map((c) => c.nombre.toLowerCase())
          .toList();

      final algunaComunaOk =
          nombresSeleccionadas.any((n) => p.contains(n));

      if (hayRegion) {
        return regionOk && algunaComunaOk;
      } else {
        return algunaComunaOk;
      }
    }

    // Solo región
    return regionOk;
  }

  Future<void> _fetchActivities() async {
    setState(() => _loading = true);
    try {
      final selected = Set<String>.from(_selectedSportIds);
      final (startUtc, endUtc) = _dateRangeForFilter(_selectedDateFilter);

      final deportesFiltro =
          (selected.isEmpty || selected.contains('ALL')) ? null : selected.toList();

      final base = await widget.actividades.list(
        startUtc: startUtc,
        endUtc: endUtc,
        estados: _activeStatuses,
        sportIds: deportesFiltro,
        limit: 400,
      );

      _activities = base.where(_matchesRegionComuna).toList();
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

  // ============== Filtro por deportes (emoji consistente, mismo “círculo”) ==============
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

            Widget pillTile({
              required bool selected,
              required Widget title,
              required String emoji,
              VoidCallback? onTap,
            }) {
              return ListTile(
                leading: CircleAvatar(
                  radius: 14,
                  backgroundColor: cs.primary.withOpacity(0.15),
                  child: Text(
                    emoji.isEmpty ? '🎯' : emoji,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                title: title,
                trailing: Icon(
                  selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
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
                  pillTile(
                    selected: tempSelected.contains('ALL'),
                    title: const Text('Todos'),
                    emoji: '🎯',
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
                        final selected = tempSelected.contains(id);
                        final emoji = _trimOrEmpty(s.iconEmoji);

                        return pillTile(
                          selected: selected,
                          onTap: () => toggleOne(id),
                          emoji: emoji,
                          title: Text(s.name),
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

  // ============== Filtro de fecha ==============
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

  // ============== Bottom sheet de LUGAR (Región/Comuna múltiple + “todas”) ==============
  Future<void> _openLugarSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true, 
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85, //c limita altura al 85%
      ),
      builder: (ctx) {
        final t = Theme.of(ctx).textTheme;
        final cs = Theme.of(ctx).colorScheme;

        RegionCL? tempRegion = _selectedRegion;
        final Set<int> tempComunaIds = Set<int>.from(_selectedComunaIds);
        bool tempTodas = _todasComunasDeRegion;
        String tempQuery = _comunaQuery;

        return StatefulBuilder(
          builder: (context, setModalState) {
            final comunasFiltradas = _comunas.where((c) {
              if (tempQuery.trim().isEmpty) return true;
              return c.nombre.toLowerCase().contains(tempQuery.toLowerCase());
            }).toList();

            Future<void> onRegionChanged(RegionCL? r) async {
              setModalState(() {
                tempRegion = r;
                tempComunaIds.clear();
                tempTodas = false;
                tempQuery = '';
                _comunas = [];
              });
              if (r != null) {
                await _fetchComunas(r.id); // int
                setModalState(() {}); // refresca lista
              }
            }

            Widget seleccionarTodasTile() {
              if (tempRegion == null) return const SizedBox.shrink();
              return ListTile(
                leading: CircleAvatar(
                  radius: 14,
                  backgroundColor: cs.primary.withOpacity(0.12),
                  child: const Icon(Icons.select_all, size: 16),
                ),
                title: Text('Seleccionar todas las comunas de ${tempRegion!.nombre}'),
                trailing: Icon(
                  tempTodas ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: tempTodas ? cs.primary : null,
                ),
                onTap: () {
                  setModalState(() {
                    tempTodas = !tempTodas;
                    if (tempTodas) {
                      tempComunaIds.clear();
                    }
                  });
                },
              );
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      title: Text('Filtrar por lugar', style: t.titleMedium),
                      subtitle: const Text('Selecciona Región y comunas (opcional)'),
                      trailing: TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedRegion = null;
                            _selectedComunaIds.clear();
                            _todasComunasDeRegion = false;
                            _comunaQuery = '';
                          });
                          Navigator.pop(ctx);
                          _fetchActivities();
                        },
                        child: const Text('Limpiar'),
                      ),
                    ),
                    const Divider(height: 1),

                    // Región (diseño uniforme: borde redondo y denso)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: DropdownButtonFormField<RegionCL>(
                        value: tempRegion,
                        isExpanded: true, //aki se evita overflow del icono
                        decoration: InputDecoration(
                          labelText: 'Región',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          isDense: true, // <- reduce alturas y ayuda al layout
                        ),
                        items: _regiones
                            .map((r) => DropdownMenuItem(
                                  value: r,
                                  child: Text(r.nombre),
                                ))
                            .toList(),
                        onChanged: (r) => onRegionChanged(r),
                      ),
                    ),

                    // Buscador de comuna
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: TextField(
                        enabled: tempRegion != null,
                        decoration: InputDecoration(
                          labelText: 'Buscar comuna',
                          hintText: 'Escribe para filtrar…',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          isDense: true,
                          prefixIcon: const Icon(Icons.search),
                        ),
                        onChanged: (v) => setModalState(() => tempQuery = v),
                      ),
                    ),

                    // Seleccionar todas
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: seleccionarTodasTile(),
                    ),

                    // Lista de comunas con Expanded para que sea scrolleable
                    Expanded(
                      child: ListView.separated(
                        shrinkWrap: true, // Añade esto
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                        itemCount: tempRegion == null ? 0 : comunasFiltradas.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final c = comunasFiltradas[i];
                          final selected = tempComunaIds.contains(c.id);

                          return ListTile(
                            enabled: tempRegion != null,
                            leading: CircleAvatar(
                              radius: 14,
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withOpacity(0.12),
                              child: const Icon(Icons.location_on_outlined, size: 16),
                            ),
                            title: Text(c.nombre),
                            trailing: Icon(
                              // círculo consistente
                              selected
                                  ? Icons.check_circle
                                  : Icons.circle_outlined,
                              color: selected
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                            ),
                            onTap: () {
                              setModalState(() {
                                if (selected) {
                                  tempComunaIds.remove(c.id);
                                } else {
                                  tempComunaIds.add(c.id);
                                }
                                // si selecciono alguna, desactivo "todas"
                                if (tempComunaIds.isNotEmpty) {
                                  tempTodas = false;
                                }
                              });
                            },
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
                                  _selectedRegion = tempRegion;
                                  _selectedComunaIds
                                    ..clear()
                                    ..addAll(tempComunaIds);
                                  _todasComunasDeRegion = tempTodas;
                                  _comunaQuery = tempQuery;
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
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    final muted = Theme.of(context).brightness == Brightness.dark
        ? Colors.white70
        : const Color(0xFF6B7280);

    final isAllSports = _selectedSportIds.contains('ALL');
    final sportsLabel =
        isAllSports ? 'Deportes: Todos' : 'Deportes (${_selectedSportIds.length})';
    final dateLabel = 'Fecha: ${_dateFilterLabel[_selectedDateFilter]}';

    // Label Lugar
    String lugarLabel;
    if (_selectedRegion == null && _selectedComunaIds.isEmpty) {
      lugarLabel = 'Lugar: Todos';
    } else if (_selectedRegion != null && _todasComunasDeRegion) {
      lugarLabel = 'Lugar: Todas las comunas, ${_selectedRegion!.nombre}';
    } else if (_selectedRegion != null && _selectedComunaIds.isNotEmpty) {
      final n = _selectedComunaIds.length;
      lugarLabel = 'Lugar: $n comuna${n == 1 ? '' : 's'}, ${_selectedRegion!.nombre}';
    } else if (_selectedRegion != null) {
      lugarLabel = 'Lugar: ${_selectedRegion!.nombre}';
    } else {
      lugarLabel = 'Lugar: ${_selectedComunaIds.length} comunas';
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false, // Oculta la flecha de retroceso
        
        title: const Text('Explorar'), 
        centerTitle: true),
      body: RefreshIndicator(
        onRefresh: () async {
          await _fetchSports();
          await _fetchRegiones();
          if (_selectedRegion != null) {
            await _fetchComunas(_selectedRegion!.id);
          }
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
                        label: lugarLabel,
                        icon: Icons.place_outlined,
                        onTap: _openLugarSheet,
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
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
                  final emoji = _trimOrEmpty(sport?.iconEmoji);
                  final sportLabel = sport == null
                      ? 'Actividad'
                      : '${emoji.isEmpty ? '🎯' : emoji} ${sport.name}';

                  final rawTitle = _trimOrEmpty(a.title);
                  final desc = _trimOrEmpty(a.description);
                  final title =
                      rawTitle.isNotEmpty ? rawTitle : (desc.isEmpty ? 'Sin título' : desc);

                  final place = _trimOrEmpty(a.placeName ?? a.formattedAddress);
                  final dt = a.date.toLocal();

                  final previewUrl = _previewUrlFor(a);

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _ExploreCard(
                      category: sportLabel,
                      title: title,
                      datetime: DateFormat('dd/MM/yyyy, h:mm a').format(dt),
                      place: place.isEmpty ? null : place,
                      imageUrl: previewUrl,
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          '/detail-activity',
                          arguments: a.id,
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
              ? cs.primary.withOpacity(0.15)
              : cs.primaryContainer.withOpacity(0.8),
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
  final String? imageUrl;
  final VoidCallback? onTap;

  const _ExploreCard({
    required this.category,
    required this.title,
    required this.datetime,
    this.place,
    this.imageUrl,
    this.onTap,
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
          child: Icon(Icons.image, color: cs.onPrimaryContainer, size: 28),
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
              previewBox(),
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
                      style:
                          t.titleMedium?.copyWith(fontWeight: FontWeight.w700),
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
