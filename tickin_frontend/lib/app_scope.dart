// ignore_for_file: use_super_parameters, prefer_const_constructors_in_immutables, sort_child_properties_last
import 'package:flutter/material.dart';

import 'storage/token_store.dart';
import 'api/http_client.dart';
import 'api/slots_api.dart';
import 'api/orders_api.dart';
import 'api/sales_api.dart';
import 'api/goals_api.dart';
import 'api/timeline_api.dart';
import 'api/orders_flow_api.dart';
import 'api/users_api.dart';
import 'api/vehicles_api.dart';
import 'providers/auth_provider.dart';
import 'api/attendance_api.dart';
import 'api/attendance_dashboard_api.dart';
import 'api/attendance_config_api.dart';

class TickinAppScope extends InheritedWidget {
  final TokenStore tokenStore;
  final HttpClient httpClient;

  final OrdersApi ordersApi;
  final SalesApi salesApi;
  final GoalsApi goalsApi;
  final TimelineApi timelineApi;
  final OrdersFlowApi flowApi;
  final UsersApi userApi;
  final VehiclesApi vehiclesApi;
  final SlotsApi slotsApi;

  final AuthProvider authProvider;
  final AttendanceApi attendanceApi;
  final AttendanceDashboardApi attendanceDashboardApi;
  final AttendanceConfigApi attendanceConfigApi;
  TickinAppScope._({
    required super.child,
    required this.tokenStore,
    required this.httpClient,
    required this.ordersApi,
    required this.salesApi,
    required this.goalsApi,
    required this.timelineApi,
    required this.flowApi,
    required this.userApi,
    required this.vehiclesApi,
    required this.slotsApi,
    required this.authProvider,
    required this.attendanceApi,
    required this.attendanceDashboardApi,
    required this.attendanceConfigApi,
    super.key,
  });

  factory TickinAppScope({
    Key? key,
    required Widget child,
    TokenStore? tokenStore,
  }) {
    final ts = tokenStore ?? TokenStore();
    final client = HttpClient(ts);

    return TickinAppScope._(
      key: key,
      child: child,
      tokenStore: ts,
      httpClient: client,
      ordersApi: OrdersApi(client),
      salesApi: SalesApi(client),
      goalsApi: GoalsApi(client),
      timelineApi: TimelineApi(client),
      flowApi: OrdersFlowApi(client),
      userApi: UsersApi(client),
      vehiclesApi: VehiclesApi(client),
      slotsApi: SlotsApi(client),
      authProvider: AuthProvider(ts),
      attendanceApi: AttendanceApi(client),
      attendanceDashboardApi: AttendanceDashboardApi(client),
      attendanceConfigApi: AttendanceConfigApi(client),
    );
  }

  static TickinAppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<TickinAppScope>();
    assert(scope != null, "TickinAppScope not found above this context");
    return scope!;
  }

  @override
  bool updateShouldNotify(TickinAppScope oldWidget) => false;
}
