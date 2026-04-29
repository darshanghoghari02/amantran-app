import 'package:flutter/material.dart';
import '../../../models/kankotri_data.dart';
import '../../../models/template_model.dart';

class Page1 extends StatelessWidget {
  final KankotriData data;
  final TemplateModel template;

  const Page1(this.data, this.template, {super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 🔹 BACKGROUND IMAGE
        Positioned.fill(child: Image.asset(template.getPageImage(0), fit: BoxFit.cover)),

        // 🔹 MAIN CONTENT
        SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min, // 🔥 prevents overflow + swipe issues
                children: [
                  // 🕉️ GANESH IMAGE
                  if (data.ganeshImage.isNotEmpty)
                    Image.asset(data.ganeshImage, height: 90),

                  const SizedBox(height: 15),

                  // 🔴 SHLOK
                  Text(
                    data.shlok1Gu.isNotEmpty ? data.shlok1Gu : "॥ વક્રતુંડ મહાકાય સૂર્યકોટી સમપ્રભ\nનિર્વિઘ્નં કુરુમેદેવ સર્વકાર્યેષુસર્વદા ॥",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: template.textColor,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      fontFamily: template.fontFamily,
                    ),
                  ),

                  const SizedBox(height: 25),

                  // 🔴 TITLE
                  Text(
                    "શુભ વિવાહ",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: template.primaryColor,
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      fontFamily: template.fontFamily,
                    ),
                  ),

                  const SizedBox(height: 30),

                  // 🔴 BRIDE & GROOM
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        data.brideNameGu.isNotEmpty ? data.brideNameGu : "ચિ. હાર્મી",
                        style: TextStyle(
                          color: template.primaryColor,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          fontFamily: template.fontFamily,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "સંગ",
                    style: TextStyle(
                      color: template.textColor,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFamily: template.fontFamily,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(width: 60), // offset to the right
                      Text(
                        data.groomNameGu.isNotEmpty ? data.groomNameGu : "ચિ. કિશન",
                        style: TextStyle(
                          color: template.primaryColor,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          fontFamily: template.fontFamily,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),

                  // 🔴 DATE
                  Text(
                    data.weddingDateGu.isNotEmpty ? data.weddingDateGu : "તા. ૨૩/૦૧/૨૦૨૬, શુક્રવાર",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: template.textColor,
                      fontFamily: template.fontFamily,
                    ),
                  ),

                  const SizedBox(height: 25),

                  // 🔴 INVITEE
                  Text(
                    "સ્નેહી શ્રી, ...........................................",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: template.textColor,
                      fontFamily: template.fontFamily,
                    ),
                  ),

                  const SizedBox(height: 30),

                  // 🔴 NIMANTRAK TITLE
                  Text(
                    "નિમંત્રક",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: template.primaryColor,
                      fontFamily: template.fontFamily,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // 🔴 PARENTS & ADDRESS
                  Text(
                    [
                      if (data.fatherNameGu.isNotEmpty) data.fatherNameGu else "કમલેશકુમાર કાંતિલાલ પટેલ",
                      if (data.motherNameGu.isNotEmpty) data.motherNameGu else "વીણાબેન કમલેશકુમાર પટેલ",
                      if (data.addressGu.isNotEmpty) data.addressGu else "૧૨, વિશ્વરૂપા સોસાયટી,\nસુમુલડેરી રોડ, સુરત."
                    ].join("\n"),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
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
}
