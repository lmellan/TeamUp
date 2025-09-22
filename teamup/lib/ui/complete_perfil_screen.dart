import 'package:flutter/material.dart';
 
import '../../domain/entities/deportes.dart';
import '../../domain/services/perfil_services.dart';
import '../../domain/services/deportes_services.dart';
import '../../data/perfil_data.dart';
import '../../data/deportes_data.dart';

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

  bool _loading = false;
  bool _notify = true;
  List<Sport> _sports = [];
  final Set<String> _selectedSportIds = <String>{};

  @override
  void initState() {
    super.initState();
    _fetchSportsAndProfile();
  }

  @override
  void dispose() {
    _bio.dispose();
    super.dispose();
  }

  Future<void> _fetchSportsAndProfile() async {
    setState(() => _loading = true);
    try {
      final sports = await _sportSvc.listAll();
      final prof = await _profileSvc.getMyProfile();

      setState(() {
        _sports = sports;
        if (prof != null) {
          _bio.text = prof.bio ?? '';
          _selectedSportIds
            ..clear()
            ..addAll(prof.preferredSportIds);
          _notify = prof.notifyNewActivity;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudieron cargar los datos')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveAndContinue() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      // 1) lee perfil actual (para obtener id)
      final current = await _profileSvc.getMyProfile();
      if (current == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sesión no encontrada')),
        );
        setState(() => _loading = false);
        return;
      }

      // 2) crea nuevo estado inmutable
      final updated = current.copyWith(
        bio: _bio.text.trim().isEmpty ? null : _bio.text.trim(),
        notifyNewActivity: _notify,
        preferredSportIds: _selectedSportIds.toList(),
      );

      // 3) persiste
      await _profileSvc.updateMyProfile(updated);

      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/perfil');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error guardando: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final onSurfaceVariant = Theme.of(context).brightness == Brightness.dark
        ? Colors.white.withOpacity(0.75)
        : const Color(0xFF757575);

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
                  Text('TeamUp',
                      style: t.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      )),
                  const SizedBox(height: 16),
                  Text('Preferencias básicas',
                      style: t.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      )),
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

                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Deportes preferidos',
                              style: t.titleSmall?.copyWith(color: cs.onSurface)),
                        ),
                        const SizedBox(height: 8),

                        if (_loading && _sports.isEmpty)
                          const LinearProgressIndicator()
                        else if (_sports.isEmpty)
                          Text('Aún no hay deportes en el catálogo.',
                              style: t.bodySmall?.copyWith(color: onSurfaceVariant))
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _sports.map((s) {
                              final selected = _selectedSportIds.contains(s.id);
                              final label = (s.iconEmoji == null || s.iconEmoji!.isEmpty)
                                  ? s.name
                                  : '${s.iconEmoji}  ${s.name}';
                              return FilterChip(
                                label: Text(label),
                                selected: selected,
                                onSelected: (v) {
                                  setState(() {
                                    if (v) {
                                      _selectedSportIds.add(s.id);
                                    } else {
                                      _selectedSportIds.remove(s.id);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),

                        const SizedBox(height: 16),
                        SwitchListTile(
                          value: _notify,
                          onChanged: (v) => setState(() => _notify = v),
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
                            onPressed: _loading ? null : _saveAndContinue,
                            child: _loading
                                ? const CircularProgressIndicator()
                                : const Text('Continuar'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _loading
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
