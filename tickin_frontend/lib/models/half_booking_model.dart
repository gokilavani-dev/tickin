class HalfBooking {
  final String orderId;
  final String agencyName;
  final double amount;
  final String time;
  final String mergeKey;

  HalfBooking({
    required this.orderId,
    required this.agencyName,
    required this.amount,
    required this.time,
    required this.mergeKey,
  });

  static String _s(dynamic v) => (v ?? "").toString().trim();

  factory HalfBooking.fromJson(Map<String, dynamic> json) {
    final oid = _s(
      json["orderId"] ??
      json["orderID"] ??
      json["order_id"] ??
      json["id"],
    );

    final t = _s(
      json["slotTime"] ??
      json["time"] ??
      json["bookingTime"],
    );

    final mk = _s(
      json["mergeKey"] ??
      json["merge_key"],
    );

    final ag = _s(
      json["agencyName"] ??
      json["distributorName"] ??
      json["agency"] ??
      json["name"],
    );

    final amtRaw = json["amount"] ?? 0;
    final amt = (amtRaw is num) ? amtRaw.toDouble() : (double.tryParse("$amtRaw") ?? 0);

    return HalfBooking(
      orderId: oid,
      agencyName: ag,
      amount: amt,
      time: t,
      mergeKey: mk,
    );
  }
}
