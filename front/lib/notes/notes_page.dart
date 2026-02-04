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
    Future.microtask(() => ref.read(notesControllerProvider).init());
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _controllers.clear();
    super.dispose();
  }

  TextEditingController _getController(int lineNumber, String content) {
    if (!_controllers.containsKey(lineNumber)) {
      _controllers[lineNumber] = TextEditingController(text: content);
    }
    return _controllers[lineNumber]!;
  }

  void _showCreateNoteDialog(BuildContext context, ctrl) {
    final titleController = TextEditingController();
    
    showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Note'),
        content: TextField(
          controller: titleController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Note Title',
            hintText: 'Enter note title',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) {
            final title = value.trim();
            if (title.isNotEmpty) {
              Navigator.of(context).pop(title);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final title = titleController.text.trim();
              if (title.isNotEmpty) {
                Navigator.of(context).pop(title);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    ).then((title) {
      titleController.dispose();
      // Only create note if dialog returned a title (not cancelled)
      if (title != null && title.isNotEmpty) {
        ctrl.createNewNote(title);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = ref.watch(notesControllerProvider);

    if (ctrl.loading && ctrl.lines.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (ctrl.error != null && ctrl.lines.isEmpty) {
      return Scaffold(
        body: Center(child: Text('Error: ${ctrl.error}')),
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
              if (ctrl.notes.isNotEmpty)
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: ctrl.noteId,
                      isExpanded: true,
                      items: [
                        for (final n in ctrl.notes)
                          DropdownMenuItem(
                            value: n.id.toString(),
                            child: Text(n.title),
                          ),
                      ],
                      onChanged: (v) {
                        if (v == null || v == ctrl.noteId) return;
                        ctrl.openNote(v);
                      },
                    ),
                  ),
                ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Create New Note',
              onPressed: () => _showCreateNoteDialog(context, ctrl),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 8, right: 12),
              child: Center(
                child: Text(
                  ctrl.isConnected ? 'Online' : 'Offline',
                  style: TextStyle(
                    color: ctrl.isConnected ? Colors.green : Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
        body: ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: ctrl.lines.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            final line = ctrl.lines[i];
            final selected = ctrl.selectedLine == line.lineNumber;
            final lockedBy = ctrl.lockedBy(line.lineNumber);
            final canEdit = ctrl.canEditLine(line.lineNumber);

            return _LineCard(
              key: ValueKey('line_${line.lineNumber}'),
              line: line,
              controller: _getController(line.lineNumber, line.content),
              lockedBy: lockedBy,
              canEdit: canEdit,
              selected: selected,
              onTap: () => ctrl.selectLine(line.lineNumber),
              onChanged: (v) => ctrl.updateLineContent(line.lineNumber, v),
              onUnlock: () => ctrl.unlockSelectedLine(),
            );
          },
        ),
      ),
    );
  }
}

class _LineCard extends StatefulWidget {
  const _LineCard({
    super.key,
    required this.line,
    required this.controller,
    required this.lockedBy,
    required this.canEdit,
    required this.selected,
    required this.onTap,
    required this.onChanged,
    required this.onUnlock,
  });

  final NoteLineDto line;
  final TextEditingController controller;
  final String? lockedBy;
  final bool canEdit;
  final bool selected;
  final VoidCallback onTap;
  final ValueChanged<String> onChanged;
  final VoidCallback onUnlock;

  @override
  State<_LineCard> createState() => _LineCardState();
}

class _LineCardState extends State<_LineCard> {
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(_LineCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // ✅ When selected state changes, manage focus
    if (widget.selected && !oldWidget.selected) {
      // Line just got selected - focus it
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _focusNode.requestFocus();
        }
      });
    } else if (!widget.selected && oldWidget.selected) {
      // Line just got unselected - unfocus it
      if (_focusNode.hasFocus) {
        _focusNode.unfocus();
      }
    }

    // ✅ CRITICAL: Only update controller text when NOT selected/editing
    // This prevents cursor jumps
    if (!widget.selected && widget.controller.text != widget.line.content) {
      widget.controller.text = widget.line.content;
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.canEdit && widget.selected;

    return InkWell(
      onTap: widget.selected ? null : widget.onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: widget.selected ? Colors.blue : Colors.grey.shade300,
            width: widget.selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Line ${widget.line.lineNumber}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 10),
                if (widget.lockedBy != null && !widget.canEdit)
                  Text(
                    'locked by ${widget.lockedBy}',
                    style: const TextStyle(color: Colors.red),
                  ),
                const Spacer(),
                _ColorDot(hex: widget.line.color),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              enabled: enabled,
              maxLines: null,
              onChanged: widget.onChanged,
              onTap: enabled ? null : widget.onTap,
              onSubmitted: (_) {
                // ✅ User pressed Enter - unlock the line
                if (enabled) {
                  widget.onUnlock();
                }
              },
              decoration: InputDecoration(
                hintText: enabled 
                    ? 'Type here...' 
                    : 'Tap to edit',
                border: const OutlineInputBorder(),
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