import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web3dart/crypto.dart';

const RPC = 'https://bsc-dataseed1.binance.org/';
const CONTRACT = '0x1A1AFE5BF1ffDB64aC10958cCe2D06B22Fb47Fb8';
const USDC = '0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d';
const APIKEY = '2BH5BYV1DFQKCUQSQSJM6PKT6JH8WPS5N6';

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

Future<dynamic> escan(Map<String, String> q) async {
  q['chainid'] = '56';
  q['apikey'] = APIKEY;
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

String? decodeRevertReason(String hexResult) {
  if (!hexResult.startsWith('0x08c379a0')) return null;
  // Error(string): skip selector + offset(32) + length(32) reading
  final data = hexResult.substring(2 + 8 + 64);
  final lenHex = data.substring(0, 64);
  final len = int.parse(lenHex, radix: 16);
  final strHex = data.substring(64, 64 + len * 2);
  final bytes = <int>[];
  for (int i = 0; i < strHex.length; i += 2) {
    bytes.add(int.parse(strHex.substring(i, i + 2), radix: 16));
  }
  return utf8.decode(bytes);
}

Future<void> main(List<String> args) async {
  // Last 20 txs to the AnetSwap contract — find the reverted one matching user's hash prefix
  final r = await escan({
    'module': 'account',
    'action': 'txlist',
    'address': CONTRACT,
    'startblock': '0',
    'endblock': '99999999',
    'sort': 'desc',
    'page': '1',
    'offset': '50',
  });
  print('Etherscan status=${r['status']} message=${r['message']}');
  final txs = (r['result'] is List) ? (r['result'] as List) : [];
  print('Found ${txs.length} txs');
  print('');
  print(
    'Reverted txs in last 50 (isError=1) — first 20 char prefixes & full hash:',
  );
  String? target;
  for (final t in txs) {
    final h = t['hash'] as String;
    final isError = t['isError'];
    final from = t['from'];
    final input = (t['input'] as String);
    final fnsel = input.length >= 10 ? input.substring(0, 10) : input;
    print(
      '  isError=$isError  hash=$h  from=$from  fn=$fnsel  block=${t['blockNumber']}',
    );
    if (h.startsWith('0x7b81f16eb2')) target = h;
  }
  if (target == null) {
    print(
      '\nUser tx prefix 0x7b81f16eb2... not found in last 50 — fetching more...',
    );
    final r2 = await escan({
      'module': 'account',
      'action': 'txlist',
      'address': CONTRACT,
      'startblock': '0',
      'endblock': '99999999',
      'sort': 'desc',
      'page': '1',
      'offset': '500',
    });
    final txs2 = (r2['result'] is List) ? (r2['result'] as List) : [];
    for (final t in txs2) {
      final h = t['hash'] as String;
      if (h.startsWith('0x7b81f16eb2') && h.endsWith('1a9efc09')) {
        target = h;
        print(
          'Found: $h  block=${t['blockNumber']}  from=${t['from']}  input=${(t['input'] as String).substring(0, 138)}',
        );
        break;
      }
    }
  }
  if (target == null) {
    print('STILL not found. Listing recent errors only:');
    for (final t in txs) {
      if (t['isError'] == '1') print(t);
    }
    return;
  }

  print('\n=== Target tx: $target ===');
  final tx = (await rpc('eth_getTransactionByHash', [target]))['result'];
  final rc = (await rpc('eth_getTransactionReceipt', [target]))['result'];
  print(
    'from=${tx['from']}  to=${tx['to']}  value=${tx['value']}  gas=${tx['gas']}  gasPrice=${tx['gasPrice']}',
  );
  print('input=${tx['input']}');
  print(
    'status=${rc['status']}  gasUsed=${rc['gasUsed']}  block=${rc['blockNumber']}',
  );

  // Re-simulate at the block BEFORE for the cleanest revert reason
  final blockNum = int.parse(
    (tx['blockNumber'] as String).substring(2),
    radix: 16,
  );
  final atBlock = '0x${(blockNum - 1).toRadixString(16)}';
  final sim = await rpc('eth_call', [
    {
      'from': tx['from'],
      'to': tx['to'],
      'data': tx['input'],
      'value': tx['value'] ?? '0x0',
      'gas': tx['gas'],
    },
    atBlock,
  ]);
  print('\n=== Re-simulation (block-1) ===');
  print(sim);
  if (sim['error'] != null) {
    final dataField = sim['error']['data'];
    if (dataField is String) {
      final reason = decodeRevertReason(dataField);
      if (reason != null) print('>>> REVERT REASON: $reason');
    }
    print('>>> message: ${sim['error']['message']}');
  }

  // Also check user's allowance & balance at that block
  final userAddr = tx['from'] as String;
  print('\n=== User USDC balance @block-1 ===');
  print(
    await rpc('eth_call', [
      {'to': USDC, 'data': selector('balanceOf(address)') + padAddr(userAddr)},
      atBlock,
    ]),
  );
  print('\n=== User USDC allowance to AnetSwap @block-1 ===');
  print(
    await rpc('eth_call', [
      {
        'to': USDC,
        'data':
            selector('allowance(address,address)') +
            padAddr(userAddr) +
            padAddr(CONTRACT),
      },
      atBlock,
    ]),
  );

  // Contract's ANET token balance (does the bridge have ANET to send to L1?)
  // First find the ANET token address used by the contract
  print('\n=== AnetSwap contract reads ===');
  final readers = [
    'anetToken()',
    'anet()',
    'token()',
    'anetTokenAddress()',
    'getAnetToken()',
  ];
  for (final s in readers) {
    final res = await rpc('eth_call', [
      {'to': CONTRACT, 'data': selector(s)},
      'latest',
    ]);
    print('$s -> ${res['result'] ?? res['error']}');
  }
}
