import '../auth/auth_service.dart';
import '../api.dart';
import 'mock_data.dart';

class MockAuthService extends AuthService {
  @override
  Future<void> login({
    required String username,
    required String password,
    required String companyCode,
  }) async {
    // Fake delay
    await Future.delayed(const Duration(milliseconds: 600));

    // Fake token
    const fakeJwt =
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
        'eyJpZCI6IjEiLCJ1c2VybmFtZSI6Im1hbmFnZXIiLCJyb2xlIjoibWFuYWdlciIsImNvbXBhbnlJZCI6IjEiLCJleHAiOjQ3MDAwMDAwMDB9.'
        'signature';

    await ApiClient.instance.storage.write(key: 'token', value: fakeJwt);
    await ApiClient.instance.storage.write(key: 'refresh_token', value: 'mock');
  }

  @override
  Future<String> registerCompany({
    required String companyName,
    required String managerUsername,
    required String managerPassword,
  }) async {
    await Future.delayed(const Duration(milliseconds: 600));
    return 'MOCK-CODE-123';
  }

  @override
  Future<void> refresh() async {}
}
