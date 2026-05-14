import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/project_controller.dart';
import '../../controllers/timer_controller.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../models/project.dart';
import '../../screens/projects/create_project_screen.dart';
import '../../services/obsidian_service.dart';

/// Modal bottom sheet for picking a project + task before starting a session.
/// Call via [TaskPickerSheet.show].
class TaskPickerSheet extends StatefulWidget {
  const TaskPickerSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const TaskPickerSheet(),
    );
  }

  @override
  State<TaskPickerSheet> createState() => _TaskPickerSheetState();
}

class _TaskPickerSheetState extends State<TaskPickerSheet> {
  Project? _selectedProject;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final projects = context.watch<ProjectController>().projects;

    return Container(
      decoration: BoxDecoration(
        color: t.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppTokens.of(context).border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _selectedProject == null ? 'Select Project' : _selectedProject!.name,
                    style: TextStyle(
                      fontFamily: AppFonts.ui,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: t.ink,
                    ),
                  ),
                ),
                if (_selectedProject != null)
                  GestureDetector(
                    onTap: () => setState(() => _selectedProject = null),
                    child: Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: t.ink3),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Content
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.55,
            ),
            child: _selectedProject == null
                ? _ProjectList(
                    projects: projects,
                    t: t,
                    onSelect: (p) async {
                      await context.read<ProjectController>().selectProject(p);
                      setState(() => _selectedProject = p);
                    },
                  )
                : _TaskList(project: _selectedProject!, t: t),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ── Project list ──────────────────────────────────────────────────────────────

class _ProjectList extends StatelessWidget {
  const _ProjectList({required this.projects, required this.t, required this.onSelect});
  final List<Project> projects;
  final AppTokens t;
  final Future<void> Function(Project) onSelect;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      shrinkWrap: true,
      children: [
        if (projects.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'No projects yet',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: AppFonts.ui, fontSize: 14, color: t.ink3),
            ),
          ),
        ...projects.map((p) => _ProjectRow(project: p, t: t, onTap: () => onSelect(p))),
        const SizedBox(height: 4),
        _NewProjectRow(t: t),
      ],
    );
  }
}

class _ProjectRow extends StatelessWidget {
  const _ProjectRow({required this.project, required this.t, required this.onTap});
  final Project project;
  final AppTokens t;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _hexToColor(project.color) ?? t.pop;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    project.name,
                    style: TextStyle(fontFamily: AppFonts.ui, fontSize: 15, fontWeight: FontWeight.w600, color: t.ink),
                  ),
                  Text(
                    '${project.totalPomodoros} sessions · ${project.completedTasks}/${project.totalTasks} tasks',
                    style: TextStyle(fontFamily: AppFonts.ui, fontSize: 12, color: t.ink3),
                  ),
                ],
              ),
            ),
            if (project.isObsidian)
              Icon(Icons.auto_stories_outlined, size: 14, color: t.ink3),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, size: 16, color: t.ink3),
          ],
        ),
      ),
    );
  }
}

class _NewProjectRow extends StatelessWidget {
  const _NewProjectRow({required this.t});
  final AppTokens t;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.of(context).push<Project>(
          MaterialPageRoute(builder: (_) => const CreateProjectScreen()),
        );
        if (result != null && context.mounted) {
          await context.read<ProjectController>().selectProject(result);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: t.ink3),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'New project',
              style: TextStyle(fontFamily: AppFonts.ui, fontSize: 15, color: t.ink3),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Task list ─────────────────────────────────────────────────────────────────

class _TaskList extends StatelessWidget {
  const _TaskList({required this.project, required this.t});
  final Project project;
  final AppTokens t;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ProjectController>();

    if (project.isObsidian) {
      final tasks = controller.obsidianTasks;
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        shrinkWrap: true,
        children: [
          if (tasks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'No pending tasks in this file',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: AppFonts.ui, fontSize: 14, color: t.ink3),
              ),
            ),
          ...tasks.map(
            (task) => _ObsidianTaskRow(
              task: task,
              t: t,
              onTap: () {
                context.read<ProjectController>().selectObsidianTask(task);
                context.read<TimerController>().setProjectTask(
                      projectId: project.id,
                      taskRef: task.blockRef,
                      taskName: task.title,
                    );
                Navigator.of(context).pop();
              },
            ),
          ),
        ],
      );
    }

    // Native tasks
    final tasks = controller.nativeTasks.where((t) => !t.isCompleted).toList();
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      shrinkWrap: true,
      children: [
        if (tasks.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'No tasks — add some in the project view',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: AppFonts.ui, fontSize: 14, color: t.ink3),
            ),
          ),
        ...tasks.map(
          (task) => _NativeTaskRow(
            task: task,
            t: t,
            onTap: () {
              context.read<ProjectController>().selectNativeTask(task);
              context.read<TimerController>().setProjectTask(
                    projectId: project.id,
                    taskRef: task.id,
                    taskName: task.title,
                  );
              Navigator.of(context).pop();
            },
          ),
        ),
      ],
    );
  }
}

class _NativeTaskRow extends StatelessWidget {
  const _NativeTaskRow({required this.task, required this.t, required this.onTap});
  final ProjectTask task;
  final AppTokens t;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                task.title,
                style: TextStyle(fontFamily: AppFonts.ui, fontSize: 15, color: t.ink),
              ),
            ),
            if (task.expectedPomodoros > 0) ...[
              const SizedBox(width: 8),
              Text(
                '${task.actualPomodoros}/${task.expectedPomodoros}',
                style: TextStyle(fontFamily: AppFonts.mono, fontSize: 12, color: t.ink3),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ObsidianTaskRow extends StatelessWidget {
  const _ObsidianTaskRow({required this.task, required this.t, required this.onTap});
  final ObsidianTask task;
  final AppTokens t;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: TextStyle(fontFamily: AppFonts.ui, fontSize: 15, color: t.ink),
                  ),
                  Text(
                    task.fileName,
                    style: TextStyle(fontFamily: AppFonts.ui, fontSize: 11, color: t.ink3),
                  ),
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
      ),
    );
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
