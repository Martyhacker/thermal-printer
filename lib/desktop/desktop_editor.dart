import 'dart:io';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:barcode_widget/barcode_widget.dart' as bc;
import '../models.dart';
import '../template_provider.dart';

class DesktopEditorPage extends StatefulWidget {
  final TemplateModel template;
  final bool isNew;

  const DesktopEditorPage({
    super.key,
    required this.template,
    this.isNew = false,
  });

  @override
  State<DesktopEditorPage> createState() => _DesktopEditorPageState();
}

class _DesktopEditorPageState extends State<DesktopEditorPage> {
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
    // Fluent doesn't have SnackBar exactly, but we can use infoBar or just pop
  }

  void _addText() {
    setState(() {
      final newWidget = TextWidgetModel(
        id: const Uuid().v4(),
        x: 20,
        y: 50,
        text: 'New Text',
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
        barcodeType: bc.Barcode.qrCode(),
      );
      _widgets.add(newWidget);
      _onWidgetSelected(newWidget);
    });
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

  void _deleteSelected() {
    if (_selectedWidget == null) return;
    setState(() {
      _widgets.removeWhere((item) => item.id == _selectedWidget!.id);
      _selectedWidget = null;
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
    return ScaffoldPage(
      header: PageHeader(
        leading: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: IconButton(
            icon: const Icon(FluentIcons.back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: TextBox(
          controller: _nameController,
          onChanged: (val) => _name = val,
          placeholder: 'Template Name',
        ),
        commandBar: CommandBar(
          mainAxisAlignment: MainAxisAlignment.end,
          primaryItems: [
            CommandBarButton(
              icon: Icon(
                _showGrid ? FluentIcons.grid_view_medium : FluentIcons.view_all,
              ),
              label: const Text('Grid'),
              onPressed: () => setState(() => _showGrid = !_showGrid),
            ),
            CommandBarButton(
              icon: const Icon(FluentIcons.save),
              label: const Text('Save'),
              onPressed: _save,
            ),
          ],
          secondaryItems: [
            CommandBarButton(
              icon: const Icon(FluentIcons.size_legacy),
              label: const Text('58mm (Small)'),
              onPressed: () => setState(() => _paperWidth = 384.0),
            ),
            CommandBarButton(
              icon: const Icon(FluentIcons.size_legacy),
              label: const Text('80mm (Large)'),
              onPressed: () => setState(() => _paperWidth = 576.0),
            ),
            CommandBarSeparator(),
            CommandBarButton(
              icon: const Icon(FluentIcons.export),
              label: const Text('Export Template'),
              onPressed: () async {
                await context.read<TemplateProvider>().exportTemplate(
                  widget.template.copyWith(
                    name: _name,
                    widgets: _widgets,
                    paperWidth: _paperWidth,
                  ),
                );
              },
            ),
          ],
        ),
      ),
      content: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyC, control: true):
              _copySelected,
          const SingleActivator(LogicalKeyboardKey.keyV, control: true): _paste,
          const SingleActivator(LogicalKeyboardKey.delete): _deleteSelected,
          const SingleActivator(LogicalKeyboardKey.backspace): _deleteSelected,
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
                          border: Border.all(color: Colors.grey[100], width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 15,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: ClipRect(
                          child: RepaintBoundary(
                            child: Stack(
                              children: [
                                if (_showGrid)
                                  Positioned.fill(
                                    child: ExcludeSemantics(
                                      child: CustomPaint(
                                        painter: GridPainter(),
                                      ),
                                    ),
                                  ),
                                ..._widgets.map(
                                  (w) => _buildDraggableWidget(w),
                                ),
                              ],
                            ),
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

  Widget _buildToolbar() {
    final w = _selectedWidget!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: FluentTheme.of(context).micaBackgroundColor,
      child: Row(
        children: [
          if (w is TextWidgetModel) ...[
            Expanded(
              child: TextBox(
                controller: _textController,
                onChanged: (val) {
                  w.text = val;
                  setState(() {});
                },
                placeholder: 'Enter text',
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(FluentIcons.font_increase),
              onPressed: () => setState(() => w.fontSize += 2),
            ),
            IconButton(
              icon: const Icon(FluentIcons.font_decrease),
              onPressed: () =>
                  setState(() => w.fontSize = (w.fontSize - 2).clamp(8, 72)),
            ),
          ],
          if (w is BarcodeWidgetModel) ...[
            Expanded(
              child: TextBox(
                controller: _barcodeDataController,
                onChanged: (val) {
                  w.data = val;
                  setState(() {});
                },
                placeholder: 'Barcode data',
              ),
            ),
            const SizedBox(width: 8),
            ComboBox<String>(
              value: _getBarcodeDisplayName(w.barcodeType),
              items: ['QR Code', 'Code 128', 'EAN 8', 'EAN 13'].map((type) {
                return ComboBoxItem(value: type, child: Text(type));
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(
                    () =>
                        w.barcodeType = BarcodeWidgetModel.barcodeFromType(val),
                  );
                }
              },
            ),
          ],
          if (w is ImageWidgetModel || w is BarcodeWidgetModel) ...[
            const SizedBox(width: 12),
            const Text('Size:'),
            SizedBox(
              width: 150,
              child: Slider(
                value: (w is ImageWidgetModel)
                    ? w.width
                    : (w as BarcodeWidgetModel).width,
                min: 20,
                max: _paperWidth.clamp(20, 576),
                onChanged: (val) {
                  setState(() {
                    if (w is ImageWidgetModel) {
                      w.width = val;
                      w.height = val;
                    } else if (w is BarcodeWidgetModel) {
                      w.width = val;
                      w.height = val * 0.6;
                    }
                  });
                },
              ),
            ),
          ],
          const SizedBox(width: 12),
          IconButton(
            icon: Icon(FluentIcons.delete, color: Colors.red),
            onPressed: _deleteSelected,
          ),
        ],
      ),
    );
  }

  String _getBarcodeDisplayName(bc.Barcode barcode) {
    final name = barcode.name;
    if (name.contains('QR')) return 'QR Code';
    if (name.contains('128')) return 'Code 128';
    if (name.contains('EAN 8') || (name.contains('8') && !name.contains('128')))
      return 'EAN 8';
    if (name.contains('EAN 13') || name.contains('13')) return 'EAN 13';
    return 'QR Code';
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Button(onPressed: _addText, child: const Text('Add Text')),
          const SizedBox(width: 8),
          Button(onPressed: _addImage, child: const Text('Add Image')),
          const SizedBox(width: 8),
          Button(onPressed: _addBarcode, child: const Text('Add Barcode')),
        ],
      ),
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
            w.x = (w.x + details.delta.dx).clamp(0, _paperWidth - 20);
            w.y = (w.y + details.delta.dy).clamp(0, 580);
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

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey[100]
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
