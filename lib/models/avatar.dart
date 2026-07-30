class Avatar {
  final String id;
  final String name;
  final String archetype;
  final String description;
  final String defaultStat;
  final String colorHex;
  final DateTime createdAt;

  Avatar({
    required this.id,
    required this.name,
    required this.archetype,
    required this.description,
    required this.defaultStat,
    required this.colorHex,
    required this.createdAt,
  });

  factory Avatar.fromJson(Map<String, dynamic> json) {
    return Avatar(
      id: json['id'] as String,
      name: json['name'] as String,
      archetype: json['archetype'] as String,
      description: json['description'] as String,
      defaultStat: json['default_stat'] as String,
      colorHex: json['color_hex'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'archetype': archetype,
      'description': description,
      'default_stat': defaultStat,
      'color_hex': colorHex,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
