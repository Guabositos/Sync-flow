import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import '../models/task_model.dart';
import '../widgets/loading.dart';
import '../widgets/error.dart';
import 'tasks_service.dart';

final tasksServiceProvider = Provider<TasksService>((ref) => TasksService());

class TasksPage extends ConsumerStatefulWidget {
  const TasksPage({super.key});

  @override
  ConsumerState<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends ConsumerState<TasksPage> {
  bool _loading = true;
  String? _error;
  List<TaskDto> _tasks = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final auth = ref.read(authControllerProvider);
      final userId = auth.user?.id;
      if (userId == null || userId.isEmpty) {
        throw Exception('Please log in to view your tasks.');
      }

      final service = ref.read(tasksServiceProvider);
      final tasks = await service.fetchTasksByUser(userId);

      setState(() {
        _tasks = tasks;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  bool _isMissed(TaskDto task) {
    final due = task.dueDate;
    if (due == null) return false;
    if (task.completed) return false;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(due.year, due.month, due.day);

    return dueDay.isBefore(today);
  }

  bool _isPending(TaskDto task) {
    if (task.completed) return false;

    final due = task.dueDate;
    if (due == null) return true;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(due.year, due.month, due.day);

    return dueDay.isAtSameMomentAs(today) || dueDay.isAfter(today);
  }

  String _formatDue(DateTime? due) {
    if (due == null) return 'No due date';
    return '${due.year}-${due.month.toString().padLeft(2, '0')}-${due.day.toString().padLeft(2, '0')}';
  }

  /// ✅ Check-only completion:
  /// - if already completed => do nothing
  /// - else call POST /tasks/done/:id
  Future<void> _markDone(int index) async {
    final service = ref.read(tasksServiceProvider);
    final task = _tasks[index];

    // Check-only: do not allow undo
    if (task.completed) return;

    // Optimistic UI update: set completed true
    final updated = TaskDto(
      id: task.id,
      title: task.title,
      description: task.description,
      dueDate: task.dueDate,
      completed: true,
      assignedTo: task.assignedTo,
    );

    setState(() {
      _tasks[index] = updated;
    });

    try {
      await service.markTaskDone(task.id);
    } catch (e) {
      // Revert on error
      setState(() {
        _tasks[index] = task;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error marking task as done: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final name = auth.user?.username ?? 'User';

    if (_loading) {
      return const Scaffold(body: AppLoading(message: 'Loading tasks...'));
    }

    if (_error != null) {
      return Scaffold(
        body: AppError(
          message: _error!,
          onRetry: _load,
        ),
      );
    }

    final completedCount = _tasks.where((t) => t.completed).length;
    final pendingCount = _tasks.length - completedCount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          )
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          children: [
            _HeaderCard(name: name),
            const SizedBox(height: 14),
            if (_tasks.isEmpty)
              const _EmptyCard(
                title: 'No tasks assigned',
                subtitle: "You don't have any tasks assigned to you yet.",
              )
            else
              ...List.generate(_tasks.length, (i) {
                final t = _tasks[i];

                final missed = _isMissed(t);

                final statusText = t.completed
                    ? 'Completed'
                    : missed
                        ? 'Missed'
                        : 'Pending';

                final statusKind = t.completed
                    ? _StatusKind.completed
                    : missed
                        ? _StatusKind.missed
                        : _StatusKind.pending;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _TaskCard(
                    title: t.title,
                    description: t.description,
                    dueText: _formatDue(t.dueDate),
                    assigneeName: t.assignedTo?.username,
                    status: statusText,
                    statusKind: statusKind,
                    checked: t.completed,
                    // ✅ disable toggle if completed
                    onToggle: t.completed ? null : () => _markDone(i),
                  ),
                );
              }),
            const SizedBox(height: 16),
            _StatsCard(
              total: _tasks.length,
              completed: completedCount,
              pending: pendingCount,
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.name});
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'My Tasks',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Welcome, $name! Here are your assigned tasks.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

enum _StatusKind { completed, missed, pending }

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.title,
    required this.description,
    required this.dueText,
    required this.assigneeName,
    required this.status,
    required this.statusKind,
    required this.checked,
    this.onToggle,
  });

  final String title;
  final String? description;
  final String dueText;
  final String? assigneeName;

  final String status;
  final _StatusKind statusKind;

  final bool checked;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final Color borderColor;
    final Color tint;
    final Color badge;

    switch (statusKind) {
      case _StatusKind.completed:
        borderColor = cs.primary.withOpacity(0.35);
        tint = cs.primary.withOpacity(0.06);
        badge = cs.primary;
        break;
      case _StatusKind.missed:
        borderColor = cs.error.withOpacity(0.35);
        tint = cs.error.withOpacity(0.06);
        badge = cs.error;
        break;
      case _StatusKind.pending:
        borderColor = cs.secondary.withOpacity(0.35);
        tint = cs.secondary.withOpacity(0.06);
        badge = cs.secondary;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: checked,
            // ✅ check-only: disable if already completed
            onChanged: checked ? null : (_) => onToggle?.call(),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        decoration: checked ? TextDecoration.lineThrough : null,
                      ),
                ),
                if (description != null && description!.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    description!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                          decoration: checked ? TextDecoration.lineThrough : null,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  children: [
                    _MetaPill(label: 'Due: $dueText'),
                    if (assigneeName != null && assigneeName!.isNotEmpty)
                      _MetaPill(label: 'Assigned: $assigneeName'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _StatusPill(text: status, color: badge),
        ],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: color,
            ),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({
    required this.total,
    required this.completed,
    required this.pending,
  });

  final int total;
  final int completed;
  final int pending;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    final cols = width >= 700 ? 3 : 2;
    final ratio = width < 360 ? 1.8 : 2.0;

    final items = [
      _StatItem(title: 'Total Tasks', value: '$total', tint: cs.primary.withOpacity(0.10)),
      _StatItem(title: 'Completed', value: '$completed', tint: cs.primary.withOpacity(0.10)),
      _StatItem(title: 'Pending', value: '$pending', tint: cs.secondary.withOpacity(0.10)),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Task Statistics',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: ratio,
            ),
            itemCount: items.length,
            itemBuilder: (_, i) => items[i],
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.title, required this.value, required this.tint});
  final String title;
  final String value;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
          ),
                  const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
        ],
      ),
    );
  }
}


