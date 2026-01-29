import 'package:flutter/material.dart';
import 'package:barcode_widget/barcode_widget.dart';

enum WidgetType { text, image, barcode }

abstract class BaseWidgetModel {
  final String id;
  double x;
  double y;
  final WidgetType type;

  BaseWidgetModel({
    required this.id,
    required this.x,
    required this.y,
    required this.type,
  });

  Map<String, dynamic> toJson();
}

class TextWidgetModel extends BaseWidgetModel {
  String text;
  double fontSize;
  FontWeight fontWeight;
  TextAlign textAlign;

  TextWidgetModel({
    required super.id,
    required super.x,
    required super.y,
    this.text = 'New Text',
    this.fontSize = 16.0,
    this.fontWeight = FontWeight.normal,
    this.textAlign = TextAlign.left,
  }) : super(type: WidgetType.text);

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'x': x,
    'y': y,
    'type': 'text',
    'text': text,
    'fontSize': fontSize,
    'fontWeight': fontWeight.index,
    'textAlign': textAlign.index,
  };

  factory TextWidgetModel.fromJson(Map<String, dynamic> json) =>
      TextWidgetModel(
        id: json['id'],
        x: json['x'],
        y: json['y'],
        text: json['text'],
        fontSize: json['fontSize'],
        fontWeight: FontWeight.values[json['fontWeight']],
        textAlign: TextAlign.values[json['textAlign']],
      );
}

class ImageWidgetModel extends BaseWidgetModel {
  String imagePath;
  double width;
  double height;

  ImageWidgetModel({
    required super.id,
    required super.x,
    required super.y,
    required this.imagePath,
    this.width = 100.0,
    this.height = 100.0,
  }) : super(type: WidgetType.image);

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'x': x,
    'y': y,
    'type': 'image',
    'imagePath': imagePath,
    'width': width,
    'height': height,
  };

  factory ImageWidgetModel.fromJson(Map<String, dynamic> json) =>
      ImageWidgetModel(
        id: json['id'],
        x: json['x'],
        y: json['y'],
        imagePath: json['imagePath'],
        width: json['width'],
        height: json['height'],
      );
}

class BarcodeWidgetModel extends BaseWidgetModel {
  String data;
  double width;
  double height;
  Barcode barcodeType;

  BarcodeWidgetModel({
    required super.id,
    required super.x,
    required super.y,
    this.data = '12345678',
    this.width = 150.0,
    this.height = 80.0,
    required this.barcodeType,
  }) : super(type: WidgetType.barcode);

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'x': x,
    'y': y,
    'type': 'barcode',
    'data': data,
    'width': width,
    'height': height,
    'barcodeType': barcodeType.name,
  };

  factory BarcodeWidgetModel.fromJson(Map<String, dynamic> json) =>
      BarcodeWidgetModel(
        id: json['id'],
        x: json['x'],
        y: json['y'],
        data: json['data'],
        width: json['width'],
        height: json['height'],
        barcodeType: barcodeFromType(json['barcodeType']),
      );

  static Barcode barcodeFromType(String type) {
    switch (type) {
      case 'QR Code':
        return Barcode.qrCode();
      case 'Code 128':
        return Barcode.code128();
      case 'EAN 8':
        return Barcode.ean8();
      case 'EAN 13':
        return Barcode.ean13();
      default:
        return Barcode.qrCode();
    }
  }
}

class TemplateModel {
  final String id;
  String name;
  List<BaseWidgetModel> widgets;
  double paperWidth; // Added for 58mm / 80mm support

  TemplateModel({
    required this.id,
    required this.name,
    required this.widgets,
    this.paperWidth = 384, // Default to 58mm (approx 384px)
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'widgets': widgets.map((w) => w.toJson()).toList(),
    'paperWidth': paperWidth,
  };

  factory TemplateModel.fromJson(Map<String, dynamic> json) {
    final widgetsJson = json['widgets'] as List;
    final widgets = widgetsJson.map((w) {
      if (w['type'] == 'text') {
        return TextWidgetModel.fromJson(w);
      } else if (w['type'] == 'image') {
        return ImageWidgetModel.fromJson(w);
      } else {
        return BarcodeWidgetModel.fromJson(w);
      }
    }).toList();

    return TemplateModel(
      id: json['id'],
      name: json['name'],
      widgets: widgets,
      paperWidth: (json['paperWidth'] as num?)?.toDouble() ?? 384,
    );
  }

  TemplateModel copyWith({
    String? id,
    String? name,
    List<BaseWidgetModel>? widgets,
    double? paperWidth,
  }) {
    return TemplateModel(
      id: id ?? this.id,
      name: name ?? this.name,
      widgets: widgets ?? this.widgets,
      paperWidth: paperWidth ?? this.paperWidth,
    );
  }
}

enum ConnectionType { bluetooth, serial, usb }

class PrinterDevice {
  final String name;
  final String address; // MAC address or Port name
  final ConnectionType type;

  PrinterDevice({
    required this.name,
    required this.address,
    required this.type,
  });
}
