import 'package:flutter/material.dart';
import '../../domain/entities/perfil.dart';
import '../../data/perfil_data.dart'; // Donde está ProfileServiceSupabase
import '../../domain/services/perfil_services.dart';
import '../../domain/entities/deportes.dart';
import '../../domain/services/deportes_services.dart';
import '../../data/deportes_data.dart'; // Donde está SportServiceSupabase

class EditProfileScreen extends StatefulWidget {
  final Profile? profile;
  const EditProfileScreen({super.key, required this.profile});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final ProfileService _profileService = ProfileServiceSupabase();
  final SportService _sportService = SportServiceSupabase();

  late final TextEditingController _nameController;
  late final TextEditingController _bioController;
  late final TextEditingController _locationController;

  List<Sport> _sports = [];
  List<String> _selectedSportIds = [];
  String? _selectedAvatar; // Emoji (se guarda en avatarUrl)
  bool _isLoading = false;
  bool _loadingSports = true;

  @override
  void initState() {
    super.initState();
    final profile = widget.profile;
    _nameController = TextEditingController(text: profile?.name ?? '');
    _bioController = TextEditingController(text: profile?.bio ?? '');
    _locationController = TextEditingController(text: profile?.locationLabel ?? '');
    _selectedAvatar = profile?.avatarUrl; // emoji guardado o null
    _selectedSportIds = List<String>.from(profile?.preferredSportIds ?? []);
    _fetchSports();
  }

  Future<void> _fetchSports() async {
    setState(() => _loadingSports = true);
    try {
      final sports = await _sportService.listAll();
      setState(() {
        _sports = sports;
        // Validamos los deportes del perfil con los de la base
        final validSportIds = sports.map((s) => s.id).toSet();
        _selectedSportIds = _selectedSportIds.where((id) => validSportIds.contains(id)).toList();
      });
    } catch (_) {
      setState(() => _sports = []);
    } finally {
      setState(() => _loadingSports = false);
    }
  }

  Future<String?> showEmojiPicker(BuildContext context) async {
    final emojis = ['😀','😺','🤖','🏀','🚴‍♂️','🏊‍♂️','🎮','🍕','🐶','🐱','👽','🦄','🐻','🐨','🐼'];
    return showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Selecciona tu avatar'),
        children: emojis.map((emoji) => SimpleDialogOption(
          onPressed: () => Navigator.pop(context, emoji),
          child: Center(child: Text(emoji, style: TextStyle(fontSize: 36))),
        )).toList(),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    if (widget.profile == null) return;
    setState(() => _isLoading = true);
    try {
      final updatedProfile = widget.profile!.copyWith(
        name: _nameController.text,
        bio: _bioController.text,
        locationLabel: _locationController.text,
        preferredSportIds: _selectedSportIds,
        avatarUrl: _selectedAvatar, // emoji aquí (o null)
      );
      await _profileService.updateMyProfile(updatedProfile);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil actualizado con éxito')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ocurrió un error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Se muestra la inicial del nombre si no hay emoji seleccionado
    String? name = _nameController.text.trim();
    String? initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar perfil', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: SizedBox(
                width: 24, height: 24,
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
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () async {
                final selected = await showEmojiPicker(context);
                if (selected != null) {
                  setState(() => _selectedAvatar = selected);
                }
              },
              child: CircleAvatar(
                radius: 48,
                child: _selectedAvatar != null && _selectedAvatar!.isNotEmpty
                    ? Text(_selectedAvatar!, style: TextStyle(fontSize: 48))
                    : Text(initial, style: TextStyle(fontSize: 48)),
              ),
            ),
            const SizedBox(height: 8),
            Text('Toca para cambiar avatar', style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 24),
            _buildTextField('Nombre', _nameController),
            const SizedBox(height: 16),
            _buildTextField('Biografía / Descripción', _bioController),
            const SizedBox(height: 16),
            _buildTextField('Ubicación', _locationController),
            const SizedBox(height: 16),
            _loadingSports
              ? const Center(child: CircularProgressIndicator())
              : _buildMultiSelectSports('Deportes favoritos'),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0),
              borderSide: const BorderSide(color: Colors.grey),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
          ),
        ),
      ],
    );
  }

  // Multi-select con chips (puedes cambiar por Dropdown si quieres solo uno)
  Widget _buildMultiSelectSports(String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        if (_sports.isEmpty)
          const Text("No hay deportes disponibles.")
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _sports.map((sport) {
              final selected = _selectedSportIds.contains(sport.id);
              return FilterChip(
                label: Text('${sport.iconEmoji ?? ''} ${sport.name}'),
                selected: selected,
                onSelected: (val) {
                  setState(() {
                    if (val) {
                      _selectedSportIds.add(sport.id);
                    } else {
                      _selectedSportIds.remove(sport.id);
                    }
                  });
                },
                selectedColor: Colors.green[200],
              );
            }).toList(),
          ),
      ],
    );
  }
}
