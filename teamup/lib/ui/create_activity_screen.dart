// lib/ui/create_activity_screen.dart
// Formulario dual: Crear y Editar actividad (según activityId)

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:flutter_google_places_sdk/flutter_google_places_sdk.dart' as places;

import '../domain/entities/deportes.dart';
import '../domain/entities/field_spec.dart';
import '../domain/entities/actividad.dart';
import '../domain/entities/picked_place.dart';

import '../domain/services/deportes_services.dart';
import '../domain/services/actividad_services.dart';

import '../data/deportes_data.dart';
import '../data/actividad_data.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class CreateActivityScreen extends StatefulWidget {
  CreateActivityScreen({
    super.key,
    this.activityId,                 // null => crear, no null => editar
    SportService? deportes,
    ActivityService? activitySvc,
  })  : deportes = deportes ?? SportServiceSupabase(),
        activitySvc = activitySvc ?? ActivityServiceSupabase();

  final String? activityId;
  final SportService deportes;
  final ActivityService activitySvc;

  @override
  State<CreateActivityScreen> createState() => _CreateActivityScreenState();
}

class _CreateActivityScreenState extends State<CreateActivityScreen> {
  final _page = PageController();
  int _currentPage = 0;

  bool get _isEdit => widget.activityId != null;

  void _goBack() {
    if (_currentPage == 0) {
      Navigator.of(context).pushNamedAndRemoveUntil('/explore', (route) => false);
    } else {
      _prev();
    }
  }

  // forms
  final _form1 = GlobalKey<FormState>();
  final _form2 = GlobalKey<FormState>();
  final _form3 = GlobalKey<FormState>();

  // Paso 1
  final titleCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  final maxPlayersCtrl = TextEditingController();
  String? level;             // Principiante | Intermedio | Avanzado
  Sport? _sport;

  // deportes (fetch interno)
  List<Sport> _sports = [];
  bool _loadingSports = true;

  // Paso 2
  DateTime? _date;
  TimeOfDay? _time;

  // estos se rellenan con el picker
  final placeNameCtrl = TextEditingController();        // place_name (requerido)
  final formattedAddrCtrl = TextEditingController();    // formatted_address (requerido)
  final activityLocCtrl = TextEditingController();      // activity_location (opcional)
  final latCtrl = TextEditingController();              // opcional
  final lngCtrl = TextEditingController();              // opcional
  final googlePlaceIdCtrl = TextEditingController();    // opcional

  // Paso 3 (dinámico)
  List<FieldSpec> dynamicFields = const [];
  final Map<String, dynamic> dynamicAnswers = {};

  bool _saving = false;

  // --- Edición ---
  Activity? _original;   // actividad cargada para edición
  String? _ownerId;

  @override
  void initState() {
    super.initState();
    _fetchSports().then((_) {
      if (_isEdit) _loadActivityForEdit();
    });
  }

  Future<void> _fetchSports() async {
    try {
      final list = await widget.deportes.listAll();
      if (!mounted) return;
      setState(() {
        _sports = list;
        _loadingSports = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingSports = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('No se pudieron cargar los deportes')));
    }
  }

