import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_bluetooth_serial_plus/flutter_bluetooth_serial_plus.dart'
    as bt_plus;
import 'package:bluez/bluez.dart' as bz;
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import 'models.dart';

class PrinterService {
  static final PrinterService instance = PrinterService._internal();
  factory PrinterService() => instance;
  PrinterService._internal();

  bt_plus.BluetoothConnection? _btPlusConnection;
  bz.BlueZClient? _bluezClient;

  bool _isConnecting = false;
  bool _isConnected = false;

  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;

  final StreamController<bool> _connectionStreamController =
      StreamController<bool>.broadcast();
  Stream<bool> get connectionStream => _connectionStreamController.stream;

  Future<List<PrinterDevice>> getAvailableDevices() async {
    final List<PrinterDevice> devices = [];

    // ── Android Bluetooth (reliable with flutter_bluetooth_serial_plus)
    if (Platform.isAndroid) {
      try {
        final btDevices = await bt_plus.FlutterBluetoothSerial.instance
            .getBondedDevices();
        devices.addAll(
          btDevices.map(
            (d) => PrinterDevice(
              name: d.name ?? d.address,
              address: d.address,
              type: ConnectionType.bluetooth,
            ),
          ),
        );
      } catch (e) {
        debugPrint('Android BT discovery error: $e');
      }
    }

    // 1.5 Bluetooth (Desktop/Mobile)
    // Pivot to bluez for Linux. Windows/macOS would need another plugin if classic_serial is removed.
    if (Platform.isWindows || Platform.isMacOS) {
      // Placeholder: User removed bt_classic, so we can't use it here without the plugin.
      debugPrint(
        'Bluetooth Classic not implemented for Windows/macOS in this version.',
      );
    }

    // 1.6 Linux Bluetooth (via bluez)
    if (Platform.isLinux) {
      try {
        _bluezClient ??= bz.BlueZClient();
        // connect() can be called multiple times, it just ensures connection
        await _bluezClient!.connect();

        final bluezDevices = _bluezClient!.devices;
        for (final device in bluezDevices) {
          // Check if device supports SPP (Serial Port Profile)
          // UUID for SPP: 00001101-0000-1000-8000-00805f9b34fb
          bool hasSpp = device.uuids.any((u) => u.toString().contains('1101'));

          if (hasSpp ||
              device.name?.toLowerCase().contains('printer') == true) {
            devices.add(
              PrinterDevice(
                name: '${device.alias} (BlueZ)',
                address: device.address,
                type: ConnectionType.bluetooth,
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('BlueZ discovery error: $e');
      }
    }

    // ── Linux: prefer Bluetooth SPP via /dev/rfcomm* (most stable for thermal printers)
    if (Platform.isLinux) {
      try {
        final devDir = Directory('/dev');
        final rfcommFiles = devDir
            .listSync(followLinks: false)
            .where((f) => f.path.contains('rfcomm'))
            .toList();

        for (final file in rfcommFiles) {
          devices.add(
            PrinterDevice(
              name: 'Bluetooth Printer: ${file.path.split('/').last}',
              address: file.path,
              type: ConnectionType
                  .serial, // ← treat as serial → uses _printViaSerial
            ),
          );
        }
      } catch (e) {
        debugPrint('rfcomm discovery error: $e');
      }
    }

    // ── Serial ports (USB-serial adapters, some Bluetooth bindings appear here too)
    try {
      final portNames = SerialPort.availablePorts;
      debugPrint('Serial ports found: $portNames');

      for (final name in portNames) {
        final port = SerialPort(name);
        String desc = port.description ?? '';
        if (port.manufacturer?.isNotEmpty == true)
          desc += ' (${port.manufacturer})';

        devices.add(
          PrinterDevice(
            name: 'Serial: $name ${desc.isNotEmpty ? '— $desc' : ''}',
            address: name,
            type: ConnectionType.serial,
          ),
        );
      }
    } catch (e) {
      debugPrint('Serial discovery error: $e');
    }

    // ── Linux USB direct (usblp / usbLP)
    if (Platform.isLinux) {
      try {
        final usbDir = Directory('/dev/usb');
        if (usbDir.existsSync()) {
          final lpFiles = usbDir
              .listSync()
              .where((e) => e.path.contains('lp'))
              .toList();
          for (final f in lpFiles) {
            devices.add(
              PrinterDevice(
                name: 'USB Printer: ${f.path.split('/').last}',
                address: f.path,
                type: ConnectionType.usb,
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('usblp discovery error: $e');
      }
    }

    return devices;
  }

  Future<bool> printImageBytes({
    required PrinterDevice device,
    required Uint8List imageBytes,
    int paperWidth = 384,
    int baudRate = 9600,
  }) async {
    if (_isConnecting || _isConnected) return false;

    final bytes = _preparePrintBytes(imageBytes, paperWidth);
    if (bytes == null) return false;

    try {
      _updateState(connecting: true);

      if (device.type == ConnectionType.bluetooth) {
        if (Platform.isAndroid) {
          return await _printViaBluetoothAndroid(device.address, bytes);
        } else {
          // On Linux/Windows: try classic first → fallback to serial (rfcomm)
          final btSuccess = await _printViaBluetoothDesktop(
            device.address,
            bytes,
          );
          if (btSuccess) return true;

          // Most Linux Bluetooth printers appear as /dev/rfcomm0 after pairing
          final rfcommPath = _findRfcommPath(device.address);
          if (rfcommPath != null) {
            debugPrint('Falling back to rfcomm serial: $rfcommPath');
            return await _printViaSerial(rfcommPath, bytes, baudRate: baudRate);
          }

          return false;
        }
      } else if (device.type == ConnectionType.usb) {
        return await _printViaUsb(device.address, bytes);
      } else {
        return await _printViaSerial(device.address, bytes, baudRate: baudRate);
      }
    } finally {
      _updateState(connected: false);
    }
  }

  String? _findRfcommPath(String btAddress) {
    if (!Platform.isLinux) return null;
    try {
      final dev = Directory('/dev');
      final candidates = dev.listSync().where((f) => f.path.contains('rfcomm'));
      // In real use → you could match by udevadm info or ls -l to see bound MAC
      // For simplicity: return first rfcomm if only one exists
      if (candidates.isNotEmpty) return candidates.first.path;
    } catch (_) {}
    return null;
  }

  Uint8List? _preparePrintBytes(Uint8List imageBytes, int paperWidth) {
    try {
      final original = img.decodeImage(imageBytes);
      if (original == null) return null;

      final targetWidth = original.width > paperWidth
          ? paperWidth
          : original.width;
      final resized = img.copyResize(original, width: targetWidth);
      final gray = img.grayscale(resized);

      final List<int> bytes = [];
      bytes.addAll([0x1B, 0x40]); // Init / reset
      bytes.addAll([0x1B, 0x61, 0x01]); // Center align
      bytes.addAll(_imageToRaster(gray));
      bytes.addAll([0x0A, 0x0A, 0x0A]); // 3 line feeds
      bytes.addAll([0x1D, 0x56, 0x00]); // Full cut (if supported)

      return Uint8List.fromList(bytes);
    } catch (e) {
      debugPrint('Image prepare error: $e');
      return null;
    }
  }

  Future<bool> _printViaBluetoothAndroid(
    String address,
    Uint8List bytes,
  ) async {
    try {
      _btPlusConnection = await bt_plus.BluetoothConnection.toAddress(
        address,
      ).timeout(const Duration(seconds: 12));
      _updateState(connected: true);

      _btPlusConnection!.output.add(bytes);
      await _btPlusConnection!.output.allSent;
      await Future.delayed(const Duration(milliseconds: 2200));
      return true;
    } catch (e) {
      debugPrint('Android BT print failed: $e');
      return false;
    } finally {
      _btPlusConnection?.dispose();
      _btPlusConnection = null;
    }
  }

  Future<bool> _printViaBluetoothDesktop(
    String address,
    Uint8List bytes,
  ) async {
    if (Platform.isLinux) {
      // On Linux, the bluez package doesn't easily provide a way to open an SPP socket directly.
      // We rely on the rfcomm device fallback which is already handled in printImageBytes.
      // However, if we are here, we can try to find the rfcomm path for this address.
      final rfcommPath = _findRfcommPath(address);
      if (rfcommPath != null) {
        return await _printViaSerial(rfcommPath, bytes);
      }
      debugPrint(
        'No rfcomm device found for $address. Please pair and bind using "rfcomm bind".',
      );
      return false;
    }

    // Windows/macOS Placeholder
    debugPrint('Bluetooth printing not implemented for Windows/macOS.');
    return false;
  }

  Future<bool> _printViaUsb(String devicePath, Uint8List bytes) async {
    try {
      debugPrint('Writing to USB: $devicePath');
      final file = File(devicePath);
      await file.writeAsBytes(bytes, mode: FileMode.writeOnly);
      await Future.delayed(const Duration(milliseconds: 1200));
      return true;
    } catch (e) {
      debugPrint('USB write error: $e');
      debugPrint(
        'Hint (Linux): sudo chmod 666 $devicePath  or add user to lp group',
      );
      return false;
    }
  }

  Future<bool> _printViaSerial(
    String portName,
    Uint8List bytes, {
    int baudRate = 9600,
  }) async {
    final port = SerialPort(portName);
    try {
      debugPrint('Opening $portName @ $baudRate baud');

      if (!port.openReadWrite()) {
        final err = SerialPort.lastError;
        throw Exception(
          'Cannot open $portName → ${err?.message ?? "unknown"}\n'
          '→ Linux fix: sudo chmod 666 $portName   OR   sudo usermod -aG dialout \$USER (then relogin)',
        );
      }

      final config = port.config;
      config.baudRate = baudRate;
      config.bits = 8;
      config.parity = SerialPortParity.none;
      config.stopBits = 1;

      try {
        port.config = config;
      } catch (e) {
        debugPrint(
          'Warning: Could not set port config (may be expected for rfcomm): $e',
        );
      }

      final written = port.write(bytes);
      if (written <= 0) {
        throw Exception('Write returned $written bytes');
      }

      debugPrint('Wrote $written bytes to $portName. Draining...');
      port.drain();
      debugPrint('Drain complete.');
      return true;
    } catch (e) {
      debugPrint('Serial error: $e');
      return false;
    } finally {
      port.close();
    }
  }

  void _updateState({bool? connecting, bool? connected}) {
    if (connecting != null) _isConnecting = connecting;
    if (connected != null) _isConnected = connected;
    _connectionStreamController.add(_isConnected);
  }

  List<int> _imageToRaster(img.Image image) {
    final List<int> bytes = [0x1D, 0x76, 0x30, 0x00]; // GS v 0 m=0

    final wBytes = (image.width + 7) ~/ 8;
    bytes.addAll([wBytes & 0xFF, (wBytes >> 8) & 0xFF]);
    bytes.addAll([image.height & 0xFF, (image.height >> 8) & 0xFF]);

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x += 8) {
        int byte = 0;
        for (int bit = 0; bit < 8; bit++) {
          if (x + bit < image.width) {
            final lum = img.getLuminance(image.getPixel(x + bit, y));
            if (lum < 128) byte |= (1 << (7 - bit));
          }
        }
        bytes.add(byte);
      }
    }
    return bytes;
  }

  void dispose() {
    _connectionStreamController.close();
    _btPlusConnection?.dispose();
    _bluezClient?.close();
  }
}
