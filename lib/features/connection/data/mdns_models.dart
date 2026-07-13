class MdnsEndpoint {
  final String host;
  final int port;

  const MdnsEndpoint({required this.host, required this.port});

  String get key => '$host:$port';
}
