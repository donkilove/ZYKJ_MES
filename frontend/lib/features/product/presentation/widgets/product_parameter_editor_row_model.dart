import 'package:flutter/material.dart';

class ProductParameterEditorRowModel {
  ProductParameterEditorRowModel.initial({
    required this.rowId,
    required String name,
    required String category,
    required String parameterType,
    required String value,
    required String description,
  }) : nameController = TextEditingController(text: name),
       categoryController = TextEditingController(text: category),
       valueController = TextEditingController(text: value),
       descriptionController = TextEditingController(text: description),
       parameterType = parameterType == 'Link' ? 'Link' : 'Text';

  ProductParameterEditorRowModel.empty({required this.rowId})
    : nameController = TextEditingController(),
      categoryController = TextEditingController(),
      valueController = TextEditingController(),
      descriptionController = TextEditingController(),
      parameterType = 'Text';

  final int rowId;
  final TextEditingController nameController;
  final TextEditingController categoryController;
  final TextEditingController valueController;
  final TextEditingController descriptionController;
  String parameterType;
  bool categoryListenerBound = false;

  void dispose() {
    nameController.dispose();
    categoryController.dispose();
    valueController.dispose();
    descriptionController.dispose();
  }
}
