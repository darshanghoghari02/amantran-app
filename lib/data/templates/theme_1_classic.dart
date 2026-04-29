import 'package:flutter/material.dart';
import '../../models/template_model.dart';
import 'base_elements.dart';

final TemplateModel template1 = TemplateModel(
  id: 'template_1', 
  name: 'Classic Theme', 
  folderPath: "assets/templates/theme_1",
  primaryColor: Colors.black, 
  textColor: Colors.black, 
  fontFamily: 'Farsan',
  elements: buildBaseElements(primaryColor: Colors.black, textColor: Colors.black),
);
