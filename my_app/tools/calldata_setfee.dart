import 'package:web3dart/crypto.dart';

void main() {
  final sel = keccakUtf8('setFeeRecipient(address)').sublist(0, 4);
  final addr = '9C7C1058fdc9b710f688ECb7562924D9AE771417'.toLowerCase();
  final padded = addr.padLeft(64, '0');
  final selHex = sel.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  print('0x$selHex$padded');
}
