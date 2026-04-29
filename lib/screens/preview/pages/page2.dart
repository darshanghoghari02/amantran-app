import 'package:flutter/material.dart';
import '../../../models/kankotri_data.dart';
import '../../../models/template_model.dart';

class Page2 extends StatelessWidget {
  final KankotriData data;
  final TemplateModel template;

  const Page2(this.data, this.template, {super.key});

  @override
  Widget build(BuildContext context) {
    // 🔥 Get first event date
    final eventDate = data.events.isNotEmpty ? data.events[0].date : "";

    return Stack(
      children: [
        // 🔹 BACKGROUND
        Positioned.fill(child: Image.asset(template.getPageImage(1), fit: BoxFit.cover)),

        // 🔹 CONTENT
        SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min, // 🔥 IMPORTANT FIX
                children: [
                  // 🔴 TITLE
                  Text(
                    "લગ્ન નિમંત્રણ",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: template.primaryColor,
                      fontFamily: template.fontFamily,
                    ),
                  ),

                  const SizedBox(height: 25),

                  // 🔴 PARENTS
                  Text(
                    "શ્રી ${data.fatherName.isEmpty ? '---' : data.fatherName}",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      color: template.textColor,
                      fontFamily: template.fontFamily,
                    ),
                  ),

                  const SizedBox(height: 5),

                  Text(
                    "શ્રીમતી ${data.motherName.isEmpty ? '---' : data.motherName}",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      color: template.textColor,
                      fontFamily: template.fontFamily,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    "ના લાડલા પુત્ર",
                    style: TextStyle(
                      fontSize: 14,
                      color: template.textColor,
                      fontFamily: template.fontFamily,
                    ),
                  ),

                  const SizedBox(height: 25),

                  // 🔴 GROOM NAME
                  Text(
                    "ચિ. ${data.groomName.isEmpty ? '---' : data.groomName}",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: template.primaryColor,
                      fontFamily: template.fontFamily,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 🔴 SAATHE
                  Text(
                    "સાથે",
                    style: TextStyle(
                      fontSize: 16,
                      fontStyle: FontStyle.italic,
                      color: template.textColor,
                      fontFamily: template.fontFamily,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 🔴 BRIDE NAME
                  Text(
                    "ચિ. ${data.brideName.isEmpty ? '---' : data.brideName}",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: template.primaryColor,
                      fontFamily: template.fontFamily,
                    ),
                  ),

                  const SizedBox(height: 30),

                  // 🔴 DATE
                  Column(
                    children: [
                      Text(
                        "લગ્ન તારીખ",
                        style: TextStyle(
                          fontFamily: template.fontFamily,
                          color: template.textColor,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        eventDate.isEmpty ? "---" : eventDate,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: template.textColor,
                          fontFamily: template.fontFamily,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 25),

                  // 🔴 DIVIDER
                  Container(
                    width: 180,
                    height: 1,
                    color: template.textColor.withOpacity(0.3),
                  ),

                  const SizedBox(height: 15),

                  // 🔴 FOOTER
                  Text(
                    "આપ સહપરિવાર પધારશો",
                    style: TextStyle(
                      fontSize: 14,
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
