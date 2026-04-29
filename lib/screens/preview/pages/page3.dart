import 'package:flutter/material.dart';
import '../../../models/kankotri_data.dart';
import '../../../models/template_model.dart';

class Page3 extends StatelessWidget {
  final KankotriData data;
  final TemplateModel template;

  const Page3(this.data, this.template, {super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 🔹 BACKGROUND
        Positioned.fill(child: Image.asset(template.getPageImage(2), fit: BoxFit.cover)),

        // 🔹 CONTENT
        SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min, // 🔥 IMPORTANT
                children: [
                  // 🔴 TITLE
                  Text(
                    "કાર્યક્રમ વિગત",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: template.primaryColor,
                      fontFamily: template.fontFamily,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 🔥 EVENTS (NO LISTVIEW NOW)
                  if (data.events.isEmpty)
                    Text(
                      "કોઈ કાર્યક્રમ ઉમેરાયેલ નથી",
                      style: TextStyle(
                        fontSize: 14,
                        color: template.textColor,
                        fontFamily: template.fontFamily,
                      ),
                    )
                  else
                    Column(
                      children: data.events.map((event) {
                        return _eventCard(event);
                      }).toList(),
                    ),

                  const SizedBox(height: 25),

                  // 🔴 FOOTER
                  Text(
                    "આપની ઉપસ્થિતિ અમને આનંદ આપશે",
                    style: TextStyle(
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      color: template.textColor,
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

  // 🔥 EVENT CARD (FIXED)
  Widget _eventCard(EventModel event) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: templateColor(event)),
        color: Colors.white.withOpacity(0.9),
      ),
      child: Column(
        children: [
          // 🔴 TITLE
          Text(
            event.title.isEmpty ? "કાર્યક્રમ" : event.title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: template.primaryColor,
              fontFamily: template.fontFamily,
            ),
          ),

          const SizedBox(height: 8),

          _row("તારીખ", event.date),
          _row("સમય", event.time),
          _row("સ્થળ", event.place),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        "$label: ${value.isEmpty ? '---' : value}",
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 14,
          color: template.textColor,
          fontFamily: template.fontFamily,
        ),
      ),
    );
  }

  Color templateColor(EventModel event) {
    return Colors.black26;
  }
}
