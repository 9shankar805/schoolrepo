import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({Key? key}) : super(key: key);

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final ApiService _api = ApiService();
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    returnImage: false,
  );
  final _inputController = TextEditingController();

  String _gateType = 'entry'; // entry | exit
  bool _isVerifying = false;
  bool _isScannerActive = true;
  Map<String, dynamic>? _verifiedUser;
  String? _errorMessage;

  @override
  void dispose() {
    _scannerController.dispose();
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _verify(String code) async {
    if (code.trim().isEmpty) return;

    // Pause scanner while verifying to avoid duplicate scans
    _scannerController.stop();
    setState(() {
      _isVerifying = true;
      _isScannerActive = false;
      _errorMessage = null;
      _verifiedUser = null;
    });

    final res =
        await _api.verifyGateQr(code.trim(), gateType: _gateType);

    setState(() {
      _isVerifying = false;
      if (res.success && res.data != null) {
        _verifiedUser = res.data;
      } else {
        _errorMessage = res.message;
      }
    });
  }

  void _resetScan() {
    setState(() {
      _verifiedUser = null;
      _errorMessage = null;
      _isScannerActive = true;
      _inputController.clear();
    });
    _scannerController.start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          'Campus Gate QR Scanner',
          style: GoogleFonts.plusJakartaSans(
              fontSize: 18, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _scannerController.torchEnabled
                  ? Icons.flash_on_rounded
                  : Icons.flash_off_rounded,
              color: _scannerController.torchEnabled
                  ? AppTheme.gold
                  : AppTheme.textMuted,
            ),
            tooltip: 'Toggle Torch',
            onPressed: () => _scannerController.toggleTorch(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Gate mode selector
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Center(
                        child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.login_rounded, size: 14),
                        SizedBox(width: 4),
                        Text('Gate Entry'),
                      ],
                    )),
                    selected: _gateType == 'entry',
                    selectedColor: AppTheme.emeraldLight,
                    onSelected: (_) => setState(() => _gateType = 'entry'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ChoiceChip(
                    label: const Center(
                        child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.logout_rounded, size: 14),
                        SizedBox(width: 4),
                        Text('Early Exit'),
                      ],
                    )),
                    selected: _gateType == 'exit',
                    selectedColor: AppTheme.goldLight,
                    onSelected: (_) => setState(() => _gateType = 'exit'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Scanner viewport
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                height: 220,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: _isScannerActive
                          ? AppTheme.royalBlue
                          : AppTheme.borderLight,
                      width: 2),
                ),
                child: _isScannerActive
                    ? Stack(
                        alignment: Alignment.center,
                        children: [
                          MobileScanner(
                            controller: _scannerController,
                            onDetect: (capture) {
                              final barcode =
                                  capture.barcodes.firstOrNull;
                              if (barcode?.rawValue != null) {
                                _verify(barcode!.rawValue!);
                              }
                            },
                          ),
                          // Scanner overlay frame
                          Container(
                            width: 160,
                            height: 160,
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: AppTheme.emerald, width: 2.5),
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          // Corner decorations
                          ...['tl', 'tr', 'bl', 'br'].map((pos) {
                            final isTop = pos.startsWith('t');
                            final isLeft = pos.endsWith('l');
                            return Positioned(
                              top: isTop ? 29 : null,
                              bottom: isTop ? null : 29,
                              left: isLeft ? 99 : null,
                              right: isLeft ? null : 99,
                              child: Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  border: Border(
                                    top: isTop
                                        ? const BorderSide(
                                            color: Colors.white,
                                            width: 3)
                                        : BorderSide.none,
                                    bottom: !isTop
                                        ? const BorderSide(
                                            color: Colors.white,
                                            width: 3)
                                        : BorderSide.none,
                                    left: isLeft
                                        ? const BorderSide(
                                            color: Colors.white,
                                            width: 3)
                                        : BorderSide.none,
                                    right: !isLeft
                                        ? const BorderSide(
                                            color: Colors.white,
                                            width: 3)
                                        : BorderSide.none,
                                  ),
                                ),
                              ),
                            );
                          }),
                          Positioned(
                            bottom: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(20)),
                              child: Text(
                                'Align Student / Staff QR Badge',
                                style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white, fontSize: 11),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.qr_code_scanner_rounded,
                                color: Colors.white38, size: 56),
                            const SizedBox(height: 8),
                            Text(
                              'Scanner paused',
                              style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white54, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // Manual entry
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    decoration: InputDecoration(
                      hintText: 'Enter Student ID, Roll, or QR Code',
                      fillColor: Colors.white,
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: AppTheme.borderLight),
                      ),
                    ),
                    onSubmitted: _verify,
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _isVerifying
                      ? null
                      : () => _verify(_inputController.text),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                  ),
                  child: _isVerifying
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Verify'),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Error card
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.crimsonLight,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.crimson),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: AppTheme.crimson),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text(_errorMessage!,
                            style:
                                const TextStyle(color: AppTheme.crimson))),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 16),
                  label: const Text('Scan Again'),
                  onPressed: _resetScan,
                ),
              ),
            ],

            // Verified user card
            if (_verifiedUser != null) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.emerald, width: 2),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4))
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                              color: AppTheme.emeraldLight,
                              borderRadius: BorderRadius.circular(8)),
                          child: const Row(
                            children: [
                              Icon(Icons.verified,
                                  size: 14, color: AppTheme.emerald),
                              SizedBox(width: 4),
                              Text('VERIFIED BADGE',
                                  style: TextStyle(
                                      color: AppTheme.emerald,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11)),
                            ],
                          ),
                        ),
                        Text(
                          _verifiedUser!['timestamp'] ?? '',
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _verifiedUser!['name'] ?? '',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      '${_verifiedUser!['class_section'] ?? ''} • Roll #${_verifiedUser!['roll_no'] ?? '—'}',
                      style: const TextStyle(
                          fontSize: 13, color: AppTheme.textMuted),
                    ),
                    const Divider(height: 24),
                    if (_verifiedUser!['has_dues'] == true) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: AppTheme.crimsonLight,
                            borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded,
                                color: AppTheme.crimson, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Fee Dues: NPR ${(_verifiedUser!['dues_amount'] as num?)?.toInt() ?? 0} pending',
                              style: const TextStyle(
                                  color: AppTheme.crimson,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (_verifiedUser!['guardian_phone'] != null)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading:
                            const Icon(Icons.phone, color: AppTheme.royalBlue),
                        title: const Text('Guardian Phone',
                            style: TextStyle(
                                fontSize: 12, color: AppTheme.textMuted)),
                        subtitle:
                            Text(_verifiedUser!['guardian_phone']),
                        trailing: IconButton(
                          icon: const Icon(Icons.call,
                              color: AppTheme.emerald),
                          onPressed: () => launchUrl(Uri.parse(
                              'tel:${_verifiedUser!['guardian_phone']}')),
                        ),
                      ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(
                            Icons.qr_code_scanner_rounded,
                            size: 16),
                        label: const Text('Scan Next Badge'),
                        onPressed: _resetScan,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
