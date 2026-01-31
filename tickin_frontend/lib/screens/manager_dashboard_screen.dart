import 'package:book_yours/screens/attendance/dashboard_screen.dart';
import 'package:book_yours/screens/attendance_screen.dart';
import 'package:book_yours/screens/driver_orders.dart';
import 'package:book_yours/screens/master_orders_screen.dart';
import 'package:book_yours/screens/my_orders_screen.dart';
import 'package:flutter/material.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

import '../app_scope.dart';
import 'create_order_screen.dart';
import 'slots/slot_booking_screen.dart';
import 'login_screen.dart';

// ✅ FIX: import slot confirmed orders list screen
import 'manager_orders_with_slot_screen.dart';

/// =======================================================
/// 🔥 ROLE ENUM (NEW – ACTIVE)
/// =======================================================
enum UserRole {
  master,
  manager,
  driver,
  distributor,
  salesOfficer,
  salesOfficerVnr,
}

/// ✅ CHANGED: StatelessWidget -> StatefulWidget (to load counts)
class ManagerDashboardScreen extends StatefulWidget {
  final UserRole role;
  final String userId;

  const ManagerDashboardScreen({
    super.key,
    required this.userId,
    this.role = UserRole.manager, // default
  });

  @override
  State<ManagerDashboardScreen> createState() => _ManagerDashboardScreenState();
}

class _ManagerDashboardScreenState extends State<ManagerDashboardScreen> {
  bool loadingCounts = false;
  bool _loadedOnce = false;
  bool _oneSignalDone = false;

