import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:multicast_dns/multicast_dns.dart';

import 'mdns_models.dart';

const _serviceName = '_gshub._tcp.local';
const _androidChannel = MethodChannel('com.gshub.sysapp/mdns');

Future<List<MdnsEndpoint>> browseGshubEndpoints({
  required Duration timeout,
}) async {
  final client = MDnsClient();
  final endpoints = <String, MdnsEndpoint>{};
  final pending = <Future<void>>[];
  StreamSubscription<PtrResourceRecord>? subscription;

  try {
    if (Platform.isAndroid) {
      await _androidChannel.invokeMethod<void>('acquireMulticastLock');
    }
    await client.start();
    subscription = client
        .lookup<PtrResourceRecord>(
          ResourceRecordQuery.serverPointer(_serviceName),
        )
        .listen((ptr) {
          pending.add(_resolve(client, ptr, endpoints));
        });
    await Future<void>.delayed(timeout);
    await subscription.cancel();
    await Future.wait(pending);
  } finally {
    client.stop();
    if (Platform.isAndroid) {
      try {
        await _androidChannel.invokeMethod<void>('releaseMulticastLock');
      } catch (_) {
        // The Activity may already be detached while the dialog is closing.
      }
    }
  }

  return endpoints.values.toList(growable: false);
}

Future<void> _resolve(
  MDnsClient client,
  PtrResourceRecord ptr,
  Map<String, MdnsEndpoint> endpoints,
) async {
  try {
    final srv = await client
        .lookup<SrvResourceRecord>(ResourceRecordQuery.service(ptr.domainName))
        .first
        .timeout(const Duration(seconds: 2));
    final address = await client
        .lookup<IPAddressResourceRecord>(
          ResourceRecordQuery.addressIPv4(srv.target),
        )
        .first
        .timeout(const Duration(seconds: 2));
    final endpoint = MdnsEndpoint(
      host: address.address.address,
      port: srv.port,
    );
    endpoints[endpoint.key] = endpoint;
  } catch (_) {
    // Individual mDNS records are allowed to expire or resolve incompletely.
  }
}
