import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'services/todo_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: 'assets/app.env');
  } catch (e) {
    debugPrint('Gagal memuat env: $e');
  }
  runApp(const ChainTodoApp());
}

class ChainTodoApp extends StatelessWidget {
  const ChainTodoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ChainTodo Sepolia',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
      ),
      home: const TodoHomePage(),
    );
  }
}

enum FilterTugas { semua, belumSelesai, selesai, milikSendiri }

enum StatusTx { idle, memproses, berhasil, gagal }

class TodoHomePage extends StatefulWidget {
  const TodoHomePage({super.key});

  @override
  State<TodoHomePage> createState() => _TodoHomePageState();
}

class _TodoHomePageState extends State<TodoHomePage> {
  final TodoService _todoService = TodoService();
  final TextEditingController _judulController = TextEditingController();

  List<TodoItem> _semuaTugas = [];
  FilterTugas _filterAktif = FilterTugas.semua;
  bool _isLoadingList = true;

  StatusTx _statusTx = StatusTx.idle;
  String _pesanTx = '';
  String? _lastTxHash;

  @override
  void initState() {
    super.initState();
    _inisialisasiDanMuat();
  }

  @override
  void dispose() {
    _judulController.dispose();
    super.dispose();
  }

  Future<void> _inisialisasiDanMuat() async {
    setState(() => _isLoadingList = true);
    try {
      await _todoService.init();
      await _muatDaftarTugas();
    } catch (e) {
      setState(() {
        _statusTx = StatusTx.gagal;
        _pesanTx = 'Gagal inisialisasi kontrak/RPC: $e';
        _isLoadingList = false;
      });
    }
  }

  Future<void> _muatDaftarTugas() async {
    setState(() => _isLoadingList = true);
    try {
      final data = await _todoService.ambilSemuaTugas();
      setState(() {
        _semuaTugas = data.reversed.toList();
        _isLoadingList = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingList = false;
        _statusTx = StatusTx.gagal;
        _pesanTx = 'Gagal membaca data dari kontrak: $e';
      });
    }
  }

  List<TodoItem> get _tugasTerfilter {
    switch (_filterAktif) {
      case FilterTugas.belumSelesai:
        return _semuaTugas.where((t) => !t.selesai).toList();
      case FilterTugas.selesai:
        return _semuaTugas.where((t) => t.selesai).toList();
      case FilterTugas.milikSendiri:
        return _semuaTugas
            .where((t) =>
                t.pembuat.toLowerCase() ==
                _todoService.walletAddress.toLowerCase())
            .toList();
      case FilterTugas.semua:
        return _semuaTugas;
    }
  }

  Future<void> _kirimTambahTugas(String judul) async {
    if (judul.trim().isEmpty) return;

    setState(() {
      _statusTx = StatusTx.memproses;
      _pesanTx = 'Mengirim transaksi tambahTugas ke Sepolia...';
      _lastTxHash = null;
    });

    try {
      final txHash = await _todoService.tambahTugas(judul.trim());
      setState(() {
        _statusTx = StatusTx.berhasil;
        _pesanTx = 'Tugas berhasil dikirim ke blockchain!';
        _lastTxHash = txHash;
      });
      _judulController.clear();

      await Future.delayed(const Duration(seconds: 4));
      await _muatDaftarTugas();
    } catch (e) {
      setState(() {
        _statusTx = StatusTx.gagal;
        _pesanTx = 'Transaksi tambahTugas gagal: $e';
        _lastTxHash = null;
      });
    }
  }

  Future<void> _kirimTandaiSelesai(TodoItem item) async {
    setState(() {
      _statusTx = StatusTx.memproses;
      _pesanTx = 'Menandai tugas #${item.id} selesai di Sepolia...';
      _lastTxHash = null;
    });

    try {
      final txHash = await _todoService.tandaiSelesai(item.id);
      setState(() {
        _statusTx = StatusTx.berhasil;
        _pesanTx = 'Tugas #${item.id} berhasil ditandai selesai!';
        _lastTxHash = txHash;
      });

      await Future.delayed(const Duration(seconds: 4));
      await _muatDaftarTugas();
    } catch (e) {
      setState(() {
        _statusTx = StatusTx.gagal;
        _pesanTx = 'Transaksi tandaiSelesai gagal: $e';
        _lastTxHash = null;
      });
    }
  }

