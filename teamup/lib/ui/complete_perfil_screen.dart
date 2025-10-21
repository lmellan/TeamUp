import 'package:flutter/material.dart';

import '../../domain/entities/deportes.dart';
import '../../domain/services/perfil_services.dart';
import '../../domain/services/deportes_services.dart';
import '../../data/perfil_data.dart';
import '../../data/deportes_data.dart';

// === NUEVO: catálogos y preferencias de localidades ===
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/localidades/region.dart';
import '../../domain/entities/localidades/comuna.dart';
import '../../domain/services/localidades_service.dart';
import '../../domain/entities/localidades/preferencia_localidad.dart';
import '../../data/localidad.dart';

class CompletePerfilScreen extends StatefulWidget {
  const CompletePerfilScreen({super.key});

  @override
  State<CompletePerfilScreen> createState() => _CompletePerfilScreenState();
}

class _CompletePerfilScreenState extends State<CompletePerfilScreen> {
  final _formKey = GlobalKey<FormState>();
  final _bio = TextEditingController();

  final ProfileService _profileSvc = ProfileServiceSupabase();
  final SportService _sportSvc = SportServiceSupabase();

  final CatalogoLocalidadesService _catalogoSvc = CatalogoLocalidadesSupabase();
  final PreferredLocationsService _prefsLocSvc = PreferredLocationsServiceSupabase();

  bool _cargando = false;
  bool _notificar = true;

  List<Sport> _deportes = <Sport>[];
  final Set<String> _idsDeportesSeleccionados = <String>{};

  // Catálogos
  List<RegionCL> _regiones = <RegionCL>[];
  final Map<int, List<ComunaCL>> _comunasPorRegion = <int, List<ComunaCL>>{};

  // Bloques Región → Comunas
  final List<_BloqueRegion> _bloques = <_BloqueRegion>[];

  @override
  void initState() {
    super.initState();
    _cargarTodo();
  }

  @override
  void dispose() {
    _bio.dispose();
    super.dispose();
  }

  Future<void> _cargarTodo() async {
    setState(() {
      _cargando = true;
    });
    try {
      final deportes = await _sportSvc.listAll();
      final perfil = await _profileSvc.getMyProfile();

      // Catálogos
      final regiones = await _catalogoSvc.listarRegiones();
      final comunasPorRegion = <int, List<ComunaCL>>{};
      for (final r in regiones) {
        final comunas = await _catalogoSvc.listarComunasPorRegion(r.id);
        comunas.sort((a, b) => a.nombre.compareTo(b.nombre));
        comunasPorRegion[r.id] = comunas;
      }

      // Reconstruye bloques desde preferencias guardadas
      final bloques = <_BloqueRegion>[];
      if (perfil != null) {
        final uid = perfil.id;
        if (uid.isNotEmpty) {
          final prefs = await _prefsLocSvc.listar(uid);
          final porRegion = <int, Set<int>>{};
          final regionesCompletas = <int>{};

          for (final p in prefs) {
            if (p.regionId != null && p.comunaId == null) {
              regionesCompletas.add(p.regionId!);
            } else if (p.regionId != null && p.comunaId != null) {
              porRegion.putIfAbsent(p.regionId!, () => <int>{}).add(p.comunaId!);
            }
          }

          for (final rid in regionesCompletas) {
            bloques.add(
              _BloqueRegion(regionId: rid, todaLaRegion: true, comunaIds: <int>{}),
            );
          }
          for (final entry in porRegion.entries) {
            bloques.add(
              _BloqueRegion(regionId: entry.key, todaLaRegion: false, comunaIds: entry.value),
            );
          }
        }
      }

      setState(() {
        _deportes = deportes;
        if (perfil != null) {
          final texto = perfil.bio ?? '';
          _bio.text = texto;
          _idsDeportesSeleccionados
            ..clear()
            ..addAll(perfil.preferredSportIds);
          _notificar = perfil.notifyNewActivity;
        }
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
        const SnackBar(content: Text('No se pudieron cargar los datos')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _cargando = false;
        });
      }
    }
  }

