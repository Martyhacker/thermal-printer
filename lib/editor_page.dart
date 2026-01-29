import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter_barcode_scanner_plus/flutter_barcode_scanner_plus.dart';
import 'models.dart';
import 'template_provider.dart';

class EditorPage extends StatefulWidget {
  final TemplateModel template;
  final bool isNew;

  const EditorPage({super.key, required this.template, this.isNew = false});

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  late String _name;
  late List<BaseWidgetModel> _widgets;
  BaseWidgetModel? _selectedWidget;
  late double _paperWidth;
  bool _showGrid = true;
  BaseWidgetModel? _clipboard;

  late TextEditingController _nameController;
  late TextEditingController _textController;
  late TextEditingController _barcodeDataController;

  @override
  void initState() {
    super.initState();
    _name = widget.template.name;
    _widgets = List.from(widget.template.widgets);
    _paperWidth = widget.template.paperWidth;
    _nameController = TextEditingController(text: _name);
    _textController = TextEditingController();
    _barcodeDataController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _textController.dispose();
    _barcodeDataController.dispose();
    super.dispose();
  }

  void _save() {
    final updatedTemplate = widget.template.copyWith(
      name: _name,
      widgets: _widgets,
      paperWidth: _paperWidth,
    );

    if (widget.isNew) {
      Provider.of<TemplateProvider>(
        context,
        listen: false,
      ).addTemplate(updatedTemplate);
    } else {
      Provider.of<TemplateProvider>(
        context,
        listen: false,
      ).updateTemplate(updatedTemplate);
    }

    Navigator.pop(context);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Template saved!')));
  }

  void _addText() {
    setState(() {
      final newWidget = TextWidgetModel(
        id: const Uuid().v4(),
        x: 20,
        y: 50,
        text: 'Tap to edit',
      );
      _widgets.add(newWidget);
      _onWidgetSelected(newWidget);
    });
  }

