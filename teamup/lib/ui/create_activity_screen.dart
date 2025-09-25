import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/entities/deportes.dart';
import '../domain/entities/field_spec.dart';
import '../domain/entities/actividad.dart';

import '../domain/services/deportes_services.dart';
import '../data/deportes_data.dart';
import '../data/actividad_data.dart';

class CreateActivityScreen extends StatefulWidget {
  CreateActivityScreen({
    super.key,
    SportService? deportes,
  }) : deportes = deportes ?? SportServiceSupabase();

  final SportService deportes;

  @override
  State<CreateActivityScreen> createState() => _CreateActivityScreenState();
}

class _CreateActivityScreenState extends State<CreateActivityScreen> {
  final _page = PageController();

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
  final placeNameCtrl = TextEditingController();        // place_name (requerido)
  final formattedAddrCtrl = TextEditingController();    // formatted_address (requerido)
  final activityLocCtrl = TextEditingController();      // activity_location (opcional texto)
  final latCtrl = TextEditingController();              // opcional
  final lngCtrl = TextEditingController();              // opcional
  final googlePlaceIdCtrl = TextEditingController();    // opcional

  // Paso 3 (dinámico)
  List<FieldSpec> dynamicFields = const [];
  final Map<String, dynamic> dynamicAnswers = {};

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _fetchSports();
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
    );
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _publish() async {
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

    setState(() => _saving = true);
    try {
      final created = await ActivityServiceSupabase().create(activity);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Actividad publicada (${created.id})')));
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error al publicar: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final levels = const ['Principiante', 'Intermedio', 'Avanzado'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear actividad'),
        leading: IconButton(icon: const Icon(Icons.chevron_left), onPressed: _prev),
      ),
      body: AbsorbPointer(
        absorbing: _saving,
        child: Stack(
          children: [
            PageView(
              controller: _page,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                // PASO 1
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _form1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LinearProgressIndicator(value: 1 / 3),
                        const SizedBox(height: 16),

                        DropdownButtonFormField<Sport>(
                          value: _sport,
                          decoration: const InputDecoration(labelText: 'Deporte'),
                          items: _loadingSports
                              ? const []
                              : _sports
                                  .map((s) => DropdownMenuItem(value: s, child: Text(s.name)))
                                  .toList(),
                          onChanged: _loadingSports
                              ? null
                              : (s) {
                                  setState(() {
                                    _sport = s;
                                    dynamicFields = s?.fields ?? const [];
                                    dynamicAnswers.clear();
                                  });
                                },
                          validator: (_) => _sport == null ? 'Selecciona un deporte' : null,
                        ),
                        if (_loadingSports) ...[
                          const SizedBox(height: 8),
                          const LinearProgressIndicator(minHeight: 2),
                        ],

                        const SizedBox(height: 12),
                        TextFormField(
                          controller: titleCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Título',
                            hintText: 'Ej. Partido amistoso',
                          ),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Ingresa un título' : null,
                        ),

                        const SizedBox(height: 12),
                        TextFormField(
                          controller: descCtrl,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Descripción',
                            hintText: 'Cuéntales detalles de la actividad',
                          ),
                        ),

                        const SizedBox(height: 12),
                        TextFormField(
                          controller: maxPlayersCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Máximo de participantes',
                            hintText: 'Ej. 10',
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return null;
                            final n = num.tryParse(v);
                            if (n == null || n <= 0) return 'Número inválido';
                            return null;
                          },
                        ),

                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: level,
                          decoration: const InputDecoration(labelText: 'Nivel'),
                          items: levels
                              .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                              .toList(),
                          onChanged: (v) => setState(() => level = v),
                          validator: (v) => v == null ? 'Selecciona un nivel' : null,
                        ),

                        const Spacer(),
                        FilledButton(onPressed: () => _next(1), child: const Text('Siguiente')),
                      ],
                    ),
                  ),
                ),

                // PASO 2
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _form2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LinearProgressIndicator(value: 2 / 3),
                        const SizedBox(height: 16),

                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Fecha'),
                          subtitle: Text(
                            _date != null
                                ? '${_date!.day}/${_date!.month}/${_date!.year}'
                                : 'Selecciona fecha',
                          ),
                          trailing: const Icon(Icons.calendar_today),
                          onTap: _pickDate,
                        ),
                        const SizedBox(height: 4),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Hora'),
                          subtitle:
                              Text(_time != null ? _time!.format(context) : 'Selecciona hora'),
                          trailing: const Icon(Icons.access_time),
                          onTap: _pickTime,
                        ),

                        const SizedBox(height: 12),
                        TextFormField(
                          controller: placeNameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Lugar (place_name)',
                            hintText: 'Ej. Estadio Municipal, Cancha 2',
                          ),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Ingresa el lugar' : null,
                        ),

                        const SizedBox(height: 12),
                        TextFormField(
                          controller: formattedAddrCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Dirección (formatted_address)',
                            hintText: 'Ej. Viña del Mar, Chile',
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Ingresa la dirección'
                              : null,
                        ),

                        const SizedBox(height: 12),
                        TextFormField(
                          controller: activityLocCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Referencia (activity_location)',
                            hintText: 'Indoor / Outdoor / Cancha techada… (opcional)',
                          ),
                        ),

                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: latCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Lat (opcional)',
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: lngCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Lng (opcional)',
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),
                        TextFormField(
                          controller: googlePlaceIdCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Google Place ID (opcional)',
                          ),
                        ),

                        const Spacer(),
                        FilledButton(onPressed: () => _next(2), child: const Text('Siguiente')),
                      ],
                    ),
                  ),
                ),

                // PASO 3
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _form3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LinearProgressIndicator(value: 3 / 3),
                        const SizedBox(height: 16),
                        Text('Preguntas específicas',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        if ((_sport?.fields ?? const []).isEmpty)
                          const Text('Este deporte no requiere campos adicionales.'),
                        ...dynamicFields.map((f) => _buildDynamicField(f)),
                        const Spacer(),
                        FilledButton.icon(
                          onPressed: _saving ? null : _publish,
                          icon: const Icon(Icons.check),
                          label: const Text('Publicar actividad'),
                        ),
                      ],
                    ),
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
        return SwitchListTile(
          title: Text(f.label),
          value: (value as bool?) ?? false,
          onChanged: (v) => setState(() => dynamicAnswers[f.key] = v),
        );

      case 'select':
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: DropdownButtonFormField<String>(
            value: (value as String?),
            decoration: InputDecoration(labelText: f.label),
            items: f.options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
            onChanged: (v) => setState(() => dynamicAnswers[f.key] = v),
            validator: (v) =>
                (f.required && (v == null || v.isEmpty)) ? 'Requerido' : null,
          ),
        );

      case 'number':
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: TextFormField(
            initialValue: value?.toString(),
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: f.label),
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
            decoration: InputDecoration(labelText: f.label),
            validator: (v) =>
                (f.required && (v == null || v.trim().isEmpty)) ? 'Requerido' : null,
            onChanged: (v) => dynamicAnswers[f.key] = v,
          ),
        );
    }
  }
}
