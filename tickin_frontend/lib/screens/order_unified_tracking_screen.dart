// ignore_for_file: unnecessary_to_list_in_spreads, unused_local_variable

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_scope.dart';

class OrderUnifiedTrackingScreen extends StatefulWidget {
  final String orderId;
  const OrderUnifiedTrackingScreen({super.key, required this.orderId});

  @override
  State<OrderUnifiedTrackingScreen> createState() =>
      _OrderUnifiedTrackingScreenState();
}

class _OrderUnifiedTrackingScreenState extends State<OrderUnifiedTrackingScreen> {
  bool loading = false;

  Map<String, dynamic> meta = {};

  // ✅ Common (FULL) neat timeline
  List<Map<String, dynamic>> neatCommon = [];

  // ✅ Pre-merge timelines (D1/D2) keyed by childOrderId
  Map<String, List<Map<String, dynamic>>> preMerge = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void toast(String msg) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    });
  }

  // ✅ IST formatter: backend already sends IST string, but keep safe handling.
  String formatIST(String? raw) {
    if (raw == null || raw.trim().isEmpty) return "";
    final s = raw.trim();

    // If already like "10 Jan 2026, 05:28 PM" keep it
    final looksPretty = RegExp(r"[A-Za-z]{3}").hasMatch(s) &&
        RegExp(r"\bAM\b|\bPM\b", caseSensitive: false).hasMatch(s);
    if (looksPretty) return s;

    // else parse ISO -> local
    try {
      final dt = DateTime.parse(s).toLocal();
      return DateFormat("dd MMM yyyy, hh:mm a").format(dt);
    } catch (_) {
      return s;
    }
  }

  String _s(Map e, List<String> keys) {
    for (final k in keys) {
      final v = e[k];
      if (v != null && v.toString().trim().isNotEmpty) return v.toString();
    }
    return "";
  }

  bool _isDone(String s) => s.toUpperCase() == "DONE";
  bool _isCurrent(String s) => s.toUpperCase() == "CURRENT";

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final scope = TickinAppScope.of(context);

      final resp = await scope.timelineApi.getTimeline(widget.orderId);

      final res = (resp["data"] is Map)
          ? Map<String, dynamic>.from(resp["data"])
          : Map<String, dynamic>.from(resp);

      final metaRaw = res["meta"];
      meta = (metaRaw is Map) ? Map<String, dynamic>.from(metaRaw) : {};

      // ✅ Common neat timeline (backend: neatTimeline)
      dynamic neatRaw = res["neatTimeline"];
      if (neatRaw is Map) neatRaw = neatRaw["neatTimeline"];
      final commonList = (neatRaw is List ? neatRaw : [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      // ✅ preMerge: { childOrderId: [steps...] }
      final preRaw = res["preMerge"];
      final Map<String, List<Map<String, dynamic>>> pre = {};
      final isMerged = (meta["isMerged"] == true) || pre.isNotEmpty;
      final filteredCommon = isMerged
    ? commonList
    : commonList.where((s) {
        final k = (s["key"] ?? "").toString().toUpperCase();
        return !k.contains("_D2");
      }).toList();

      if (preRaw is Map) {
        preRaw.forEach((key, value) {
          final k = key.toString();
          final list = (value is List ? value : [])
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          if (list.isNotEmpty) pre[k] = list;
        });
      }

      if (mounted) {
        setState(() {
          neatCommon = commonList;
          preMerge = pre;
        });
      }
    } catch (e) {
      toast("❌ Timeline load failed: $e");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMerged = (meta["isMerged"] == true) || preMerge.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text("Tracking ${widget.orderId}"),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(14),
                children: [
                  _metaCard(),
                  const SizedBox(height: 14),

                  if (isMerged && preMerge.isNotEmpty) ...[
                    _sectionTitle("Pre-Merge Timelines"),
                    const SizedBox(height: 10),
                    ...preMerge.entries.map((e) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _timelineCard(
                          title: "Order ${e.key}",
                          steps: e.value,
                          subtitle: "Pre-merge (D1/D2)",
                        ),
                      );
                    }).toList(),
                    const SizedBox(height: 6),
                    _sectionTitle("Common Timeline (Post-Merge)"),
                    const SizedBox(height: 10),
                  ],

                  _timelineCard(
                    title: "Tracking Timeline",
                    steps: neatCommon,
                    subtitle: isMerged ? "Common (FULL order)" : "Single (D1 only)",
                  ),
                ],
              ),
            ),
    );
  }

  Widget _sectionTitle(String t) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Text(
        t,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
      ),
    );
  }

  Widget _metaCard() {
    final distributor = (meta["distributorName"] ?? "-").toString();
    final vehicleNo = (meta["vehicleNo"] ?? "-").toString();
    final driver = (meta["driverName"] ?? "-").toString();
    final st = (meta["status"] ?? "-").toString();

    // ✅ show mode line (single vs merged)
    final isMerged = meta["isMerged"] == true;
    String mode = "Single (D1 only)";
    if (isMerged) mode = "Merged (D1 + D2)";

    // If backend sends childOrderIds, show count
    final kids = (meta["childOrderIds"] is List)
        ? List.from(meta["childOrderIds"])
        : const [];
    if (isMerged && kids.isNotEmpty) {
      mode = "Merged (${kids.length} orders)";
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Distributor: $distributor",
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text("Vehicle No: $vehicleNo"),
            Text("Driver: $driver"),
            const SizedBox(height: 10),
            Text("Status: $st",
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text("Mode: $mode", style: TextStyle(color: Colors.grey.shade300)),
          ],
        ),
      ),
    );
  }

  Widget _timelineCard({
    required String title,
    required List<Map<String, dynamic>> steps,
    String? subtitle,
  }) {
    if (steps.isEmpty) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Text("$title: No tracking updates yet."),
        ),
      );
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            if (subtitle != null && subtitle.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(subtitle, style: TextStyle(color: Colors.grey.shade300)),
            ],
            const SizedBox(height: 14),

            ...steps.map((step) {
              final title = _s(step, ["title", "key"]);
              final status = _s(step, ["status"]);
              final rawTime = _s(step, ["time"]);
              final time = formatIST(rawTime);

              final done = _isDone(status);
              final current = _isCurrent(status);

              Color dotColor = Colors.grey;
              if (done) dotColor = Colors.green;
              if (current) dotColor = Colors.orange;

              IconData dotIcon = Icons.radio_button_unchecked;
              if (done) dotIcon = Icons.check_circle;
              if (current) dotIcon = Icons.radio_button_checked;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Icon(dotIcon, color: dotColor, size: 22),
                      if (step != steps.last)
                        Container(
                          width: 2,
                          height: 50,
                          margin: const EdgeInsets.symmetric(vertical: 2),
                          color: Colors.grey.shade500,
                        ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight:
                                  current ? FontWeight.bold : FontWeight.w600,
                              color: done || current
                                  ? Colors.white
                                  : Colors.grey.shade400,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            status,
                            style: TextStyle(
                              fontSize: 12,
                              color: dotColor,
                              fontWeight:
                                  current ? FontWeight.bold : FontWeight.w500,
                            ),
                          ),
                          if (time.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                time,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade300,
                                ),
                              ),
                            ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}
