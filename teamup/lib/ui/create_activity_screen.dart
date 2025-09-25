import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/entities/deportes.dart';   // Sport (con fields: List<FieldSpec>)
import '../domain/entities/field_spec.dart'; // FieldSpec
import '../domain/entities/actividad.dart';  // Activity (modelo con fields jsonb)
import '../data/actividad_data.dart';        // ActivityServiceSupabase

class CreateActivityScreen extends StatefulWidget {
  const CreateActivityScreen({
    super.key,
    required this.sport, // deporte ya elegido antes
  });

  final Sport sport;

  @override
  State<CreateActivityScreen> createState() => _CreateActivityScreenState();
}

class _CreateActivityScreenState extends State<CreateActivityScreen> {
  final _page = PageController();

  // forms
  final _form1 = GlobalKey<FormState>();
  final _form2 = GlobalKey<FormState>();
  final _form3 = GlobalKey<FormState>();

  // paso 1
  final titleCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  final maxPlayersCtrl = TextEditingController();
  String? level; // Principiante | Intermedio | Avanzado

  // paso 2
  DateTime? _date;
  TimeOfDay? _time;
  final locationCtrl = TextEditingController(); // place_name (texto simple)
  // si luego agregas Google Places, puedes setear formattedAddress/lat/lng

  // paso 3 (dinámico)
  late final List<FieldSpec> dynamicFields;
  final Map<String, dynamic> dynamicAnswers = {};

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    dynamicFields = widget.sport.fields;
  }

  @override
  void dispose() {
    _page.dispose();
    titleCtrl.dispose();
    descCtrl.dispose();
    maxPlayersCtrl.dispose();
    locationCtrl.dispose();
    super.dispose();
  }

  void _next(int step) {
    final isOk = switch (step) {
      1 => _form1.currentState?.validate() ?? false,
      2 => _form2.currentState?.validate() ?? false,
      _ => true,
    };
    if (isOk) {
      _page.nextPage(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
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
    final picked =
        await showTimePicker(context: context, initialTime: _time ?? TimeOfDay.now());
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _publish() async {
    if (!(_form3.currentState?.validate() ?? false)) return;
    if (_date == null || _time == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona fecha y hora')),
      );
      _page.jumpToPage(1);
      return;
    }

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes iniciar sesión')),
      );
      return;
    }

    // construir DateTime UTC
    final localDT = DateTime(
      _date!.year,
      _date!.month,
      _date!.day,
      _time!.hour,
      _time!.minute,
    );
    final dateUtc = localDT.toUtc();

    final maxPlayers = num.tryParse(maxPlayersCtrl.text.trim())?.toInt();

    final activity = Activity(
      id: '', // lo genera supabase
      creatorId: userId,
      sportId: widget.sport.id,
      title: titleCtrl.text.trim(),
      description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
      status: 'published',
      dateUtc: dateUtc,
      placeName: locationCtrl.text.trim().isEmpty ? null : locationCtrl.text.trim(),
      formattedAddress: null,
      lat: null,
      lng: null,
      level: level,
      maxPlayers: maxPlayers,
      fields: Map<String, dynamic>.from(dynamicAnswers),
    );

    setState(() => _saving = true);
    try {
      final created = await ActivityServiceSupabase().create(activity);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Actividad publicada (${created.id})')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al publicar: $e')),
      );
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
                        Text(widget.sport.name, style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
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
                        FilledButton(
                          onPressed: () => _next(1),
                          child: const Text('Siguiente'),
                        ),
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
                          subtitle: Text(
                            _time != null ? _time!.format(context) : 'Selecciona hora',
                          ),
                          trailing: const Icon(Icons.access_time),
                          onTap: _pickTime,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: locationCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Ubicación',
                            hintText: 'Ej. Estadio Municipal, Cancha 2',
                          ),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Ingresa una ubicación' : null,
                        ),
                        const Spacer(),
                        FilledButton(
                          onPressed: () => _next(2),
                          child: const Text('Siguiente'),
                        ),
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
                        if (dynamicFields.isEmpty)
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
            items: (f.options ?? const [])
                .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                .toList(),
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
