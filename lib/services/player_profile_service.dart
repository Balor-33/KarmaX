import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/player_profile.dart';

class PlayerProfileService {
  static const _playerNameKey = 'player_profile.player_name';
  static const _professionKey = 'player_profile.profession';
  static const _scheduleKey = 'player_profile.schedule';
  static const _goalKey = 'player_profile.goal';

  final _db = Supabase.instance.client;
  String? get _uid => _db.auth.currentUser?.id;

  Future<PlayerProfile?> load() async {
    if (_uid != null) {
      try {
        final row = await _db
            .from('player_profiles')
            .select()
            .eq('user_id', _uid!)
            .maybeSingle();

        if (row != null) {
          final profile = PlayerProfile(
            playerName: (row['player_name'] as String?) ?? '',
            profession: (row['profession'] as String?) ?? '',
            schedule: (row['schedule'] as String?) ?? '',
            goal: (row['goal'] as String?) ?? '',
          );
          await _writeLocal(profile);
          return profile.playerName.isEmpty ? null : profile;
        }
      } catch (e) {
        debugPrint('Supabase load failed — falling back to local: $e');
      }
    }

    return _readLocal();
  }

  Future<void> saveIdentity({
    required String playerName,
    required String profession,
    required String schedule,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_playerNameKey, playerName);
    await prefs.setString(_professionKey, profession);
    await prefs.setString(_scheduleKey, schedule);

    if (_uid == null) return;
    try {
      await _db.from('player_profiles').upsert(
        {
          'user_id': _uid,
          'player_name': playerName,
          'profession': profession,
          'schedule': schedule,
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'user_id',
      );
    } catch (e) {
      debugPrint('Supabase sync failed (identity): $e');
    }
  }

  Future<void> saveGoal(String goal) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_goalKey, goal);

    if (_uid == null) return;
    try {
      final updated = await _db
          .from('player_profiles')
          .update({
            'goal': goal,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', _uid!)
          .select()
          .maybeSingle();

      if (updated == null) {
        final local = await _readLocal();
        await _db.from('player_profiles').upsert(
          {
            'user_id': _uid,
            'player_name': local?.playerName ?? '',
            'profession': local?.profession ?? '',
            'schedule': local?.schedule ?? '',
            'goal': goal,
            'updated_at': DateTime.now().toIso8601String(),
          },
          onConflict: 'user_id',
        );
      }
    } catch (e) {
      debugPrint('Supabase sync failed (goal): $e');
    }
  }

  Future<void> saveComplete({
    required String playerName,
    required String profession,
    required String schedule,
    required String goal,
  }) async {
    final profile = PlayerProfile(
      playerName: playerName,
      profession: profession,
      schedule: schedule,
      goal: goal,
    );
    await _writeLocal(profile);

    if (_uid == null) return;
    try {
      await _db.from('player_profiles').upsert(
        {
          'user_id': _uid,
          'player_name': playerName,
          'profession': profession,
          'schedule': schedule,
          'goal': goal,
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'user_id',
      );
      debugPrint('PlayerProfileService: saveComplete success');
    } catch (e) {
      debugPrint('Supabase sync failed (complete): $e');
      rethrow; // Re-throw so callers can show an error if needed
    }
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove(_playerNameKey),
      prefs.remove(_professionKey),
      prefs.remove(_scheduleKey),
      prefs.remove(_goalKey),
    ]);
  }

  Future<PlayerProfile?> _readLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_playerNameKey) ?? '';
    final profession = prefs.getString(_professionKey) ?? '';
    final schedule = prefs.getString(_scheduleKey) ?? '';
    final goal = prefs.getString(_goalKey) ?? '';

    if (name.isEmpty && goal.isEmpty) return null;
    return PlayerProfile(
      playerName: name,
      profession: profession,
      schedule: schedule,
      goal: goal,
    );
  }

  Future<void> _writeLocal(PlayerProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setString(_playerNameKey, profile.playerName),
      prefs.setString(_professionKey, profile.profession),
      prefs.setString(_scheduleKey, profile.schedule),
      prefs.setString(_goalKey, profile.goal),
    ]);
  }
}
