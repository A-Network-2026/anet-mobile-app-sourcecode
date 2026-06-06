import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:web3dart/crypto.dart';
import 'dart:convert';

Uint8List _rlpEncodeBytes(Uint8List b) {
  if (b.length == 1 && b[0] < 0x80) return b;
  if (b.length < 56) {
    return Uint8List.fromList([0x80 + b.length, ...b]);
  }
  // long bytes
  final lenBytes = _intToBytes(b.length);
  return Uint8List.fromList([0xb7 + lenBytes.length, ...lenBytes, ...b]);
}

Uint8List _intToBytes(int x) {
  if (x == 0) return Uint8List(0);
  final out = <int>[];
  while (x > 0) {
    out.insert(0, x & 0xff);
    x >>= 8;
  }
  return Uint8List.fromList(out);
}

Uint8List _rlpEncodeList(List<Uint8List> items) {
  final payload = <int>[];
  for (final it in items) {
    payload.addAll(it);
  }
  if (payload.length < 56) {
    return Uint8List.fromList([0xc0 + payload.length, ...payload]);
  }
  final lenBytes = _intToBytes(payload.length);
  return Uint8List.fromList([0xf7 + lenBytes.length, ...lenBytes, ...payload]);
}

String _createAddress(String sender, int nonce) {
  // strip 0x
  final senderBytes = Uint8List.fromList(
    List<int>.generate(
      20,
      (i) => int.parse(sender.substring(2 + i * 2, 4 + i * 2), radix: 16),
    ),
  );
  final nonceBytes = _intToBytes(nonce);
  final rlp = _rlpEncodeList([
    _rlpEncodeBytes(senderBytes),
    _rlpEncodeBytes(nonceBytes),
  ]);
  final h = keccak256(rlp);
  return '0x${h.sublist(12).map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
}

Future<bool> _hasCode(String rpc, String addr) async {
  final r = await http.post(
    Uri.parse(rpc),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'jsonrpc': '2.0',
      'method': 'eth_getCode',
      'params': [addr, 'latest'],
      'id': 1,
    }),
  );
  final code = jsonDecode(r.body)['result'] as String;
  return code != '0x' && code.length > 4;
}

void main() async {
  const owner = '0x4f7219FB43289dfb58cEe363deD15CeD19670a91';
  const rpc = 'https://bsc-dataseed.binance.org/';
  print('Scanning CREATE addresses for $owner...');
  for (int n = 0; n <= 18; n++) {
    final addr = _createAddress(owner, n);
    final has = await _hasCode(rpc, addr);
    if (has) {
      print('nonce=$n -> $addr  ✅ HAS CODE');
    }
  }
  print('done.');
}
