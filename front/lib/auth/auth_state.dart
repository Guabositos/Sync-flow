// lib/auth/auth_state.dart
import 'package:jwt_decoder/jwt_decoder.dart';

class AuthUser {
  final String id;
  final String username;
  final String? email;
  final String role;
  final String companyId;
  final String companyCode;
  final int exp;
  final int? iat;

  AuthUser({
    required this.id,
    required this.username,
    required this.role,
    required this.companyId,
    required this.companyCode,
    required this.exp,
    this.email,
    this.iat,
  });

  factory AuthUser.fromAccessToken(String accessToken) {
    final decoded = JwtDecoder.decode(accessToken);

    return AuthUser(
      id: (decoded['sub'] ?? decoded['id']).toString(),
      username: (decoded['username'] ?? '').toString(),
      email: decoded['email']?.toString(),
      role: (decoded['role'] ?? '').toString(),
      companyId: (decoded['companyId'] ?? '').toString(),
      companyCode: (decoded['companyCode'] ?? '').toString(),
      exp: (decoded['exp'] as num).toInt(),
      iat: (decoded['iat'] as num?)?.toInt(),
    );
  }

  bool get isManager => role == 'manager';
}

class AuthState {
  final String? token;
  final AuthUser? user;

  const AuthState({required this.token, required this.user});

  bool get isAuthenticated => token != null && user != null;
  bool get isManager => user?.isManager ?? false;

  static const empty = AuthState(token: null, user: null);

  AuthState copyWith({String? token, AuthUser? user}) {
    return AuthState(
      token: token ?? this.token,
      user: user ?? this.user,
    );
  }
}
