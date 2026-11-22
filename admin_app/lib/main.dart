import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/dashboard_provider.dart';
import 'providers/approvals_provider.dart';
import 'providers/student_provider.dart';
import 'providers/teacher_provider.dart';
import 'providers/hr_leave_provider.dart';
import 'providers/notifications_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/app_lock_screen.dart';
import 'services/app_security_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSecurityService().initialize();
  runApp(const AdminCommandCenterApp());
}

class AdminCommandCenterApp extends StatelessWidget {
  const AdminCommandCenterApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
        ChangeNotifierProvider(create: (_) => ApprovalsProvider()),
        ChangeNotifierProvider(create: (_) => StudentProvider()),
        ChangeNotifierProvider(create: (_) => TeacherProvider()),
        ChangeNotifierProvider(create: (_) => HrLeaveProvider()),
        ChangeNotifierProvider(create: (_) => NotificationsProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, theme, _) => MaterialApp(
          title: 'WORKSPACE',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: theme.themeMode,
          home: const SplashScreen(),
          builder: (context, child) {
            return ValueListenableBuilder<bool>(
              valueListenable: AppSecurityService().isLockedNotifier,
              builder: (context, isLocked, _) {
                return Stack(
                  children: [
                    child ?? const SizedBox.shrink(),
                    if (isLocked)
                      Positioned.fill(
                        child: AppLockScreen(
                          onUnlocked: () {},
                        ),
                      ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
