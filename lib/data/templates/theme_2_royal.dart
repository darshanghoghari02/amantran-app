import 'package:flutter/material.dart';
import '../../models/template_model.dart';
import 'base_elements.dart';

final TemplateModel template2 = TemplateModel(
  id: 'template_2', 
  name: 'Royal Gold', 
  folderPath: "assets/templates/theme_2",
  primaryColor: Colors.black, 
  textColor: Colors.black, 
  fontFamily: 'Farsan',
  elements: buildBaseElements(primaryColor: Colors.black, textColor: Colors.black),
);
