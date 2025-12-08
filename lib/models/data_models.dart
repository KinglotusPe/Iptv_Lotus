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
    name: json['name'],
    group: json['group'],
    logo: json['logo'],
    url: json['url'],
    streamId: json['stream_id']?.toString(), // Handle int IDs from Xtream
  );
}
