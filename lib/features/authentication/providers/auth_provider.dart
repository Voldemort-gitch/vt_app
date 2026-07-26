import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/models/profile_model.dart';
import '../../../shared/services/supabase_service.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'biometric_provider.dart';
import 'biometric_enabled_provider.dart';

class AuthState {
  final ProfileModel? profile;
  final bool isLoading;
  final String? error;
  final bool isInitializing;
  final bool biometricAvailable;
  final bool biometricEnabled;

  AuthState({
    this.profile,
    this.isLoading = false,
    this.error,
    this.isInitializing = true,
    this.biometricAvailable = false,
    this.biometricEnabled = false,
  });
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    final biometricAvailable = ref.read(biometricAvailableProvider);
    final biometricEnabled = ref.read(biometricEnabledProvider);
    _init(biometricAvailable, biometricEnabled);
    return AuthState(
      isInitializing: true,
      biometricAvailable: biometricAvailable,
      biometricEnabled: biometricEnabled,
    );
  }

  Future<void> _init(bool biometricAvailable, bool biometricEnabled) async {
    await Future.microtask(() {});
    try {
      final user = SupabaseService.currentUser;
      if (user != null) {
        final profile = await SupabaseService.getCurrentProfile();
        state = AuthState(
          profile: profile,
          isInitializing: false,
          biometricAvailable: biometricAvailable,
          biometricEnabled: biometricEnabled,
        );
      } else {
        state = AuthState(
          isInitializing: false,
          biometricAvailable: biometricAvailable,
          biometricEnabled: biometricEnabled,
        );
      }
    } catch (_) {
      state = AuthState(
        isInitializing: false,
        biometricAvailable: biometricAvailable,
        biometricEnabled: biometricEnabled,
      );
    }
  }

  Future<void> signIn(String email, String password) async {
    final biometricAvailable = ref.read(biometricAvailableProvider);
    state = AuthState(isLoading: true, isInitializing: false);
    try {
      final res = await Supabase.instance.client.auth
          .signInWithPassword(email: email, password: password);

      final userId = res.session?.user.id ?? res.user?.id;
      if (userId == null) {
        state = AuthState(error: 'Login failed', isInitializing: false);
        return;
      }

      final profile = await SupabaseService.getProfile(userId);

      if (profile == null) {
        state = AuthState(error: 'Profile not found', isInitializing: false);
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getBool('biometric_enabled') ?? false;

      state = AuthState(
        profile: profile,
        isInitializing: false,
        biometricAvailable: biometricAvailable,
        biometricEnabled: stored,
      );
    } on AuthException catch (e) {
      state = AuthState(error: e.message, isInitializing: false);
    } catch (e) {
      state = AuthState(error: 'Sign in failed. Check your connection.', isInitializing: false);
    }
  }

  Future<void> employeeCodeSignIn(String code, String pin) async {
    state = AuthState(isLoading: true, isInitializing: false);

    final prefs = await SharedPreferences.getInstance();
    final attempts = prefs.getInt('pin_attempts') ?? 0;
    final lockTime = prefs.getInt('pin_lock_time') ?? 0;

    if (attempts >= 5 && DateTime.now().millisecondsSinceEpoch - lockTime < 1800000) {
      final remaining = ((lockTime + 1800000 - DateTime.now().millisecondsSinceEpoch) / 60000).ceil();
      state = AuthState(error: 'Too many attempts. Try again in $remaining min.', isInitializing: false);
      return;
    }

    if (attempts >= 5) {
      await prefs.setInt('pin_attempts', 0);
      await prefs.setInt('pin_lock_time', 0);
    }

    try {
      final email = await SupabaseService.getEmailByEmployeeCode(code);
      if (email == null) {
        await prefs.setInt('pin_attempts', attempts + 1);
        state = AuthState(error: 'Invalid employee code', isInitializing: false);
        return;
      }

      await signIn(email, pin.length < 6 ? '${pin}vt' : pin);

      await prefs.setInt('pin_attempts', 0);
      await prefs.setInt('pin_lock_time', 0);
    } catch (e) {
      await prefs.setInt('pin_attempts', attempts + 1);
      if (attempts + 1 >= 5) {
        await prefs.setInt('pin_lock_time', DateTime.now().millisecondsSinceEpoch);
      }
      state = AuthState(error: 'Login failed', isInitializing: false);
    }
  }

  Future<void> signOut() async {
    await Supabase.instance.client.auth.signOut();
    state = AuthState(isInitializing: false);
  }

  void signInStateUpdate({bool? biometricEnabled}) {
    state = AuthState(
      profile: state.profile,
      isInitializing: state.isInitializing,
      biometricAvailable: state.biometricAvailable,
      biometricEnabled: biometricEnabled ?? state.biometricEnabled,
    );
  }

  Future<void> refreshProfile() async {
    final profile = await SupabaseService.getCurrentProfile();
    if (profile != null) {
      state = AuthState(
        profile: profile,
        isInitializing: false,
        biometricAvailable: state.biometricAvailable,
        biometricEnabled: state.biometricEnabled,
      );
    }
  }
}

final authStateProvider =
    NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
