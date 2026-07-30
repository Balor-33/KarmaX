import 'package:flutter/material.dart';

class AvatarComposition {
  final String hairStyle; // ponytail, spiky, wavy, curly, long, short
  final String bodyType; // slim, athletic, muscular
  final int armorLevel; // 0-5, determines equipment tier
  final String skinTone; // 0-9 hex color offset

  AvatarComposition({
    required this.hairStyle,
    required this.bodyType,
    required this.armorLevel,
    required this.skinTone,
  });

  factory AvatarComposition.standard() {
    return AvatarComposition(
      hairStyle: 'short',
      bodyType: 'athletic',
      armorLevel: 0,
      skinTone: 'warm',
    );
  }

  factory AvatarComposition.forArchetype({
    required String archetype,
    required int level,
  }) {
    final normalized = archetype.toLowerCase();
    final armorLevel = level.clamp(1, 999);

    switch (normalized) {
      case 'knight':
        return AvatarComposition(
          hairStyle: 'short',
          bodyType: 'muscular',
          armorLevel: armorLevel,
          skinTone: 'warm',
        );
      case 'sage':
        return AvatarComposition(
          hairStyle: 'long',
          bodyType: 'slim',
          armorLevel: armorLevel,
          skinTone: 'fair',
        );
      case 'rogue':
        return AvatarComposition(
          hairStyle: 'spiky',
          bodyType: 'slim',
          armorLevel: armorLevel,
          skinTone: 'tan',
        );
      case 'guardian':
        return AvatarComposition(
          hairStyle: 'braided',
          bodyType: 'muscular',
          armorLevel: armorLevel,
          skinTone: 'dark',
        );
      case 'mage':
        return AvatarComposition(
          hairStyle: 'wavy',
          bodyType: 'slim',
          armorLevel: armorLevel,
          skinTone: 'cool',
        );
      case 'druid':
        return AvatarComposition(
          hairStyle: 'curly',
          bodyType: 'athletic',
          armorLevel: armorLevel,
          skinTone: 'tan',
        );
      default:
        return AvatarComposition(
          hairStyle: 'short',
          bodyType: 'athletic',
          armorLevel: armorLevel,
          skinTone: 'warm',
        );
    }
  }

  AvatarComposition copyWith({
    String? hairStyle,
    String? bodyType,
    int? armorLevel,
    String? skinTone,
  }) {
    return AvatarComposition(
      hairStyle: hairStyle ?? this.hairStyle,
      bodyType: bodyType ?? this.bodyType,
      armorLevel: armorLevel ?? this.armorLevel,
      skinTone: skinTone ?? this.skinTone,
    );
  }
}

enum AvatarAnimationState {
  idle,       // Breathing/bobbing
  levelUp,    // Jump and celebration
  acting,     // Action during quest
  resting,    // Calm state
}

class EquipmentTier {
  final int level; // Unlocks at this level
  final String name;
  final String description;
  final String chest; // Armor piece name
  final String legs; // Pants/skirt
  final String accessory; // Optional accessory

  EquipmentTier({
    required this.level,
    required this.name,
    required this.description,
    required this.chest,
    required this.legs,
    required this.accessory,
  });
}

final List<EquipmentTier> equipmentTiers = [
  EquipmentTier(
    level: 1,
    name: 'Novice',
    description: 'Starting outfit',
    chest: 'tunic',
    legs: 'pants',
    accessory: 'none',
  ),
  EquipmentTier(
    level: 5,
    name: 'Squire',
    description: 'Light armor apprentice',
    chest: 'leather_chest',
    legs: 'leather_pants',
    accessory: 'belt',
  ),
  EquipmentTier(
    level: 10,
    name: 'Warrior',
    description: 'Tested in battle',
    chest: 'chain_mail',
    legs: 'chain_legs',
    accessory: 'sword',
  ),
  EquipmentTier(
    level: 15,
    name: 'Knight',
    description: 'Noble armor',
    chest: 'plate_armor',
    legs: 'plate_legs',
    accessory: 'shield',
  ),
  EquipmentTier(
    level: 20,
    name: 'Champion',
    description: 'Legend in the making',
    chest: 'enchanted_plate',
    legs: 'enchanted_legs',
    accessory: 'magical_aura',
  ),
];

EquipmentTier getEquipmentForLevel(int level) {
  for (int i = equipmentTiers.length - 1; i >= 0; i--) {
    if (level >= equipmentTiers[i].level) {
      return equipmentTiers[i];
    }
  }
  return equipmentTiers[0];
}

final Map<String, String> hairStyles = {
  'short': 'Short and clean',
  'spiky': 'Spiky and bold',
  'wavy': 'Wavy and flowing',
  'curly': 'Curly and voluminous',
  'long': 'Long and elegant',
  'braided': 'Braided warrior',
};

final Map<String, String> bodyTypes = {
  'slim': 'Nimble and quick',
  'athletic': 'Balanced fighter',
  'muscular': 'Strong and mighty',
};

const Map<String, Color> skinTones = {
  'warm': Color(0xFFD4A574),
  'cool': Color(0xFFB8956A),
  'fair': Color(0xFFF5DEB3),
  'tan': Color(0xFFCD853F),
  'dark': Color(0xFF8B4513),
};
