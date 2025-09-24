import 'package:flutter/material.dart';
import 'package:teamup/data/deportes_data.dart';
// Asegúrate de importar tus clases reales
import '../../domain/entities/perfil.dart';
import '../../data/perfil_data.dart'; // Donde está ProfileServiceSupabase
import '../../domain/services/perfil_services.dart';
import '../../domain/entities/deportes.dart';
import '../../domain/services/deportes_services.dart';

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

  List<Sport> _sports = [];                 // Lista de deportes desde la base
  String? _selectedSportId;                 // ID del deporte seleccionado
  bool _isLoading = false;
  bool _loadingSports = true;

  @override
  void initState() {
    super.initState();
    final profile = widget.profile;
    _nameController = TextEditingController(text: profile?.name ?? '');
    _bioController = TextEditingController(text: profile?.bio ?? '');
    _locationController = TextEditingController(text: profile?.locationLabel ?? '');
    _fetchSportsAndSetSelected();
  }

  Future<void> _fetchSportsAndSetSelected() async {
    setState(() => _loadingSports = true);
    try {
      final sports = await _sportService.listAll(); // List<Sport>
      setState(() {
        _sports = sports;
        // Si el perfil ya tenía deportes, asignamos el primero que exista
        if (widget.profile != null && widget.profile!.preferredSportIds.isNotEmpty) {
          final firstValid = widget.profile!.preferredSportIds.firstWhere(
              (id) => _sports.any((s) => s.id == id),
              orElse: () => '',
            );
            _selectedSportId = firstValid.isNotEmpty ? firstValid : null;
        }
      });
    } catch (_) {
      setState(() => _sports = []);
    } finally {
      setState(() => _loadingSports = false);
    }
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
        // Guarda el deporte seleccionado como una lista de un solo elemento
        preferredSportIds: _selectedSportId != null ? [_selectedSportId!] : [],
      );
      await _profileService.updateMyProfile(updatedProfile);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil actualizado con éxito')),
        );
        Navigator.of(context).pop(true); // true si el perfil se cambia
      }
    } on StateError catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.message}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ocurrió un error inesperado: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
            const SizedBox(height: 24),
            _buildTextField('Nombre', _nameController),
            const SizedBox(height: 16),
            _buildTextField('Biografía / Descripción', _bioController),
            const SizedBox(height: 16),
            _buildTextField('Ubicación', _locationController),
            const SizedBox(height: 16),
            _loadingSports
              ? const Center(child: CircularProgressIndicator())
              : _buildDropdownField('Deporte Favorito'),
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

  Widget _buildDropdownField(String label) {
    // Validación: si el id ya no existe, límpialo
    if (_selectedSportId != null && !_sports.any((s) => s.id == _selectedSportId)) {
      _selectedSportId = null;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedSportId,
          items: _sports.map((sport) {
            return DropdownMenuItem<String>(
              value: sport.id,
              child: Text('${sport.iconEmoji ?? ''} ${sport.name}'),
            );
          }).toList(),
          onChanged: (newValue) {
            setState(() => _selectedSportId = newValue);
          },
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
          ),
        ),
      ],
    );
  }
}