  void _tampilkanDialogTambahTugas() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tambah Tugas On-Chain'),
        content: TextField(
          controller: _judulController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Judul Tugas',
            hintText: 'Contoh: Presentasi Pemrograman Mobile 2',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              final teks = _judulController.text;
              Navigator.pop(ctx);
              _kirimTambahTugas(teks);
            },
            child: const Text('Kirim Transaksi'),
          ),
        ],
      ),
    );
  }

  Widget _buildBannerStatusTransaksi() {
    if (_statusTx == StatusTx.idle) return const SizedBox.shrink();

    Color bgColor;
    Color iconColor;
    IconData iconData;

    switch (_statusTx) {
      case StatusTx.memproses:
        bgColor = Colors.amber.shade100;
        iconColor = Colors.amber.shade900;
        iconData = Icons.hourglass_top;
        break;
      case StatusTx.berhasil:
        bgColor = Colors.green.shade100;
        iconColor = Colors.green.shade900;
        iconData = Icons.check_circle;
        break;
      case StatusTx.gagal:
        bgColor = Colors.red.shade100;
        iconColor = Colors.red.shade900;
        iconData = Icons.error;
        break;
      case StatusTx.idle:
        return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (_statusTx == StatusTx.memproses)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: iconColor,
                  ),
                )
              else
                Icon(iconData, color: iconColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _pesanTx,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: iconColor,
                  ),
                ),
              ),
              if (_statusTx != StatusTx.memproses)
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(() => _statusTx = StatusTx.idle),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          if (_lastTxHash != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Tx Hash: $_lastTxHash',
                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  tooltip: 'Salin Hash Transaksi',
                  icon: const Icon(Icons.copy, size: 16),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _lastTxHash!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Hash transaksi disalin')),
                    );
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          _chipItem('Semua', FilterTugas.semua),
          const SizedBox(width: 8),
          _chipItem('Belum Selesai', FilterTugas.belumSelesai),
          const SizedBox(width: 8),
          _chipItem('Selesai', FilterTugas.selesai),
          const SizedBox(width: 8),
          _chipItem('Milik Wallet Saya', FilterTugas.milikSendiri),
        ],
      ),
    );
  }

  Widget _chipItem(String label, FilterTugas tipe) {
    return ChoiceChip(
      label: Text(label),
      selected: _filterAktif == tipe,
      onSelected: (_) => setState(() => _filterAktif = tipe),
    );
  }

  String _formatWaktu(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final daftarTampil = _tugasTerfilter;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ChainTodo (Sepolia)'),
        actions: [
          IconButton(
            tooltip: 'Muat Ulang Data Kontrak',
            icon: const Icon(Icons.refresh),
            onPressed: _isLoadingList ? null : _muatDaftarTugas,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildBannerStatusTransaksi(),
          _buildFilterChips(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _muatDaftarTugas,
              child: _isLoadingList
                  ? const Center(child: CircularProgressIndicator())
                  : daftarTampil.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 120),
                            Center(
                              child: Text(
                                'Belum ada data tugas pada filter ini.\nTarik ke bawah untuk menyegarkan.',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 84),
                          itemCount: daftarTampil.length,
                          itemBuilder: (context, index) {
                            final item = daftarTampil[index];
                            final adalahPembuat = item.pembuat.toLowerCase() ==
                                _todoService.walletAddress.toLowerCase();

                            return Card(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              child: ListTile(
                                leading: Icon(
                                  item.selesai
                                      ? Icons.check_circle
                                      : Icons.radio_button_unchecked,
                                  color: item.selesai
                                      ? Colors.green
                                      : Colors.grey,
                                ),
                                title: Text(
                                  item.judul,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    decoration: item.selesai
                                        ? TextDecoration.lineThrough
                                        : TextDecoration.none,
                                    color: item.selesai
                                        ? Colors.grey
                                        : Colors.black87,
                                  ),
                                ),
                                subtitle: Text(
                                  'ID #${item.id} • ${_formatWaktu(item.dibuat)}\n'
                                  'Pembuat: ${item.pembuat.substring(0, 6)}...${item.pembuat.substring(item.pembuat.length - 4)}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                isThreeLine: true,
                                trailing: item.selesai
                                    ? const Chip(
                                        label: Text('Selesai',
                                            style: TextStyle(fontSize: 11)),
                                      )
                                    : ElevatedButton(
                                        onPressed: (_statusTx ==
                                                    StatusTx.memproses ||
                                                !adalahPembuat)
                                            ? null
                                            : () => _kirimTandaiSelesai(item),
                                        child: const Text('Selesai'),
                                      ),
                              ),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed:
            _statusTx == StatusTx.memproses ? null : _tampilkanDialogTambahTugas,
        icon: const Icon(Icons.add),
        label: const Text('Tambah Tugas'),
      ),
    );
  }
}