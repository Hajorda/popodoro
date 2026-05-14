import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/project_controller.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../models/project.dart';
import '../../services/obsidian_service.dart';

// Color palette for projects — uses design system tokens resolved at build time.
List<Color> _projectColors(AppTokens t) => [
      t.pop,
      t.sage,
      t.ember,
      t.lavender,
      t.ink2,
      const Color(0xFF5BA8A0), // teal
    ];

class CreateProjectScreen extends StatefulWidget {
  const CreateProjectScreen({super.key});

  @override
  State<CreateProjectScreen> createState() => _CreateProjectScreenState();
}

class _CreateProjectScreenState extends State<CreateProjectScreen> {
  final _nameController = TextEditingController();
  ProjectType _type = ProjectType.native;
  int _colorIndex = 0;
  List<String> _obsidianFilePaths = [];
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickObsidianFiles() async {
    final obsidian = context.read<ObsidianService>();
    if (!obsidian.isConnected) return;
    final picked = await obsidian.pickFiles();
    if (picked.isNotEmpty) {
      setState(() {
        // Merge without duplicates
        final merged = {..._obsidianFilePaths, ...picked}.toList();
        _obsidianFilePaths = merged;
      });
    }
  }

  void _removeFile(String path) {
    setState(() => _obsidianFilePaths.remove(path));
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Name is required');
      return;
    }
    if (_type == ProjectType.obsidian && _obsidianFilePaths.isEmpty) {
      setState(() => _error = 'Select at least one markdown file');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final t = AppTokens.of(context);
    final colors = _projectColors(t);
    final hex =
        '#${colors[_colorIndex].value.toRadixString(16).padLeft(8, '0').substring(2)}';

    final project = await context.read<ProjectController>().createProject(
          name: name,
          color: hex,
          type: _type,
          obsidianPaths: _obsidianFilePaths,
        );

    if (!mounted) return;
    if (project != null) {
      Navigator.of(context).pop(project);
    } else {
      setState(() {
        _saving = false;
        _error = context.read<ProjectController>().error ?? 'Failed to create';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final obsidian = context.watch<ObsidianService>();

    return Scaffold(
      backgroundColor: t.bg,
      appBar: _AppBar(t: t),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          // Type selector
          _SectionLabel(label: 'TYPE', t: t),
          const SizedBox(height: 8),
          _TypeSelector(
            selected: _type,
            obsidianAvailable: obsidian.isConnected,
            t: t,
            onChanged: (v) => setState(() {
              _type = v;
              _obsidianFilePaths = [];
            }),
          ),
          const SizedBox(height: 20),

          // Name
          _SectionLabel(label: 'NAME', t: t),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: t.border),
            ),
            child: TextField(
              controller: _nameController,
              autofocus: true,
              style: TextStyle(fontFamily: AppFonts.ui, fontSize: 15, color: t.ink),
              decoration: InputDecoration(
                hintText: 'Project name',
                hintStyle: TextStyle(fontFamily: AppFonts.ui, color: t.ink3),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Color
          _SectionLabel(label: 'COLOR', t: t),
          const SizedBox(height: 8),
          _ColorPicker(
            colors: _projectColors(t),
            selected: _colorIndex,
            t: t,
            onChanged: (i) => setState(() => _colorIndex = i),
          ),

          // Obsidian files
          if (_type == ProjectType.obsidian) ...[
            const SizedBox(height: 20),
            _SectionLabel(label: 'MARKDOWN FILES', t: t),
            const SizedBox(height: 8),
            _FilePickerList(
              paths: _obsidianFilePaths,
              t: t,
              onAdd: _pickObsidianFiles,
              onRemove: _removeFile,
            ),
          ],

          // Error
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(fontFamily: AppFonts.ui, fontSize: 13, color: t.ember),
              textAlign: TextAlign.center,
            ),
          ],

          const SizedBox(height: 28),
          _SaveButton(saving: _saving, t: t, onTap: _save),
        ],
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
            child: Icon(Icons.close_rounded, size: 14, color: t.ink),
          ),
        ),
      ),
      title: Text(
        'New Project',
        style: TextStyle(fontFamily: AppFonts.ui, fontSize: 17, fontWeight: FontWeight.w600, color: t.ink),
      ),
      centerTitle: true,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.t});
  final String label;
  final AppTokens t;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontFamily: AppFonts.ui,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
        color: t.ink3,
      ),
    );
  }
}

