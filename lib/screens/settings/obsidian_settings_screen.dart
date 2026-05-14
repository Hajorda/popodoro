import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../services/obsidian_service.dart';

class ObsidianSettingsScreen extends StatelessWidget {
  const ObsidianSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      appBar: _AppBar(t: t),
      body: Consumer<ObsidianService>(
        builder: (context, obsidian, _) =>
            _Body(t: t, obsidian: obsidian),
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
        'Obsidian',
        style: TextStyle(
          fontFamily: AppFonts.ui,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: t.ink,
        ),
      ),
      centerTitle: true,
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.t, required this.obsidian});
  final AppTokens t;
  final ObsidianService obsidian;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        _SectionHeader(label: 'VAULT', t: t),
        const SizedBox(height: 8),
        if (!obsidian.isConnected) _ConnectCard(t: t, obsidian: obsidian),
        if (obsidian.isConnected) _ConnectedCard(t: t, obsidian: obsidian),
        if (obsidian.isConnected) ...[
          const SizedBox(height: 24),
          _SectionHeader(label: 'TASK FORMAT', t: t),
          const SizedBox(height: 8),
          _FormatCard(t: t),
        ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.t});
  final String label;
  final AppTokens t;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: AppFonts.ui,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          color: t.ink3,
        ),
      ),
    );
  }
}

class _ConnectCard extends StatelessWidget {
  const _ConnectCard({required this.t, required this.obsidian});
  final AppTokens t;
  final ObsidianService obsidian;

  Future<void> _pickVault(BuildContext context) async {
    final dir = await getDirectoryPath(
      confirmButtonText: 'Select Vault',
    );
    if (dir != null && context.mounted) {
      await context.read<ObsidianService>().connectVault(dir);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.border),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: t.surface2,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.folder_outlined, size: 18, color: t.ink2),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'No vault connected',
                  style: TextStyle(
                    fontFamily: AppFonts.ui,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: t.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Connect your Obsidian vault to import tasks. Popodoro reads your markdown files and tracks sessions against them.',
            style: TextStyle(
              fontFamily: AppFonts.ui,
              fontSize: 13,
              color: t.ink3,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => _pickVault(context),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: t.pop,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  'Choose Vault Folder',
                  style: TextStyle(
                    fontFamily: AppFonts.ui,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: t.ink,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectedCard extends StatefulWidget {
  const _ConnectedCard({required this.t, required this.obsidian});
  final AppTokens t;
  final ObsidianService obsidian;

  @override
  State<_ConnectedCard> createState() => _ConnectedCardState();
}

class _ConnectedCardState extends State<_ConnectedCard> {
  bool _refreshing = false;

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    await widget.obsidian.refresh();
    if (mounted) setState(() => _refreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final path = widget.obsidian.vaultPath ?? '';
    final folderName = path.split('/').last;
    final taskCount = widget.obsidian.pendingTasks.length;

    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: t.sage.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.folder_rounded, size: 18, color: t.sage),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        folderName,
                        style: TextStyle(
                          fontFamily: AppFonts.ui,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: t.ink,
                        ),
                      ),
                      Text(
                        '$taskCount pending task${taskCount == 1 ? '' : 's'}',
                        style: TextStyle(
                          fontFamily: AppFonts.ui,
                          fontSize: 12,
                          color: t.ink3,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: _refreshing ? null : _refresh,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _refreshing
                        ? SizedBox(
                            key: const ValueKey('spin'),
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: t.sage,
                            ),
                          )
                        : Icon(
                            key: const ValueKey('icon'),
                            Icons.refresh_rounded,
                            size: 18,
                            color: t.ink3,
                          ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: t.border),
          _ActionRow(
            icon: Icons.link_off_rounded,
            label: 'Disconnect vault',
            color: t.ember,
            onTap: () => _confirmDisconnect(context),
          ),
        ],
      ),
    );
  }

  void _confirmDisconnect(BuildContext context) {
    final t = AppTokens.of(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Disconnect vault?',
          style: TextStyle(fontFamily: AppFonts.ui, fontWeight: FontWeight.w600, color: t.ink),
        ),
        content: Text(
          'Your sessions and project stats are kept. Only the vault connection is removed.',
          style: TextStyle(fontFamily: AppFonts.ui, fontSize: 13, color: t.ink2),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: t.ink2, fontFamily: AppFonts.ui)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<ObsidianService>().disconnectVault();
            },
            child: Text('Disconnect', style: TextStyle(color: t.ember, fontFamily: AppFonts.ui, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontFamily: AppFonts.ui,
                fontSize: 14,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FormatCard extends StatelessWidget {
  const _FormatCard({required this.t});
  final AppTokens t;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add the inline field to any task to track sessions:',
            style: TextStyle(fontFamily: AppFonts.ui, fontSize: 13, color: t.ink2, height: 1.5),
          ),
          const SizedBox(height: 12),
          _CodeLine(text: '- [ ] Design new feature [popcorn:: 0/5]', t: t),
          const SizedBox(height: 6),
          _CodeLine(text: '- [ ] Fix bug [popcorn:: 3]', t: t),
          const SizedBox(height: 12),
          Text(
            'Format: [popcorn:: done] or [popcorn:: done/goal]. Popodoro increments "done" after each session.',
            style: TextStyle(fontFamily: AppFonts.ui, fontSize: 12, color: t.ink3, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _CodeLine extends StatelessWidget {
  const _CodeLine({required this.text, required this.t});
  final String text;
  final AppTokens t;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: t.surface2,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: AppFonts.mono,
          fontSize: 12,
          color: t.ink,
        ),
      ),
    );
  }
}
