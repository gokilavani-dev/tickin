enum SlotStatus { available, booked, closed }

class MasterSlot {
  final int slotId;
  final String date;
  final String session; // Morning / Afternoon / Evening / Night
  String timeLabel;

  SlotStatus status;

  double thresholdAmount;
  bool isOpen; // Night control

  List<SlotOrder> orders;

  MasterSlot({
    required this.slotId,
    required this.date,
    required this.session,
    required this.timeLabel,
    this.status = SlotStatus.available,
    this.thresholdAmount = 20000,
    this.isOpen = true,
    List<SlotOrder>? orders,
  }) : orders = orders ?? [];

  double get usedAmount => orders.fold(0, (sum, o) => sum + o.amount);

  bool get isFull => usedAmount >= thresholdAmount;
}

class SlotOrder {
  final String orderId;
  final String distributorName;
  final String locationId;
  final double amount;
  final String vehicleType; // FULL_TRUCK / HALF_TRUCK

  SlotOrder({
    required this.orderId,
    required this.distributorName,
    required this.locationId,
    required this.amount,
    required this.vehicleType,
  });
}
