import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_controller.dart';
import '../models/task_model.dart';
import '../models/user_model.dart';
import '../widgets/tasks_chart.dart';
import '../widgets/loading.dart';
import '../widgets/error.dart';
import 'dashboard_service.dart';
import '../chat/chat_controller.dart';


final dashboardServiceProvider = Provider<DashboardService>((ref) => DashboardService());

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  bool _loading = true;
  String? _error;

  List<TaskDto> _companyTasks = [];
  List<TaskDto> _todayTasks = [];

  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final service = ref.read(dashboardServiceProvider);

      final companyTasks = await service.fetchCompanyTasks();
      
      // ✅ WORKAROUND: Add 1 day to compensate for server timezone offset
      // Server stores dates in UTC, so when we ask for "today", it returns "yesterday"
      final now = DateTime.now();
      final todayNormalized = DateTime(now.year, now.month, now.day);
      final todayPlusOne = todayNormalized.add(const Duration(days: 1));
      final todayStr = _yyyyMmDd(todayPlusOne);
      final todayTasks = await service.fetchTasksByDay(todayStr);

      setState(() {
        _companyTasks = companyTasks;
        _todayTasks = todayTasks;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openAddTaskSheet() async {
    final auth = ref.read(authControllerProvider);
    if (!auth.isManager) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only managers can add tasks')),
      );
      return;
    }

    final service = ref.read(dashboardServiceProvider);

    List<UserDto> users = [];
    try {
      users = await service.fetchAssignableUsers();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load users: $e')),
      );
      return;
    }

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AddTaskSheet(
        users: users,
        submitting: _creating,
        onSubmit: (data) async {
          Navigator.pop(context);
          await _createTask(data);
        },
      ),
    );
  }

  Future<void> _createTask(_AddTaskData data) async {
    setState(() => _creating = true);
    try {
      final service = ref.read(dashboardServiceProvider);
      await service.createTask(
        title: data.title,
        description: data.description,
        dueDateIso: data.dueDateIso,
        assignedToId: data.assignedToId,
      );
      await _loadAll();
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final name = auth.user?.username ?? 'User';
    final isManager = auth.isManager;

    if (_loading) {
      return const Scaffold(body: AppLoading(message: 'Loading dashboard...'));
    }

    if (_error != null) {
      return Scaffold(
        body: AppError(
          message: _error!,
          onRetry: _loadAll,
        ),
      );
    }

    final stats = _computeStats(_companyTasks);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              await ref.read(authControllerProvider.notifier).logout();
              ref.invalidate(appChatControllerProvider);
              context.pushReplacement('/login');
            },
          ),
        ],
      ),

      // ✅ Manager-only Add Task button
      floatingActionButton: isManager
          ? FloatingActionButton.extended(
              onPressed: _creating ? null : _openAddTaskSheet,
              icon: const Icon(Icons.add_rounded),
              label: Text(_creating ? 'Creating...' : 'Add Task'),
            )
          : null,

      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          children: [
            _GreetingCard(name: name),
            const SizedBox(height: 14),

            _StatsRow(stats: stats),
            const SizedBox(height: 14),

            // ✅ Graph: same logic as React (7 days centered on today)
            TasksChart(
              tasks: _companyTasks
                  .map((t) => TaskItemForChart(
                        dueDate: t.dueDate,
                        completed: t.completed,
                      ))
                  .toList(),
            ),

            const SizedBox(height: 16),
            _SectionTitle(
              title: "Today's Tasks",
              actionText: 'View all',
              onAction: () => context.go('/tasks'),
            ),
            const SizedBox(height: 8),

            if (_todayTasks.isEmpty)
              const _EmptyCard(text: 'No tasks due today.')
            else
              ..._todayTasks.take(6).map((t) {
                final isMine =
                    (t.assignedTo?.id != null && t.assignedTo!.id == auth.user?.id);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _TaskTile(task: t, highlight: isMine),
                );
              }),
          ],
        ),
      ),
    );
  }
}

// ---------- Stats helpers ----------
class _Stats {
  final int total;
  final int completed;
  final int pending;
  final int completionRate;

  _Stats({
    required this.total,
    required this.completed,
    required this.pending,
    required this.completionRate,
  });
}

_Stats _computeStats(List<TaskDto> tasks) {
  final total = tasks.length;
  final completed = tasks.where((t) => t.completed).length;
  final pending = total - completed;
  final rate = total == 0 ? 0 : ((completed / total) * 100).round();
  return _Stats(total: total, completed: completed, pending: pending, completionRate: rate);
}

String _yyyyMmDd(DateTime d) {
  final mm = d.month.toString().padLeft(2, '0');
  final dd = d.day.toString().padLeft(2, '0');
  return '${d.year}-$mm-$dd';
}