  int todayCount = 0;
  int pendingCount = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loadedOnce) {
      _loadedOnce = true;
      _loadCounts();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _linkAndSyncOneSignal();
    });
  }

  Future<void> _linkAndSyncOneSignal() async {
    if (_oneSignalDone) return;
    _oneSignalDone = true;

    final userId = widget.userId;
    String? playerId;

    // 1️⃣ Link external user first (login can rotate subscription id)
    try {
      await OneSignal.login(userId);
    } catch (e) {
      debugPrint("❌ OneSignal login failed: $e");
      return;
    }

    debugPrint("✅ OneSignal linked");
    debugPrint("userId = $userId");

    // 2️⃣ Wait until OneSignal subscription ready (after login)
    for (int i = 0; i < 20; i++) {
      playerId = OneSignal.User.pushSubscription.id;
      if (playerId != null && playerId.isNotEmpty) break;
      await Future.delayed(const Duration(milliseconds: 500));
    }

    if (playerId == null || playerId.isEmpty) {
      debugPrint("❌ OneSignal subscription not ready after login");
      return;
    }

    debugPrint("playerId = $playerId");

    // 3️⃣ Sync playerId to backend
    final scope = TickinAppScope.of(context);

    try {
      await scope.httpClient.post(
        "/api/users/me/player-id",
        body: {"playerId": playerId},
      );
      debugPrint("✅ PlayerId synced to backend");
    } catch (e) {
      debugPrint("❌ Failed to sync playerId: $e");
    }
  }

  Future<void> _loadCounts() async {
    // Badge counts needed only for master & manager (as per your request)
    final role = widget.role;
    if (!(role == UserRole.master || role == UserRole.manager)) return;

    setState(() => loadingCounts = true);
    try {
      final scope = TickinAppScope.of(context);

      // today count only for MASTER (backend allowRoles MASTER)
      if (role == UserRole.master) {
        final todayRes = await scope.ordersApi.today();
        dynamic todayRaw = todayRes["orders"] ?? todayRes["data"] ?? todayRes;
        if (todayRaw is Map) {
          todayRaw = todayRaw["orders"] ?? todayRaw["data"] ?? [];
        }
        todayCount = (todayRaw is List) ? todayRaw.length : 0;
      }

      // pending count for MASTER + MANAGER (backend allowRoles MASTER, MANAGER)
      final pendingRes = await scope.ordersApi.pending();
      dynamic pendingRaw =
          pendingRes["orders"] ?? pendingRes["data"] ?? pendingRes;
      if (pendingRaw is Map) {
        pendingRaw = pendingRaw["orders"] ?? pendingRaw["data"] ?? [];
      }
      pendingCount = (pendingRaw is List) ? pendingRaw.length : 0;

      if (mounted) setState(() {});
    } catch (_) {
      // silent (badge will show 0)
    } finally {
      if (mounted) setState(() => loadingCounts = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("VAGR Dashboard"),
        actions: [
          IconButton(onPressed: _loadCounts, icon: const Icon(Icons.refresh)),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final scope = TickinAppScope.of(context);
              await scope.tokenStore.clear();
              await OneSignal.logout();

              if (!context.mounted) return;

              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (_) => false,
              );
            },
          ),
        ],
      ),

      /// ===================================================
      /// 🔥 NEW ROLE BASED DASHBOARD (ACTIVE)
      /// ===================================================
      body: GridView.count(
        padding: const EdgeInsets.all(20),
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        children: _roleBasedCards(context),
      ),

      /// ===================================================
      /// ❌ OLD DASHBOARD (COMMENTED – NOT DELETED)
      /// ===================================================
      /*
      body: GridView.count(
        padding: const EdgeInsets.all(20),
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        children: [
          _card(
            context,
            Icons.event_available,
            "Slot Booking",
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SlotBookingScreen(
                    role: "MANAGER",
                    distributorCode: "MANAGER",
                    distributorName: "MANAGER",
                  ),
                ),
              );
            },
          ),

          _card(
            context,
            Icons.account_tree,
            "Orders Flow",
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ManagerOrdersWithSlotScreen(),
                ),
              );
            },
          ),

          _card(
            context,
            Icons.track_changes,
            "Tracking",
            () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Tracking open from Orders Flow screen"),
                ),
              );
            },
          ),

          _card(
            context,
            Icons.add_box_rounded,
            "Create Order",
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CreateOrderScreen(),
                ),
              );
            },
          ),
        ],
      ),
      */
    );
  }

  /// ===================================================
  /// 🔥 ROLE SWITCH (NEW – ACTIVE)
  /// ===================================================
  List<Widget> _roleBasedCards(BuildContext context) {
    switch (widget.role) {
      // ================= MASTER =================
      case UserRole.master:
        return [
          _cardWithBadge(
            context,
            Icons.today,
            "Today Orders",
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const MasterOrdersScreen(type: MasterOrderType.today),
                ),
              );
            },
            badgeCount: todayCount,
            showSpinner: loadingCounts,
          ),
          _cardWithBadge(context, Icons.dashboard, "Dashboard", () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AttendanceDashboardScreen(),
              ),
            );
          }),
          _cardWithBadge(
            context,
            Icons.pending_actions,
            "Pending Orders",
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const MasterOrdersScreen(type: MasterOrderType.pending),
                ),
              );
            },
            badgeCount: pendingCount,
            showSpinner: loadingCounts,
          ),
          _cardWithBadge(context, Icons.list_alt, "All Orders", () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    const MasterOrdersScreen(type: MasterOrderType.all),
              ),
            );
          }),
        ];

      // ================= MANAGER =================
      case UserRole.manager:
        return [
          _cardWithBadge(context, Icons.add_box_rounded, "Create Order", () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreateOrderScreen()),
            );
          }),
          _cardWithBadge(context, Icons.event_available, "Slot Booking", () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const SlotBookingScreen(
                  role: "MANAGER",
                  distributorCode: "MANAGER",
                  distributorName: "MANAGER",
                ),
              ),
            );
          }),
          _cardWithBadge(context, Icons.account_tree, "Order Flow", () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ManagerOrdersWithSlotScreen(),
              ),
            );
          }),
          // ✅ MANAGER pending orders badge too
          _cardWithBadge(
            context,
            Icons.pending_actions,
            "Pending Orders",
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const MasterOrdersScreen(type: MasterOrderType.pending),
                ),
              );
            },
            badgeCount: pendingCount,
            showSpinner: loadingCounts,
          ),

          _cardWithBadge(context, Icons.how_to_reg, "Attendance", () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AttendanceScreen()),
            );
          }),
        ];

      // ================= DRIVER =================
      case UserRole.driver:
        return [
          _cardWithBadge(context, Icons.list_alt, "My Orders", () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DriverOrdersScreen()),
            );
          }),
          _cardWithBadge(context, Icons.how_to_reg, "Attendance", () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AttendanceScreen()),
            );
          }),
        ];

      // ================= DISTRIBUTOR =================
      case UserRole.distributor:
        return [
          _cardWithBadge(context, Icons.list_alt, "My Orders", () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MyOrdersScreen()),
            );
          }),
          _cardWithBadge(context, Icons.track_changes, "Tracking", () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MyOrdersScreen()),
            );
          }),
        ];

      // ================= SALES OFFICER =================
      case UserRole.salesOfficer:
        return [
          _cardWithBadge(context, Icons.add_box_rounded, "Create Order", () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreateOrderScreen()),
            );
          }),
          _cardWithBadge(context, Icons.account_tree, "Order Flow", () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ManagerOrdersWithSlotScreen(),
              ),
            );
          }),
          _cardWithBadge(context, Icons.track_changes, "Tracking", () {}),
        ];
      // ================= SALES OFFICER VNR =================
      case UserRole.salesOfficerVnr:
        return [
          _cardWithBadge(context, Icons.add_box_rounded, "Create Order", () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreateOrderScreen()),
            );
          }),
        ];
    }
  }

  /// ===================================================
  /// ✅ NEW CARD (WITH BADGE) — ADDED
  /// ===================================================
  Widget _cardWithBadge(
    BuildContext ctx,
    IconData icon,
    String title,
    VoidCallback onTap, {
    int? badgeCount,
    bool showSpinner = false,
  }) {
    String badgeText(int n) => n > 9 ? "9+" : "$n";

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Stack(
          children: [
            // ✅ MAIN CONTENT ALWAYS DEAD CENTER
            const Positioned.fill(child: SizedBox()),

            Positioned.fill(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, size: 42),
                      const SizedBox(height: 12),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ✅ BADGE (TOP RIGHT) - DOES NOT AFFECT CENTER
            if (badgeCount != null && badgeCount > 0)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: const [
                      BoxShadow(
                        blurRadius: 8,
                        offset: Offset(0, 3),
                        color: Colors.black26,
                      ),
                    ],
                  ),
                  child: Text(
                    badgeText(badgeCount),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),

            // ✅ OPTIONAL SPINNER (BOTTOM RIGHT)
            if (showSpinner &&
                (title == "Today Orders" || title == "Pending Orders"))
              const Positioned(
                right: 12,
                bottom: 12,
                child: SizedBox(
                  height: 14,
                  width: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// ===================================================
  /// ❌ OLD CARD WIDGET (COMMENTED – NOT DELETED)
  /// ===================================================
  /*
  Widget _card(
    BuildContext ctx,
    IconData icon,
    String title,
    VoidCallback onTap,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 42),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
  */
}
