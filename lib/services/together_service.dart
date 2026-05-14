import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TogetherRoom {
  const TogetherRoom({
    required this.id,
    required this.code,
    required this.hostId,
    this.taskName,
    required this.durationMinutes,
    required this.status,
    this.startedAt,
    this.breakMinutes = 5,
    this.breakStartedAt,
    this.elapsedSeconds = 0,
  });

  final String id;
  final String code;
  final String hostId;
  final String? taskName;
  final int durationMinutes;
  final String status; // lobby | active | paused | break | complete
  final DateTime? startedAt;
  final int breakMinutes;
  final DateTime? breakStartedAt;
  final int elapsedSeconds;

  bool get isLobby => status == 'lobby';
  bool get isFocusing => status == 'active';
  bool get isPaused => status == 'paused';
  bool get isOnBreak => status == 'break';
  bool get isComplete => status == 'complete';

  factory TogetherRoom.fromMap(Map<String, dynamic> m) => TogetherRoom(
        id: m['id'] as String,
        code: m['code'] as String,
        hostId: m['host_id'] as String,
        taskName: m['task_name'] as String?,
        durationMinutes: m['duration_minutes'] as int,
        status: m['status'] as String,
        startedAt: m['started_at'] != null
            ? DateTime.parse(m['started_at'] as String).toLocal()
            : null,
        breakMinutes: (m['break_minutes'] as int?) ?? 5,
        breakStartedAt: m['break_started_at'] != null
            ? DateTime.parse(m['break_started_at'] as String).toLocal()
            : null,
        elapsedSeconds: (m['elapsed_seconds'] as int?) ?? 0,
      );

  TogetherRoom copyWith({String? status, DateTime? startedAt, DateTime? breakStartedAt, int? elapsedSeconds}) =>
      TogetherRoom(
        id: id,
        code: code,
        hostId: hostId,
        taskName: taskName,
        durationMinutes: durationMinutes,
        status: status ?? this.status,
        startedAt: startedAt ?? this.startedAt,
        breakMinutes: breakMinutes,
        breakStartedAt: breakStartedAt ?? this.breakStartedAt,
        elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      );

  Duration get remaining {
    if (startedAt == null) return Duration(minutes: durationMinutes);
    if (isPaused) {
      final left = Duration(minutes: durationMinutes) - Duration(seconds: elapsedSeconds);
      return left.isNegative ? Duration.zero : left;
    }
    final elapsed = DateTime.now().difference(startedAt!);
    final total = Duration(minutes: durationMinutes);
    final left = total - elapsed;
    return left.isNegative ? Duration.zero : left;
  }

  double get progress {
    if (startedAt == null) return 0;
    if (isPaused) return (elapsedSeconds / (durationMinutes * 60)).clamp(0.0, 1.0);
    final elapsed = DateTime.now().difference(startedAt!).inSeconds;
    final total = durationMinutes * 60;
    return (elapsed / total).clamp(0.0, 1.0);
  }

  Duration get breakRemaining {
    if (breakStartedAt == null) return Duration(minutes: breakMinutes);
    final elapsed = DateTime.now().difference(breakStartedAt!);
    final total = Duration(minutes: breakMinutes);
    final left = total - elapsed;
    return left.isNegative ? Duration.zero : left;
  }

  double get breakProgress {
    if (breakStartedAt == null) return 0;
    final elapsed = DateTime.now().difference(breakStartedAt!).inSeconds;
    final total = breakMinutes * 60;
    return (elapsed / total).clamp(0.0, 1.0);
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String get timeDisplay => isFocusing || isLobby || isPaused
      ? _fmt(remaining)
      : isOnBreak
          ? _fmt(breakRemaining)
          : '00:00';

  double get currentProgress => isFocusing || isPaused ? progress : isOnBreak ? breakProgress : 1.0;
}

class TogetherParticipant {
  const TogetherParticipant({
    required this.userId,
    required this.displayName,
    required this.status,
  });

  final String userId;
  final String displayName;
  final String status; // joining | ready | focusing | done

  factory TogetherParticipant.fromMap(Map<String, dynamic> m) =>
      TogetherParticipant(
        userId: m['user_id'] as String,
        displayName: (m['display_name'] as String?)?.isNotEmpty == true
            ? m['display_name'] as String
            : 'anon',
        status: m['status'] as String,
      );

  bool get isReady => status == 'ready';
  bool get isFocusing => status == 'focusing';
  bool get isDone => status == 'done';
}

class TogetherReaction {
  const TogetherReaction({
    required this.emoji,
    required this.fromUserId,
    required this.fromDisplayName,
    required this.toUserId,
    required this.createdAt,
  });

  final String emoji;
  final String fromUserId;
  final String fromDisplayName;
  final String toUserId;
  final DateTime createdAt;

  factory TogetherReaction.fromMap(Map<String, dynamic> m) => TogetherReaction(
        emoji: m['emoji'] as String,
        fromUserId: m['from_user_id'] as String,
        fromDisplayName: (m['from_display_name'] as String?)?.isNotEmpty == true
            ? m['from_display_name'] as String
            : 'anon',
        toUserId: m['to_user_id'] as String,
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}

class TogetherService extends ChangeNotifier {
  SupabaseClient get _client => Supabase.instance.client;

  TogetherRoom? _room;
  List<TogetherParticipant> _participants = [];
  List<TogetherReaction> _recentReactions = [];
  RealtimeChannel? _channel;
  Timer? _ticker;

  bool _loading = false;
  String? _error;

  // ── Getters ───────────────────────────────────────────────────────────────────

  TogetherRoom? get room => _room;
  List<TogetherParticipant> get participants => _participants;
  List<TogetherReaction> get recentReactions => _recentReactions;
  bool get loading => _loading;
  String? get error => _error;
  bool get isInRoom => _room != null;
  bool get isHost => _room?.hostId == _client.auth.currentUser?.id;
  String? get myUserId => _client.auth.currentUser?.id;
  bool get isSignedIn => _client.auth.currentUser != null;

  String get myDisplayName {
    final email = _client.auth.currentUser?.email ?? '';
    return email.split('@').first;
  }

  TogetherParticipant? get myParticipant =>
      _participants.where((p) => p.userId == myUserId).firstOrNull;

  bool get allReady =>
      _participants.isNotEmpty &&
      _participants.every((p) => p.isReady || p.isFocusing || p.isDone);

  // ── Public API ────────────────────────────────────────────────────────────────

  Future<bool> createRoom({
    String? taskName,
    int durationMinutes = 25,
    int breakMinutes = 5,
  }) =>
      _run(() async {
        final userId = _client.auth.currentUser!.id;
        final code = _generateCode();

        final roomData = await _client.from('rooms').insert({
          'host_id': userId,
          'code': code,
          if (taskName != null && taskName.isNotEmpty) 'task_name': taskName,
          'duration_minutes': durationMinutes,
          'break_minutes': breakMinutes,
          'status': 'lobby',
        }).select().single();

        _room = TogetherRoom.fromMap(roomData);

        await _client.from('room_participants').insert({
          'room_id': _room!.id,
          'user_id': userId,
          'display_name': myDisplayName,
          'status': 'ready',
        });

        await _refreshParticipants();
        _subscribeToRoom(_room!.id);
      });

  Future<bool> joinRoom(String code) => _run(() async {
        final roomData = await _client
            .from('rooms')
            .select()
            .eq('code', code.toLowerCase().trim())
            .neq('status', 'complete')
            .maybeSingle();

        if (roomData == null) throw Exception('Room not found or already ended');

        _room = TogetherRoom.fromMap(roomData);

        await _client.from('room_participants').upsert({
          'room_id': _room!.id,
          'user_id': _client.auth.currentUser!.id,
          'display_name': myDisplayName,
          'status': 'joining',
        }, onConflict: 'room_id,user_id');

        await _refreshParticipants();
        _subscribeToRoom(_room!.id);
      });

  Future<void> setReady() async {
    if (_room == null || myUserId == null) return;
    await _client
        .from('room_participants')
        .update({'status': 'ready'})
        .eq('room_id', _room!.id)
        .eq('user_id', myUserId!);
  }

  Future<void> startRoom() async {
    if (_room == null || !isHost) return;
    final now = DateTime.now().toUtc().toIso8601String();
    await _client
        .from('rooms')
        .update({'status': 'active', 'started_at': now})
        .eq('id', _room!.id);
    await _client
        .from('room_participants')
        .update({'status': 'focusing'})
        .eq('room_id', _room!.id);
    // Realtime will echo the change, but start ticking immediately so the host
    // sees the timer decrement without waiting for the round-trip.
    _updateTicker();
  }

  /// Host → transitions room from active → break.
  Future<void> startBreak() async {
    if (_room == null || !isHost) return;
    final now = DateTime.now().toUtc().toIso8601String();
    await _client
        .from('rooms')
        .update({'status': 'break', 'break_started_at': now})
        .eq('id', _room!.id);
  }

  /// Host → pauses the focus timer.
  Future<void> pauseSession() async {
    if (_room == null || !isHost || !_room!.isFocusing) return;
    final elapsed = DateTime.now().difference(_room!.startedAt!).inSeconds;
    await _client.from('rooms').update({
      'status': 'paused',
      'elapsed_seconds': elapsed,
    }).eq('id', _room!.id);
  }

  /// Host → resumes a paused session.
  Future<void> resumeSession() async {
    if (_room == null || !isHost || !_room!.isPaused) return;
    final newStartedAt = DateTime.now()
        .subtract(Duration(seconds: _room!.elapsedSeconds))
        .toUtc()
        .toIso8601String();
    await _client.from('rooms').update({
      'status': 'active',
      'started_at': newStartedAt,
      'elapsed_seconds': 0,
    }).eq('id', _room!.id);
    _updateTicker();
  }

  /// Host → resets the room to lobby so everyone can go again.
  Future<void> resetRoom() async {
    if (_room == null || !isHost) return;
    await _client.from('rooms').update({
      'status': 'lobby',
      'started_at': null,
      'break_started_at': null,
      'elapsed_seconds': 0,
    }).eq('id', _room!.id);
    await _client
        .from('room_participants')
        .update({'status': 'ready'})
        .eq('room_id', _room!.id);
  }

  /// Host → adds [minutes] to the focus duration (live extension).
  Future<void> addMinutes(int minutes) async {
    if (_room == null || !isHost) return;
    final newDuration = _room!.durationMinutes + minutes;
    await _client
        .from('rooms')
        .update({'duration_minutes': newDuration})
        .eq('id', _room!.id);
  }

  /// Host → marks the session as complete.
  Future<void> endSession() async {
    if (_room == null || !isHost) return;
    await _client
        .from('rooms')
        .update({'status': 'complete'})
        .eq('id', _room!.id);
  }

  Future<void> sendReaction(String emoji, String toUserId) async {
    if (_room == null || myUserId == null) return;
    try {
      await _client.from('reactions').insert({
        'room_id': _room!.id,
        'from_user_id': myUserId!,
        'from_display_name': myDisplayName,
        'to_user_id': toUserId,
        'emoji': emoji,
      });
    } catch (e) {
      debugPrint('[TogetherService] reaction error: $e');
    }
  }

  Future<void> leaveRoom() async {
    _ticker?.cancel();
    _ticker = null;
    _unsubscribe();
    if (_room != null && myUserId != null) {
      try {
        await _client
            .from('room_participants')
            .delete()
            .eq('room_id', _room!.id)
            .eq('user_id', myUserId!);
      } catch (_) {}
    }
    _room = null;
    _participants = [];
    _recentReactions = [];
    _error = null;
    notifyListeners();
  }

  // ── Internal ──────────────────────────────────────────────────────────────────

  Future<void> _refreshParticipants() async {
    if (_room == null) return;
    final rows = await _client
        .from('room_participants')
        .select()
        .eq('room_id', _room!.id);
    _participants = (rows as List)
        .map((r) => TogetherParticipant.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  void _subscribeToRoom(String roomId) {
    _unsubscribe();
    _channel = _client
        .channel('together:$roomId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'rooms',
          filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq, column: 'id', value: roomId),
          callback: _onRoomChange,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'room_participants',
          filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'room_id',
              value: roomId),
          callback: _onParticipantChange,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'reactions',
          filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'room_id',
              value: roomId),
          callback: _onReaction,
        )
        .subscribe();
  }

  void _onRoomChange(PostgresChangePayload payload) {
    final data = payload.newRecord;
    if (data.isNotEmpty && _room != null) {
      _room = TogetherRoom.fromMap(data);
      _updateTicker();
      notifyListeners();
    }
  }

  void _onParticipantChange(PostgresChangePayload payload) {
    _refreshParticipants().then((_) => notifyListeners());
  }

  void _onReaction(PostgresChangePayload payload) {
    final data = payload.newRecord;
    if (data.isNotEmpty) {
      final reaction = TogetherReaction.fromMap(data);
      _recentReactions = [reaction, ..._recentReactions.take(9)];
      notifyListeners();
    }
  }

  void _updateTicker() {
    final needsTick = _room != null && (_room!.isFocusing || _room!.isOnBreak) && !_room!.isPaused;
    if (needsTick && _ticker == null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) => notifyListeners());
    } else if (!needsTick) {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  void _unsubscribe() {
    if (_channel != null) {
      _client.removeChannel(_channel!);
      _channel = null;
    }
  }

  Future<bool> _run(Future<void> Function() action) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await action();
      _loading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _loading = false;
      debugPrint('[TogetherService] error: $e');
      notifyListeners();
      return false;
    }
  }

  static String _generateCode() {
    const chars = 'abcdefghjkmnpqrstuvwxyz23456789';
    final random = Random.secure();
    return List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _unsubscribe();
    super.dispose();
  }
}
