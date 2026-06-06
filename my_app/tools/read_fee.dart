import 'package:http/http.dart' as http;
import 'package:web3dart/web3dart.dart';

const abi = '''[
  {"name":"feeRecipient","type":"function","stateMutability":"view","inputs":[],"outputs":[{"name":"","type":"address"}]},
  {"name":"feeBps","type":"function","stateMutability":"view","inputs":[],"outputs":[{"name":"","type":"uint256"}]},
  {"name":"owner","type":"function","stateMutability":"view","inputs":[],"outputs":[{"name":"","type":"address"}]},
  {"name":"paused","type":"function","stateMutability":"view","inputs":[],"outputs":[{"name":"","type":"bool"}]},
  {"name":"totalNativeReceived","type":"function","stateMutability":"view","inputs":[],"outputs":[{"name":"","type":"uint256"}]}
]''';

void main() async {
  final c = Web3Client('https://bsc-dataseed.binance.org/', http.Client());
  final addr = EthereumAddress.fromHex('0x1A1AFE5BF1ffDB64aC10958cCe2D06B22Fb47Fb8');
  final contract = DeployedContract(ContractAbi.fromJson(abi, 'AnetSwap'), addr);
  for (final fn in ['feeRecipient','feeBps','owner','paused','totalNativeReceived']) {
    try {
      final res = await c.call(contract: contract, function: contract.function(fn), params: []);
      print('$fn = ${res.first}');
    } catch (e) {
      print('$fn ERROR: $e');
    }
  }
  await c.dispose();
}
