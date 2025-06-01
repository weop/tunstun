class TunnelConfig {
  final String id;
  final String remoteHost;
  final int remotePort;
  final String sshUser;
  final String sshHost;
  final int localPort;
  final String name;
  bool isConnected;

  TunnelConfig({
    required this.id,
    required this.remoteHost,
    required this.remotePort,
    required this.sshUser,
    required this.sshHost,
    required this.localPort,
    required this.name,
    this.isConnected = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'remoteHost': remoteHost,
      'remotePort': remotePort,
      'sshUser': sshUser,
      'sshHost': sshHost,
      'localPort': localPort,
      'name': name,
      'isConnected': isConnected,
    };
  }

  factory TunnelConfig.fromJson(Map<String, dynamic> json) {
    return TunnelConfig(
      id: json['id'] ?? '',
      remoteHost: json['remoteHost'] ?? '',
      remotePort: json['remotePort'] ?? 0,
      sshUser: json['sshUser'] ?? '',
      sshHost: json['sshHost'] ?? '',
      localPort: json['localPort'] ?? 0,
      name: json['name'] ?? '',
      isConnected: json['isConnected'] ?? false,
    );
  }

  String get connectionString => '$sshUser@$sshHost';
  String get remoteEndpoint => '$remoteHost:$remotePort';

  @override
  String toString() {
    return 'TunnelConfig(name: $name, local: $localPort, remote: $remoteEndpoint, ssh: $connectionString)';
  }
}
