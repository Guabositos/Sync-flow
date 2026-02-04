import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/note_model.dart';
import 'notes_controller.dart';

class NotesPage extends ConsumerStatefulWidget {
  const NotesPage({super.key});

  @override
  ConsumerState<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends ConsumerState<NotesPage> {
  final Map<int, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(notesControllerProvider.notifier).init());
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _controllers.clear();
    super.dispose();
  }

  TextEditingController _getController({
    required NoteLineDto line,
    required bool selected,
  }) {
    final existing = _controllers[line.lineNumber];
    if (existing == null) {
      final c = TextEditingController(text: line.content);
      _controllers[line.lineNumber] = c;
      return c;
    }

    // ✅ CRITICAL: Never update controller while line is selected/being edited
    // This prevents cursor jumps and text loss while typing
    if (selected) {
      return existing;
    }

    // Only sync when content actually changed
    if (existing.text != line.content) {
      existing.value = existing.value.copyWith(
        text: line.content,
        selection: TextSelection.collapsed(offset: line.content.length),
        composing: TextRange.empty,
      );
    }

    return existing;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notesControllerProvider);
    final ctrl = ref.read(notesControllerProvider.notifier);

    if (state.loading && state.lines.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (state.error != null && state.lines.isEmpty) {
      return Scaffold(
        body: Center(child: Text('Error: ${state.error}')),
      );
    }

    return PopScope(
      canPop: true,
      onPopInvoked: (_) => ctrl.unlockSelectedLine(),
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              const Text('Notes'),
              const SizedBox(width: 12),
              if (state.notes.isNotEmpty)
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: state.noteId,
                      isExpanded: true,
                      items: [
                        for (final n in state.notes)
                          DropdownMenuItem(
                            value: n.id.toString(),
                            child: Text('${n.title} (#${n.id})'),
                          ),
                      ],
                      onChanged: (v) {
                        if (v == null || v == state.noteId) return;
                        ctrl.openNote(v);
                      },
                    ),
                  ),
                ),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Text(
                  state.isConnected ? 'Online' : 'Offline',
                  style: TextStyle(
                    color: state.isConnected ? Colors.green : Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
        body: ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: state.lines.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            final line = state.lines[i];
            final selected = state.selectedLine == line.lineNumber;

            final lockedBy = ctrl.lockedBy(line.lineNumber);
            final canEdit = ctrl.canEditLine(line.lineNumber);

            return _LineCard(
              line: line,
              controller: _getController(line: line, selected: selected),
              lockedBy: lockedBy,
              canEdit: canEdit,
              selected: selected,
              onTap: () => ctrl.selectLine(line.lineNumber),
              onChanged: (v) => ctrl.updateLineContent(line.lineNumber, v),
            );
          },
        ),
      ),
    );
  }
}

class _LineCard extends StatelessWidget {
  const _LineCard({
    required this.line,
    required this.controller,
    required this.lockedBy,
    required this.canEdit,
    required this.selected,
    required this.onTap,
    required this.onChanged,
  });

  final NoteLineDto line;
  final TextEditingController controller;
  final String? lockedBy;
  final bool canEdit;
  final bool selected;
  final VoidCallback onTap;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final enabled = canEdit && selected;

    return InkWell(
      // ✅ Only trigger onTap if not already selected - prevents stealing focus
      onTap: selected ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? Colors.blue : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Line ${line.lineNumber}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 10),
                if (lockedBy != null && !canEdit)
                  Text(
                    'locked by $lockedBy',
                    style: const TextStyle(color: Colors.red),
                  ),
                const Spacer(),
                _ColorDot(hex: line.color),
              ],
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: enabled ? null : onTap,
              child: TextField(
                controller: controller,
                enabled: enabled,
                maxLines: null,
                onChanged: onChanged,
                decoration: InputDecoration(
                  hintText: enabled ? 'Type here...' : 'Tap to edit',
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({required this.hex});
  final String hex;

  @override
  Widget build(BuildContext context) {
    Color c = Colors.black;
    try {
      final h = hex.replaceAll('#', '');
      final v = int.parse(h.length == 6 ? 'FF$h' : h, radix: 16);
      c = Color(v);
    } catch (_) {}

    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: c,
        shape: BoxShape.circle,
      ),
    );
  }
}