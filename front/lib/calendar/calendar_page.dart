import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '/widgets/error.dart';
import '/widgets/loading.dart';
import '../models/event_model.dart';
import 'calendar_service.dart';
import '../auth/auth_controller.dart';

final calendarServiceProvider = Provider<CalendarService>((ref) {
  return CalendarService();
});

class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key});

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  DateTime _selectedDay = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

  bool _loading = true;
  String? _error;
  bool _creating = false;

  List<EventDto> _events = [];

  @override
  void initState() {
    super.initState();
    _loadDay(_selectedDay);
  }

  String _yyyyMmDd(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  Future<void> _loadDay(DateTime day) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final service = ref.read(calendarServiceProvider);
      final res = await service.fetchEventsByDay(_yyyyMmDd(day));

      // Sort by time
      res.sort((a, b) => a.date.compareTo(b.date));

      setState(() {
        _events = res;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDay,
      firstDate: DateTime(DateTime.now().year - 1, 1, 1),
      lastDate: DateTime(DateTime.now().year + 3, 12, 31),
    );
    if (picked == null) return;

    setState(() => _selectedDay = DateTime(picked.year, picked.month, picked.day));
    await _loadDay(_selectedDay);
  }

  Future<void> _openAddEventSheet() async {
    // ✅ Server-side should also enforce manager role, but UI is restricted here.
    final auth = ref.read(authControllerProvider);
    if (!auth.isManager) return;

    final result = await showModalBottomSheet<_AddEventData>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _AddEventSheet(),
    );

    if (result == null) return;

    setState(() => _creating = true);
    try {
      final service = ref.read(calendarServiceProvider);

      final dtLocal = DateTime(
        _selectedDay.year,
        _selectedDay.month,
        _selectedDay.day,
        result.time.hour,
        result.time.minute,
      );

      await service.createEvent(
        title: result.title,
        description: result.description,
        dateTimeIso: dtLocal.toUtc().toIso8601String(),
      );

      await _loadDay(_selectedDay);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating event: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final isManager = auth.isManager;

    if (_loading) {
      return const Scaffold(body: AppLoading(message: 'Loading events...'));
    }
    if (_error != null) {
      return Scaffold(
        body: AppError(
          message: _error!,
          onRetry: () => _loadDay(_selectedDay),
        ),
      );
    }

    final dayLabel = DateFormat('EEEE, MMM d, yyyy').format(_selectedDay);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        actions: [
          IconButton(
            tooltip: 'Pick day',
            icon: const Icon(Icons.event_rounded),
            onPressed: _pickDay,
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _loadDay(_selectedDay),
          ),
        ],
      ),

      // ✅ Only managers see the "Add Event" button
      floatingActionButton: isManager
          ? FloatingActionButton.extended(
              onPressed: _creating ? null : _openAddEventSheet,
              icon: const Icon(Icons.add_rounded),
              label: Text(_creating ? 'Adding...' : 'Add Event'),
            )
          : null,

      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          children: [
            _DayHeader(
              dayLabel: dayLabel,
              onPick: _pickDay,
            ),
            const SizedBox(height: 12),

            if (_events.isEmpty)
              const _EmptyCard(text: 'No events for this day.')
            else
              ..._events.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _EventTile(event: e),
                  )),

            // Optional manager hint section (kept if you had it)
            if (isManager) ...[
              const SizedBox(height: 10),
              const _InfoCard(
                text: 'Only managers can create events. All users can view them.',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.dayLabel, required this.onPick});

  final String dayLabel;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            dayLabel,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        TextButton.icon(
          onPressed: onPick,
          icon: const Icon(Icons.calendar_today_rounded),
          label: const Text('Change'),
        ),
      ],
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Text(text),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Text(text),
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event});
  final EventDto event;

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('HH:mm').format(event.date);
    final dateLine = '$time • ${DateFormat('MMM d, yyyy').format(event.date)}';

    return Card(
      child: ListTile(
        title: Text(event.title),
        subtitle: Text(
          (event.description?.trim().isNotEmpty ?? false)
              ? '${event.description}\n$dateLine'
              : dateLine,
        ),
        isThreeLine: (event.description?.trim().isNotEmpty ?? false),
      ),
    );
  }
}

/* ---------- Add Event Sheet ---------- */

class _AddEventData {
  final String title;
  final String? description;
  final TimeOfDay time;

  _AddEventData({
    required this.title,
    required this.description,
    required this.time,
  });
}

class _AddEventSheet extends StatefulWidget {
  const _AddEventSheet();

  @override
  State<_AddEventSheet> createState() => _AddEventSheetState();
}

class _AddEventSheetState extends State<_AddEventSheet> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  TimeOfDay _time = const TimeOfDay(hour: 9, minute: 0);

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
    );
    if (picked != null) setState(() => _time = picked);
  }

  void _submit() {
    final title = _titleCtrl.text.trim();
    final desc = _descCtrl.text;

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title is required')),
      );
      return;
    }

    Navigator.pop(
      context,
      _AddEventData(
        title: title,
        description: desc,
        time: _time,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Add Event', style: Theme.of(context).textTheme.titleMedium),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              )
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(
              labelText: 'Title',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _descCtrl,
            decoration: const InputDecoration(
              labelText: 'Description',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: Text('Time: ${_time.format(context)}')),
              TextButton.icon(
                onPressed: _pickTime,
                icon: const Icon(Icons.schedule_rounded),
                label: const Text('Pick time'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.check_rounded),
              label: const Text('Create'),
            ),
          ),
        ],
      ),
    );
  }
}