  Future<void> _addImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        final newWidget = ImageWidgetModel(
          id: const Uuid().v4(),
          x: 20,
          y: 50,
          imagePath: pickedFile.path,
        );
        _widgets.add(newWidget);
        _onWidgetSelected(newWidget);
      });
    }
  }

  void _addBarcode() {
    setState(() {
      final newWidget = BarcodeWidgetModel(
        id: const Uuid().v4(),
        x: 20,
        y: 50,
        data: '12345678',
        barcodeType: Barcode.qrCode(),
      );
      _widgets.add(newWidget);
      _onWidgetSelected(newWidget);
    });
  }

  Future<void> _scanBarcodeForSelected() async {
    if (_selectedWidget is! BarcodeWidgetModel) return;
    try {
      final result = await FlutterBarcodeScanner.scanBarcode(
        '#ff6666',
        'Cancel',
        true,
        ScanMode.DEFAULT,
      );
      if (result != '-1') {
        setState(() {
          (_selectedWidget as BarcodeWidgetModel).data = result;
          _barcodeDataController.text = result;
        });
      }
    } catch (e) {
      debugPrint('Scan error: $e');
    }
  }

  void _onWidgetSelected(BaseWidgetModel? w) {
    setState(() {
      _selectedWidget = w;
      if (w is TextWidgetModel) {
        _textController.text = w.text;
      } else if (w is BarcodeWidgetModel) {
        _barcodeDataController.text = w.data;
      }
    });
  }

  void _copySelected() {
    if (_selectedWidget == null) return;
    final w = _selectedWidget!;
    final id = const Uuid().v4();

    if (w is TextWidgetModel) {
      _clipboard = TextWidgetModel(
        id: id,
        x: w.x,
        y: w.y,
        text: w.text,
        fontSize: w.fontSize,
        fontWeight: w.fontWeight,
        textAlign: w.textAlign,
      );
    } else if (w is ImageWidgetModel) {
      _clipboard = ImageWidgetModel(
        id: id,
        x: w.x,
        y: w.y,
        imagePath: w.imagePath,
        width: w.width,
        height: w.height,
      );
    } else if (w is BarcodeWidgetModel) {
      _clipboard = BarcodeWidgetModel(
        id: id,
        x: w.x,
        y: w.y,
        data: w.data,
        width: w.width,
        height: w.height,
        barcodeType: w.barcodeType,
      );
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied'), duration: Duration(seconds: 1)),
    );
  }

  void _paste() {
    if (_clipboard == null) return;
    setState(() {
      final copy = _clipboard!;
      final id = const Uuid().v4();
      BaseWidgetModel newWidget;

      if (copy is TextWidgetModel) {
        newWidget = TextWidgetModel(
          id: id,
          x: copy.x + 10,
          y: copy.y + 10,
          text: copy.text,
          fontSize: copy.fontSize,
          fontWeight: copy.fontWeight,
          textAlign: copy.textAlign,
        );
      } else if (copy is ImageWidgetModel) {
        newWidget = ImageWidgetModel(
          id: id,
          x: copy.x + 10,
          y: copy.y + 10,
          imagePath: copy.imagePath,
          width: copy.width,
          height: copy.height,
        );
      } else {
        final b = copy as BarcodeWidgetModel;
        newWidget = BarcodeWidgetModel(
          id: id,
          x: b.x + 10,
          y: b.y + 10,
          data: b.data,
          width: b.width,
          height: b.height,
          barcodeType: b.barcodeType,
        );
      }

      _widgets.add(newWidget);
      _onWidgetSelected(newWidget);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _nameController,
          onChanged: (val) => _name = val,
          style: const TextStyle(color: Colors.black, fontSize: 18),
          decoration: const InputDecoration(
            hintText: 'Template Name',
            border: InputBorder.none,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(_showGrid ? Icons.grid_on : Icons.grid_off),
            onPressed: () => setState(() => _showGrid = !_showGrid),
            tooltip: 'Toggle Grid',
          ),
          _buildPaperSizeToggle(),
          IconButton(icon: const Icon(Icons.check), onPressed: _save),
        ],
      ),
      body: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyC, control: true):
              _copySelected,
          const SingleActivator(LogicalKeyboardKey.keyV, control: true): _paste,
        },
        child: Focus(
          autofocus: true,
          child: Column(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _onWidgetSelected(null),
                  child: Center(
                    child: SingleChildScrollView(
                      child: Container(
                        width: _paperWidth,
                        height: 600,
                        margin: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(
                            color: Colors.grey[300]!,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 15,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: ClipRect(
                          child: Stack(
                            children: [
                              if (_showGrid)
                                Positioned.fill(
                                  child: CustomPaint(painter: GridPainter()),
                                ),
                              ..._widgets.map((w) => _buildDraggableWidget(w)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (_selectedWidget != null) _buildToolbar(),
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaperSizeToggle() {
    return PopupMenuButton<double>(
      icon: const Icon(Icons.straighten),
      tooltip: 'Paper Size',
      onSelected: (val) {
        setState(() {
          _paperWidth = val;
        });
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 384.0, child: Text('58mm (384px)')),
        const PopupMenuItem(value: 576.0, child: Text('80mm (576px)')),
      ],
    );
  }

  Widget _buildDraggableWidget(BaseWidgetModel w) {
    final isSelected = _selectedWidget?.id == w.id;

    return Positioned(
      left: w.x,
      top: w.y,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            w.x = (w.x + details.delta.dx).clamp(0, _paperWidth - 50);
            w.y = (w.y + details.delta.dy).clamp(0, 550);
          });
        },
        onTap: () => _onWidgetSelected(w),
        child: Container(
          decoration: BoxDecoration(
            border: isSelected
                ? Border.all(color: Colors.blue, width: 2)
                : null,
          ),
          child: _renderWidgetContent(w),
        ),
      ),
    );
  }

  Widget _renderWidgetContent(BaseWidgetModel w) {
    if (w is TextWidgetModel) {
      return Text(
        w.text,
        style: TextStyle(fontSize: w.fontSize, fontWeight: w.fontWeight),
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

  Widget _buildToolbar() {
    final w = _selectedWidget!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey[200],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (w is TextWidgetModel) ...[
                Expanded(
                  child: TextField(
                    controller: _textController,
                    onChanged: (val) {
                      // Only call setState if we need to update the canvas,
                      // and ensure we don't reset the controller text which would jump the cursor.
                      w.text = val;
                      setState(() {});
                    },
                    decoration: const InputDecoration(
                      hintText: 'Enter text',
                      isDense: true,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.text_increase),
                  onPressed: () => setState(() => w.fontSize += 2),
                ),
                IconButton(
                  icon: const Icon(Icons.text_decrease),
                  onPressed: () => setState(
                    () => w.fontSize = (w.fontSize - 2).clamp(8, 72),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.format_bold,
                    color: w.fontWeight == FontWeight.bold ? Colors.blue : null,
                  ),
                  onPressed: () {
                    setState(() {
                      w.fontWeight = w.fontWeight == FontWeight.bold
                          ? FontWeight.normal
                          : FontWeight.bold;
                    });
                  },
                ),
              ],
              if (w is BarcodeWidgetModel) ...[
                Expanded(
                  child: TextField(
                    controller: _barcodeDataController,
                    onChanged: (val) {
                      setState(() => w.data = val);
                    },
                    decoration: const InputDecoration(
                      hintText: 'Barcode data',
                      isDense: true,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.qr_code_scanner),
                  onPressed: _scanBarcodeForSelected,
                ),
                DropdownButton<String>(
                  value: _getBarcodeDisplayName(w.barcodeType),
                  items: ['QR Code', 'Code 128', 'EAN 8', 'EAN 13'].map((type) {
                    return DropdownMenuItem(value: type, child: Text(type));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(
                        () => w.barcodeType =
                            BarcodeWidgetModel.barcodeFromType(val),
                      );
                    }
                  },
                ),
              ],
              if (w is ImageWidgetModel || w is BarcodeWidgetModel) ...[
                const Text('Size: '),
                Expanded(
                  child: Slider(
                    value: (w is ImageWidgetModel)
                        ? w.width
                        : (w as BarcodeWidgetModel).width,
                    min: 20,
                    max: 300,
                    onChanged: (val) {
                      setState(() {
                        if (w is ImageWidgetModel) {
                          w.width = val;
                          w.height = val;
                        } else if (w is BarcodeWidgetModel) {
                          w.width = val;
                          w.height = val * 0.6; // Maintain some ratio
                        }
                      });
                    },
                  ),
                ),
              ],
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () {
                  setState(() {
                    _widgets.removeWhere((item) => item.id == w.id);
                    _selectedWidget = null;
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getBarcodeDisplayName(Barcode barcode) {
    final name = barcode.name;
    if (name.contains('QR')) return 'QR Code';
    if (name.contains('128')) return 'Code 128';
    if (name.contains('EAN 8') || (name.contains('8') && !name.contains('128')))
      return 'EAN 8';
    if (name.contains('EAN 13') || name.contains('13')) return 'EAN 13';
    return 'QR Code';
  }

  Widget _buildActionButtons() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          ElevatedButton.icon(
            onPressed: _addText,
            icon: const Icon(Icons.text_fields),
            label: const Text('Add Text'),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _addImage,
            icon: const Icon(Icons.image),
            label: const Text('Add Image'),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _addBarcode,
            icon: const Icon(Icons.qr_code),
            label: const Text('Add Barcode'),
          ),
        ],
      ),
    );
  }
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.green[100]!
      ..strokeWidth = 1;

    const step = 20.0;

    for (double i = step; i < size.width; i += step) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }

    for (double i = step; i < size.height; i += step) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
