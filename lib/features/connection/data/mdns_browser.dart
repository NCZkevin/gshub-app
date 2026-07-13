import 'mdns_browser_stub.dart'
    if (dart.library.io) 'mdns_browser_io.dart'
    as platform;
import 'mdns_models.dart';

Future<List<MdnsEndpoint>> browseGshubEndpoints({
  Duration timeout = const Duration(seconds: 4),
}) => platform.browseGshubEndpoints(timeout: timeout);
