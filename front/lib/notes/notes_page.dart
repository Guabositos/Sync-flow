import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import '../widgets/loading.dart';
import '../widgets/error.dart';
import 'notes_controller.dart';
import '../models/note_model.dart';

class NotesPage extends ConsumerStatefulWidget {
  const NotesPage({super.key});

  @override
  ConsumerState<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends ConsumerState<NotesPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(notesControllerProvider.notifier).init());
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final state = ref.watch(notesControllerProvider);
    final ctrl = ref.read(notesControllerProvider.notifier);

    if (auth.user == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in to access notes.')),
      );
    }

    if (state.loading) {
      return const Scaffold(body: AppLoading(message: 'Loading note...'));
    }

    if (state.error != null && state.lines.isEmpty) {
      return Scaffold(
        body: AppError(
          message: state.error!,
          onRetry: () => ref.read(notesControllerProvider.notifier).init(),
        ),
      );
    }

    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
        // ✅ Release lock when leaving page (back/gesture)
        ref.read(notesControllerProvider.notifier).unlockSelectedLine();
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () async {
          // tap outside => unlock selected line
          await ref.read(notesControllerProvider.notifier).unlockSelectedLine();
          FocusScope.of(context).unfocus();
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Notes'),
            actions: [
              _ConnectionPill(isConnected: state.isConnected),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Style',
                onPressed: state.selectedLine == null
                    ? null
                    : () {
                        final ln = state.selectedLine!;
                        final line = state.lines.firstWhere((l) => l.lineNumber == ln);
                        _openStyleSheet(context, line);
                      },
                icon: const Icon(Icons.format_paint_rounded),
              ),
              const SizedBox(width: 6),
            ],
          ),
          body: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
            itemCount: state.lines.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final line = state.lines[i];
              final lockedBy = ctrl.lockedBy(line.lineNumber);
              final canEdit = ctrl.canEditLine(line.lineNumber);
              final isSelected = state.selectedLine == line.lineNumber;

              return _LineCard(
                line: line,
                lockedBy: lockedBy,
                canEdit: canEdit,
                selected: isSelected,
                onTap: () => ctrl.selectLine(line.lineNumber),
                onChanged: (v) => ctrl.updateLineContent(line.lineNumber, v),
              );
            },
          ),
        ),
      ),
    );
  }

  void _openStyleSheet(BuildContext context, NoteLineDto line) {
    final ctrl = ref.read(notesControllerProvider.notifier);

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) {
        // local sheet state
        double fs = line.fontSize;
        bool hl = line.highlighted;
        String selectedColor = line.color;

        // fixed palette
        const palette = <String>[
          '#000000',
          '#1f2937',
          '#ef4444',
          '#f59e0b',
          '#10b981',
          '#3b82f6',
          '#8b5cf6',
        ];

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                16 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Line ${line.lineNumber} style',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      const Icon(Icons.text_fields_rounded),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Slider(
                          value: fs.clamp(10, 28),
                          min: 10,
                          max: 28,
                          divisions: 18,
                          label: fs.round().toString(),
                          onChanged: (v) => setSheetState(() => fs = v),
                          onChangeEnd: (v) => ctrl.updateLineStyle(
                            lineNumber: line.lineNumber,
                            fontSize: v,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 42,
                        child: Text(fs.round().toString(),
                            textAlign: TextAlign.end),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Color',
                        style: Theme.of(context).textTheme.titleSmall),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final c in palette)
                        _ColorDot(
                          hex: c,
                          selected: c.toLowerCase() ==
                              selectedColor.toLowerCase(),
                          onTap: () {
                            setSheetState(() => selectedColor = c);
                            ctrl.updateLineStyle(
                              lineNumber: line.lineNumber,
                              color: c,
                            );
                          },
                        ),
                    ],
                  ),

                  const SizedBox(height: 14),
                  SwitchListTile(
                    value: hl,
                    onChanged: (v) {
                      setSheetState(() => hl = v);
                      ctrl.updateLineStyle(
                        lineNumber: line.lineNumber,
                        highlighted: v,
                      );
                    },
                    title: const Text('Highlight'),
                    subtitle: const Text('Makes this line stand out for everyone'),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ConnectionPill extends StatelessWidget {
  const _ConnectionPill({required this.isConnected});
  final bool isConnected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg =
        isConnected ? Colors.green.withOpacity(0.15) : cs.error.withOpacity(0.12);
    final fg = isConnected ? Colors.green : cs.error;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withOpacity(0.30)),
      ),
      child: Text(
        isConnected ? 'Connected' : 'Disconnected',
        style: TextStyle(color: fg, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _LineCard extends StatelessWidget {
  const _LineCard({
    required this.line,
    required this.lockedBy,
    required this.canEdit,
    required this.selected,
    required this.onTap,
    required this.onChanged,
  });

  final NoteLineDto line;
  final String? lockedBy;
  final bool canEdit;
  final bool selected;
  final VoidCallback onTap;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final border =
        selected ? cs.primary.withOpacity(0.55) : cs.outlineVariant.withOpacity(0.55);

    final bg = line.highlighted ? cs.primary.withOpacity(0.08) : cs.surface;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // line number
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${line.lineNumber}',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(width: 10),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (lockedBy != null && !canEdit)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Icon(Icons.lock_rounded, size: 16, color: cs.error),
                          const SizedBox(width: 6),
                          Text(
                            'Locked by $lockedBy',
                            style: TextStyle(
                              color: cs.error,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  TextFormField(
                    enabled: canEdit,
                    minLines: 1,
                    maxLines: 6,
                    initialValue: line.content,
                    onChanged: onChanged,
                    style: TextStyle(
                      fontSize: line.fontSize,
                      color: _hexToColor(line.color),
                      height: 1.25,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: canEdit ? 'Type…' : 'Locked…',
                      border: InputBorder.none,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              canEdit ? Icons.edit_rounded : Icons.lock_rounded,
              color: canEdit ? cs.primary : cs.outline,
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({required this.hex, required this.selected, required this.onTap});
  final String hex;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _hexToColor(hex);
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? cs.primary : Colors.black.withOpacity(0.15),
            width: selected ? 3 : 1,
          ),
        ),
      ),
    );
  }
}

Color _hexToColor(String hex) {
  final h = hex.replaceAll('#', '').trim();
  final v = int.parse(h.length == 6 ? 'FF$h' : h, radix: 16);
  return Color(v);
}