  Future<void> _loadActivityForEdit() async {
    try {
      final id = widget.activityId!;
      final a = await widget.activitySvc.getById(id);
      if (a == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Actividad no encontrada')),
        );
        Navigator.of(context).pop();
        return;
      }

      // seguridad: solo el creador puede editar
      final currentUser = Supabase.instance.client.auth.currentUser?.id;
      if (currentUser == null || currentUser != a.creatorId) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No tienes permisos para editar esta actividad')),
        );
        Navigator.of(context).pop();
        return;
      }

      _original = a;
      _ownerId = a.creatorId;

      // Prefill controles
      titleCtrl.text = a.title;
      descCtrl.text  = a.description ?? '';
      maxPlayersCtrl.text = (a.maxPlayers ?? 0) > 0 ? '${a.maxPlayers}' : '';

      level = a.level;

      // Fecha/Hora en local
      final local = a.date.toLocal();
      _date = DateTime(local.year, local.month, local.day);
      _time = TimeOfDay(hour: local.hour, minute: local.minute);

      // Ubicación
      placeNameCtrl.text     = a.placeName ?? a.formattedAddress ?? '';
      formattedAddrCtrl.text = a.formattedAddress ?? a.placeName ?? '';
      activityLocCtrl.text   = a.activityLocation ?? '';
      latCtrl.text           = a.lat?.toString() ?? '';
      lngCtrl.text           = a.lng?.toString() ?? '';
      googlePlaceIdCtrl.text = a.googlePlaceId ?? '';

      // Deporte + campos dinámicos
      _sport = _sports.where((s) => s.id == a.sportId).cast<Sport?>().firstOrNull ?? (_sports.isNotEmpty ? _sports.first : null);
      dynamicFields = _sport?.fields ?? const [];
      dynamicAnswers
        ..clear()
        ..addAll(a.fields);

      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo cargar la actividad: $e')),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _page.dispose();
    titleCtrl.dispose();
    descCtrl.dispose();
    maxPlayersCtrl.dispose();
    placeNameCtrl.dispose();
    formattedAddrCtrl.dispose();
    activityLocCtrl.dispose();
    latCtrl.dispose();
    lngCtrl.dispose();
    googlePlaceIdCtrl.dispose();
    super.dispose();
  }

  void _next(int step) {
    final ok = switch (step) {
      1 => (_form1.currentState?.validate() ?? false) && _sport != null,
      2 => _form2.currentState?.validate() ?? false,
      _ => true,
    };
    if (!ok && step == 1 && _sport == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Selecciona un deporte')));
      return;
    }
    if (ok) {
      _page.nextPage(duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
    }
  }

  void _prev() => _page.previousPage(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: DateTime(now.year + 2),
      initialDate: _date ?? now,
    );
    if (picked != null) setState(() => _date = picked);
  }

