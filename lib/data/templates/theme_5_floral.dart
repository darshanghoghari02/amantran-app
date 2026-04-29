import 'package:flutter/material.dart';
import '../../models/template_model.dart';
import 'base_elements.dart';

final TemplateModel template5 = TemplateModel(
  id: 'template_5', 
  name: 'Floral', 
  folderPath: "assets/templates/theme_5",
  primaryColor: Colors.black, 
  textColor: Colors.black, 
  fontFamily: 'Farsan',
  elements: buildBaseElements(primaryColor: Colors.black, textColor: Colors.black),
);
