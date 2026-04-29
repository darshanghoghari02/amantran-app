import 'package:flutter/material.dart';
import '../../../models/kankotri_data.dart';
import '../../../models/template_model.dart';

class Page5 extends StatelessWidget {
  final KankotriData data;
  final TemplateModel template;

  const Page5(this.data, this.template, {super.key});

  @override
  Widget build(BuildContext context) {
    final text = data.invitationText.trim().isNotEmpty
        ? data.invitationText
        : _defaultGujaratiText();

    return Stack(
      children: [
        // 🔹 BACKGROUND
        Positioned.fill(child: Image.asset(template.getPageImage(4), fit: BoxFit.cover)),

        // 🔹 CONTENT
        SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min, // 🔥 IMPORTANT FIX
                children: [
                  const SizedBox(height: 10),

                  // 🔴 TITLE
                  Text(
                    "નિમંત્રણ",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: template.primaryColor,
                      fontFamily: template.fontFamily,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 🔴 DIVIDER
                  Container(
                    width: 180,
                    height: 1,
                    color: template.textColor.withOpacity(0.3),
                  ),

                  const SizedBox(height: 20),

                  // 🔴 MAIN TEXT (NO SCROLL NOW)
                  Text(
                    text,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.7,
                      color: template.textColor,
                      fontFamily: template.fontFamily,
                    ),
                  ),

                  const SizedBox(height: 25),

                  // 🔴 FOOTER
                  Text(
                    "આપની ઉપસ્થિતિ અમને આનંદ આપશે",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      color: template.textColor,
                      fontFamily: template.fontFamily,
                    ),
                  ),

                  const SizedBox(height: 10),

                  // 🔴 SHLOK
                  Text(
                    "॥ શુભલગ્નમસ્તુ ॥",
                    textAlign: TextAlign.center,
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

  // 🔥 DEFAULT TEXT
  String _defaultGujaratiText() {
    final groom = data.groomName.isEmpty ? "વરનું નામ" : data.groomName;
    final bride = data.brideName.isEmpty ? "વધુનું નામ" : data.brideName;

    final event = data.events.isNotEmpty ? data.events[0] : null;

    final date = event?.date.isNotEmpty == true ? event!.date : "તારીખ";
    final time = event?.time.isNotEmpty == true ? event!.time : "સમય";
    final place = event?.place.isNotEmpty == true ? event!.place : "સ્થળ";

    return """
અમારા પ્રિય પુત્ર ચિ. $groom 
અને ચિ. $bride 
ના શુભ લગ્ન પ્રસંગે આપને સહપરિવાર હાજરી આપવા હાર્દિક આમંત્રણ છે।

લગ્ન તારીખ: $date  
સમય: $time  
સ્થળ: $place  

આ શુભ અવસર પર આપની ઉપસ્થિતિ અમને આનંદ અને ગૌરવ આપશે।
""";
  }
}
