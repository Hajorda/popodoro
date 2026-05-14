import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/project_controller.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../models/project.dart';
import 'create_project_screen.dart';
import 'project_detail_screen.dart';

class ProjectsScreen extends StatelessWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      appBar: _AppBar(t: t),
      body: Consumer<ProjectController>(
        builder: (context, ctrl, _) => _Body(t: t, ctrl: ctrl),
      ),
    );
  }
}

class _AppBar extends StatelessWidget implements PreferredSizeWidget {
  const _AppBar({required this.t});
  final AppTokens t;

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
        'Projects',
        style: TextStyle(fontFamily: AppFonts.ui, fontSize: 17, fontWeight: FontWeight.w600, color: t.ink),
      ),
      centerTitle: true,
      actions: [
        GestureDetector(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const CreateProjectScreen()),
          ),
          child: Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: t.surface,
                border: Border.all(color: t.border),
              ),
              child: Icon(Icons.add_rounded, size: 16, color: t.ink),
            ),
          ),
        ),
      ],
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.t, required this.ctrl});
  final AppTokens t;
  final ProjectController ctrl;

  @override
  Widget build(BuildContext context) {
    if (ctrl.loading && ctrl.projects.isEmpty) {
      return Center(child: CircularProgressIndicator(color: t.pop, strokeWidth: 2));
    }

    if (ctrl.projects.isEmpty) {
      return _EmptyState(t: t);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: ctrl.projects
          .map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ProjectCard(project: p, t: t),
              ))
          .toList(),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.t});
  final AppTokens t;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.folder_outlined, size: 48, color: t.border),
          const SizedBox(height: 16),
          Text(
            'No projects yet',
            style: TextStyle(fontFamily: AppFonts.ui, fontSize: 16, fontWeight: FontWeight.w600, color: t.ink2),
          ),
          const SizedBox(height: 6),
          Text(
            'Create one to start tracking sessions',
            style: TextStyle(fontFamily: AppFonts.ui, fontSize: 13, color: t.ink3),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const CreateProjectScreen()),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: t.pop,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'New Project',
                style: TextStyle(fontFamily: AppFonts.ui, fontSize: 14, fontWeight: FontWeight.w600, color: t.ink),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.project, required this.t});
  final Project project;
  final AppTokens t;

  @override
  Widget build(BuildContext context) {
    final color = _hexToColor(project.color) ?? t.pop;
    final remaining = project.totalTasks - project.completedTasks;

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => ProjectDetailScreen(project: project)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: t.border),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Color accent strip
            Container(
              width: 4,
              height: 48,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          project.name,
                          style: TextStyle(
                            fontFamily: AppFonts.ui,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: t.ink,
                          ),
                        ),
                      ),
                      if (project.isObsidian)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Icon(Icons.auto_stories_outlined, size: 13, color: t.ink3),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '${project.totalPomodoros} sessions',
                        style: TextStyle(fontFamily: AppFonts.ui, fontSize: 12, color: t.ink3),
                      ),
                      if (project.totalTasks > 0) ...[
                        Text(' · ', style: TextStyle(color: t.ink3, fontSize: 12)),
                        Text(
                          '$remaining task${remaining == 1 ? '' : 's'} left',
                          style: TextStyle(fontFamily: AppFonts.ui, fontSize: 12, color: t.ink3),
                        ),
                      ],
                    ],
                  ),
                  if (project.totalTasks > 0) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: project.totalTasks > 0
                            ? project.completedTasks / project.totalTasks
                            : 0,
                        backgroundColor: t.surface2,
                        color: color,
                        minHeight: 3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, size: 16, color: t.ink3),
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
