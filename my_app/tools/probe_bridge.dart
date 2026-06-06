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

// Etherscan V2 multichain API (chainid=56 for BSC). No API key needed for low-rate reads.
Future<dynamic> escan(Map<String, String> q) async {
  q['chainid'] = '56';
  final uri = Uri.https('api.etherscan.io', '/v2/api', q);
  final res = await http.get(uri);
  return jsonDecode(res.body);
}

String selector(String sig) {
  final h = keccakUtf8(sig);
  return '0x${bytesToHex(h.sublist(0, 4))}';
}

String padAddr(String a) =>
    a.toLowerCase().replaceFirst('0x', '').padLeft(64, '0');

void main(List<String> args) async {
  // 1) Get recent INTERNAL+EXTERNAL txs to the AnetSwap contract via Etherscan V2
  final r = await escan({
    'module': 'account',
    'action': 'txlist',
    'address': CONTRACT,
    'startblock': '99290000',
    'endblock': '99303000',
    'sort': 'desc',
    'page': '1',
    'offset': '20',
  });
  print('=== Recent txs to AnetSwap (last ~13k blocks) ===');
  final txs = (r['result'] as List?) ?? [];
  for (final t in txs) {
    print(
      'hash=${t['hash']}  from=${t['from']}  isError=${t['isError']}  value=${t['value']}  input=${(t['input'] as String).substring(0, 10)}',
    );
  }

  // 2) Find the user's reverted tx (truncated hash starts 0x7b81f16eb2 and ends 1a9efc09)
  String? userTx;
  for (final t in txs) {
    final h = t['hash'] as String;
    if (h.startsWith('0x7b81f16eb2') && h.endsWith('1a9efc09')) {
      userTx = h;
      print('\n=== Found user tx: $h ===');
      print('Full tx: $t');
      break;
    }
  }

  if (userTx == null) {
    // Maybe outside the block window — search widely with full-list pagination via V2 logs
    print('\nNot found in window — searching wider window...');
    final r2 = await escan({
      'module': 'account',
      'action': 'txlist',
      'address': CONTRACT,
      'startblock': '90000000',
      'endblock': '99303000',
      'sort': 'desc',
      'page': '1',
      'offset': '100',
    });
    for (final t in (r2['result'] as List? ?? [])) {
      final h = t['hash'] as String;
      if (h.startsWith('0x7b81f16eb2')) {
        userTx = h;
        print('Found: $h tx=$t');
        break;
      }
    }
  }

  if (userTx == null) {
    print('Tx not found via Etherscan V2 — falling back to RPC scan.');
    return;
  }

  // 3) Get the tx + receipt
  final tx = await rpc('eth_getTransactionByHash', [userTx]);
  final rc = await rpc('eth_getTransactionReceipt', [userTx]);
  print('\n=== Tx ===\n$tx');
  print('\n=== Receipt ===\n$rc');

  // 4) Re-simulate at the same block to extract revert reason
  final t = tx['result'];
  if (t == null) return;
  final simResult = await rpc('eth_call', [
    {
      'from': t['from'],
      'to': t['to'],
      'data': t['input'],
      'value': t['value'] ?? '0x0',
      'gas': t['gas'],
    },
    '0x${(int.parse((t['blockNumber'] as String).substring(2), radix: 16) - 1).toRadixString(16)}',
  ]);
  print('\n=== Re-simulation (one block before) ===\n$simResult');

  final simAtBlock = await rpc('eth_call', [
    {
      'from': t['from'],
      'to': t['to'],
      'data': t['input'],
      'value': t['value'] ?? '0x0',
    },
    t['blockNumber'],
  ]);
  print('\n=== Re-simulation at exact block ===\n$simAtBlock');
}
