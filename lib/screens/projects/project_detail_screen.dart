import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/project_controller.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../models/project.dart';
import '../../services/obsidian_service.dart';
import '../../services/project_service.dart';

class ProjectDetailScreen extends StatefulWidget {
  const ProjectDetailScreen({super.key, required this.project});
  final Project project;

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProjectController>().selectProject(widget.project);
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final color = _hexToColor(widget.project.color) ?? t.pop;

    return Scaffold(
      backgroundColor: t.bg,
      appBar: _AppBar(t: t, project: widget.project, color: color),
      body: Column(
        children: [
          _StatsHeader(t: t, project: widget.project, color: color),
          TabBar(
            controller: _tabs,
            labelColor: t.ink,
            unselectedLabelColor: t.ink3,
            indicatorColor: color,
            indicatorWeight: 2,
            labelStyle: TextStyle(
              fontFamily: AppFonts.ui,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            tabs: const [Tab(text: 'Tasks'), Tab(text: 'History')],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _TasksTab(project: widget.project, t: t, color: color),
                _HistoryTab(project: widget.project, t: t),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AppBar extends StatelessWidget implements PreferredSizeWidget {
  const _AppBar({required this.t, required this.project, required this.color});
  final AppTokens t;
  final Project project;
  final Color color;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: t.bg,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: t.surface,
              border: Border.all(color: t.border),
            ),
            child: Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: t.ink),
          ),
        ),
      ),
      title: Text(
        project.name,
        style: TextStyle(fontFamily: AppFonts.ui, fontSize: 17, fontWeight: FontWeight.w600, color: t.ink),
      ),
      centerTitle: true,
      actions: [
        PopupMenuButton<String>(
          color: t.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          onSelected: (v) async {
            if (v == 'archive') {
              await context.read<ProjectController>().archiveProject(project.id);
              if (context.mounted) Navigator.of(context).pop();
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'archive',
              child: Row(
                children: [
                  Icon(Icons.archive_outlined, size: 16, color: t.ink2),
                  const SizedBox(width: 8),
                  Text('Archive', style: TextStyle(fontFamily: AppFonts.ui, color: t.ink2)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatsHeader extends StatelessWidget {
  const _StatsHeader({required this.t, required this.project, required this.color});
  final AppTokens t;
  final Project project;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: t.bg,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Row(
        children: [
          _StatChip(
            label: 'Sessions',
            value: '${project.totalPomodoros}',
            color: color,
            t: t,
          ),
          const SizedBox(width: 12),
          _StatChip(
            label: 'Done',
            value: '${project.completedTasks}/${project.totalTasks}',
            color: t.sage,
            t: t,
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value, required this.color, required this.t});
  final String label;
  final String value;
  final Color color;
  final AppTokens t;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: TextStyle(fontFamily: AppFonts.mono, fontSize: 18, fontWeight: FontWeight.w700, color: t.ink)),
          Text(label, style: TextStyle(fontFamily: AppFonts.ui, fontSize: 11, color: t.ink3)),
        ],
      ),
    );
  }
}

// ── Tasks tab ─────────────────────────────────────────────────────────────────

class _TasksTab extends StatelessWidget {
  const _TasksTab({required this.project, required this.t, required this.color});
  final Project project;
  final AppTokens t;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (project.isObsidian) {
      return _ObsidianTasksView(project: project, t: t, color: color);
    }
    return _NativeTasksView(project: project, t: t, color: color);
  }
}

class _NativeTasksView extends StatefulWidget {
  const _NativeTasksView({required this.project, required this.t, required this.color});
  final Project project;
  final AppTokens t;
  final Color color;

  @override
  State<_NativeTasksView> createState() => _NativeTasksViewState();
}

class _NativeTasksViewState extends State<_NativeTasksView> {
  final _ctrl = TextEditingController();
  bool _adding = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tasks = context.watch<ProjectController>().nativeTasks;
    final t = widget.t;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        ...tasks.map((task) => _NativeTaskRow(task: task, t: t, color: widget.color)),
        const SizedBox(height: 8),
        if (_adding)
          _AddTaskField(
            controller: _ctrl,
            t: t,
            onSubmit: () async {
              final title = _ctrl.text.trim();
              if (title.isNotEmpty) {
                await context.read<ProjectController>().addTask(title: title);
              }
              _ctrl.clear();
              setState(() => _adding = false);
            },
            onCancel: () => setState(() => _adding = false),
          )
        else
          GestureDetector(
            onTap: () => setState(() => _adding = true),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.add_rounded, size: 16, color: t.ink3),
                  const SizedBox(width: 8),
                  Text('Add task', style: TextStyle(fontFamily: AppFonts.ui, fontSize: 14, color: t.ink3)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _NativeTaskRow extends StatelessWidget {
  const _NativeTaskRow({required this.task, required this.t, required this.color});
  final ProjectTask task;
  final AppTokens t;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: task.isCompleted
                ? null
                : () => context.read<ProjectController>().completeTask(task.id),
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: task.isCompleted ? color : Colors.transparent,
                border: Border.all(
                  color: task.isCompleted ? color : t.border,
                  width: 1.5,
                ),
              ),
              child: task.isCompleted
                  ? Icon(Icons.check_rounded, size: 12, color: t.bg)
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              task.title,
              style: TextStyle(
                fontFamily: AppFonts.ui,
                fontSize: 14,
                color: task.isCompleted ? t.ink3 : t.ink,
                decoration: task.isCompleted ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          if (task.expectedPomodoros > 0) ...[
            const SizedBox(width: 8),
            _PomodoroProgress(actual: task.actualPomodoros, expected: task.expectedPomodoros, color: color, t: t),
          ] else if (task.actualPomodoros > 0) ...[
            const SizedBox(width: 8),
            Text(
              '${task.actualPomodoros}',
              style: TextStyle(fontFamily: AppFonts.mono, fontSize: 12, color: t.ink3),
            ),
          ],
        ],
      ),
    );
  }
}

class _PomodoroProgress extends StatelessWidget {
  const _PomodoroProgress({required this.actual, required this.expected, required this.color, required this.t});
  final int actual;
  final int expected;
  final Color color;
  final AppTokens t;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '$actual/$expected',
          style: TextStyle(fontFamily: AppFonts.mono, fontSize: 12, color: t.ink3),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(
            value: expected > 0 ? (actual / expected).clamp(0.0, 1.0) : 0,
            backgroundColor: t.surface2,
            color: color,
            strokeWidth: 2.5,
          ),
        ),
      ],
    );
  }
}

