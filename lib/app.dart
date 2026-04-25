import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/app_snackbar.dart';
import 'core/widgets/app_notification_host.dart';
import 'ui/screens/onboarding_screen.dart';
import 'ui/screens/home_screen.dart';
import 'startup/lifecycle_observer.dart';
import 'startup/global_listeners.dart';

class LudoPrinceApp extends StatefulWidget {
  final bool hasSeenOnboarding;
  const LudoPrinceApp({super.key, required this.hasSeenOnboarding});

  @override
  State<LudoPrinceApp> createState() => _LudoPrinceAppState();
}

class _LudoPrinceAppState extends State<LudoPrinceApp>
    with WidgetsBindingObserver, AppLifecycleHandler {
  final GlobalListeners _globalListeners = GlobalListeners();

  @override
  void initState() {
    super.initState();
    initLifecycleObserver();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _globalListeners.init(context);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(const AssetImage('assets/crown.png'), context);
  }

  @override
  void dispose() {
    disposeLifecycleObserver();
    _globalListeners.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ludo Prince',
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return Stack(
          children: [
            if (child != null) child,
            const AppSnackBarHost(),
            const AppNotificationHost(),
          ],
        );
      },
      theme: AppTheme.build(),
      home: widget.hasSeenOnboarding
          ? const HomeScreen()
          : const OnboardingScreen(),
    );
  }
}
