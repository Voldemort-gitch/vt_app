import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/theme/theme.dart';
import 'shared/router/router.dart';
import 'core/constants/constants.dart';
import 'features/authentication/providers/biometric_provider.dart';
import 'features/authentication/providers/biometric_enabled_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConstants.supabaseUrl,
    publishableKey: SupabaseConstants.supabasePublishableKey,
  );

  bool biometricAvailable = false;
  if (!kIsWeb) {
    try {
      final localAuth = LocalAuthentication();
      final canAuth = await localAuth.canCheckBiometrics;
      final isDevice = await localAuth.isDeviceSupported();
      biometricAvailable = canAuth && isDevice;
    } catch (_) {
      biometricAvailable = false;
    }
  }

  final prefs = await SharedPreferences.getInstance();
  final biometricEnabled = prefs.getBool('biometric_enabled') ?? false;

  runApp(
    ProviderScope(
      overrides: [
        biometricAvailableProvider.overrideWith((ref) => biometricAvailable),
        biometricEnabledProvider.overrideWith((ref) => biometricEnabled && biometricAvailable),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Visual Time',
      theme: AppTheme.darkTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
