import 'package:flutter/material.dart';

import '../../domain/entities/perfil.dart';
import '../../data/perfil_data.dart';
import '../../domain/services/perfil_services.dart';

import '../../domain/entities/deportes.dart';
import '../../domain/services/deportes_services.dart';
import '../../data/deportes_data.dart';

// === Catálogos y preferencias de localidades ===
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/localidades/region.dart';
import '../../domain/entities/localidades/comuna.dart';
import '../../domain/services/localidades_service.dart';
import '../../domain/entities/localidades/preferencia_localidad.dart';
import '../../data/localidad.dart';

class EditProfileScreen extends StatefulWidget {
  final Profile? profile;
  const EditProfileScreen({super.key, required this.profile});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  // Servicios
  final ProfileService _profileService = ProfileServiceSupabase();
  final SportService _sportService = SportServiceSupabase();
  final CatalogoLocalidadesService _catalogoSvc = CatalogoLocalidadesSupabase();
  final PreferredLocationsService _prefsLocSvc = PreferredLocationsServiceSupabase();

  // Controllers
  late final TextEditingController _nameController;
  late final TextEditingController _bioController;

  // Estado perfil
  List<Sport> _sports = <Sport>[];
  List<String> _selectedSportIds = <String>[];
  String? _selectedAvatar; // emoji guardado en avatarUrl
  bool _notificar = true;
  bool _isLoading = false;
  bool _loadingSports = true;
  bool _loadingLocalidades = true;

  // Control de cambios sin guardar
  bool _dirty = false;

  // Catálogos localidades
  List<RegionCL> _regiones = <RegionCL>[];
  final Map<int, List<ComunaCL>> _comunasPorRegion = <int, List<ComunaCL>>{};

  // Bloques Región → Comunas
  final List<_BloqueRegion> _bloques = <_BloqueRegion>[];

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _nameController = TextEditingController(text: p?.name ?? '');
    _bioController = TextEditingController(text: p?.bio ?? '');
    _selectedAvatar = p?.avatarUrl;
    _selectedSportIds = List<String>.from(p?.preferredSportIds ?? []);
    _notificar = p?.notifyNewActivity ?? true;

    // Listeners para marcar cambios
    _nameController.addListener(_markDirty);
    _bioController.addListener(_markDirty);

    _fetchSports();
    _cargarLocalidadesYPrefs();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _markDirty() {
    if (!_dirty) {
      setState(() {
        _dirty = true;
      });
    }
  }

  Future<void> _fetchSports() async {
    setState(() => _loadingSports = true);
    try {
      final sports = await _sportService.listAll();
      final valid = sports.map((s) => s.id).toSet();
      setState(() {
        _sports = sports;
        _selectedSportIds =
            _selectedSportIds.where((id) => valid.contains(id)).toList();
      });
    } catch (_) {
      setState(() => _sports = <Sport>[]);
    } finally {
      setState(() => _loadingSports = false);
    }
  }

