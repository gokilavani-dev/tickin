import 'package:flutter/material.dart';
import '../../app_scope.dart';

class AllowanceConfigTab extends StatefulWidget {
  const AllowanceConfigTab({super.key});

  @override
  State<AllowanceConfigTab> createState() => _AllowanceConfigTabState();
}

class _AllowanceConfigTabState extends State<AllowanceConfigTab> {
  final _managerBata = TextEditingController();
  final _driverMorningBata = TextEditingController();
  final _driverNightAllowance = TextEditingController();

  String mlFrom = "09:00";
  String mlTo = "10:00";

  String dFrom = "09:00";
  String dTo = "10:00";

  String dnFrom = "09:00";
  String dnTo = "10:30";

  bool loading = true;
  bool saving = false;
  bool dirty = false;

  String? lastUpdatedAt;

  @override
  void initState() {
    super.initState();
  }

  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_initialized) {
      _initialized = true;
      _loadConfig();
    }
  }

  Future<void> _loadConfig() async {
    try {
      final api = TickinAppScope.of(context).attendanceConfigApi;
      final res = await api.getConfig();
      final c = res["data"];

      setState(() {
        _managerBata.text = c["managerLoadmanBata"].toString();
        _driverMorningBata.text = c["driverMorningBata"].toString();
        _driverNightAllowance.text = c["driverNightAllowance"].toString();

        mlFrom = c["managerLoadmanCheckin"]["from"];
        mlTo = c["managerLoadmanCheckin"]["to"];

        dFrom = c["driverCheckinNormal"]["from"];
        dTo = c["driverCheckinNormal"]["to"];

        dnFrom = c["driverCheckinAfterNightDuty"]["from"];
        dnTo = c["driverCheckinAfterNightDuty"]["to"];

        lastUpdatedAt = c["updatedAt"];
        loading = false;
        dirty = false;
      });
    } catch (e) {
      setState(() => loading = false);
      _showMsg("Failed to load config");
    }
  }

  void _showMsg(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _pickTime(String current, void Function(String) setTime) async {
    final parts = current.split(":");
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      ),
    );

    if (t != null) {
      setState(() {
        setTime(
          "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}",
        );
        dirty = true;
      });
    }
  }

  Future<bool> _confirmSave() async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text("Confirm Update"),
            content: const Text(
              "Are you sure you want to update allowance settings?",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text("Confirm"),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _save() async {
    if (saving || !dirty) return;

    final ok = await _confirmSave();
    if (!ok) return;

    setState(() => saving = true);

    try {
      final api = TickinAppScope.of(context).attendanceConfigApi;

      await api.updateConfig(
        managerLoadmanBata: int.parse(_managerBata.text),
        driverMorningBata: int.parse(_driverMorningBata.text),
        driverNightAllowance: int.parse(_driverNightAllowance.text),
        managerLoadmanCheckin: {"from": mlFrom, "to": mlTo},
        driverCheckinNormal: {"from": dFrom, "to": dTo},
        driverCheckinAfterNightDuty: {"from": dnFrom, "to": dnTo},
      );

      setState(() {
        saving = false;
        dirty = false;
      });

      _showMsg("Config updated successfully");
    } catch (e) {
      setState(() => saving = false);
      _showMsg("Update failed. Try again.");
    }
  }

  Widget _numberField(String label, TextEditingController c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        keyboardType: TextInputType.number,
        onChanged: (_) => setState(() => dirty = true),
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _timeRow(
    String label,
    String from,
    String to,
    VoidCallback pickFrom,
    VoidCallback pickTo,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Row(
            children: [
              TextButton(onPressed: pickFrom, child: Text("From $from")),
              TextButton(onPressed: pickTo, child: Text("To $to")),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (lastUpdatedAt != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              "Last updated: $lastUpdatedAt",
              style: const TextStyle(color: Colors.grey),
            ),
          ),

        // -------- AMOUNTS CARD --------
        Card(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Amounts",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple.shade700,
                  ),
                ),
                const SizedBox(height: 12),
                _numberField("Manager / Loadman Bata (₹)", _managerBata),
                _numberField("Driver Morning Bata (₹)", _driverMorningBata),
                _numberField(
                  "Driver Night Allowance (₹)",
                  _driverNightAllowance,
                ),
              ],
            ),
          ),
        ),

        // -------- TIME WINDOWS CARD --------
        Card(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.only(bottom: 20),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Time Windows",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple.shade700,
                  ),
                ),
                const SizedBox(height: 12),

                _timeRow(
                  "Manager / Loadman Check-in",
                  mlFrom,
                  mlTo,
                  () => _pickTime(mlFrom, (v) => mlFrom = v),
                  () => _pickTime(mlTo, (v) => mlTo = v),
                ),

                _timeRow(
                  "Driver Normal Check-in",
                  dFrom,
                  dTo,
                  () => _pickTime(dFrom, (v) => dFrom = v),
                  () => _pickTime(dTo, (v) => dTo = v),
                ),

                _timeRow(
                  "Driver After Night Duty",
                  dnFrom,
                  dnTo,
                  () => _pickTime(dnFrom, (v) => dnFrom = v),
                  () => _pickTime(dnTo, (v) => dnTo = v),
                ),
              ],
            ),
          ),
        ),

        // -------- SAVE BUTTON --------
        Center(
          child: ElevatedButton(
            onPressed: (!dirty || saving) ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple.shade700,
              padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 14),
            ),
            child: saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    "Save Changes",
                    style: TextStyle(color: Colors.white),
                  ),
          ),
        ),
      ],
    );
  }
}
