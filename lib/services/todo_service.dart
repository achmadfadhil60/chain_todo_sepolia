import 'package:flutter/services.dart';
import 'package:http/http.dart';
import 'package:wallet/wallet.dart';
import 'package:web3dart/web3dart.dart';
import '../config/blockchain_config.dart';

class TodoItem {
  final int id;
  final String judul;
  final bool selesai;
  final DateTime dibuat;
  final String pembuat;

  TodoItem({
    required this.id,
    required this.judul,
    required this.selesai,
    required this.dibuat,
    required this.pembuat,
  });
}

class TodoService {
  late Web3Client _client;
  late DeployedContract _contract;
  late EthPrivateKey _credentials;

  String get walletAddress => _credentials.address.toString();

  Future<void> init() async {
    _client = Web3Client(BlockchainConfig.rpcUrl, Client());
    _credentials = EthPrivateKey.fromHex(BlockchainConfig.privateKey);

    final abiString = await rootBundle.loadString('assets/abi.json');
    final contractAddr =
        EthereumAddress.fromHex(BlockchainConfig.contractAddress);
    _contract = DeployedContract(
      ContractAbi.fromJson(abiString, 'ChainTodo'),
      contractAddr,
    );
  }

  Future<List<TodoItem>> ambilSemuaTugas() async {
    final fungsiJumlah = _contract.function('jumlahTugas');
    final fungsiAmbil = _contract.function('ambilTugas');

    final hasilJumlah = await _client.call(
      contract: _contract,
      function: fungsiJumlah,
      params: [],
    );
    final total = (hasilJumlah.first as BigInt).toInt();

    List<TodoItem> daftar = [];
    for (int i = 0; i < total; i++) {
      final res = await _client.call(
        contract: _contract,
        function: fungsiAmbil,
        params: [BigInt.from(i)],
      );
      daftar.add(TodoItem(
        id: i,
        judul: res[0] as String,
        selesai: res[1] as bool,
        dibuat: DateTime.fromMillisecondsSinceEpoch(
            (res[2] as BigInt).toInt() * 1000),
        pembuat: res[3].toString(),
      ));
    }
    return daftar;
  }

  Future<String> tambahTugas(String judul) async {
    final fungsiTambah = _contract.function('tambahTugas');
    final txHash = await _client.sendTransaction(
      _credentials,
      Transaction.callContract(
        contract: _contract,
        function: fungsiTambah,
        parameters: [judul],
      ),
      chainId: BlockchainConfig.chainId,
    );
    return txHash;
  }

  Future<String> tandaiSelesai(int id) async {
    final fungsiSelesai = _contract.function('tandaiSelesai');
    final txHash = await _client.sendTransaction(
      _credentials,
      Transaction.callContract(
        contract: _contract,
        function: fungsiSelesai,
        parameters: [BigInt.from(id)],
      ),
      chainId: BlockchainConfig.chainId,
    );
    return txHash;
  }
}