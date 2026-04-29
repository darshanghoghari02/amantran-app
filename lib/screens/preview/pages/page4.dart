import 'package:flutter/material.dart';
import '../../../models/kankotri_data.dart';
import '../../../models/template_model.dart';

class Page4 extends StatelessWidget {
  final KankotriData data;
  final TemplateModel template;

  const Page4(this.data, this.template, {super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 🔹 BACKGROUND
        Positioned.fill(child: Image.asset(template.getPageImage(3), fit: BoxFit.cover)),

        // 🔹 CONTENT
        SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 🔴 TITLE
                  Text(
                    "પરિવાર વિગત",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: template.primaryColor,
                      fontFamily: template.fontFamily,
                    ),
                  ),

                  const SizedBox(height: 25),

                  // 🔴 PARENTS
                  _nameText("શ્રી", data.fatherName),
                  _nameText("શ્રીમતી", data.motherName),

                  const SizedBox(height: 20),

                  // 🔴 FAMILY LINE
                  Text(
                    "સહપરિવાર તરફથી",
                    style: TextStyle(
                      fontSize: 16,
                      fontStyle: FontStyle.italic,
                      color: template.textColor,
                      fontFamily: template.fontFamily,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 🔴 FAMILY NAME
                  Text(
                    data.familyName.isEmpty
                        ? "--- પરિવાર"
                        : "${data.familyName} પરિવાર",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: template.textColor,
                      fontFamily: template.fontFamily,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 8),

                  // 🔴 VILLAGE
                  Text(
                    data.village.isEmpty ? "ગામ: ---" : "ગામ: ${data.village}",
                    style: TextStyle(
                      fontSize: 15,
                      color: template.textColor.withOpacity(0.7),
                      fontFamily: template.fontFamily,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 30),

                  // 🔴 DIVIDER
                  Container(
                    width: 180,
                    height: 1,
                    color: template.textColor.withOpacity(0.3),
                  ),

                  const SizedBox(height: 15),

                  // 🔴 FOOTER
                  Text(
                    "આપના આશીર્વાદ અમૂલ્ય છે",
                    style: TextStyle(
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      color: template.textColor.withOpacity(0.7),
                      fontFamily: template.fontFamily,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _nameText(String prefix, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        "$prefix ${value.isEmpty ? '---' : value}",
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: template.textColor,
          fontFamily: template.fontFamily,
        ),
      ),
    );
  }
}
