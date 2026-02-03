import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_controller.dart';
import '../models/user_model.dart';
import 'users_service.dart';

final usersServiceProvider = Provider<UsersService>((ref) => UsersService());

final usersControllerProvider =
    StateNotifierProvider<UsersController, UsersState>(
  (ref) => UsersController(ref),
);

class UsersState {
  final bool loading;
  final String? error;

  final bool showDeleted;
  final String searchTerm;
  final String selectedRole; // "" means all roles

  final List<UserDto> users; // raw loaded users

  const UsersState({
    required this.loading,
    required this.users,
    required this.showDeleted,
    required this.searchTerm,
    required this.selectedRole,
    this.error,
  });

  factory UsersState.initial() => const UsersState(
        loading: true,
        users: [],
        showDeleted: false,
        searchTerm: '',
        selectedRole: '',
        error: null,
      );

  UsersState copyWith({
    bool? loading,
    String? error,
    bool? showDeleted,
    String? searchTerm,
    String? selectedRole,
    List<UserDto>? users,
  }) {
    return UsersState(
      loading: loading ?? this.loading,
      error: error,
      showDeleted: showDeleted ?? this.showDeleted,
      searchTerm: searchTerm ?? this.searchTerm,
      selectedRole: selectedRole ?? this.selectedRole,
      users: users ?? this.users,
    );
  }

  List<UserDto> get filtered {
    final q = searchTerm.trim().toLowerCase();

    return users.where((u) {
      final matchesSearch = q.isEmpty ||
          u.username.toLowerCase().contains(q) ||
          // React fakes an email as username@company.com
          ('${u.username}@company.com').toLowerCase().contains(q);

      final matchesRole = selectedRole.isEmpty ||
          u.role.toUpperCase() == selectedRole.toUpperCase();

      return matchesSearch && matchesRole;
    }).toList();
  }

  List<String> get roles {
    final set = <String>{};
    for (final u in users) {
      set.add(u.role.toUpperCase());
    }
    final list = set.toList()..sort();
    return list;
  }
}

class UsersController extends StateNotifier<UsersState> {
  UsersController(this.ref) : super(UsersState.initial());

  final Ref ref;

  Future<void> load() async {
    state = state.copyWith(loading: true, error: null);

    try {
      final auth = ref.read(authControllerProvider);
      final service = ref.read(usersServiceProvider);

      final users = state.showDeleted
    ? await service.fetchDeletedUsers()
    : await service.fetchActiveUsersByCompany();


      state = state.copyWith(loading: false, users: users);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  void setShowDeleted(bool v) {
    state = state.copyWith(showDeleted: v);
    load();
  }

  void setSearch(String v) => state = state.copyWith(searchTerm: v);

  void setRole(String v) => state = state.copyWith(selectedRole: v);

  Future<void> createUser({
    required String username,
    required String password,
    required String role,
  }) async {
    final auth = ref.read(authControllerProvider);
    

    final service = ref.read(usersServiceProvider);
    await service.createUser(
      username: username,
      password: password,
      role: role,
    );


    // refresh active list after create
    if (state.showDeleted) {
      state = state.copyWith(showDeleted: false);
    }
    await load();
  }


  Future<void> deleteUser(String userId) async {
    final service = ref.read(usersServiceProvider);
    await service.deleteUser(userId);
    await load();
  }

  Future<void> recoverUser(String userId) async {
    final service = ref.read(usersServiceProvider);
    await service.recoverUser(userId);
    await load();
  }
}
