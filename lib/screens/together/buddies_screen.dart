import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../services/auth_service.dart';
import '../../services/together_service.dart';
import '../../widgets/mascot/pop_mascot.dart';
import '../../widgets/together/buddy_avatar.dart';
import '../settings/account_screen.dart';
import 'create_room_screen.dart';
import 'lobby_screen.dart';

class BuddiesScreen extends StatefulWidget {
  const BuddiesScreen({super.key});

  @override
  State<BuddiesScreen> createState() => _BuddiesScreenState();
}

class _BuddiesScreenState extends State<BuddiesScreen> {
  final _codeController = TextEditingController();
  bool _joining = false;
  String? _joinError;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _joinRoom() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    setState(() {
      _joining = true;
      _joinError = null;
    });

    final together = context.read<TogetherService>();
    final ok = await together.joinRoom(code);

    if (!mounted) return;
    setState(() => _joining = false);

    if (ok) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const LobbyScreen()),
      );
      _codeController.clear();
    } else {
      setState(() => _joinError = together.error ?? 'Could not join room');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final auth = context.watch<AuthService>();

    if (!auth.isSignedIn) {
      return _AuthGate(t: t);
    }

    return Scaffold(
      backgroundColor: t.bg,
      appBar: _TogetherAppBar(t: t),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const SizedBox(height: 16),
          _HeroCard(t: t),
          const SizedBox(height: 24),
          _CreateCard(t: t),
          const SizedBox(height: 12),
          _JoinCard(
            t: t,
            controller: _codeController,
            joining: _joining,
            error: _joinError,
            onJoin: _joinRoom,
          ),
          const SizedBox(height: 32),
          Center(
            child: Text(
              'share your 6-letter code to invite friends',
              style: TextStyle(
                fontFamily: AppFonts.mono,
                fontSize: 10,
                color: t.ink3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Auth gate ─────────────────────────────────────────────────────────────────

class _AuthGate extends StatelessWidget {
  const _AuthGate({required this.t});
  final AppTokens t;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: t.bg,
      appBar: _TogetherAppBar(t: t),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            PopMascot(
              size: 80,
              mood: PopMood.hi,
              accentColor: t.pop,
              bumpColor: t.bump,
              bumpEdgeColor: t.bumpEdge,
              inkColor: t.ink,
            ),
            const SizedBox(height: 20),
            Text(
              'pop one together.',
              style: TextStyle(
                fontFamily: AppFonts.display,
                fontSize: 28,
                color: t.ink,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'sign in to focus with friends in real-time',
              style: TextStyle(
                fontFamily: AppFonts.ui,
                fontSize: 14,
                color: t.ink2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const AccountScreen()),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: t.pop,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    'Sign in',
                    style: TextStyle(
                      fontFamily: AppFonts.ui,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: t.ink,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── App bar ───────────────────────────────────────────────────────────────────

class _TogetherAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _TogetherAppBar({required this.t});
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
            child: Icon(Icons.arrow_back_ios_new_rounded,
                size: 14, color: t.ink),
          ),
        ),
      ),
      title: Text(
        'Pop Together',
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

// ── Hero card ─────────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.t});
  final AppTokens t;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        color: t.dim,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              BuddyAvatar(
                t: t,
                size: 56,
                ringColor: t.ember,
                statusColor: t.ember,
                mood: PopMood.celebrating,
              ),
              Positioned(
                right: -4,
                bottom: 8,
                child: BuddyAvatar(
                  t: t,
                  size: 44,
                  ringColor: t.sage,
                  statusColor: t.sage,
                  mood: PopMood.working,
                ),
              ),
            ],
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'focus together.',
                  style: TextStyle(
                    fontFamily: AppFonts.display,
                    fontSize: 22,
                    color: t.ink,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'share a room code and pop side-by-side',
                  style: TextStyle(
                    fontFamily: AppFonts.ui,
                    fontSize: 12,
                    color: t.ink2,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Create card ───────────────────────────────────────────────────────────────

class _CreateCard extends StatelessWidget {
  const _CreateCard({required this.t});
  final AppTokens t;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const CreateRoomScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        decoration: BoxDecoration(
          color: t.pop,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: t.ink.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.add_rounded, size: 20, color: t.ink),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Create a room',
                    style: TextStyle(
                      fontFamily: AppFonts.ui,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: t.ink,
                    ),
                  ),
                  Text(
                    'get a code to share with friends',
                    style: TextStyle(
                      fontFamily: AppFonts.ui,
                      fontSize: 12,
                      color: t.ink.withValues(alpha: 0.60),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 20, color: t.ink.withValues(alpha: 0.50)),
          ],
        ),
      ),
    );
  }
}

// ── Join card ─────────────────────────────────────────────────────────────────

class _JoinCard extends StatelessWidget {
  const _JoinCard({
    required this.t,
    required this.controller,
    required this.joining,
    required this.error,
    required this.onJoin,
  });

  final AppTokens t;
  final TextEditingController controller;
  final bool joining;
  final String? error;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'JOIN A ROOM',
            style: TextStyle(
              fontFamily: AppFonts.mono,
              fontSize: 10,
              color: t.ink3,
              letterSpacing: 0.14,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  style: TextStyle(
                    fontFamily: AppFonts.mono,
                    fontSize: 18,
                    color: t.ink,
                    letterSpacing: 2,
                  ),
                  decoration: InputDecoration(
                    hintText: 'abc123',
                    hintStyle: TextStyle(
                      fontFamily: AppFonts.mono,
                      fontSize: 18,
                      color: t.ink3,
                      letterSpacing: 2,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                    LengthLimitingTextInputFormatter(6),
                  ],
                  textCapitalization: TextCapitalization.none,
                  onSubmitted: (_) => onJoin(),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: joining ? null : onJoin,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: joining ? t.surface2 : t.ink,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: joining
                      ? SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: t.ink3,
                          ),
                        )
                      : Text(
                          'Join',
                          style: TextStyle(
                            fontFamily: AppFonts.ui,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: t.bg,
                          ),
                        ),
                ),
              ),
            ],
          ),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(
              error!,
              style: TextStyle(
                fontFamily: AppFonts.ui,
                fontSize: 12,
                color: t.ember,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