Future<void> _pickTime() async {
  final picked = await showTimePicker(
    context: context,
    initialTime: _time ?? TimeOfDay.now(),
    initialEntryMode: TimePickerEntryMode.input,
    builder: (context, child) {
      // Fuerza formato 24 h en el diálogo
      final media = MediaQuery.of(context);
      return MediaQuery(
        data: media.copyWith(alwaysUse24HourFormat: true),
        child: child!,
      );
    },
  );
  if (picked != null) setState(() => _time = picked);
}


  Future<void> _openPlacePicker() async {
    final picked = await showPlacePicker(context);
    if (picked != null) {
      setState(() {
        formattedAddrCtrl.text  = picked.formattedAddress;
        placeNameCtrl.text      = picked.placeName.isEmpty ? picked.formattedAddress : picked.placeName;
        latCtrl.text            = picked.lat.toString();
        lngCtrl.text            = picked.lng.toString();
        googlePlaceIdCtrl.text  = picked.placeId ?? '';
      });
    }
  }

  Future<void> _saveOrPublish() async {
    if (!(_form3.currentState?.validate() ?? false)) return;
    if (_sport == null) {
      _page.jumpToPage(0);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un deporte')),
      );
      return;
    }
    if (_date == null || _time == null) {
      _page.jumpToPage(1);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona fecha y hora')),
      );
      return;
    }

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Debes iniciar sesión')));
      return;
    }

    // Construir DateTime en UTC
    final localDT = DateTime(_date!.year, _date!.month, _date!.day, _time!.hour, _time!.minute);
    final whenUtc = localDT.toUtc();

    setState(() => _saving = true);
    try {
      if (_isEdit) {
        // seguridad: dueño
        if (_original == null || _original!.creatorId != userId) {
          throw 'No tienes permisos para editar esta actividad';
        }

        final updated = Activity(
          id: _original!.id,
          sportId: _sport!.id,
          creatorId: _original!.creatorId,
          createdAt: _original!.createdAt,
          title: titleCtrl.text.trim(),
          description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
          status: _original!.status,
          date: whenUtc,
          // ubicación
          placeName: placeNameCtrl.text.trim().isEmpty ? null : placeNameCtrl.text.trim(),
          formattedAddress: formattedAddrCtrl.text.trim().isEmpty ? null : formattedAddrCtrl.text.trim(),
          activityLocation: activityLocCtrl.text.trim().isEmpty ? null : activityLocCtrl.text.trim(),
          googlePlaceId: googlePlaceIdCtrl.text.trim().isEmpty ? null : googlePlaceIdCtrl.text.trim(),
          lat: num.tryParse(latCtrl.text.trim())?.toDouble(),
          lng: num.tryParse(lngCtrl.text.trim())?.toDouble(),
          // otros
          maxPlayers: num.tryParse(maxPlayersCtrl.text.trim())?.toInt(),
          level: level,
          fields: Map<String, dynamic>.from(dynamicAnswers),
        );

        await widget.activitySvc.update(_original!.id!, updated);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cambios guardados')),
        );
        Navigator.of(context).pop(true); // para refrescar detalle
      } else {
        final activity = Activity(
          sportId: _sport!.id,
          creatorId: userId,
          title: titleCtrl.text.trim(),
          description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
          status: 'activa',
          date: whenUtc,
          // ubicación
          placeName: placeNameCtrl.text.trim(),
          formattedAddress: formattedAddrCtrl.text.trim(),
          activityLocation: activityLocCtrl.text.trim().isEmpty ? null : activityLocCtrl.text.trim(),
          googlePlaceId: googlePlaceIdCtrl.text.trim().isEmpty ? null : googlePlaceIdCtrl.text.trim(),
          lat: num.tryParse(latCtrl.text.trim())?.toDouble(),
          lng: num.tryParse(lngCtrl.text.trim())?.toDouble(),
          // otros
          maxPlayers: num.tryParse(maxPlayersCtrl.text.trim())?.toInt(),
          level: level,
          fields: Map<String, dynamic>.from(dynamicAnswers),
        );

        final created = await ActivityServiceSupabase().create(activity);
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Actividad publicada: ${created.title}')));
        Navigator.of(context).pushReplacementNamed('/detail-activity', arguments: created.id.toString());
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Editar actividad' : 'Crear actividad'),
        leading: IconButton(icon: const Icon(Icons.chevron_left), onPressed: _goBack),
      ),
      body: AbsorbPointer(
        absorbing: _saving,
        child: Stack(
          children: [
            PageView(
              controller: _page,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (i) => setState(() => _currentPage = i),
              children: [
                // PASO 1
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        padding: EdgeInsets.only(
                          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                        ),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: constraints.maxHeight),
                          child: Form(
                            key: _form1,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                LinearProgressIndicator(value: 1 / 3),
                                const SizedBox(height: 20),
                                Text('🎯 ${_isEdit ? 'Actualiza tu actividad' : '¿Qué actividad crearás?'}',
                                    style: Theme.of(context).textTheme.titleLarge),
                                const SizedBox(height: 20),
                                Text("Deporte", style: const TextStyle(fontWeight: FontWeight.w500)),
                                DropdownButtonFormField<Sport>(
                                  value: _sport,
                                  decoration: const InputDecoration(
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.sports_soccer),
                                    hintText: 'Selecciona un deporte',
                                  ),
                                  items: _loadingSports
                                      ? const []
                                      : _sports
                                          .map((s) => DropdownMenuItem(
                                                value: s,
                                                child: Text("${s.iconEmoji} ${s.name}"),
                                              ))
                                          .toList(),
                                  onChanged: _loadingSports
                                      ? null
                                      : (_isEdit // si no quieres permitir cambiar deporte en edición, descomenta esto
                                          ? (s) {
                                              // Permitir cambiar deporte en edición (opcional)
                                              setState(() {
                                                _sport = s;
                                                dynamicFields = s?.fields ?? const [];
                                                dynamicAnswers
                                                  ..clear()
                                                  ..addAll(_original?.fields ?? {});
                                              });
                                            }
                                          : (s) {
                                              setState(() {
                                                _sport = s;
                                                dynamicFields = s?.fields ?? const [];
                                                dynamicAnswers.clear();
                                              });
                                            }),
                                  validator: (_) =>
                                      _sport == null ? 'Selecciona un deporte' : null,
                                ),
                                if (_loadingSports) ...[
                                  const SizedBox(height: 8),
                                  const LinearProgressIndicator(minHeight: 2),
                                ],

                                const SizedBox(height: 16),
                                Text("Título", style: const TextStyle(fontWeight: FontWeight.w500)),
                                TextFormField(
                                  controller: titleCtrl,
                                  decoration: const InputDecoration(
                                    hintText: 'Ej. Partido amistoso',
                                    prefixIcon: Icon(Icons.title),
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (v) =>
                                      (v == null || v.trim().isEmpty) ? 'Ingresa un título' : null,
                                ),

                                const SizedBox(height: 16),
                                Text("Descripción", style: const TextStyle(fontWeight: FontWeight.w500)),
                                TextFormField(
                                  controller: descCtrl,
                                  maxLines: 3,
                                  decoration: const InputDecoration(
                                    hintText: 'Cuéntales detalles de la actividad',
                                    prefixIcon: Icon(Icons.description_outlined),
                                    border: OutlineInputBorder(),
                                  ),
                                ),

                                const SizedBox(height: 16),
                                Text("Máximo de participantes", style: const TextStyle(fontWeight: FontWeight.w500)),
                                TextFormField(
                                  controller: maxPlayersCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    hintText: 'Ej. 10',
                                    prefixIcon: Icon(Icons.people_outline),
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) return null;
                                    final n = num.tryParse(v);
                                    if (n == null || n <= 0) return 'Número inválido';
                                    return null;
                                  },
                                ),

                                const SizedBox(height: 16),
                                Text("Nivel", style: const TextStyle(fontWeight: FontWeight.w500)),
                                DropdownButtonFormField<String>(
                                  value: level,
                                  decoration: const InputDecoration(
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.fitness_center),
                                    hintText: 'Selecciona un nivel',
                                  ),
                                  items: ['Principiante', 'Intermedio', 'Avanzado']
                                      .map((l) =>
                                          DropdownMenuItem(value: l, child: Text(l)))
                                      .toList(),
                                  onChanged: (v) => setState(() => level = v),
                                  validator: (v) =>
                                      v == null ? 'Selecciona un nivel' : null,
                                ),

                                const SizedBox(height: 24),
                                FilledButton(
                                  onPressed: () => _next(1),
                                  child: const Text('Siguiente'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // PASO 2
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        padding: EdgeInsets.only(
                          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                        ),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: constraints.maxHeight),
                          child: Form(
                            key: _form2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                LinearProgressIndicator(value: 2 / 3),
                                const SizedBox(height: 20),
                                Text('📍 ¿Cuándo y dónde?', style: Theme.of(context).textTheme.titleLarge),
                                const SizedBox(height: 20),
                                Text("Fecha", style: const TextStyle(fontWeight: FontWeight.w500)),
                                TextFormField(
                                  readOnly: true,
                                  decoration: const InputDecoration(
                                    hintText: 'Selecciona la fecha',
                                    prefixIcon: Icon(Icons.calendar_today),
                                    border: OutlineInputBorder(),
                                  ),
                                  controller: TextEditingController(
                                    text: _date == null
                                        ? ''
                                        : '${_date!.day}/${_date!.month}/${_date!.year}',
                                  ),
                                  onTap: _pickDate,
                                  validator: (_) => _date == null ? 'Selecciona la fecha' : null,
                                ),

                                const SizedBox(height: 16),
                                Text("Hora", style: const TextStyle(fontWeight: FontWeight.w500)),
                                TextFormField(
                                  readOnly: true,
                                  decoration: const InputDecoration(
                                    hintText: 'Selecciona la hora',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.access_time),
                                  ),
                                  controller: TextEditingController(
                                    text: _time == null ? '' : _time!.format(context),
                                  ),
                                  onTap: _pickTime,
                                  validator: (_) => _time == null ? 'Selecciona la hora' : null,
                                ),

                                const SizedBox(height: 16),
                                Text("Ubicación", style: const TextStyle(fontWeight: FontWeight.w500)),
                                TextFormField(
                                  readOnly: true,
                                  decoration: const InputDecoration(
                                    hintText: 'Selecciona la ubicación',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.place),
                                  ),
                                  controller: formattedAddrCtrl,
                                  onTap: _openPlacePicker,
                                  validator: (v) =>
                                      (v == null || v.trim().isEmpty) ? 'Selecciona la ubicación' : null,
                                ),

                                const SizedBox(height: 16),
                                Text("Referencias (Opcional)", style: const TextStyle(fontWeight: FontWeight.w500)),
                                TextFormField(
                                  controller: activityLocCtrl,
                                  maxLines: 2,
                                  decoration: const InputDecoration(
                                    hintText: 'Ej: Cancha 2, sector norte...',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.comment)
                                  ),
                                ),

                                const SizedBox(height: 24),
                                FilledButton(onPressed: () => _next(2), child: const Text('Siguiente')),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // PASO 3
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        padding: EdgeInsets.only(
                          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                        ),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: constraints.maxHeight),
                          child: Form(
                            key: _form3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                LinearProgressIndicator(value: 3 / 3),
                                const SizedBox(height: 20),
                                Text('📝 Preguntas adicionales', style: Theme.of(context).textTheme.titleLarge),
                                const SizedBox(height: 4),
                                if ((_sport?.fields ?? const []).isEmpty)
                                  const Text('Este deporte no requiere campos adicionales.')
                                else
                                  ...dynamicFields.map((f) => _buildDynamicField(f)),

                                const SizedBox(height: 24),
                                FilledButton.icon(
                                  onPressed: _saving ? null : _saveOrPublish,
                                  icon: Icon(_isEdit ? Icons.save : Icons.check),
                                  label: Text(
                                    _saving
                                        ? (_isEdit ? 'Guardando…' : 'Publicando…')
                                        : (_isEdit ? 'Guardar cambios' : 'Publicar actividad'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            if (_saving)
              const Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: LinearProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDynamicField(FieldSpec f) {
    final value = dynamicAnswers[f.key];
    switch (f.type) {
      case 'boolean':
        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: SwitchListTile(
            title: Text(f.label),
            value: (value as bool?) ?? false,
            onChanged: (v) => setState(() => dynamicAnswers[f.key] = v),
          ),
        );

      case 'select':
        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: DropdownButtonFormField<String>(
            value: (value as String?),
            decoration: InputDecoration(labelText: f.label, border: const OutlineInputBorder()),
            items: f.options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
            onChanged: (v) => setState(() => dynamicAnswers[f.key] = v),
            validator: (v) =>
                (f.required && (v == null || v.isEmpty)) ? 'Requerido' : null,
          ),
        );

      case 'number':
        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: TextFormField(
            initialValue: value?.toString(),
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: f.label, border: const OutlineInputBorder()),
            validator: (v) {
              if (f.required && (v == null || v.trim().isEmpty)) return 'Requerido';
              if (v == null || v.isEmpty) return null;
              final n = num.tryParse(v);
              if (n == null) return 'Número inválido';
              if (f.min != null && n < f.min!) return 'Mínimo ${f.min}';
              if (f.max != null && n > f.max!) return 'Máximo ${f.max}';
              return null;
            },
            onChanged: (v) => dynamicAnswers[f.key] = num.tryParse(v),
          ),
        );

      default: // text
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: TextFormField(
            initialValue: value?.toString(),
            decoration: InputDecoration(labelText: f.label, border: const OutlineInputBorder()),
            validator: (v) =>
                (f.required && (v == null || v.trim().isEmpty)) ? 'Requerido' : null,
            onChanged: (v) => dynamicAnswers[f.key] = v,
          ),
        );
    }
  }
}