  Future<void> _guardarYContinuar() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _cargando = true;
    });

    try {
      final actual = await _profileSvc.getMyProfile();
      if (actual == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sesión no encontrada')),
        );
        setState(() {
          _cargando = false;
        });
        return;
      }

      // Guarda perfil base
      final textoBio = _bio.text.trim();
      final String? bioFinal = textoBio.isEmpty ? null : textoBio;

      final actualizado = actual.copyWith(
        bio: bioFinal,
        notifyNewActivity: _notificar,
        preferredSportIds: _idsDeportesSeleccionados.toList(),
      );
      await _profileSvc.updateMyProfile(actualizado);

      // Guarda preferencias de localidades
      await _persistirBloques(actual.id);

      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/perfil');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error guardando: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _cargando = false;
        });
      }
    }
  }

  Future<void> _persistirBloques(String userId) async {
    final db = Supabase.instance.client;
    await db.from('user_preferred_locations').delete().eq('user_id', userId);

    for (final b in _bloques) {
      if (b.regionId == null) continue;

      final rid = b.regionId!;
      if (b.todaLaRegion) {
        // ✅ Expandir a TODAS las comunas de la región y guardarlas una a una
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

  void _anadirBloque() {
    setState(() {
      _bloques.add(_BloqueRegion.empty());
    });
  }

  void _quitarBloque(int index) {
    setState(() {
      _bloques.removeAt(index);
      if (_bloques.isEmpty) {
        _bloques.add(_BloqueRegion.empty());
      }
    });
  }

  List<DropdownMenuItem<int>> _itemsRegiones() {
    final items = <DropdownMenuItem<int>>[];
    for (final r in _regiones) {
      items.add(DropdownMenuItem<int>(value: r.id, child: Text(r.nombre)));
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final bool esOscuro = Theme.of(context).brightness == Brightness.dark;
    final Color onSurfaceVariant =
        esOscuro ? Colors.white.withOpacity(0.75) : const Color(0xFF757575);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'TeamUp',
                    style: t.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Preferencias básicas',
                    style: t.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Opcional: completa tu perfil para mejores recomendaciones.',
                    style: t.bodyMedium?.copyWith(color: onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // BIO
                        SizedBox(
                          height: 120,
                          child: TextFormField(
                            controller: _bio,
                            expands: true,
                            minLines: null,
                            maxLines: null,
                            textAlignVertical: TextAlignVertical.center,
                            decoration: const InputDecoration(
                              hintText: 'Sobre mí (opcional)',
                              prefixIcon: Icon(Icons.person_outline),
                              border: OutlineInputBorder(),
                              floatingLabelBehavior: FloatingLabelBehavior.never,
                              contentPadding: EdgeInsets.symmetric(horizontal: 16),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Deportes
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Deportes preferidos',
                              style: t.titleSmall?.copyWith(color: cs.onSurface)),
                        ),
                        const SizedBox(height: 8),

                        if (_cargando && _deportes.isEmpty) ...[
                          const LinearProgressIndicator(),
                        ] else ...[
                          if (_deportes.isEmpty) ...[
                            Text(
                              'Aún no hay deportes en el catálogo.',
                              style: t.bodySmall?.copyWith(color: onSurfaceVariant),
                            ),
                          ] else ...[
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _deportes.map((s) {
                                final bool seleccionado = _idsDeportesSeleccionados.contains(s.id);
                                String etiqueta = s.name;
                                if (s.iconEmoji != null) {
                                  final ico = s.iconEmoji!;
                                  if (ico.isNotEmpty) {
                                    etiqueta = '$ico  ${s.name}';
                                  }
                                }
                                return FilterChip(
                                  label: Text(etiqueta),
                                  selected: seleccionado,
                                  onSelected: (v) {
                                    setState(() {
                                      if (v) {
                                        _idsDeportesSeleccionados.add(s.id);
                                      } else {
                                        _idsDeportesSeleccionados.remove(s.id);
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                          ],
                        ],

                        const SizedBox(height: 20),

                        // Selector de localidades (nuevo)
                        Text('Localidades de preferencia', style: t.titleMedium),
                        const SizedBox(height: 8),
                        Text(
                          'Selecciona una región donde te interese jugar o tengas disponibilidad.',
                          style: t.bodySmall?.copyWith(color: onSurfaceVariant),
                        ),
                        const SizedBox(height: 12),

                        ..._bloques.asMap().entries.map((entry) {
                          final index = entry.key;
                          final bloque = entry.value;

                          return SelectorRegionComunas(
                            regiones: _regiones,
                            comunasPorRegion: _comunasPorRegion,
                            bloque: bloque,
                            onQuitar: () {
                              _quitarBloque(index);
                            },
                            onCambio: () {
                              setState(() {});
                            },
                          );
                        }).toList(),

                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _anadirBloque,
                          icon: const Icon(Icons.add),
                          label: const Text('Añadir otra región'),
                        ),

                        const SizedBox(height: 16),

                        // Notificaciones
                        SwitchListTile(
                          value: _notificar,
                          onChanged: (v) {
                            setState(() {
                              _notificar = v;
                            });
                          },
                          title: const Text('Recibir avisos de nuevas actividades'),
                          subtitle: Text(
                            'Te notificaremos cuando aparezcan actividades de tu interés.',
                            style: t.bodySmall?.copyWith(color: onSurfaceVariant),
                          ),
                        ),

                        const SizedBox(height: 16),
                        SizedBox(
                          height: 56,
                          child: FilledButton(
                            onPressed: _cargando ? null : _guardarYContinuar,
                            child: _cargando
                                ? const CircularProgressIndicator()
                                : const Text('Continuar'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _cargando
                              ? null
                              : () => Navigator.of(context).pushReplacementNamed('/perfil'),
                          child: const Text('Saltar por ahora'),
                        ),
                      ],
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
    return _BloqueRegion(regionId: null, todaLaRegion: false, comunaIds: <int>{});
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
                    isExpanded: true, // evita overflow
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
                      // ✅ Al seleccionar región: activar por defecto "toda la región"
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
                  // ✅ Si activa "toda la región", limpiar comunas
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
                _BadgeSeleccion(
                  texto: _textoBadge(bloque),
                ),
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
                        // ✅ Si activa "toda la región" desde la hoja: limpiar selección
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
                        child: Text('Sin resultados', style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
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
                                  // ✅ Sin límites: agregar libremente
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
                      onPressed: () {
                        Navigator.of(ctx).pop();
                      },
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
