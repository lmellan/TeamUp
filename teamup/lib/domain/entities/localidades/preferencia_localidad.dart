class PreferenciaLocalidad {
  final String userId;
  final int? regionId;   // null si no aplica
  final int? comunaId;   // null => “toda la región”
  final int prioridad;
  const PreferenciaLocalidad({
    required this.userId,
    this.regionId,
    this.comunaId,
    this.prioridad = 1,
  });
}