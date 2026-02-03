
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TaskItemForChart {
  final DateTime? dueDate;
  final bool completed;

  const TaskItemForChart({
    required this.dueDate,
    required this.completed,
  });
}

class TasksChart extends StatelessWidget {
  const TasksChart({
    super.key,
    required this.tasks,
    this.title = 'Tasks Completed by Day (Last 7 Days)',
  });

  final List<TaskItemForChart> tasks;
  final String title;

  @override
  Widget build(BuildContext context) {
    final weekly = _buildWeeklyData(tasks);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 280,
            child: LineChart(_chartData(context, weekly)),
          ),
          const SizedBox(height: 10),
          _Legend(context),
        ],
      ),
    );
  }

  /// Mirrors your React logic: create 7 days centered on today (today ±3).
  List<_DayPoint> _buildWeeklyData(List<TaskItemForChart> tasks) {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    // Pre-group by yyyy-MM-dd for speed
    final tasksByDay = <String, List<TaskItemForChart>>{};
    for (final t in tasks) {
      if (t.dueDate == null) continue;
      final d = DateTime(t.dueDate!.year, t.dueDate!.month, t.dueDate!.day);
      final key = _yyyyMmDd(d);
      (tasksByDay[key] ??= []).add(t);
    }

    final points = <_DayPoint>[];
    for (int i = 0; i < 7; i++) {
      final date = todayDate.add(Duration(days: i - 3));
      final key = _yyyyMmDd(date);
      final dayTasks = tasksByDay[key] ?? const [];

      final total = dayTasks.length;
      final completed = dayTasks.where((t) => t.completed).length;

      points.add(
        _DayPoint(
          date: date,
          display: DateFormat('MMM d').format(date), // e.g. "Jan 26"
          isToday: date == todayDate,
          total: total,
          completed: completed,
        ),
      );
    }

    return points;
  }

  LineChartData _chartData(BuildContext context, List<_DayPoint> weekly) {
    final cs = Theme.of(context).colorScheme;

    // x-axis is 0..6
    final completedSpots = <FlSpot>[];
    final totalSpots = <FlSpot>[];

    int maxY = 0;
    for (int i = 0; i < weekly.length; i++) {
      final d = weekly[i];
      completedSpots.add(FlSpot(i.toDouble(), d.completed.toDouble()));
      totalSpots.add(FlSpot(i.toDouble(), d.total.toDouble()));
      if (d.total > maxY) maxY = d.total;
    }
    // Add headroom for nicer look
    final yMax = (maxY + 1).toDouble();

    return LineChartData(
      minX: 0,
      maxX: 6,
      minY: 0,
      maxY: yMax < 3 ? 3 : yMax,

      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: 1,
        getDrawingHorizontalLine: (value) {
          return FlLine(
            color: cs.outlineVariant.withOpacity(0.5),
            strokeWidth: 1,
            dashArray: [4, 6],
          );
        },
      ),
      borderData: FlBorderData(
        show: true,
        border: Border(
          left: BorderSide(color: cs.outlineVariant.withOpacity(0.6)),
          bottom: BorderSide(color: cs.outlineVariant.withOpacity(0.6)),
          top: BorderSide.none,
          right: BorderSide.none,
        ),
      ),

      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 32,
            interval: 1,
            getTitlesWidget: (value, meta) {
              // show integer labels only
              if (value % 1 != 0) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  value.toInt().toString(),
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                ),
              );
            },
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 28,
            interval: 1,
            getTitlesWidget: (value, meta) {
              final i = value.toInt();
              if (i < 0 || i >= weekly.length) return const SizedBox.shrink();
              final d = weekly[i];

              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  d.display,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: d.isToday ? FontWeight.w800 : FontWeight.w500,
                    color: d.isToday ? cs.primary : cs.onSurfaceVariant,
                  ),
                ),
              );
            },
          ),
        ),
      ),

      lineTouchData: LineTouchData(
        enabled: true,
        handleBuiltInTouches: true,
        touchTooltipData: LineTouchTooltipData(
          tooltipRoundedRadius: 12,
          tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          getTooltipColor: (_) => cs.surface,
          getTooltipItems: (touchedSpots) {
            if (touchedSpots.isEmpty) return [];

            // Both lines will report spots; we want one tooltip per line with nice labels.
            final items = <LineTooltipItem>[];

            // Determine day index from the first spot
            final dayIndex = touchedSpots.first.x.toInt();
            final day = (dayIndex >= 0 && dayIndex < weekly.length)
                ? weekly[dayIndex]
                : null;

            // Tooltip title: "Today (Jan 26)" or "Jan 24"
            final header = day == null
                ? ''
                : day.isToday
                    ? 'Today (${day.display})\n'
                    : '${day.display}\n';

            // Sort so completed appears first (like your green line prominence)
            final sorted = [...touchedSpots]
              ..sort((a, b) => (b.barIndex).compareTo(a.barIndex));
            // Note: barIndex depends on order we add lines below.

            // We'll create 2 items: Completed + Total
            // Colors are taken from the line colors.
            for (final s in sorted) {
              final isCompletedLine = s.barIndex == 0; // first line we add below
              final label = isCompletedLine ? 'Tasks Completed' : 'Total Tasks Due';
              final value = s.y.toInt();

              items.add(
                LineTooltipItem(
                  header + '$label: $value',
                  TextStyle(
                    color: isCompletedLine ? cs.primary : cs.tertiary,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
              );

              // After the first item, remove header so it doesn't repeat
              if (header.isNotEmpty) {
                // set header empty for next items
                // (we can't mutate header, so we handle by only prefixing on first item)
              }
              // Trick: only prefix header on first tooltip item
              break;
            }

            // Add the second line value as a separate tooltip line (without repeating header)
            if (day != null) {
              final completed = day.completed;
              final total = day.total;

              items
                ..clear()
                ..add(
                  LineTooltipItem(
                    day.isToday ? 'Today (${day.display})\n' : '${day.display}\n',
                    TextStyle(color: cs.onSurface, fontWeight: FontWeight.w800),
                  ),
                )
                ..add(
                  LineTooltipItem(
                    'Tasks Completed: $completed',
                    TextStyle(color: cs.primary, fontWeight: FontWeight.w700),
                  ),
                )
                ..add(
                  LineTooltipItem(
                    'Total Tasks Due: $total',
                    TextStyle(color: cs.tertiary, fontWeight: FontWeight.w700),
                  ),
                );
            }

            return items;
          },
        ),
      ),

      lineBarsData: [
        // Completed: solid
        LineChartBarData(
          spots: completedSpots,
          isCurved: true,
          barWidth: 3,
          color: cs.primary,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, barData, index) {
              return FlDotCirclePainter(
                radius: 4,
                color: cs.primary,
                strokeWidth: 2,
                strokeColor: cs.surface,
              );
            },
          ),
        ),

        // Total: dashed
        LineChartBarData(
          spots: totalSpots,
          isCurved: true,
          barWidth: 2,
          color: cs.tertiary,
          dashArray: [6, 6],
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, barData, index) {
              return FlDotCirclePainter(
                radius: 3,
                color: cs.tertiary,
                strokeWidth: 2,
                strokeColor: cs.surface,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend(this.context);

  final BuildContext context;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Wrap(
      spacing: 14,
      runSpacing: 8,
      children: [
        _LegendItem(
          color: cs.primary,
          label: 'Tasks Completed',
          solid: true,
        ),
        _LegendItem(
          color: cs.tertiary,
          label: 'Total Tasks Due',
          solid: false,
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
    required this.solid,
  });

  final Color color;
  final String label;
  final bool solid;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 26,
          height: 14,
          child: CustomPaint(
            painter: _LegendLinePainter(
              color: color,
              dashed: !solid,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _LegendLinePainter extends CustomPainter {
  _LegendLinePainter({required this.color, required this.dashed});

  final Color color;
  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final y = size.height / 2;

    if (!dashed) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      return;
    }

    const dashWidth = 6.0;
    const dashSpace = 5.0;
    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, y),
        Offset((startX + dashWidth).clamp(0, size.width), y),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _LegendLinePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.dashed != dashed;
  }
}

class _DayPoint {
  final DateTime date;
  final String display; // "Jan 26"
  final bool isToday;
  final int completed;
  final int total;

  _DayPoint({
    required this.date,
    required this.display,
    required this.isToday,
    required this.completed,
    required this.total,
  });
}

String _yyyyMmDd(DateTime d) {
  final mm = d.month.toString().padLeft(2, '0');
  final dd = d.day.toString().padLeft(2, '0');
  return '${d.year}-$mm-$dd';
}