class _TypeSelector extends StatelessWidget {
  const _TypeSelector({
    required this.selected,
    required this.obsidianAvailable,
    required this.t,
    required this.onChanged,
  });

  final ProjectType selected;
  final bool obsidianAvailable;
  final AppTokens t;
  final ValueChanged<ProjectType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _TypeChip(
          label: 'Native',
          icon: Icons.layers_outlined,
          active: selected == ProjectType.native,
          t: t,
          onTap: () => onChanged(ProjectType.native),
        ),
        const SizedBox(width: 10),
        _TypeChip(
          label: 'Obsidian',
          icon: Icons.auto_stories_outlined,
          active: selected == ProjectType.obsidian,
          enabled: obsidianAvailable,
          t: t,
          onTap: obsidianAvailable ? () => onChanged(ProjectType.obsidian) : null,
        ),
      ],
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.icon,
    required this.active,
    required this.t,
    this.enabled = true,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final bool active;
  final bool enabled;
  final AppTokens t;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bg = active ? t.pop : t.surface;
    final fg = active ? t.ink : (enabled ? t.ink2 : t.ink3);
    final border = active ? t.pop : t.border;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontFamily: AppFonts.ui,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorPicker extends StatelessWidget {
  const _ColorPicker({
    required this.colors,
    required this.selected,
    required this.t,
    required this.onChanged,
  });

  final List<Color> colors;
  final int selected;
  final AppTokens t;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(colors.length, (i) {
        final active = i == selected;
        return Padding(
          padding: EdgeInsets.only(right: i < colors.length - 1 ? 10 : 0),
          child: GestureDetector(
            onTap: () => onChanged(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: colors[i],
                shape: BoxShape.circle,
                border: active
                    ? Border.all(color: t.ink, width: 2.5)
                    : Border.all(color: Colors.transparent, width: 2.5),
                boxShadow: active
                    ? [BoxShadow(color: colors[i].withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 2))]
                    : null,
              ),
              child: active
                  ? Icon(Icons.check_rounded, size: 14, color: t.ink)
                  : null,
            ),
          ),
        );
      }),
    );
  }
}

class _FilePickerList extends StatelessWidget {
  const _FilePickerList({
    required this.paths,
    required this.t,
    required this.onAdd,
    required this.onRemove,
  });
  final List<String> paths;
  final AppTokens t;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ...paths.map((p) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: t.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: t.border),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Icon(Icons.description_outlined, size: 15, color: t.ink3),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        p.split('/').last,
                        style: TextStyle(fontFamily: AppFonts.ui, fontSize: 13, color: t.ink),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => onRemove(p),
                      child: Icon(Icons.close_rounded, size: 15, color: t.ink3),
                    ),
                  ],
                ),
              ),
            )),
        GestureDetector(
          onTap: onAdd,
          child: Container(
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: t.border),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.add_rounded, size: 16, color: t.ink3),
                const SizedBox(width: 10),
                Text(
                  paths.isEmpty ? 'Choose markdown files' : 'Add more files',
                  style: TextStyle(fontFamily: AppFonts.ui, fontSize: 14, color: t.ink3),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.saving, required this.t, required this.onTap});
  final bool saving;
  final AppTokens t;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: saving ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: saving ? t.border : t.ink,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: saving
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: t.bg),
                )
              : Text(
                  'Create Project',
                  style: TextStyle(
                    fontFamily: AppFonts.ui,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: t.bg,
                  ),
                ),
        ),
      ),
    );
  }
}