// ---------- Picker con mapa + autocomplete (VERSIÓN ROBUSTA) ----------
Future<PickedPlace?> showPlacePicker(BuildContext context) {
  return showModalBottomSheet<PickedPlace>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const _PlacePickerSheet(),
  );
}

class _PlacePickerSheet extends StatefulWidget {
  const _PlacePickerSheet();
  @override
  State<_PlacePickerSheet> createState() => _PlacePickerSheetState();
}

class _PlacePickerSheetState extends State<_PlacePickerSheet> {
  late final places.FlutterGooglePlacesSdk _places;
  final _searchCtrl = TextEditingController();

  final _mapC = Completer<gmaps.GoogleMapController>();

  // Centro y bounds de Chile
  static const gmaps.LatLng _chileCenter = gmaps.LatLng(-33.45, -70.66); // Stgo aprox
  static final gmaps.LatLngBounds _chileBounds = gmaps.LatLngBounds(
    southwest: const gmaps.LatLng(-56.0, -76.0),
    northeast: const gmaps.LatLng(-17.5, -66.0),
  );

  // Estado del mapa y selección
  gmaps.Marker? _marker;
  gmaps.LatLng _cameraCenter = _chileCenter;

  // Autocomplete
  List<places.AutocompletePrediction> _pred = [];
  String? _selectedPlaceId;   // placeId cuando viene del autocomplete
  String? _selectedName;      // título (arriba)
  String? _selectedAddress;   // dirección (abajo)