// ---------- UI widgets ----------
class _GreetingCard extends StatelessWidget {
  const _GreetingCard({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: cs.primary.withOpacity(0.14),
            child: Icon(Icons.person_rounded, color: cs.primary, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back,',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});
  final _Stats stats;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.checklist_rounded,
            label: 'Total',
            value: '${stats.total}',
            color: cs.primary,
            bg: cs.primaryContainer,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.check_circle_rounded,
            label: 'Completed',
            value: '${stats.completed}',
            color: cs.tertiary,
            bg: cs.tertiaryContainer,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.pending_actions_rounded,
            label: 'Pending',
            value: '${stats.pending}',
            color: cs.secondary,
            bg: cs.secondaryContainer,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.bg,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: bg.withOpacity(0.4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 24),
              Text(
                value,
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w900, color: color),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(fontWeight: FontWeight.w700, color: color.withOpacity(0.85)),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.actionText, this.onAction});
  final String title;
  final String? actionText;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
        if (actionText != null && onAction != null)
          TextButton(
            onPressed: onAction,
            child: Text(actionText!),
          ),
      ],
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({required this.task, required this.highlight});
  final TaskDto task;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // ✅ FIXED: No longer adding 1 day - display the actual due date
    final due = task.dueDate == null
        ? 'No due date'
        : '${task.dueDate!.year}-${task.dueDate!.month.toString().padLeft(2, '0')}-${task.dueDate!.day.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: highlight ? cs.primary.withOpacity(0.06) : cs.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: highlight ? cs.primary.withOpacity(0.35) : cs.outlineVariant.withOpacity(0.6),
        ),
      ),
      child: Row(
        children: [
          Icon(
            task.completed ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            color: task.completed ? cs.primary : cs.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        decoration: task.completed ? TextDecoration.lineThrough : null,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Due: $due${task.assignedTo != null ? ' • ${task.assignedTo!.username}' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _StatusChip(done: task.completed),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.done});
  final bool done;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: done ? cs.primary.withOpacity(0.12) : cs.secondary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: (done ? cs.primary : cs.secondary).withOpacity(0.35)),
      ),
      child: Text(
        done ? 'Completed' : 'Pending',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: done ? cs.primary : cs.secondary,
            ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

// ---------- Add Task Bottom Sheet ----------
class _AddTaskData {
  final String title;
  final String? description;
  final String? dueDateIso;
  final String? assignedToId;

  _AddTaskData({
    required this.title,
    required this.description,
    required this.dueDateIso,
    required this.assignedToId,
  });
}

class _AddTaskSheet extends StatefulWidget {
  const _AddTaskSheet({
    required this.users,
    required this.submitting,
    required this.onSubmit,
  });

  final List<UserDto> users;
  final bool submitting;
  final Future<void> Function(_AddTaskData data) onSubmit;

  @override
  State<_AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends State<_AddTaskSheet> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  DateTime? _dueDate;
  String? _assignedTo;

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Add New Task',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Title *', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _desc,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: context,
                      firstDate: DateTime(now.year - 1, 1, 1),
                      lastDate: DateTime(now.year + 3, 12, 31),
                      initialDate: _dueDate ?? now,
                    );
                    // ✅ FIXED: Normalize the picked date exactly like calendar_page.dart
                    if (picked != null) {
                      setState(() {
                        _dueDate = DateTime(picked.year, picked.month, picked.day);
                      });
                    }
                  },
                  icon: const Icon(Icons.event_rounded),
                  label: Text(_dueDate == null ? 'Pick due date' : _yyyyMmDd(_dueDate!)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _assignedTo,
                  decoration: const InputDecoration(labelText: 'Assign to', border: OutlineInputBorder()),
                  items: [
                    const DropdownMenuItem<String>(value: null, child: Text('Unassigned')),
                    ...widget.users.map((u) => DropdownMenuItem(
                          value: u.id,
                          child: Text('${u.username}${u.role != null ? ' (${u.role})' : ''}'),
                        )),
                  ],
                  onChanged: (v) => setState(() => _assignedTo = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.submitting ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: widget.submitting
                      ? null
                      : () async {
                          final t = _title.text.trim();
                          if (t.isEmpty) {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(const SnackBar(content: Text('Task title is required')));
                            return;
                          }
                          
                          // ✅ FIXED: Send date as ISO8601 with time at noon to avoid timezone issues
                          String? dueDateIso;
                          if (_dueDate != null) {
                            final dtWithTime = DateTime(
                              _dueDate!.year,
                              _dueDate!.month,
                              _dueDate!.day,
                              12, // noon
                              0,
                            );
                            dueDateIso = dtWithTime.toUtc().toIso8601String();
                          }
                          
                          await widget.onSubmit(_AddTaskData(
                            title: t,
                            description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
                            dueDateIso: dueDateIso,
                            assignedToId: _assignedTo,
                          ));
                        },
                  child: Text(widget.submitting ? 'Creating...' : 'Create'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}