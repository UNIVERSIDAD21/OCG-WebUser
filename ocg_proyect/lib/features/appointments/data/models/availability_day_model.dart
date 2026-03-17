class AvailabilityDayModel {
  const AvailabilityDayModel({
    required this.id,
    required this.date,
    required this.timezone,
    required this.slotDurationMinutes,
    required this.slots,
  });

  final String id;
  final String date;
  final String timezone;
  final int slotDurationMinutes;
  final Map<String, bool> slots;

  factory AvailabilityDayModel.fromJson(String id, Map<String, dynamic> json) {
    final rawSlots = (json['slots'] as Map<String, dynamic>? ?? const {});
    return AvailabilityDayModel(
      id: id,
      date: (json['date'] ?? id).toString(),
      timezone: (json['timezone'] ?? 'America/Bogota').toString(),
      slotDurationMinutes: (json['slotDurationMinutes'] as num?)?.toInt() ?? 30,
      slots: rawSlots.map((k, v) => MapEntry(k, v == true)),
    );
  }

  bool isSlotAvailable(String time) => slots[time] != false;
}
