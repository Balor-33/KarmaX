import 'package:flutter/material.dart';

class AvatarTheme {
  static const Map<String, Color> statColors = {
    'health': Color(0xFFFF6B4A), // Red-orange
    'knowledge': Color(0xFF5B7FFF), // Blue-purple
    'discipline': Color(0xFFFFD54F), // Gold-yellow
    'social': Color(0xFF4ECDC4), // Teal-green
  };

  static const Map<String, String> statEmojis = {
    'health': '🏃',
    'knowledge': '📚',
    'discipline': '⚡',
    'social': '🧍',
  };

  static const Map<String, String> badgeNames = {
    'first_quest': 'First Step',
    'first_10_quests': 'On a Roll',
    'quest_master': 'Quest Master',
    'legend': 'Living Legend',
    'level_5': 'Rising Star',
    'level_10': 'Seasoned Warrior',
    'level_20': 'Legendary Hero',
  };

  static const Map<String, String> badgeEmojis = {
    'first_quest': '⭐',
    'first_10_quests': '🔥',
    'quest_master': '👑',
    'legend': '🌟',
    'level_5': '🌱',
    'level_10': '⚔️',
    'level_20': '🏆',
  };

  static const List<Map<String, String>> avatarArchetypes = [
    {
      'archetype': 'vegeta',
      'name': 'Vegeta',
      'description':
          'Prince of Saiyans — relentless discipline, driven to be the best.',
      'defaultStat': 'discipline',
      'colorHex': '#3D5AFC',
    },
    {
      'archetype': 'broly',
      'name': 'Broly',
      'description':
          'The Legendary Super Saiyan — raw, unstoppable physical power.',
      'defaultStat': 'health',
      'colorHex': '#43A047',
    },
    {
      'archetype': 'goku',
      'name': 'Goku',
      'description': 'A warrior always hungry to learn the next technique.',
      'defaultStat': 'knowledge',
      'colorHex': '#FF8C1A',
    },
    {
      'archetype': 'roshi',
      'name': 'Master Roshi',
      'description': 'The Turtle Hermit — wise mentor, master of connection.',
      'defaultStat': 'social',
      'colorHex': '#F4B400',
    },
  ];

  static const Map<String, String> avatarModels = {
    'vegeta': 'assets/models/vegeta.glb',
    'broly': 'assets/models/broly.glb',
    'goku': 'assets/models/goku.glb',
    'roshi': 'assets/models/roshi.glb',
  };
}
