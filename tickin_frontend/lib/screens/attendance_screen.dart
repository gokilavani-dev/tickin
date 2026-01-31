import 'dart:convert';

import 'package:flutter/material.dart';
import '../app_scope.dart';
import '../api/location.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  void _showMsg(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  bool checkingIn = false;
  bool checkingOut = false;
  String? username;
  bool userLoading = true;
  @override
  void initState() {
    super.initState();
  }

  bool _loadedUser = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_loadedUser) return;
    _loadedUser = true;

    _loadUser();
  }

  Future<void> _loadUser() async {
    final scope = TickinAppScope.of(context);
    final userJson = await scope.tokenStore.getUserJson();

    if (userJson == null) return;

    final u = jsonDecode(userJson) as Map<String, dynamic>;

    setState(() {
      username = (u["name"] ?? u["Name"] ?? u["uid"] ?? "").toString();
      userLoading = false;
    });
  }

  // ---------------- CHECK-IN ----------------
  Future<void> _doCheckIn() async {
    if (checkingIn) return; // 🔒 double tap prevent

    setState(() => checkingIn = true);

    try {
      final pos = await LocationService.getCurrentPosition();

      if (!mounted) return;

      if (pos == null) {
        _showMsg("Please turn ON Location.");
        return;
      }

      final attendanceApi = TickinAppScope.of(context).attendanceApi;

      final res = await attendanceApi.checkIn(
        lat: pos.latitude,
        lng: pos.longitude,
      );

      if (!mounted) return;

      if (res["ok"] == true) {
        _showMsg("Checked In Successfully!");
      } else if (res["error"] == "already_checked_in") {
        _showMsg("You have already checked in today.");
      } else if (res["error"] == "outside_all_locations") {
        _showMsg("You are not in an allowed office location.");
      } else {
        _showMsg("Check-In Failed.");
      }
    } catch (e) {
      _showMsg(e.toString());
    } finally {
      if (mounted) setState(() => checkingIn = false);
    }
  }

  // ---------------- CHECK-OUT ----------------
  Future<void> _doCheckOut() async {
    if (checkingOut) return; // 🔒 double tap prevent

    setState(() => checkingOut = true);

    try {
      final pos = await LocationService.getCurrentPosition();

      if (!mounted) return;

      if (pos == null) {
        _showMsg("Please turn ON Location & allow permission.");
        return;
      }

      final attendanceApi = TickinAppScope.of(context).attendanceApi;

      final res = await attendanceApi.checkOut(
        lat: pos.latitude,
        lng: pos.longitude,
      );

      if (!mounted) return;

      if (res["ok"] == true) {
        _showMsg("Checked Out Successfully!");
      } else if (res["error"] == "no_checkin_found") {
        _showMsg("You have not checked in today.");
      } else if (res["error"] == "already_checked_out") {
        _showMsg("You have already checked out today.");
      } else if (res["error"] == "checkout_window_closed") {
        _showMsg("Checkout time exceeded. Contact admin.");
      } else if (res["error"] == "outside_all_locations") {
        _showMsg("You are not in an allowed office location.");
      } else {
        _showMsg("Check-Out Failed. Try again.");
      }
    } catch (e) {
      _showMsg(e.toString());
    } finally {
      if (mounted) setState(() => checkingOut = false);
    }
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(title: const Text("Dashboard"), leading: BackButton()),

      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (userLoading)
              const CircularProgressIndicator()
            else
              Text(
                "Welcome, ${username ?? ""}",
                style: TextStyle(
                  fontSize: 22,
                  color: Colors.purple.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),

            const SizedBox(height: 40),

            ElevatedButton(
              onPressed: checkingIn ? null : _doCheckIn,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 15,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: checkingIn
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      "Check In",
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: checkingOut ? null : _doCheckOut,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 15,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: checkingOut
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      "Check Out",
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
