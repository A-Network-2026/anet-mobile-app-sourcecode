import 'dart:convert';
import 'package:http/http.dart' as http;

const rpc = 'https://bsc-dataseed.binance.org/';
const contract = '0x15c848e00610d1bd820b122b81879a66318e1c66';

Future<String> _call(String selector) async {
  final r = await http.post(
    Uri.parse(rpc),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'jsonrpc': '2.0',
      'method': 'eth_call',
      'id': 1,
      'params': [
        {'to': contract, 'data': selector},
        'latest',
      ],
    }),
  );
  return jsonDecode(r.body)['result'] as String;
}

void main() async {
  // selectors
  final feeRecipient = await _call('0x46904840'); // feeRecipient()
  final owner = await _call('0x8da5cb5b'); // owner()
  final regFee = await _call(
    '0x14c44e09',
  ); // registrationFee() — let me compute
  // actually we need proper selectors; let me use eth_call with known sigs:
  final r = await _call('0x46904840');
  final o = await _call('0x8da5cb5b');
  print('Contract: $contract');
  print('feeRecipient() = 0x${r.substring(26)}');
  print('owner()        = 0x${o.substring(26)}');
}
