import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../componentes/navigate_bar.dart';

// === Paleta TeamUp (solo usada en esta pantalla) ===
const _lightPrimary    = Color(0xFFDCEDC8);
const _primary         = Color(0xFF8BC34A);
const _accent          = Color(0xFFFFC107);
const _textPrimary     = Color(0xFF212121);
const _textSecondary   = Color(0xFF757575);
const _dividerColor    = Color(0xFFBDBDBD);

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  bool _loading = true;
  String? _error;
  List<_AlertItem> _alerts = [];

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) {
        setState(() {
          _loading = false;
          _error = 'Debes iniciar sesión para ver tus alertas';
        });
        return;
      }

      final rows = await client
          .from('alerts')
          .select(
            'id, activity_id, activity_title, activity_date, place_name, formatted_address, sport_name, is_read, created_at',
          )
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      // debug
      debugPrint('ALERTS raw rows: $rows');
      debugPrint('CURRENT USER ID: ${user.id}');

      final list = (rows as List)
          .map((r) => _AlertItem.fromMap(r as Map<String, dynamic>))
          .toList();

      setState(() {
        _alerts = list;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error cargando alertas: $e');
      setState(() {
        _loading = false;
        _error = 'Ocurrió un error al cargar tus alertas';
      });
    }
  }

  Future<void> _markAsRead(_AlertItem item) async {
    try {
      final client = Supabase.instance.client;

      await client
          .from('alerts')
          .update({'is_read': true})
          .eq('id', item.id);

      setState(() {
        _alerts = _alerts
            .map((a) => a.id == item.id ? a.copyWith(isRead: true) : a)
            .toList();
      });
    } catch (e) {
      debugPrint('Error marcando alerta como leída: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo marcar como leída')),
      );
    }
  }

  Future<void> _markAllAsRead() async {
    if (_alerts.isEmpty) return;

    try {
      final client = Supabase.instance.client;
      final ids = _alerts.map((a) => a.id).toList();

      await client
          .from('alerts')
          .update({'is_read': true})
          .inFilter('id', ids);

      setState(() {
        _alerts = _alerts.map((a) => a.copyWith(isRead: true)).toList();
      });
    } catch (e) {
      debugPrint('Error marcando todas como leídas: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudieron marcar todas como leídas')),
      );
    }
  }

  Future<void> _openActivityDetail(_AlertItem item) {
    return Navigator.pushNamed(
      context,
      '/detail-activity',
      arguments: item.activityId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // fondo limpio tipo M3
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _textPrimary,
        elevation: 0,
        title: const Text('Alertas'),
        actions: [
          if (_alerts.any((a) => !a.isRead))
            IconButton(
              tooltip: 'Marcar todas como leídas',
              onPressed: _markAllAsRead,
              icon: const Icon(Icons.done_all),
              color: _accent,
            ),
        ],
      ),
      body: RefreshIndicator(
        color: _primary,
        onRefresh: _loadAlerts,
        child: _buildBody(),
      ),
      bottomNavigationBar: TeamUpBottomNav(
        currentIndex: 2,
        onTap: (i) => teamUpNavigate(context, i),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _primary));
    }

    if (_error != null) {
      return ListView(
        children: const [
          SizedBox(height: 80),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Ocurrió un error al cargar tus alertas.',
              style: TextStyle(
                fontSize: 16,
                color: _textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    }

    if (_alerts.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 80),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'No tienes alertas por ahora.\nCuando se creen actividades que coincidan con tus preferencias, aparecerán aquí.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _textSecondary,
                fontSize: 15,
              ),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _alerts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final a = _alerts[index];
        return _buildAlertCard(context, a);
      },
    );
  }

  Widget _buildAlertCard(BuildContext context, _AlertItem a) {
    final dateStr = a.activityDate != null
        ? '${a.activityDate!.day.toString().padLeft(2, '0')}/'
          '${a.activityDate!.month.toString().padLeft(2, '0')}/'
          '${a.activityDate!.year} '
          '${a.activityDate!.hour.toString().padLeft(2, '0')}:'
          '${a.activityDate!.minute.toString().padLeft(2, '0')}'
        : '';

    final bool isUnread = !a.isRead;

    return Card(
      elevation: isUnread ? 2 : 0,
      color: isUnread ? _lightPrimary : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isUnread ? _primary.withOpacity(0.4) : _dividerColor,
          width: 0.7,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          await _openActivityDetail(a);
          if (!a.isRead) {
            _markAsRead(a);
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icono izquierda, estilo M3 “tonal”
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _primary.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.notifications_active_outlined,
                  color: _primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),

              // Contenido principal
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Título + "Nuevo"
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            a.activityTitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _textPrimary,
                              fontWeight:
                                  isUnread ? FontWeight.w700 : FontWeight.w500,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        if (isUnread) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _accent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'Nuevo',
                              style: TextStyle(
                                fontSize: 10,
                                color: _textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),

                    if (a.sportName != null && a.sportName!.isNotEmpty)
                      Text(
                        a.sportName!,
                        style: const TextStyle(
                          color: _primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),

                    const SizedBox(height: 4),

                    if (dateStr.isNotEmpty)
                      Row(
                        children: [
                          const Icon(Icons.event, size: 14, color: _textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            dateStr,
                            style: const TextStyle(
                              fontSize: 12,
                              color: _textSecondary,
                            ),
                          ),
                        ],
                      ),

                    const SizedBox(height: 4),

                    if (a.placeName != null && a.placeName!.isNotEmpty)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.place, size: 14, color: _textSecondary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              a.placeName!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: _textSecondary,
                              ),
                            ),
                          ),
                        ],
                      )
                    else if (a.formattedAddress != null &&
                        a.formattedAddress!.isNotEmpty)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.place, size: 14, color: _textSecondary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              a.formattedAddress!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: _textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),

              if (isUnread)
                IconButton(
                  tooltip: 'Marcar como leída',
                  icon: const Icon(
                    Icons.check_circle_outline,
                    size: 20,
                    color: _primary,
                  ),
                  onPressed: () => _markAsRead(a),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// --------- Modelo local para una alerta ---------

class _AlertItem {
  final int id; // id de la alerta (alerts.id)
  final String activityId;
  final String activityTitle;
  final DateTime? activityDate;
  final String? placeName;
  final String? formattedAddress;
  final String? sportName;
  final bool isRead;
  final DateTime? createdAt;

  _AlertItem({
    required this.id,
    required this.activityId,
    required this.activityTitle,
    this.activityDate,
    this.placeName,
    this.formattedAddress,
    this.sportName,
    required this.isRead,
    this.createdAt,
  });

  factory _AlertItem.fromMap(Map<String, dynamic> m) {
    return _AlertItem(
      id: (m['id'] as num).toInt(),
      activityId: (m['activity_id'] ?? '').toString(),
      activityTitle: (m['activity_title'] ?? '').toString(),
      activityDate: m['activity_date'] != null
          ? DateTime.parse(m['activity_date'].toString()).toLocal()
          : null,
      placeName: m['place_name'] as String?,
      formattedAddress: m['formatted_address'] as String?,
      sportName: m['sport_name'] as String?,
      isRead: (m['is_read'] as bool?) ?? false,
      createdAt: m['created_at'] != null
          ? DateTime.parse(m['created_at'].toString()).toLocal()
          : null,
    );
  }

  _AlertItem copyWith({
    bool? isRead,
  }) {
    return _AlertItem(
      id: id,
      activityId: activityId,
      activityTitle: activityTitle,
      activityDate: activityDate,
      placeName: placeName,
      formattedAddress: formattedAddress,
      sportName: sportName,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }
}
