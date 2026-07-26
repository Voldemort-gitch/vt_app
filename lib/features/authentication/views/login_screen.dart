import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _codeController = TextEditingController();
  final _pinController = TextEditingController();
  bool _obscurePassword = true;
  bool _isEmployeeMode = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _codeController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) return;

    try {
      if (_isEmployeeMode) {
        await ref.read(authStateProvider.notifier).employeeCodeSignIn(
              _codeController.text.trim(),
              _pinController.text,
            );
      } else {
        await ref.read(authStateProvider.notifier).signIn(
              _emailController.text.trim(),
              _passwordController.text,
            );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEmployeeMode ? 'Invalid code or PIN' : 'Invalid email or password'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    if (authState.isInitializing) {
      return Scaffold(
        backgroundColor: const Color(0xFF1E293B),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/logo.png',
                width: 100,
                height: 100,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.fingerprint, size: 50, color: Color(0xFF3B82F6)),
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
              const SizedBox(height: 12),
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF3B82F6),
                ),
              ),
            ],
          ).animate().fadeIn(duration: 600.ms).scale(
            begin: const Offset(0.95, 0.95),
            duration: 500.ms,
            curve: Curves.easeOut,
          ),
        ),
      );
    }

    if (authState.profile != null && authState.biometricAvailable && authState.biometricEnabled) {
      Future.microtask(() {
        if (mounted) context.go('/biometric');
      });
      return const SizedBox.shrink();
    }

    if (authState.profile != null) {
      return const SizedBox.shrink();
    }

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
              padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/logo.png',
                    width: 110,
                    height: 110,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.fingerprint, size: 60, color: Color(0xFF3B82F6)),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'Visual Time',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Attendance Management',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.4),
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 48),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(28),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () => setState(() => _isEmployeeMode = true),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(vertical: 10),
                                            decoration: BoxDecoration(
                                              color: _isEmployeeMode ? const Color(0xFF3B82F6) : Colors.transparent,
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: const Text('Employee', textAlign: TextAlign.center,
                                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () => setState(() => _isEmployeeMode = false),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(vertical: 10),
                                            decoration: BoxDecoration(
                                              color: !_isEmployeeMode ? const Color(0xFF3B82F6) : Colors.transparent,
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: const Text('Admin', textAlign: TextAlign.center,
                                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),
                                if (_isEmployeeMode) ...[
                                  TextFormField(
                                    controller: _codeController,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: InputDecoration(
                                      labelText: 'Employee Code',
                                      hintText: 'Enter your code',
                                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.25)),
                                      prefixIcon: const Icon(Icons.badge_outlined),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) return 'Please enter your employee code';
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 18),
                                  TextFormField(
                                    controller: _pinController,
                                    obscureText: true,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: InputDecoration(
                                      labelText: 'PIN',
                                      hintText: 'Enter your PIN',
                                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.25)),
                                      prefixIcon: const Icon(Icons.lock_outlined),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) return 'Please enter your PIN';
                                      if (value.length < 4) return 'PIN must be at least 4 digits';
                                      return null;
                                    },
                                  ),
                                ] else ...[
                                  TextFormField(
                                    controller: _emailController,
                                    keyboardType: TextInputType.emailAddress,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: InputDecoration(
                                      labelText: 'Email',
                                      hintText: 'Enter your email',
                                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.25)),
                                      prefixIcon: const Icon(Icons.email_outlined),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) return 'Please enter your email';
                                      if (!value.contains('@')) return 'Please enter a valid email';
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 18),
                                  TextFormField(
                                    controller: _passwordController,
                                    obscureText: _obscurePassword,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: InputDecoration(
                                      labelText: 'Password',
                                      hintText: 'Enter your password',
                                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.25)),
                                      prefixIcon: const Icon(Icons.lock_outlined),
                                      suffixIcon: IconButton(
                                        icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off, color: Colors.grey),
                                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                      ),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) return 'Please enter your password';
                                      return null;
                                    },
                                  ),
                                  ],
                                const SizedBox(height: 20),
                                if (authState.error != null)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.error_outline, color: Colors.red, size: 18),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              authState.error!,
                                              style: const TextStyle(color: Colors.red, fontSize: 13),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                SizedBox(
                                  width: double.infinity,
                                  height: 54,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
                                          blurRadius: 20,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: ElevatedButton(
                                      onPressed: _login,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        shadowColor: Colors.transparent,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                      ),
                                      child: authState.isLoading
                                          ? const SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Text(
                                              'Sign In',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 1.5,
                                              ),
                                            ),
                                    ),
                                  ).animate(
                                    onPlay: (controller) => controller.repeat(),
                                  ).shimmer(
                                    duration: 2000.ms,
                                    color: Colors.white.withValues(alpha: 0.08),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    ),
                    const SizedBox(height: 40),
                  Text(
                    'VT Attendance Systems',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.2),
                      fontSize: 10,
                      letterSpacing: 3,
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
