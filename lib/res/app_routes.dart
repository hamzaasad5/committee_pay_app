import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../views/home/home_screen.dart';
import '../views/my_committees/add_daily_committee_screen.dart';
import '../views/my_committees/add_monthly_committee_screen.dart';
import '../views/my_committees/add_user_payment.dart';

final GlobalKey<NavigatorState> rootNavigatorKey =
GlobalKey<NavigatorState>(debugLabel: 'root');

class AppRoutes {
  static GoRouter router = GoRouter(
    initialLocation: AppRouteConst.home,
    navigatorKey: rootNavigatorKey,
    routes: [
      GoRoute(
        path: AppRouteConst.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRouteConst.createDailyCommittee,
        builder: (context, state) => const DailyCommitteeScreen(
          adminId: "PLACEHOLDER_ADMIN_ID",
        ),
      ),
      GoRoute(
        path: AppRouteConst.createMonthlyCommittee,
        builder: (context, state) => const MonthlyCommitteeScreen(
          adminId: "PLACEHOLDER_ADMIN_ID",
        ),
      ),
      GoRoute(
        path: AppRouteConst.addPayment,
        builder: (context, state) => const AddUserPayment(committeeId: '', currentUserId: '',),
      ),
    ],
  );
}

class AppRouteConst {
  AppRouteConst._();

  static String home = '/';
  static String createDailyCommittee = '/createDailyCommittee';
  static String createMonthlyCommittee = '/createMonthlyCommittee';
  static String addPayment = '/addPayment';
}