  Future<void> _cargarLocalidadesYPrefs() async {
    setState(() => _loadingLocalidades = true);
    try {
      // Catálogos
      final regiones = await _catalogoSvc.listarRegiones();
      final comunasPorRegion = <int, List<ComunaCL>>{};
      for (final r in regiones) {
        final comunas = await _catalogoSvc.listarComunasPorRegion(r.id);
        comunas.sort((a, b) => a.nombre.compareTo(b.nombre));
        comunasPorRegion[r.id] = comunas;
      }

      // Reconstruir bloques desde preferencias guardadas
      final p = widget.profile;
      final bloques = <_BloqueRegion>[];
      if (p != null && p.id.isNotEmpty) {
        final prefs = await _prefsLocSvc.listar(p.id);
        final porRegion = <int, Set<int>>{};
        final regionesCompletas = <int>{};

        for (final pref in prefs) {
          if (pref.regionId != null && pref.comunaId == null) {
            regionesCompletas.add(pref.regionId!);
          } else if (pref.regionId != null && pref.comunaId != null) {
            porRegion.putIfAbsent(pref.regionId!, () => <int>{}).add(pref.comunaId!);
          }
        }

        for (final rid in regionesCompletas) {
          bloques.add(_BloqueRegion(regionId: rid, todaLaRegion: true, comunaIds: <int>{}));
        }
        for (final entry in porRegion.entries) {
          bloques.add(_BloqueRegion(
            regionId: entry.key,
            todaLaRegion: false,
            comunaIds: entry.value,
          ));
        }
      }

      setState(() {
        _regiones = regiones;
        _comunasPorRegion
          ..clear()
          ..addAll(comunasPorRegion);
        _bloques
          ..clear()
          ..addAll(bloques.isEmpty ? <_BloqueRegion>[_BloqueRegion.empty()] : bloques);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudieron cargar las localidades')),
      );
      setState(() {
        if (_bloques.isEmpty) _bloques.add(_BloqueRegion.empty());
      });
    } finally {
      setState(() => _loadingLocalidades = false);
    }
  }

  Future<void> _updateProfile() async {
    if (widget.profile == null) return;
    setState(() => _isLoading = true);
    try {
      // 1) Perfil base
      final actualizado = widget.profile!.copyWith(
        name: _nameController.text.trim(),
        bio: _bioController.text.trim(),
        preferredSportIds: _selectedSportIds,
        avatarUrl: _selectedAvatar,
        notifyNewActivity: _notificar,
      );
      await _profileService.updateMyProfile(actualizado);

      // 2) Preferencias de localidades
      await _persistirBloques(actualizado.id);

      if (!mounted) return;
      _dirty = false; // ✅ ya no hay cambios pendientes
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil actualizado con éxito')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ocurrió un error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _persistirBloques(String userId) async {
    final db = Supabase.instance.client;
    await db.from('user_preferred_locations').delete().eq('user_id', userId);

    for (final b in _bloques) {
      if (b.regionId == null) continue;

      final rid = b.regionId!;
      if (b.todaLaRegion) {
        // Expandir a TODAS las comunas de la región
        final comunas = _comunasPorRegion[rid] ?? <ComunaCL>[];
        for (final c in comunas) {
          await _prefsLocSvc.agregarComuna(userId, rid, c.id);
        }
      } else {
        for (final cid in b.comunaIds) {
          await _prefsLocSvc.agregarComuna(userId, rid, cid);
        }
      }
    }
  }

  Future<String?> showEmojiPicker(BuildContext context) async {
    final emojis = [
      '😀','😺','🤖','🏀','🚴‍♂️','🏊‍♂️','🎮','🍕','🐶','🐱','👽','🦄','🐻','🐨','🐼'
    ];
    return showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Selecciona tu avatar'),
        children: emojis
            .map(
              (emoji) => SimpleDialogOption(
                onPressed: () => Navigator.pop(context, emoji),
                child: Center(child: Text(emoji, style: const TextStyle(fontSize: 36))),
              ),
            )
            .toList(),
      ),
    );
  }

  void _anadirBloque() {
    setState(() {
      _bloques.add(_BloqueRegion.empty());
      _markDirty();
    });
  }

  void _quitarBloque(int index) {
    setState(() {
      _bloques.removeAt(index);
      if (_bloques.isEmpty) {
        _bloques.add(_BloqueRegion.empty());
      }
      _markDirty();
    });
  }

  // === Confirmación al salir si hay cambios sin guardar ===
  Future<bool> _onWillPop() async {
    if (_isLoading) return false; // evita salir mientras guarda
    if (!_dirty) return true;
    final salir = await _confirmarSalirSinGuardar();
    return salir ?? false;
  }

