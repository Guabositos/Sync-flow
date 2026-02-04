import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import '../models/user_model.dart';
import '../widgets/loading.dart';
import '../widgets/error.dart';
import 'users_controller.dart';

class UsersPage extends ConsumerStatefulWidget {
  const UsersPage({super.key});

  @override
  ConsumerState<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends ConsumerState<UsersPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(usersControllerProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final state = ref.watch(usersControllerProvider);

    // 🔒 Manager-only page
    if (!auth.isManager) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Access denied.\nManagers only.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (state.loading) {
      return const Scaffold(body: AppLoading(message: 'Loading users...'));
    }

    if (state.error != null) {
      return Scaffold(
        body: AppError(
          message: state.error!,
          onRetry: () => ref.read(usersControllerProvider.notifier).load(),
        ),
      );
    }

    final users = state.filtered;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Users'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.read(usersControllerProvider.notifier).load(),
          ),
        ],
      ),
      floatingActionButton: state.showDeleted
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _openCreateUserSheet(context),
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Add user'),
            ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          children: [
            _ShowDeletedCard(
              showDeleted: state.showDeleted,
              onToggleDeleted: (v) =>
                  ref.read(usersControllerProvider.notifier).setShowDeleted(v),
            ),
            const SizedBox(height: 12),

            if (users.isEmpty)
              _EmptyCard(showDeleted: state.showDeleted)
            else
              ...users.map(
                (u) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _UserTile(
                    user: u,
                    showDeleted: state.showDeleted,
            
                    onDelete: state.showDeleted ? null : () => _confirmDelete(context, u),
                    onRecover: state.showDeleted ? () => _confirmRecover(context, u) : null,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, UserDto user) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Delete user'),
      content: Text('Delete "${user.username}"?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );

  if (ok == true) {
    try {
      await ref.read(usersControllerProvider.notifier).deleteUser(user.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('User deleted.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }
}


  Future<void> _confirmRecover(BuildContext context, UserDto user) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Recover user'),
      content: Text('Recover "${user.username}"?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Recover'),
        ),
      ],
    ),
  );

  if (ok == true) {
    try {
      final deletedUserId = user.id; // ✅ this is the deleted user's id from the list

      await ref
          .read(usersControllerProvider.notifier)
          .recoverUser(deletedUserId);

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('User recovered.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Recover failed: $e')));
    }
  }
}


  Future<void> _openCreateUserSheet(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _UserFormSheet(
        title: 'Create user',
        submitLabel: 'Create',
        initialUsername: '',
        initialRole: 'USER',
        requirePassword: true,
        onSubmit: (username, password, role) async {
          try {
            await ref.read(usersControllerProvider.notifier).createUser(
                  username: username,
                  password: password,
                  role: role,
                );
            if (!context.mounted) return;
            Navigator.pop(context);
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('User created.')));
          } catch (e) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text('Create failed: $e')));
          }
        },
      ),
    );
  }
}

// ---------------- UI components ----------------

class _ShowDeletedCard extends StatelessWidget {
  const _ShowDeletedCard({
    required this.showDeleted,
    required this.onToggleDeleted,
  });

  final bool showDeleted;
  final ValueChanged<bool> onToggleDeleted;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FilterChip(
            label: const Text('Show deleted users'),
            selected: showDeleted,
            onSelected: onToggleDeleted,
          ),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.showDeleted});
  final bool showDeleted;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
      ),
      child: Text(
        showDeleted ? 'No deleted users.' : 'No users found.',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({
    required this.user,
    required this.showDeleted,
    this.onDelete,
    this.onRecover,
  });

  final UserDto user;
  final bool showDeleted;
  final VoidCallback? onDelete;
  final VoidCallback? onRecover;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            child: Text(user.username.isNotEmpty ? user.username[0].toUpperCase() : '?'),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.username,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        )),
                const SizedBox(height: 4),
                Text(
                  user.role.toUpperCase(),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
          if (!showDeleted) ...[
            IconButton(
              tooltip: 'Delete',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ] else ...[
            IconButton(
              tooltip: 'Recover',
              onPressed: onRecover,
              icon: const Icon(Icons.restore_rounded),
            ),
          ]
        ],
      ),
    );
  }
}

class _UserFormSheet extends StatefulWidget {
  const _UserFormSheet({
    required this.title,
    required this.submitLabel,
    required this.initialUsername,
    required this.initialRole,
    required this.requirePassword,
    required this.onSubmit,
  });

  final String title;
  final String submitLabel;
  final String initialUsername;
  final String initialRole;
  final bool requirePassword;
  final Future<void> Function(String username, String password, String role)
      onSubmit;

  @override
  State<_UserFormSheet> createState() => _UserFormSheetState();
}

class _UserFormSheetState extends State<_UserFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _usernameCtrl;
  late final TextEditingController _passwordCtrl;
  late String _role;

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _usernameCtrl = TextEditingController(text: widget.initialUsername);
    _passwordCtrl = TextEditingController();
    _role = widget.initialRole;
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      await widget.onSubmit(
        _usernameCtrl.text.trim(),
        _passwordCtrl.text,
        _role,
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  )),
          const SizedBox(height: 14),
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _usernameCtrl,
                  decoration: const InputDecoration(labelText: 'Username'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    hintText: widget.requirePassword ? null : '(leave empty)',
                  ),
                  validator: (v) {
                    if (!widget.requirePassword) return null;
                    return (v == null || v.isEmpty) ? 'Required' : null;
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _role,
                  items: const [
                    DropdownMenuItem(value: 'USER', child: Text('USER')),
                    DropdownMenuItem(value: 'MANAGER', child: Text('MANAGER')),
                    DropdownMenuItem(value: 'ADMIN', child: Text('ADMIN')),
                  ],
                  onChanged: (v) => setState(() => _role = v ?? 'USER'),
                  decoration: const InputDecoration(labelText: 'Role'),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _submitting ? null : _submit,
                    child: Text(_submitting ? 'Please wait...' : widget.submitLabel),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}