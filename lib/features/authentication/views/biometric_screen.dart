import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';
import '../../../core/utils/logger.dart';
import '../providers/auth_provider.dart';

class BiometricScreen extends ConsumerStatefulWidget {
  const BiometricScreen({super.key});

  @override
  ConsumerState<BiometricScreen> createState() => _BiometricScreenState();
}

class _BiometricScreenState extends ConsumerState<BiometricScreen> {
  final LocalAuthentication _auth = LocalAuthentication();
  bool _isAuthenticating = false;

  Future<void> _authenticate() async {
    setState(() => _isAuthenticating = true);

    try {
      final authenticated = await _auth.authenticate(
        localizedReason: 'Unlock Visual Time to check in',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (authenticated && mounted) {
        final authNotifier = ref.read(authStateProvider.notifier);
        await authNotifier.refreshProfile();
        final profile = ref.read(authStateProvider).profile;
        if (profile != null) {
          if (profile.isAdmin) {
            context.go('/admin');
          } else {
            context.go('/employee');
          }
        } else {
          context.go('/login');
        }
      }
    } catch (e) {
      logBiometric.warning('Biometric auth failed: $e');
      if (e.toString().contains('LockedOut')) {
        await ref.read(authStateProvider.notifier).signOut();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Too many failed attempts. Use password to sign in.'),
              backgroundColor: const Color(0xFFD97706),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
          context.go('/login');
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Authentication failed. Try again.'),
            backgroundColor: Color(0xFFD97706),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isAuthenticating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1E293B),
              Color(0xFF334155),
              Color(0xFF1E3A5F),
              Color(0xFF1E293B),
            ],
            stops: [0.0, 0.25, 0.65, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                          blurRadius: 50,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(55),
                      child: Image.asset(
                        'assets/images/logo.png',
                        width: 100,
                        height: 100,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.fingerprint, size: 50, color: Color(0xFF3B82F6)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'Visual Time',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 48),
                  GestureDetector(
                    onTap: _isAuthenticating ? null : _authenticate,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                            blurRadius: 30,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(
                              Icons.fingerprint,
                              size: 56,
                              color: Color(0xFF3B82F6),
                            ).animate(
                              onPlay: (controller) => controller.repeat(),
                            ).scale(
                              duration: 2000.ms,
                              curve: Curves.easeInOut,
                              begin: const Offset(1, 1),
                              end: const Offset(1.06, 1.06),
                            ),
                        ),
                    ),
                    const SizedBox(height: 24),
                  const Text(
                    'Tap fingerprint to unlock',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Use your fingerprint to sign in quickly',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () async {
                      await ref.read(authStateProvider.notifier).signOut();
                      if (context.mounted) context.go('/login');
                    },
                    child: Text(
                      'Use password instead',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
