import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web3dart/crypto.dart';

const RPC = 'https://bsc-dataseed1.binance.org/';
const CONTRACT = '0x1A1AFE5BF1ffDB64aC10958cCe2D06B22Fb47Fb8';
const USDC = '0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d';
const USDT = '0x55d398326f99059fF775485246999027B3197955';

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
  return bytesToHex(h.sublist(0, 4));
}

String padHex(String h) => h.padLeft(64, '0');
String padAddr(String a) =>
    a.toLowerCase().replaceFirst('0x', '').padLeft(64, '0');

String encodeString(String s) {
  final bytes = utf8.encode(s);
  final len = padHex(bytes.length.toRadixString(16));
  final body = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  // Round up to multiple of 64 hex chars (32 bytes)
  final padded = body.padRight(((body.length + 63) ~/ 64) * 64, '0');
  return len + padded;
}

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

Future<void> simulate({
  required String label,
  required String from,
  required String tokenAddr,
  required BigInt amount,
  required String recipient,
}) async {
  // swapTokenForAnet(address token, uint256 amount, string recipient)
  // Offset to string = 3 * 32 = 0x60
  final data =
      '0x${selector('swapTokenForAnet(address,uint256,string)')}${padAddr(tokenAddr)}${padHex(amount.toRadixString(16))}${padHex((3 * 32).toRadixString(16))}${encodeString(recipient)}';

  final sim = await rpc('eth_call', [
    {'from': from, 'to': CONTRACT, 'data': data, 'value': '0x0'},
    'latest',
  ]);
  print('--- $label ---');
  print('  data=$data');
  if (sim['error'] != null) {
    print('  error.message: ${sim['error']['message']}');
    final d = sim['error']['data'];
    if (d is String) {
      print('  error.data: $d');
      final reason = decodeRevertReason(d);
      if (reason != null) print('  >>> REVERT: "$reason"');
    }
  } else {
    print('  result: ${sim['result']}');
  }
  print('');
}

void main() async {
  // Simulate from the company OWNER address (should have max privilege but no funds)
  const owner = '0x4f7219FB43289dfb58cEe363deD15CeD19670a91';
  // A whale USDC holder on BSC for from=funded account simulation:
  const whale =
      '0xF977814e90dA44bFA03b6295A0616a897441aceC'; // Binance hot wallet

  // 1) Try from owner
  await simulate(
    label: 'OWNER → swapTokenForAnet(USDC, 1e18, ANETE53...)',
    from: owner,
    tokenAddr: USDC,
    amount: BigInt.from(10).pow(18),
    recipient: 'ANETE53B24FD164529753D5B2CEA1251D616C923',
  );

  // 2) Try from a Binance hot wallet (lots of USDC + USDT)
  await simulate(
    label: 'WHALE → swapTokenForAnet(USDC, 1e18, ANETE53...)',
    from: whale,
    tokenAddr: USDC,
    amount: BigInt.from(10).pow(18),
    recipient: 'ANETE53B24FD164529753D5B2CEA1251D616C923',
  );

  // 3) Try USDT same amount
  await simulate(
    label: 'WHALE → swapTokenForAnet(USDT, 1e18, ANETE53...)',
    from: whale,
    tokenAddr: USDT,
    amount: BigInt.from(10).pow(18),
    recipient: 'ANETE53B24FD164529753D5B2CEA1251D616C923',
  );

  // 4) USDC at minimum amount with NO recipient (empty string) — should hit length check first if any
  await simulate(
    label: 'WHALE → swapTokenForAnet(USDC, 1e18, "") empty recipient',
    from: whale,
    tokenAddr: USDC,
    amount: BigInt.from(10).pow(18),
    recipient: '',
  );

  // 5) USDC with 100 USDC amount (well within limits)
  await simulate(
    label: 'WHALE → swapTokenForAnet(USDC, 100e18, ANETE53...)',
    from: whale,
    tokenAddr: USDC,
    amount: BigInt.from(100) * BigInt.from(10).pow(18),
    recipient: 'ANETE53B24FD164529753D5B2CEA1251D616C923',
  );

  // 6) Check contract storage: maybe there's a pause / config like "anetTreasury" set to 0x0
  print('=== Misc reads ===');
  final reads = {
    'reservedAnet()': selector('reservedAnet()'),
    'anetBalance()': selector('anetBalance()'),
    'anetReserve()': selector('anetReserve()'),
    'feeWallet()': selector('feeWallet()'),
    'platformFeeWallet()': selector('platformFeeWallet()'),
    'anetFeeWallet()': selector('anetFeeWallet()'),
    'treasury()': selector('treasury()'),
    'anetTreasury()': selector('anetTreasury()'),
    'pendingRequests()': selector('pendingRequests()'),
    'pendingCount()': selector('pendingCount()'),
    'nextRequestId()': selector('nextRequestId()'),
    'totalRequests()': selector('totalRequests()'),
    'feeBps()': selector('feeBps()'),
    'platformFeeBps()': selector('platformFeeBps()'),
  };
  for (final e in reads.entries) {
    final r = await rpc('eth_call', [
      {'to': CONTRACT, 'data': '0x${e.value}'},
      'latest',
    ]);
    print('${e.key} -> ${r['result'] ?? r['error']?['message']}');
  }
}
