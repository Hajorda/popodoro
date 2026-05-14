import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../services/auth_service.dart';
import '../../services/sync_service.dart';
import '../../widgets/mascot/pop_mascot.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      appBar: _AppBar(t: t),
      body: Consumer<AuthService>(
        builder: (context, auth, _) => auth.isSignedIn
            ? _SignedInBody(t: t)
            : _AuthBody(t: t),
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
        onTap: () => Navigator.of(context).pop(),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Container(
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: t.surface,
                border: Border.all(color: t.border)),
            child: Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: t.ink),
          ),
        ),
      ),
      title: Text('Account',
          style: TextStyle(
              fontFamily: AppFonts.ui,
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: t.ink)),
      centerTitle: true,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Done',
              style: TextStyle(
                  fontFamily: AppFonts.ui,
                  fontSize: 15,
                  color: t.pop,
                  fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

// ── Auth form (not signed in) ─────────────────────────────────────────────────

class _AuthBody extends StatefulWidget {
  const _AuthBody({required this.t});
  final AppTokens t;

  @override
  State<_AuthBody> createState() => _AuthBodyState();
}

class _AuthBodyState extends State<_AuthBody> {
  bool _isLogin = true;
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _awaitingConfirmation = false;

  AppTokens get t => widget.t;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit(AuthService auth) async {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) return;

    final ok = _isLogin
        ? await auth.signIn(email: email, password: password)
        : await auth.signUp(email: email, password: password);

    if (!mounted) return;

    if (ok && auth.isSignedIn) {
      // Signed in immediately (email confirmation disabled).
      Navigator.of(context).pop();
    } else if (ok && !_isLogin) {
      // Sign-up succeeded but email confirmation is required.
      setState(() => _awaitingConfirmation = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    // Email confirmation pending — show waiting screen instead of the form.
    if (_awaitingConfirmation) {
      return _ConfirmationPending(
        t: t,
        email: _email.text.trim(),
        onBack: () => setState(() => _awaitingConfirmation = false),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        const SizedBox(height: 16),

        // Hero
        Container(
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: t.border),
          ),
          child: Column(
            children: [
              PopMascot(
                size: 72,
                mood: PopMood.hi,
                accentColor: t.pop,
                bumpColor: t.bump,
                bumpEdgeColor: t.bumpEdge,
                inkColor: t.ink,
              ),
              const SizedBox(height: 14),
              Text(
                'Sync your sessions.',
                style: TextStyle(
                    fontFamily: AppFonts.display,
                    fontSize: 22,
                    color: t.ink,
                    letterSpacing: -0.3),
              ),
              const SizedBox(height: 6),
              Text(
                'Your data stays on-device. An account\nunlocks backup and Pop Together.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: AppFonts.ui,
                    fontSize: 13,
                    color: t.ink2,
                    height: 1.5),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Mode toggle
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: t.border),
          ),
          child: Row(
            children: [
              _Tab(
                t: t,
                label: 'Sign in',
                active: _isLogin,
                onTap: () => setState(() => _isLogin = true),
              ),
              _Tab(
                t: t,
                label: 'Create account',
                active: !_isLogin,
                onTap: () => setState(() => _isLogin = false),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Error banner
        if (auth.error != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: t.lavender.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: t.lavender.withValues(alpha: 0.4)),
            ),
            child: Text(
              auth.error!,
              style: TextStyle(fontFamily: AppFonts.ui, fontSize: 13, color: t.ink),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Fields
        _Field(
          t: t,
          controller: _email,
          hint: 'Email',
          keyboardType: TextInputType.emailAddress,
          icon: Icons.mail_outline_rounded,
        ),
        const SizedBox(height: 10),
        _Field(
          t: t,
          controller: _password,
          hint: 'Password',
          obscure: _obscure,
          icon: Icons.lock_outline_rounded,
          trailing: GestureDetector(
            onTap: () => setState(() => _obscure = !_obscure),
            child: Icon(
              _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              size: 18,
              color: t.ink3,
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Submit button
        GestureDetector(
          onTap: auth.loading ? null : () => _submit(auth),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 50,
            decoration: BoxDecoration(
              color: auth.loading ? t.ink.withValues(alpha: 0.4) : t.ink,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: auth.loading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: t.bg),
                    )
                  : Text(
                      _isLogin ? 'Sign in' : 'Create account',
                      style: TextStyle(
                          fontFamily: AppFonts.ui,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: t.bg),
                    ),
            ),
          ),
        ),

        // Forgot password
        if (_isLogin) ...[
          const SizedBox(height: 14),
          Center(
            child: GestureDetector(
              onTap: () => _showForgotPassword(context, auth),
              child: Text(
                'Forgot password?',
                style: TextStyle(
                    fontFamily: AppFonts.ui,
                    fontSize: 13,
                    color: t.ink2,
                    decoration: TextDecoration.underline,
                    decorationColor: t.ink2),
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _showForgotPassword(BuildContext context, AuthService auth) {
    final t = widget.t;
    final emailCtrl = TextEditingController(text: _email.text.trim());
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Reset password',
            style: TextStyle(
                fontFamily: AppFonts.ui,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: t.ink)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("We'll send a reset link to your email.",
                style: TextStyle(
                    fontFamily: AppFonts.ui, fontSize: 13, color: t.ink2)),
            const SizedBox(height: 14),
            _Field(t: t, controller: emailCtrl, hint: 'Email',
                keyboardType: TextInputType.emailAddress,
                icon: Icons.mail_outline_rounded),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel',
                style: TextStyle(fontFamily: AppFonts.ui, color: t.ink2)),
          ),
          TextButton(
            onPressed: () async {
              final ok = await auth.sendPasswordReset(email: emailCtrl.text.trim());
              if (ctx.mounted) {
                Navigator.of(ctx).pop();
                if (ok) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Reset link sent.',
                        style: TextStyle(fontFamily: AppFonts.ui)),
                    backgroundColor: t.ink,
                  ));
                }
              }
            },
            child: Text('Send link',
                style: TextStyle(
                    fontFamily: AppFonts.ui,
                    color: t.pop,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ── Confirmation pending ──────────────────────────────────────────────────────

class _ConfirmationPending extends StatelessWidget {
  const _ConfirmationPending({
    required this.t,
    required this.email,
    required this.onBack,
  });
  final AppTokens t;
  final String email;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: t.border),
            ),
            child: Column(
              children: [
                Text('✉', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 16),
                Text(
                  'Check your email',
                  style: TextStyle(
                      fontFamily: AppFonts.display,
                      fontSize: 22,
                      color: t.ink,
                      letterSpacing: -0.3),
                ),
                const SizedBox(height: 8),
                Text(
                  'We sent a confirmation link to',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontFamily: AppFonts.ui, fontSize: 13, color: t.ink2),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontFamily: AppFonts.mono,
                      fontSize: 12,
                      color: t.ink,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 20),
                Text(
                  'Click the link in the email, then come\nback and sign in.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontFamily: AppFonts.ui,
                      fontSize: 13,
                      color: t.ink2,
                      height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: onBack,
            child: Text(
              '← Back to sign in',
              style: TextStyle(
                  fontFamily: AppFonts.ui,
                  fontSize: 13,
                  color: t.ink2,
                  decoration: TextDecoration.underline,
                  decorationColor: t.ink2),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Signed-in view ────────────────────────────────────────────────────────────

class _SignedInBody extends StatefulWidget {
  const _SignedInBody({required this.t});
  final AppTokens t;

  @override
  State<_SignedInBody> createState() => _SignedInBodyState();
}

class _SignedInBodyState extends State<_SignedInBody> {
  AppTokens get t => widget.t;

  @override
  void initState() {
    super.initState();
    // Refresh pending count as soon as the signed-in view appears.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<SyncService>().refreshPendingCount();
    });
  }

  Future<void> _syncNow(BuildContext context, SyncService sync) async {
    final before = sync.pendingCount;
    await sync.requestSync();
    if (!context.mounted) return;

    final String msg;
    final bool isError = sync.lastError != null;
    if (isError) {
      msg = sync.lastError!;
    } else if (before == 0) {
      msg = 'Already up to date';
    } else {
      msg = 'Synced $before session${before == 1 ? '' : 's'}';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg,
            style: TextStyle(fontFamily: AppFonts.ui, color: t.bg)),
        backgroundColor: isError ? t.lavender : t.ink,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final sync = context.watch<SyncService>();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        const SizedBox(height: 16),

        // Account card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: t.border),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: t.pop.withValues(alpha: 0.15),
                  border: Border.all(color: t.pop.withValues(alpha: 0.3)),
                ),
                child: Center(
                  child: Text(
                    (auth.email ?? '?')[0].toUpperCase(),
                    style: TextStyle(
                        fontFamily: AppFonts.display,
                        fontSize: 20,
                        color: t.pop),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(auth.email ?? '',
                        style: TextStyle(
                            fontFamily: AppFonts.ui,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: t.ink)),
                    const SizedBox(height: 2),
                    Text('Signed in',
                        style: TextStyle(
                            fontFamily: AppFonts.mono,
                            fontSize: 10,
                            color: t.ink3,
                            letterSpacing: 0.1)),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 22),
        _SectionLabel(t: t, label: 'Sync'),

        // Sync status card
        Container(
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: t.border),
          ),
          child: Column(
            children: [
              // Status row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sync.isSyncing
                                ? 'Syncing…'
                                : sync.pendingCount > 0
                                    ? '${sync.pendingCount} session${sync.pendingCount == 1 ? '' : 's'} pending'
                                    : 'Up to date',
                            style: TextStyle(
                                fontFamily: AppFonts.ui,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: t.ink),
                          ),
                          if (sync.lastSyncedAt != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Last synced ${_fmtTime(sync.lastSyncedAt!)}',
                              style: TextStyle(
                                  fontFamily: AppFonts.mono,
                                  fontSize: 10,
                                  color: t.ink3,
                                  letterSpacing: 0.05),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (sync.isSyncing)
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: t.pop),
                      )
                    else
                      GestureDetector(
                        onTap: () => _syncNow(context, sync),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: t.pop.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                                color: t.pop.withValues(alpha: 0.3)),
                          ),
                          child: Text('Sync now',
                              style: TextStyle(
                                  fontFamily: AppFonts.mono,
                                  fontSize: 11,
                                  color: t.pop,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ),
                  ],
                ),
              ),

              // Error row
              if (sync.lastError != null) ...[
                Divider(color: t.border, height: 1, indent: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline_rounded, size: 14,
                          color: t.lavender),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(sync.lastError!,
                            style: TextStyle(
                                fontFamily: AppFonts.ui,
                                fontSize: 12,
                                color: t.ink2)),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 22),
        _SectionLabel(t: t, label: 'Danger zone'),

        // Sign out
        GestureDetector(
          onTap: auth.loading ? null : () async {
            final confirmed = await _confirmSignOut(context);
            if (confirmed && context.mounted) {
              await auth.signOut();
              if (context.mounted) Navigator.of(context).pop();
            }
          },
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: t.border),
            ),
            child: Row(
              children: [
                Icon(Icons.logout_rounded, size: 18, color: t.lavender),
                const SizedBox(width: 12),
                Text('Sign out',
                    style: TextStyle(
                        fontFamily: AppFonts.ui,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: t.lavender)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<bool> _confirmSignOut(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Sign out?',
            style: TextStyle(
                fontFamily: AppFonts.ui,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: t.ink)),
        content: Text(
          'Your sessions stay on this device. They will sync again when you sign back in.',
          style: TextStyle(
              fontFamily: AppFonts.ui, fontSize: 13, color: t.ink2, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel',
                style: TextStyle(fontFamily: AppFonts.ui, color: t.ink2)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Sign out',
                style: TextStyle(
                    fontFamily: AppFonts.ui,
                    color: t.lavender,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  String _fmtTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

// ── Shared primitives ─────────────────────────────────────────────────────────

class _Tab extends StatelessWidget {
  const _Tab({required this.t, required this.label, required this.active, required this.onTap});
  final AppTokens t;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 36,
          decoration: BoxDecoration(
            color: active ? t.ink : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: AppFonts.ui,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: active ? t.bg : t.ink2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.t,
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.obscure = false,
    this.trailing,
  });
  final AppTokens t;
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscure;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.border),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          Icon(icon, size: 16, color: t.ink3),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              obscureText: obscure,
              style: TextStyle(
                  fontFamily: AppFonts.ui, fontSize: 14, color: t.ink),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(
                    fontFamily: AppFonts.ui, fontSize: 14, color: t.ink3),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          if (trailing != null) ...[
            trailing!,
            const SizedBox(width: 14),
          ],
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.t, required this.label});
  final AppTokens t;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 4),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
            fontFamily: AppFonts.mono,
            fontSize: 10,
            color: t.ink3,
            letterSpacing: 0.14),
      ),
    );
  }
}
