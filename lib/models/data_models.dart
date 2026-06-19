import 'dart:convert';

class Account {
  final String name;
  final String url;
  final String username;
  final String password;
  final String type; // 'm3u' or 'xtream'

  Account({
    required this.name,
    required this.url,
    this.username = '',
    this.password = '',
    this.type = 'm3u',
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'url': url,
    'username': username,
    'password': password,
    'type': type,
  };

  factory Account.fromJson(Map<String, dynamic> json) => Account(
    name: json['name'],
    url: json['url'],
    username: json['username'] ?? '',
    password: json['password'] ?? '',
    type: json['type'] ?? 'm3u',
  );
}

class Channel {
  final String name;
  final String group;
  final String logo;
  final String url;
  final String? streamId;

  Channel({
    required this.name,
    required this.group,
    required this.logo,
    required this.url,
    this.streamId,
  });

  factory Channel.fromJson(Map<String, dynamic> json) => Channel(
    name: json['name'] ?? "",
    group: json['group'] ?? "",
    logo: json['logo'] ?? "",
    url: json['url'] ?? "",
    streamId: json['stream_id']?.toString(),
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'group': group,
    'logo': logo,
    'url': url,
    if (streamId != null) 'stream_id': streamId,
  };
}

class EpgProgram {
  final String title;
  final String description;
  final String start;
  final String end;

  EpgProgram({
    required this.title,
    required this.description,
    required this.start,
    required this.end,
  });

  factory EpgProgram.fromJson(Map<String, dynamic> json) {
    String desc = json['description'] ?? "";
    String title = json['title'] ?? "";
    
    // A veces Xtream Codes retorna los campos codificados en Base64
    try {
      // Intentamos decodificar base64. Si tiene caracteres ilegales o no es base64, fallará y usará el texto original
      desc = utf8.decode(base64.decode(desc.trim()));
    } catch (_) {}
    try {
      title = utf8.decode(base64.decode(title.trim()));
    } catch (_) {}

    return EpgProgram(
      title: title,
      description: desc,
      start: json['start'] ?? "",
      end: json['end'] ?? "",
    );
  }
}
