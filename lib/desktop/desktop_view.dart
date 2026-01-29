import 'dart:io';
import 'dart:typed_data';
import 'package:fluent_ui/fluent_ui.dart' hide FontWeight, TextAlign;
import 'package:screenshot/screenshot.dart';
import 'package:barcode_widget/barcode_widget.dart' as bc;
import '../models.dart';
import '../printer_service.dart';

class DesktopViewPage extends StatefulWidget {
  final TemplateModel template;

  const DesktopViewPage({super.key, required this.template});

  @override
  State<DesktopViewPage> createState() => _DesktopViewPageState();
}

class _DesktopViewPageState extends State<DesktopViewPage> {
  final ScreenshotController _screenshotController = ScreenshotController();
  final PrinterService _printerService = PrinterService.instance;

  List<PrinterDevice> _devices = [];
  PrinterDevice? _selectedDevice;
  bool _isScanning = false;
  bool _isPrinting = false;
  int _baudRate = 9600;

  @override
  void initState() {
    super.initState();
    _scanDevices();
  }

  Future<void> _scanDevices() async {
    setState(() => _isScanning = true);
    try {
      final devices = await _printerService.getAvailableDevices();
      setState(() {
        _devices = devices;
        if (_devices.isNotEmpty) _selectedDevice = _devices.first;
      });
    } catch (e) {
      debugPrint('Error getting devices: $e');
    } finally {
      setState(() => _isScanning = false);
    }
  }

  Future<void> _print() async {
    if (_selectedDevice == null) {
      showDialog(
        context: context,
        builder: (context) => ContentDialog(
          title: const Text('No Printer'),
          content: const Text('Please select a printer first!'),
          actions: [
            Button(
              child: const Text('OK'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
      return;
    }

    setState(() => _isPrinting = true);

    try {
      final Uint8List? imageBytes = await _screenshotController.capture(
        delay: const Duration(milliseconds: 200),
      );

      if (imageBytes != null) {
        final success = await _printerService.printImageBytes(
          device: _selectedDevice!,
          imageBytes: imageBytes,
          paperWidth: widget.template.paperWidth.toInt(),
          baudRate: _baudRate,
        );

        if (!mounted) return;

        if (success) {
          displayInfoBar(
            context,
            builder: (context, close) {
              return const InfoBar(
                title: Text('Success'),
                content: Text('Print job sent successfully.'),
                severity: InfoBarSeverity.success,
              );
            },
          );
        } else {
          throw Exception(
            'Failed to print. Check connection or port permissions.',
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => ContentDialog(
          title: const Text('Error'),
          content: Text('$e'),
          actions: [
            Button(
              child: const Text('OK'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isPrinting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      header: PageHeader(
        title: Text(widget.template.name),
        leading: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: IconButton(
            icon: const Icon(FluentIcons.back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        commandBar: CommandBar(
          mainAxisAlignment: MainAxisAlignment.end,
          primaryItems: [
            CommandBarButton(
              icon: const Icon(FluentIcons.refresh),
              label: const Text('Refresh'),
              onPressed: _scanDevices,
            ),
          ],
        ),
      ),
      content: RepaintBoundary(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    _selectedDevice?.type == ConnectionType.bluetooth
                        ? FluentIcons.bluetooth
                        : _selectedDevice?.type == ConnectionType.usb
                        ? FluentIcons.usb
                        : FluentIcons.usb, // fallback for serial
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _isScanning
                        ? const ProgressBar()
                        : ComboBox<PrinterDevice>(
                            isExpanded: true,
                            value: _selectedDevice,
                            placeholder: const Text('Select Printer'),
                            items: _devices.map((device) {
                              return ComboBoxItem(
                                value: device,
                                child: Text(device.name),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() => _selectedDevice = val);
                            },
                          ),
                  ),
                  if (_selectedDevice?.type == ConnectionType.serial) ...[
                    const SizedBox(width: 12),
                    ComboBox<int>(
                      placeholder: const Text('Baud'),
                      value: _baudRate,
                      items: [9600, 19200, 38400, 57600, 115200].map((rate) {
                        return ComboBoxItem(value: rate, child: Text('$rate'));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _baudRate = val);
                      },
                    ),
                  ],
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  vertical: 40,
                  horizontal: 16,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: widget.template.paperWidth,
                    ),
                    child: Screenshot(
                      controller: _screenshotController,
                      child: Container(
                        width: widget.template.paperWidth,
                        height: 500,
                        color: Colors.white,
                        child: Stack(
                          children: widget.template.widgets.map((w) {
                            return Positioned(
                              left: w.x,
                              top: w.y,
                              child: _renderWidgetContent(w),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                onPressed: _isPrinting ? null : _print,
                child: Container(
                  width: double.infinity,
                  height: 40,
                  alignment: Alignment.center,
                  child: _isPrinting
                      ? const ProgressRing()
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(FluentIcons.print),
                            SizedBox(width: 8),
                            Text('Print Template'),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _renderWidgetContent(BaseWidgetModel w) {
    if (w is TextWidgetModel) {
      return Text(
        w.text,
        style: TextStyle(
          fontSize: w.fontSize,
          fontWeight: w.fontWeight,
          color: Colors.black,
        ),
      );
    } else if (w is ImageWidgetModel) {
      return Image.file(
        File(w.imagePath),
        width: w.width,
        height: w.height,
        fit: BoxFit.contain,
      );
    } else if (w is BarcodeWidgetModel) {
      return bc.BarcodeWidget(
        barcode: w.barcodeType,
        data: w.data,
        width: w.width,
        height: w.height,
      );
    }
    return const SizedBox();
  }
}
