import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web3dart/crypto.dart';

const RPC = 'https://bsc-dataseed1.binance.org/';
const CONTRACT = '0x1A1AFE5BF1ffDB64aC10958cCe2D06B22Fb47Fb8';
const USDC = '0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d';

Future<dynamic> rpc(String method, List params) async {
  final res = await http.post(
    Uri.parse(RPC),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'jsonrpc': '2.0',
      'id': 1,
      'method': method,
      'params': params,
    }),
  );
  return jsonDecode(res.body);
}

String selector(String sig) {
  final h = keccakUtf8(sig);
  return '0x${bytesToHex(h.sublist(0, 4))}';
}

String padAddr(String a) =>
    a.toLowerCase().replaceFirst('0x', '').padLeft(64, '0');

String? decodeRevertReason(String hexResult) {
  if (!hexResult.startsWith('0x08c379a0')) return null;
  final data = hexResult.substring(2 + 8 + 64);
  final len = int.parse(data.substring(0, 64), radix: 16);
  final strHex = data.substring(64, 64 + len * 2);
  final bytes = <int>[];
  for (int i = 0; i < strHex.length; i += 2) {
    bytes.add(int.parse(strHex.substring(i, i + 2), radix: 16));
  }
  return utf8.decode(bytes);
}

void main() async {
  // 1) Latest block
  final blkHex = (await rpc('eth_blockNumber', []))['result'] as String;
  final latest = int.parse(blkHex.substring(2), radix: 16);
  print('latest block = $latest');

  // 2) Scan last ~5000 blocks for USDC Transfer logs TO the AnetSwap contract.
  //    USDC Transfer topic0 = keccak256("Transfer(address,address,uint256)")
  final transferTopic =
      '0x${bytesToHex(keccakUtf8('Transfer(address,address,uint256)'))}';
  final fromBlk = '0x${(latest - 5000).toRadixString(16)}';
  final toBlk = '0x${latest.toRadixString(16)}';

  print('Scanning USDC Transfers TO AnetSwap from $fromBlk to $toBlk ...');
  final logs = await rpc('eth_getLogs', [
    {
      'address': USDC,
      'fromBlock': fromBlk,
      'toBlock': toBlk,
      'topics': [transferTopic, null, '0x${padAddr(CONTRACT)}'],
    },
  ]);
  final list = (logs['result'] as List?) ?? [];
  print('found ${list.length} USDC transfers to the bridge contract');
  for (final l in list) {
    print(
      '  tx=${l['transactionHash']}  block=${l['blockNumber']}  from_topic=${l['topics'][1]}  data=${l['data']}',
    );
  }
  if (list.isEmpty) {
    print(
      'No USDC→AnetSwap transfers in last 5000 blocks (≈4 hours). The user\'s tx reverted on USDC.transferFrom or earlier require() — no transfer ever happened.',
    );
  }

  // 3) Get the most recent 200 BSC tx hashes sent TO the contract from any wallet
  //    using eth_getLogs for the bridge's own emitted event(s) if any.
  //    Try common event names:
  for (final ev in [
    'BridgeInitiated(address,address,uint256,string)',
    'TokenBridged(address,address,uint256,string)',
    'Swap(address,address,uint256,string)',
    'SwapTokenForAnet(address,address,uint256,string)',
  ]) {
    final topic = '0x${bytesToHex(keccakUtf8(ev))}';
    final r = await rpc('eth_getLogs', [
      {
        'address': CONTRACT,
        'fromBlock': fromBlk,
        'toBlock': toBlk,
        'topics': [topic],
      },
    ]);
    final l = (r['result'] as List?) ?? [];
    if (l.isNotEmpty) print('Event $ev (topic=$topic): ${l.length} logs');
  }

  // 4) Build a small set of recent reverted CALLS to the contract by scanning blocks ourselves.
  //    Too expensive. Instead: list ALL logs of the AnetSwap contract in last 5000 blocks regardless of topic.
  print('\nAll logs emitted by AnetSwap in last 5000 blocks:');
  final allLogs = await rpc('eth_getLogs', [
    {'address': CONTRACT, 'fromBlock': fromBlk, 'toBlock': toBlk},
  ]);
  final all = (allLogs['result'] as List?) ?? [];
  print('  ${all.length} logs');
  for (final l in all.take(20)) {
    print('  tx=${l['transactionHash']}  topic0=${(l['topics'] as List)[0]}');
  }

  // 5) Most likely diagnosis: try simulating swapTokenForAnet now from the user's BSC wallet address.
  //    The user's address ends in 56b8ce — we need full. Try a synthetic 1 USDC swap from a TEST sender.
  //    Better: pick the LAST successful tx hash to the bridge and look up its details, then for the next
  //    block try a 1 USDC swap as a hypothetical and see what reverts.
  print(
    '\nTry simulating swapTokenForAnet(USDC, 1e18, "ANETE53B24FD164529753D5B2CEA1251D616C923") with a random funded address',
  );
  // Use vitalik.eth-style well-funded zero — fake 'from' will likely fail allowance, but lets us see require order.
  final fakeFrom = '0x0000000000000000000000000000000000000001';
  final input =
      selector('swapTokenForAnet(address,uint256,string)') +
      padAddr(USDC) +
      BigInt.from(10).pow(18).toRadixString(16).padLeft(64, '0')
      // ABI string: offset, length, padded bytes
      +
      (3 * 32).toRadixString(16).padLeft(64, '0') +
      (40).toRadixString(16).padLeft(64, '0') +
      'ANETE53B24FD164529753D5B2CEA1251D616C923'.codeUnits
          .map((c) => c.toRadixString(16).padLeft(2, '0'))
          .join()
          .padRight(64, '0');
  final sim = await rpc('eth_call', [
    {'from': fakeFrom, 'to': CONTRACT, 'data': '0x$input'},
    'latest',
  ]);
  print('sim result: $sim');
  if (sim['error'] != null && sim['error']['data'] is String) {
    final reason = decodeRevertReason(sim['error']['data'] as String);
    if (reason != null) print('>>> REVERT: $reason');
  }
}