  Future<bool?> _confirmarSalirSinGuardar() {
    final cs = Theme.of(context).colorScheme;
    return showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Cambios sin guardar'),
          content: const Text('Tienes cambios sin guardar. ¿Deseas descartarlos y salir?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Seguir editando'),
            ),
            FilledButton(
              style: ButtonStyle(backgroundColor: WidgetStatePropertyAll(cs.error)),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Descartar y salir'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    final nombre = _nameController.text.trim();
    final inicial = nombre.isNotEmpty ? nombre[0].toUpperCase() : 'U';

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Editar perfil', style: TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: true,
          leading: BackButton(
            onPressed: () async {
              if (await _onWillPop()) {
                if (mounted) Navigator.of(context).maybePop();
              }
            },
          ),
          actions: [
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(right: 16.0),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
              )
            else
              IconButton(
                icon: const Icon(Icons.check),
                onPressed: _updateProfile,
                tooltip: 'Guardar',
              ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  // Avatar
                  Center(
                    child: GestureDetector(
                      onTap: () async {
                        final selected = await showEmojiPicker(context);
                        if (selected != null) {
                          setState(() {
                            _selectedAvatar = selected;
                            _markDirty();
                          });
                        }
                      },
                      child: CircleAvatar(
                        radius: 48,
                        child: _selectedAvatar != null && _selectedAvatar!.isNotEmpty
                            ? Text(_selectedAvatar!, style: const TextStyle(fontSize: 48))
                            : Text(inicial, style: const TextStyle(fontSize: 48)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Toca para cambiar avatar',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Nombre
                  _buildTextField(context, label: 'Nombre', controller: _nameController),

                  const SizedBox(height: 16),

                  // Bio
                  _buildTextArea(context,
                      label: 'Biografía / Descripción', controller: _bioController),

                  const SizedBox(height: 16),

                  // Deportes favoritos
                  Text('Deportes favoritos', style: t.titleSmall?.copyWith(color: cs.onSurface)),
                  const SizedBox(height: 8),
                  if (_loadingSports)
                    const LinearProgressIndicator()
                  else
                    _sports.isEmpty
                        ? Text(
                            'No hay deportes disponibles.',
                            style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                          )
                        : Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _sports.map((sport) {
                              final seleccionado = _selectedSportIds.contains(sport.id);
                              var etiqueta = sport.name;
                              if (sport.iconEmoji != null && sport.iconEmoji!.isNotEmpty) {
                                etiqueta = '${sport.iconEmoji!}  ${sport.name}';
                              }
                              return FilterChip(
                                label: Text(etiqueta),
                                selected: seleccionado,
                                onSelected: (v) {
                                  setState(() {
                                    if (v) {
                                      _selectedSportIds.add(sport.id);
                                    } else {
                                      _selectedSportIds.remove(sport.id);
                                    }
                                    _markDirty();
                                  });
                                },
                              );
                            }).toList(),
                          ),

                  const SizedBox(height: 24),

                  // ===== Localidades de preferencia =====
                  Text('Localidades de preferencia', style: t.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    'Selecciona regiones y, si quieres, comunas dentro de ellas.',
                    style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),

                  if (_loadingLocalidades)
                    const LinearProgressIndicator()
                  else
                    ..._bloques.asMap().entries.map((entry) {
                      final index = entry.key;
                      final bloque = entry.value;
                      return SelectorRegionComunas(
                        regiones: _regiones,
                        comunasPorRegion: _comunasPorRegion,
                        bloque: bloque,
                        onQuitar: () => _quitarBloque(index),
                        onCambio: () {
                          setState(() {});
                          _markDirty();
                        },
                      );
                    }).toList(),

                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _anadirBloque,
                    icon: const Icon(Icons.add),
                    label: const Text('Añadir otra región'),
                  ),

                  const SizedBox(height: 24),

                  // Switch de notificaciones
                  SwitchListTile(
                    value: _notificar,
                    onChanged: (v) {
                      setState(() {
                        _notificar = v;
                        _markDirty();
                      });
                    },
                    title: const Text('Recibir avisos de nuevas actividades'),
                    subtitle: Text(
                      'Te notificaremos cuando aparezcan actividades de tu interés.',
                      style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Botón guardar adicional
                  SizedBox(
                    height: 56,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.save_outlined),
                      onPressed: _isLoading ? null : _updateProfile,
                      label: const Text('Guardar cambios'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(BuildContext context,
      {required String label, required TextEditingController controller}) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.w500, color: cs.onSurface)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 16.0),
          ),
        ),
      ],
    );
  }

  Widget _buildTextArea(BuildContext context,
      {required String label, required TextEditingController controller}) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.w500, color: cs.onSurface)),
        const SizedBox(height: 8),
        SizedBox(
          height: 120,
          child: TextFormField(
            controller: controller,
            expands: true,
            minLines: null,
            maxLines: null,
            textAlignVertical: TextAlignVertical.center,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 16.0),
            ),
          ),
        ),
      ],
    );
  }
}

