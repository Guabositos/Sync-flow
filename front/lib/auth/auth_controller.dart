
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'auth_service.dart';
import 'auth_state.dart';
import '../config.dart';
import '../mock/mock_auth_service.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  if (AppConfig.useMockApi) {
    return MockAuthService();
  }
  return AuthService();
});
final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref.read(authServiceProvider));
});

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._service) : super(AuthState.empty) {
    _init();
  }

  final AuthService _service;
  Timer? _timer;

  Future<void> _init() async {
    await checkAndRefresh();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      checkAndRefresh();
    });
  }

  
  Future<void> checkAndRefresh() async {
    final token = await _service.readAccessToken();
    if (token == null || token.isEmpty) return;

    try {
      final decoded = JwtDecoder.decode(token);
      final exp = (decoded['exp'] as num?)?.toInt();
      if (exp == null) {
        await logout();
        return;
      }

      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      // If expired or close to expiring (< 10 seconds left)
      if (exp < now + 10) {
        await _service.refresh();
        final newToken = await _service.readAccessToken();
        if (newToken == null || newToken.isEmpty) {
          await logout();
          return;
        }
        state = AuthState(
          token: newToken,
          user: AuthUser.fromAccessToken(newToken),
        );
      } else {
        state = AuthState(
          token: token,
          user: AuthUser.fromAccessToken(token),
        );
      }
    } catch (_) {
      await logout();
    }
  }

  /// Call after successful login (if your login screen wants immediate state update)
  Future<void> syncFromStorage() async {
    await checkAndRefresh();
  }

  Future<void> login({
    required String username,
    required String password,
    required String companyCode,
  }) async {
    await _service.login(
      username: username,
      password: password,
      companyCode: companyCode,
    );
    await syncFromStorage();
  }


   Future<String> registerCompany({
    required String companyName,
    required String managerUsername,
    required String managerPassword,
  }) async {
    return _service.registerCompany(
      companyName: companyName,
      managerUsername: managerUsername,
      managerPassword: managerPassword,
    );
  }

  Future<void> logout() async {
    _timer?.cancel();
    _timer = null;
    await _service.clearTokens();
    state = AuthState.empty;
    // Navigation is handled in router guard / UI listener.
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