  // UI
  bool _confirming = false;

  @override
  void initState() {
    super.initState();
    // ⚠️ API KEY (misma que en el Manifest). Ideal mover a dotenv en prod.
    final apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
    _places = places.FlutterGooglePlacesSdk(apiKey);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // === Autocomplete: restringido a Chile ===
  Future<void> _onChangedSearch(String v) async {
    if (v.trim().isEmpty) {
      setState(() {
        _pred = [];
        _selectedPlaceId = null;
        _selectedName = null;
        _selectedAddress = null;
      });
      return;
    }
    final res = await _places.findAutocompletePredictions(
      v,
      countries: const ['cl'], // 🔒 solo Chile
    );
    setState(() {
      _pred = res.predictions;
      _selectedPlaceId = null; // aún no hay selección
      _selectedName = null;
      _selectedAddress = null;
    });
  }

  Future<void> _selectPrediction(places.AutocompletePrediction p) async {
    final details = await _places.fetchPlace(
      p.placeId,
      fields: const [
        places.PlaceField.Location,
        places.PlaceField.Name,
        places.PlaceField.Address,
        places.PlaceField.Id,
      ],
    );

    final place = details.place;
    final loc = place?.latLng;
    if (place == null || loc == null) return;

    final pos = gmaps.LatLng(loc.lat, loc.lng);
    final controller = _mapC.isCompleted ? await _mapC.future : null;

    setState(() {
      _marker = gmaps.Marker(markerId: const gmaps.MarkerId('picked'), position: pos);

      // Guarda nombre y dirección por separado
      _selectedName = place.name ?? p.primaryText;
      _selectedAddress = place.address ?? p.fullText;

      // (Opcional) mostrar ambos en el input
      _searchCtrl.text = "${_selectedName ?? ''}, ${_selectedAddress ?? ''}";

      _pred = [];
      _selectedPlaceId = place.id; // 👈 guardamos el id
      _cameraCenter = pos;
    });

    if (controller != null) {
      await controller.animateCamera(gmaps.CameraUpdate.newLatLngZoom(pos, 16));
    }
  }

  Future<void> _confirm() async {
    if (!mounted || _confirming) return;
    setState(() => _confirming = true);

    try {
      final pos = _marker?.position ?? _cameraCenter;
      final placeName = (_selectedName != null && _selectedName!.trim().isNotEmpty)
          ? _selectedName!
          : _searchCtrl.text;

      final formattedAddress = (_selectedAddress != null && _selectedAddress!.trim().isNotEmpty)
          ? _selectedAddress!
          : _searchCtrl.text;

      Navigator.pop(
        context,
        PickedPlace(
          placeName: placeName,                 // título (arriba)
          formattedAddress: formattedAddress,   // dirección (abajo)
          lat: pos.latitude,
          lng: pos.longitude,
          placeId: _selectedPlaceId,            // null si fue tap manual
        ),
      );
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.85;

    return SizedBox(
      height: height,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: 'Buscar lugar…',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: _onChangedSearch,
            ),
          ),

          if (_pred.isNotEmpty)
            Expanded(
              child: ListView.separated(
                itemCount: _pred.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final p = _pred[i];
                  return ListTile(
                    leading: const Icon(Icons.place),
                    title: Text(p.fullText ?? p.primaryText),
                    subtitle: p.secondaryText == null ? null : Text(p.secondaryText!),
                    onTap: () => _selectPrediction(p),
                  );
                },
              ),
            )
          else
            Expanded(
              child: Stack(
                children: [
                  gmaps.GoogleMap(
                    initialCameraPosition: const gmaps.CameraPosition(
                      target: _chileCenter,
                      zoom: 5.5,
                    ),
                    cameraTargetBounds: gmaps.CameraTargetBounds(_chileBounds), // 🔒 Chile
                    minMaxZoomPreference: const gmaps.MinMaxZoomPreference(4, 18),

                    // Trackea el centro de la cámara (evita usar getLatLng)
                    onCameraMove: (camPos) {
                      _cameraCenter = camPos.target;
                    },

                    myLocationButtonEnabled: true,
                    myLocationEnabled: false,

                    onMapCreated: (c) {
                      if (!_mapC.isCompleted) _mapC.complete(c);
                    },

                    markers: {if (_marker != null) _marker!},

                    onTap: (pos) async {
                      final controller = _mapC.isCompleted ? await _mapC.future : null;
                      setState(() {
                        _marker = gmaps.Marker(
                          markerId: const gmaps.MarkerId('picked'),
                          position: pos,
                        );
                        // Tap manual → sin datos de autocomplete
                        _selectedPlaceId = null;
                        _selectedName = null;
                        _selectedAddress = null;
                        _cameraCenter = pos;
                      });
                      if (controller != null) {
                        await controller.animateCamera(gmaps.CameraUpdate.newLatLng(pos));
                      }
                    },
                  ),

                  // Pin visual centrado (no intercepta toques)
                  const IgnorePointer(
                    child: Center(
                      child: Icon(Icons.place, size: 36, color: Colors.redAccent),
                    ),
                  ),
                ],
              ),
            ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _confirming ? null : () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _confirming ? null : _confirm,
                    child: Text(_confirming ? 'Guardando…' : 'Usar esta ubicación'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- Helpers ----------

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
