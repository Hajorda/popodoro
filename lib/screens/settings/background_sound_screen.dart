import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/settings_controller.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../services/bg_music_service.dart';

class BackgroundSoundScreen extends StatelessWidget {
  const BackgroundSoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      appBar: _AppBar(t: t),
      body: Consumer2<SettingsController, BgMusicService>(
        builder: (context, settings, music, _) =>
            _Body(t: t, settings: settings, music: music),
      ),
    );
  }
}

// ── App bar ───────────────────────────────────────────────────────────────────

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
        onTap: () async {
          // Stop preview when leaving the screen.
          await context.read<BgMusicService>().stopPreview();
          if (context.mounted) Navigator.of(context).pop();
        },
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
        'Ambient sounds',
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

// ── Body ──────────────────────────────────────────────────────────────────────

class _Body extends StatelessWidget {
  const _Body({required this.t, required this.settings, required this.music});

  final AppTokens t;
  final SettingsController settings;
  final BgMusicService music;

  @override
  Widget build(BuildContext context) {
    final selectedId = settings.bgSoundId;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      children: [
        // Subtitle
        Text(
          'Plays softly during focus sessions. Pauses on breaks.',
          style: TextStyle(
            fontFamily: AppFonts.ui,
            fontSize: 13,
            color: t.ink3,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 20),

        // "None" option
        _TrackTile(
          t: t,
          emoji: '✕',
          label: 'None',
          subtitle: 'No background music',
          selected: selectedId.isEmpty,
          previewing: false,
          onSelect: () async {
            await music.stopPreview();
            settings.bgSoundId = '';
          },
          onPreview: null,
        ),

        const SizedBox(height: 8),

        // Track tiles
        ...kBgTracks.map((track) {
          final isSelected = selectedId == track.id;
          final isPreviewing = music.isPreviewing && isSelected;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _TrackTile(
              t: t,
              emoji: track.emoji,
              label: track.label,
              subtitle: isSelected ? 'Selected' : null,
              selected: isSelected,
              previewing: isPreviewing,
              onSelect: () async {
                await music.stopPreview();
                settings.bgSoundId = track.id;
              },
              onPreview: () async {
                if (isPreviewing) {
                  await music.stopPreview();
                } else {
                  settings.bgSoundId = track.id;
                  await music.previewTrack(track.id);
                }
              },
            ),
          );
        }),

        const SizedBox(height: 24),

        // Volume slider — only shown when a track is selected
        if (selectedId.isNotEmpty) ...[
          _SectionLabel(t: t, label: 'VOLUME'),
          const SizedBox(height: 12),
          _VolumeSlider(t: t, settings: settings, music: music),
        ],
      ],
    );
  }
}

// ── Track tile ────────────────────────────────────────────────────────────────

class _TrackTile extends StatelessWidget {
  const _TrackTile({
    required this.t,
    required this.emoji,
    required this.label,
    required this.selected,
    required this.previewing,
    required this.onSelect,
    this.subtitle,
    this.onPreview,
  });

  final AppTokens t;
  final String emoji;
  final String label;
  final String? subtitle;
  final bool selected;
  final bool previewing;
  final VoidCallback onSelect;
  final VoidCallback? onPreview;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSelect,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? t.pop.withValues(alpha: 0.12) : t.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? t.pop : t.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // Emoji icon
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: selected ? t.pop.withValues(alpha: 0.18) : t.surface2,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(width: 14),

            // Labels
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: AppFonts.ui,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: t.ink,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontFamily: AppFonts.mono,
                        fontSize: 10,
                        color: selected ? t.pop : t.ink3,
                        letterSpacing: 0.1,
                      ),
                    ),
                ],
              ),
            ),

            // Preview button (only for actual tracks)
            if (onPreview != null)
              GestureDetector(
                onTap: onPreview,
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: previewing
                        ? t.pop.withValues(alpha: 0.2)
                        : t.surface2,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    previewing ? Icons.stop_rounded : Icons.play_arrow_rounded,
                    size: 18,
                    color: previewing ? t.pop : t.ink3,
                  ),
                ),
              ),

            const SizedBox(width: 8),

            // Selection indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? t.pop : Colors.transparent,
                border: Border.all(
                  color: selected ? t.pop : t.border,
                  width: 1.5,
                ),
              ),
              child: selected
                  ? Icon(Icons.check_rounded, size: 12, color: t.ink)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Volume slider ─────────────────────────────────────────────────────────────

class _VolumeSlider extends StatelessWidget {
  const _VolumeSlider({required this.t, required this.settings, required this.music});
  final AppTokens t;
  final SettingsController settings;
  final BgMusicService music;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.volume_down_rounded, size: 16, color: t.ink3),
                  const SizedBox(width: 6),
                  Text(
                    'Volume',
                    style: TextStyle(
                      fontFamily: AppFonts.ui,
                      fontSize: 14,
                      color: t.ink2,
                    ),
                  ),
                ],
              ),
              Text(
                '${(settings.bgVolume * 100).round()}%',
                style: TextStyle(
                  fontFamily: AppFonts.mono,
                  fontSize: 12,
                  color: t.ink3,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              activeTrackColor: t.pop,
              inactiveTrackColor: t.surface2,
              thumbColor: t.ink,
              overlayColor: t.pop.withValues(alpha: 0.15),
            ),
            child: Slider(
              value: settings.bgVolume,
              min: 0,
              max: 1,
              onChanged: (v) {
                settings.bgVolume = v;
                // Update the player volume in real time.
                unawaited(music.setVolume(v));
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.t, required this.label});
  final AppTokens t;
  final String label;

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: TextStyle(
          fontFamily: AppFonts.mono,
          fontSize: 10,
          color: t.ink3,
          letterSpacing: 0.14,
        ),
      );
}
