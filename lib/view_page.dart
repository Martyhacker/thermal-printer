import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'models.dart';
import 'printer_service.dart';

class ViewPage extends StatefulWidget {
  final TemplateModel template;

  const ViewPage({super.key, required this.template});

  @override
  State<ViewPage> createState() => _ViewPageState();
}

class _ViewPageState extends State<ViewPage> {
  final ScreenshotController _screenshotController = ScreenshotController();
  final PrinterService _printerService = PrinterService.instance;

  List<PrinterDevice> _devices = [];
  PrinterDevice? _selectedDevice;
  bool _isScanning = false;
  bool _isPrinting = false;

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a printer first!')),
      );
      return;
    }

    setState(() => _isPrinting = true);

    try {
      final Uint8List? imageBytes = await _screenshotController.capture(
        delay: const Duration(milliseconds: 10),
      );

      if (imageBytes != null) {
        final success = await _printerService.printImageBytes(
          device: _selectedDevice!,
          imageBytes: imageBytes,
          paperWidth: widget.template.paperWidth.toInt(),
        );

        if (!mounted) return;

        if (success) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Print successful!')));
        } else {
          throw Exception('Failed to print');
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _isPrinting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.template.name),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _scanDevices),
        ],
      ),
      body: Column(
        children: [
          // Device Selection
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  _selectedDevice?.type == ConnectionType.bluetooth
                      ? Icons.bluetooth
                      : Icons.usb,
                  color: Colors.blue,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _isScanning
                      ? const LinearProgressIndicator()
                      : DropdownButton<PrinterDevice>(
                          isExpanded: true,
                          value: _selectedDevice,
                          hint: const Text('Select Printer'),
                          items: _devices.map((device) {
                            return DropdownMenuItem(
                              value: device,
                              child: Text(device.name),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() => _selectedDevice = val);
                          },
                        ),
                ),
              ],
            ),
          ),

          // Preview Canvas
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: widget.template.paperWidth,
                  ),
                  child: Screenshot(
                    controller: _screenshotController,
                    child: Container(
                      width: widget.template.paperWidth,
                      height: 500, // Sample height, can be dynamic
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

          // Print Button
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: _isPrinting ? null : _print,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              icon: _isPrinting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.print),
              label: Text(_isPrinting ? 'Printing...' : 'Print Template'),
            ),
          ),
        ],
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
          color: Colors.black, // Force black for thermal printing
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
      return BarcodeWidget(
        barcode: w.barcodeType,
        data: w.data,
        width: w.width,
        height: w.height,
      );
    }
    return const SizedBox();
  }
}
