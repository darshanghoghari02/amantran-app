import 'package:flutter/material.dart';
import '../../../models/kankotri_data.dart';
import '../../../models/template_model.dart';

class Page6 extends StatelessWidget {
  final KankotriData data;
  final TemplateModel template;

  const Page6(this.data, this.template, {super.key});

  @override
  Widget build(BuildContext context) {
    final contact = data.contact.isEmpty ? "---" : data.contact;
    final address = data.address.isEmpty ? "---" : data.address;

    return Stack(
      children: [
        // 🔹 BACKGROUND
        Positioned.fill(child: Image.asset(template.getPageImage(5), fit: BoxFit.cover)),

        // 🔹 CONTENT
        SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min, // 🔥 IMPORTANT FIX
                children: [
                  // 🔴 TITLE
                  Text(
                    "આભાર",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: template.primaryColor,
                      fontFamily: template.fontFamily,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 🔴 THANK YOU MESSAGE
                  Text(
                    "આપનો કિંમતી સમય કાઢીને\nઆપ અમારી ખુશીમાં સહભાગી બનશો તે માટે દિલથી આભાર.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.6,
                      color: template.textColor,
                      fontFamily: template.fontFamily,
                    ),
                  ),

                  const SizedBox(height: 25),

                  // 🔴 DIVIDER
                  Container(
                    width: 180,
                    height: 1,
                    color: template.textColor.withOpacity(0.3),
                  ),

                  const SizedBox(height: 20),

                  // 🔴 CONTACT TITLE
                  Text(
                    "સંપર્ક વિગત",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: template.textColor,
                      fontFamily: template.fontFamily,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 🔴 CONTACT
                  Text(
                    "મોબાઇલ: $contact",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: template.textColor,
                      fontFamily: template.fontFamily,
                    ),
                  ),

                  const SizedBox(height: 10),

                  // 🔴 ADDRESS
                  Text(
                    "સરનામું: $address",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: template.textColor,
                      fontFamily: template.fontFamily,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 🔴 FAMILY NAME
                  if (data.familyName.isNotEmpty)
                    Text(
                      "${data.familyName} પરિવાર",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: template.textColor,
                        fontFamily: template.fontFamily,
                      ),
                    ),

                  // 🔴 VILLAGE
                  if (data.village.isNotEmpty)
                    Text(
                      "ગામ: ${data.village}",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: template.textColor.withOpacity(0.7),
                        fontFamily: template.fontFamily,
                      ),
                    ),

                  const SizedBox(height: 25),

                  // 🔴 FINAL DIVIDER
                  Container(
                    width: 180,
                    height: 1,
                    // ignore: deprecated_member_use
                    color: template.textColor.withValues(alpha: 0.3),
                  ),

                  const SizedBox(height: 12),

                  // 🔴 FINAL SHLOK
                  Text(
                    "॥ શ્રી કૃષ્ણાર્પણમસ્તુ ॥",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      // ignore: deprecated_member_use
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
}
