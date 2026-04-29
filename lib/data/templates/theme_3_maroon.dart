import 'package:flutter/material.dart';
import '../../models/template_model.dart';
import 'base_elements.dart';

final TemplateModel template3 = TemplateModel(
  id: 'template_3', 
  name: 'Elegant Maroon', 
  folderPath: "assets/templates/theme_3",
  primaryColor: Colors.black, 
  textColor: Colors.black, 
  fontFamily: 'Farsan',
  elements: buildBaseElements(primaryColor: Colors.black, textColor: Colors.black),
);