// ===== Modelo interno del bloque simple =====
class _BloqueRegion {
  int? regionId;            // región elegida
  bool todaLaRegion;        // si true, ignora comunas
  final Set<int> comunaIds; // comunas marcadas (si no es toda la región)

  _BloqueRegion({
    required this.regionId,
    required this.todaLaRegion,
    required this.comunaIds,
  });

  factory _BloqueRegion.empty() {
    return _BloqueRegion(regionId: null, todaLaRegion: true, comunaIds: <int>{});
  }
}

// ===== Widget reutilizable: Selector Región → Comunas =====
class SelectorRegionComunas extends StatelessWidget {
  final List<RegionCL> regiones;
  final Map<int, List<ComunaCL>> comunasPorRegion;
  final _BloqueRegion bloque;
  final VoidCallback onQuitar;
  final VoidCallback onCambio;

  const SelectorRegionComunas({
    super.key,
    required this.regiones,
    required this.comunasPorRegion,
    required this.bloque,
    required this.onQuitar,
    required this.onCambio,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    final List<ComunaCL> comunas =
        bloque.regionId == null ? <ComunaCL>[] : (comunasPorRegion[bloque.regionId!] ?? <ComunaCL>[]);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: bloque.regionId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Región',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.public_outlined),
                    ),
                    items: regiones.map((r) {
                      return DropdownMenuItem<int>(
                        value: r.id,
                        child: Text(
                          r.nombre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                        ),
                      );
                    }).toList(),
                    selectedItemBuilder: (_) => regiones.map((r) {
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          r.nombre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                        ),
                      );
                    }).toList(),
                    onChanged: (rid) {
                      if (rid == null) return;
                      // Al elegir región, por defecto "toda la región"
                      bloque.regionId = rid;
                      bloque.todaLaRegion = true;
                      bloque.comunaIds.clear();
                      onCambio();
                    },
                    validator: (v) => v == null ? 'Selecciona una región' : null,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'Quitar bloque',
                  onPressed: onQuitar,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),

            const SizedBox(height: 12),

            SwitchListTile.adaptive(
              value: bloque.todaLaRegion,
              title: const Text('Seleccionar toda la región'),
              subtitle: Text(
                'Ignora comunas individuales',
                style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              onChanged: (v) {
                if (bloque.regionId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Primero elige una región')),
                  );
                  return;
                }
                bloque.todaLaRegion = v;
                if (v) {
                  bloque.comunaIds.clear();
                }
                onCambio();
              },
              contentPadding: EdgeInsets.zero,
            ),

            if (!bloque.todaLaRegion && bloque.comunaIds.isNotEmpty) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: bloque.comunaIds.map((cid) {
                    final c = _buscarComuna(cid, comunas, bloque.regionId);
                    return InputChip(
                      label: Text(c.nombre),
                      onDeleted: () {
                        bloque.comunaIds.remove(cid);
                        onCambio();
                      },
                    );
                  }).toList(),
                ),
              ),
            ],

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      if (bloque.regionId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Primero elige una región')),
                        );
                        return;
                      }
                      await _abrirSheetComunas(
                        context: context,
                        titulo: 'Comunas de la región',
                        comunas: comunas,
                        bloque: bloque,
                        onCambio: onCambio,
                      );
                    },
                    icon: const Icon(Icons.location_city_outlined),
                    label: const Text('Elegir comunas'),
                  ),
                ),
                const SizedBox(width: 12),
                _BadgeSeleccion(texto: _textoBadge(bloque)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _textoBadge(_BloqueRegion b) {
    if (b.todaLaRegion) {
      if (b.regionId == null) {
        return 'Toda la región';
      } else {
        final comunas = comunasPorRegion[b.regionId!] ?? <ComunaCL>[];
        return 'Toda la región (${comunas.length} comunas)';
      }
    } else {
      return '${b.comunaIds.length} comunas';
    }
  }

  ComunaCL _buscarComuna(int cid, List<ComunaCL> comunas, int? regionId) {
    for (final c in comunas) {
      if (c.id == cid) return c;
    }
    final rid = regionId ?? -1;
    return ComunaCL(id: cid, nombre: 'Comuna $cid', regionId: rid);
  }

  Future<void> _abrirSheetComunas({
    required BuildContext context,
    required String titulo,
    required List<ComunaCL> comunas,
    required _BloqueRegion bloque,
    required VoidCallback onCambio,
  }) async {
    if (bloque.regionId == null) return;

    final controladorBusqueda = TextEditingController();
    final valorTodaRegion = ValueNotifier<bool>(bloque.todaLaRegion);
    final seleccionTemporal = ValueNotifier<Set<int>>(Set<int>.from(bloque.comunaIds));
    final filtroTexto = ValueNotifier<String>('');

    void actualizarFiltro() {
      final txt = controladorBusqueda.text.trim().toLowerCase();
      filtroTexto.value = txt;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final t = Theme.of(ctx).textTheme;

        List<ComunaCL> filtrar(List<ComunaCL> base, String q) {
          if (q.isEmpty) return base;
          final qq = q.toLowerCase();
          return base.where((c) => c.nombre.toLowerCase().contains(qq)).toList();
        }

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 12,
            left: 16,
            right: 16,
            top: 8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(titulo, style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),

              TextField(
                controller: controladorBusqueda,
                onChanged: (_) => actualizarFiltro(),
                decoration: const InputDecoration(
                  hintText: 'Buscar comuna',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 8),

              ValueListenableBuilder<bool>(
                valueListenable: valorTodaRegion,
                builder: (ctx2, toda, _) {
                  return SwitchListTile.adaptive(
                    value: toda,
                    title: const Text('Seleccionar toda la región'),
                    onChanged: (v) {
                      valorTodaRegion.value = v;
                      if (v) {
                        seleccionTemporal.value = <int>{};
                      }
                    },
                    contentPadding: EdgeInsets.zero,
                  );
                },
              ),

              ValueListenableBuilder<Set<int>>(
                valueListenable: seleccionTemporal,
                builder: (ctx3, setSel, _) {
                  final txt = '${setSel.length} seleccionadas';
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Text(txt, style: t.labelLarge?.copyWith(color: cs.primary)),
                  );
                },
              ),
              const SizedBox(height: 8),

              Flexible(
                child: ValueListenableBuilder<String>(
                  valueListenable: filtroTexto,
                  builder: (ctx4, q, _) {
                    final lista = filtrar(comunas, q);
                    if (lista.isEmpty) {
                      return Center(
                        child: Text(
                          'Sin resultados',
                          style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      );
                    }
                    return ValueListenableBuilder<Set<int>>(
                      valueListenable: seleccionTemporal,
                      builder: (ctx5, setSel, __) {
                        return ListView.separated(
                          itemCount: lista.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final c = lista[i];
                            final marcado = setSel.contains(c.id);
                            return CheckboxListTile(
                              value: marcado,
                              dense: true,
                              title: Text(c.nombre),
                              controlAffinity: ListTileControlAffinity.leading,
                              onChanged: (v) {
                                final nuevo = Set<int>.from(setSel);
                                if (v == true) {
                                  valorTodaRegion.value = false;
                                  nuevo.add(c.id);
                                } else {
                                  nuevo.remove(c.id);
                                }
                                seleccionTemporal.value = nuevo;
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),

              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.check),
                      label: const Text('Guardar'),
                      onPressed: () {
                        final toda = valorTodaRegion.value;
                        if (toda) {
                          bloque.todaLaRegion = true;
                          bloque.comunaIds.clear();
                        } else {
                          bloque.todaLaRegion = false;
                          bloque.comunaIds
                            ..clear()
                            ..addAll(seleccionTemporal.value);
                        }
                        onCambio();
                        Navigator.of(ctx).pop();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    controladorBusqueda.dispose();
  }
}

class _BadgeSeleccion extends StatelessWidget {
  final String texto;
  const _BadgeSeleccion({required this.texto});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final estilo = Theme.of(context).textTheme.labelMedium?.copyWith(
          color: cs.onSecondaryContainer,
        );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        texto,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
        style: estilo,
      ),
    );
  }
}
