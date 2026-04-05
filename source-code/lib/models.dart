// ─────────────────────────────────────────────
//  HackerDeck — Data Models
// ─────────────────────────────────────────────

class Instance {
  final String name;
  final String dataDir;

  Instance({required this.name, required this.dataDir});

  factory Instance.fromJson(Map<String, dynamic> json) =>
      Instance(name: json['name'] as String, dataDir: json['data_dir'] as String);

  Map<String, dynamic> toJson() => {'name': name, 'data_dir': dataDir};
}

class KeyMapping {
  final String key;
  final String type;
  final double x;
  final double y;

  KeyMapping({required this.key, required this.type, required this.x, required this.y});

  factory KeyMapping.fromJson(Map<String, dynamic> json) => KeyMapping(
        key: json['key'] as String,
        type: json['type'] as String,
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {'key': key, 'type': type, 'x': x, 'y': y};
}

class KeyCircle {
  final String key;
  final double x, y, radius;

  KeyCircle({required this.key, required this.x, required this.y, required this.radius});

  KeyCircle copyWith({String? key, double? x, double? y, double? radius}) => KeyCircle(
        key: key ?? this.key,
        x: x ?? this.x,
        y: y ?? this.y,
        radius: radius ?? this.radius,
      );
}

class AppInfo {
  String name;
  String package;
  String icon;

  AppInfo({required this.name, this.package = '', this.icon = ''});
}

class StoreApp {
  final String name;
  final String category;
  final String description;
  final String icon;
  final String downloadUrl;
  final String version;

  StoreApp({
    required this.name,
    required this.category,
    required this.description,
    required this.icon,
    required this.downloadUrl,
    required this.version,
  });
}
