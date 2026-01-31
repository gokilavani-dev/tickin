import 'slot_master.dart';

const sessions = ["Morning", "Afternoon", "Evening", "Night"];

const Map<String, List<String>> sessionTimes = {
  "Morning": ["09:00", "09:30", "10:00", "10:30"],
  "Afternoon": ["12:00", "12:30", "13:00", "13:30"],
  "Evening": ["15:00", "15:30", "16:00", "16:30"],
  "Night": ["18:00", "18:30", "19:00", "19:30"],
};

List<MasterSlot> generateSlots(String date) {
  int id = 3001;
  final slots = <MasterSlot>[];

  for (final s in sessions) {
    for (final t in sessionTimes[s]!) {
      slots.add(
        MasterSlot(
          slotId: id++,
          date: date,
          session: s,
          timeLabel: t,
          isOpen: s != "Night", // Night default CLOSED
        ),
      );
    }
  }
  return slots;
}

List<String> allowedDates() => ["2026-01-07", "2026-01-08"];