class _AddTaskField extends StatelessWidget {
  const _AddTaskField({required this.controller, required this.t, required this.onSubmit, required this.onCancel});
  final TextEditingController controller;
  final AppTokens t;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            autofocus: true,
            onSubmitted: (_) => onSubmit(),
            style: TextStyle(fontFamily: AppFonts.ui, fontSize: 14, color: t.ink),
            decoration: InputDecoration(
              hintText: 'Task name',
              hintStyle: TextStyle(fontFamily: AppFonts.ui, color: t.ink3),
              border: InputBorder.none,
            ),
          ),
        ),
        GestureDetector(onTap: onSubmit, child: Icon(Icons.check_rounded, size: 18, color: t.sage)),
        const SizedBox(width: 8),
        GestureDetector(onTap: onCancel, child: Icon(Icons.close_rounded, size: 18, color: t.ink3)),
      ],
    );
  }
}

class _ObsidianTasksView extends StatelessWidget {
  const _ObsidianTasksView({required this.project, required this.t, required this.color});
  final Project project;
  final AppTokens t;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final obsidian = context.watch<ObsidianService>();
    final tasks = project.obsidianPaths.isEmpty
        ? obsidian.pendingTasks
        : obsidian.pendingTasks
            .where((t) => project.obsidianPaths.contains(t.filePath))
            .toList();

    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline_rounded, size: 40, color: t.border),
            const SizedBox(height: 12),
            Text('All tasks complete', style: TextStyle(fontFamily: AppFonts.ui, fontSize: 14, color: t.ink3)),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: tasks
          .map((task) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: t.border, width: 1.5),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(task.title, style: TextStyle(fontFamily: AppFonts.ui, fontSize: 14, color: t.ink)),
                          Text(task.fileName, style: TextStyle(fontFamily: AppFonts.ui, fontSize: 11, color: t.ink3)),
                        ],
                      ),
                    ),
                    if (task.expectedPomodoros > 0 || task.actualPomodoros > 0) ...[
                      const SizedBox(width: 8),
                      Text(
                        task.expectedPomodoros > 0
                            ? '${task.actualPomodoros}/${task.expectedPomodoros}'
                            : '${task.actualPomodoros}',
                        style: TextStyle(fontFamily: AppFonts.mono, fontSize: 12, color: t.ink3),
                      ),
                    ],
                  ],
                ),
              ))
          .toList(),
    );
  }
}

// ── History tab ───────────────────────────────────────────────────────────────

class _HistoryTab extends StatelessWidget {
  const _HistoryTab({required this.project, required this.t});
  final Project project;
  final AppTokens t;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<TaskPomodoro>>(
      future: context.read<ProjectService>().historyForProject(project.id),
      builder: (context, snap) {
        if (!snap.hasData) {
          return Center(child: CircularProgressIndicator(color: t.pop, strokeWidth: 2));
        }
        final history = snap.data!;
        if (history.isEmpty) {
          return Center(
            child: Text(
              'No sessions recorded yet',
              style: TextStyle(fontFamily: AppFonts.ui, fontSize: 14, color: t.ink3),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          itemCount: history.length,
          separatorBuilder: (_, __) => Divider(height: 1, color: t.border),
          itemBuilder: (_, i) {
            final h = history[i];
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _shortRef(h.taskRef),
                          style: TextStyle(fontFamily: AppFonts.ui, fontSize: 13, color: t.ink),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _formatDate(h.completedAt),
                          style: TextStyle(fontFamily: AppFonts.ui, fontSize: 11, color: t.ink3),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${h.durationMinutes}m',
                    style: TextStyle(fontFamily: AppFonts.mono, fontSize: 13, color: t.ink2),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // SHA-1 hashes are 40 hex chars; UUIDs contain dashes. Show first 8 chars.
  String _shortRef(String ref) => ref.length > 12 ? ref.substring(0, 8) : ref;

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'Today ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    if (diff.inDays == 1) return 'Yesterday';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

Color? _hexToColor(String hex) {
  try {
    final h = hex.replaceFirst('#', '');
    return Color(int.parse('FF$h', radix: 16));
  } catch (_) {
    return null;
  }
}
