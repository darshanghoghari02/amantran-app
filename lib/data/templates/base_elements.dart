import 'package:flutter/material.dart';
import '../../models/template_element.dart';

// ─────────────────────────────────────────────────
// 🔥 PAGE NAMES (for UI display)
// ─────────────────────────────────────────────────
const List<String> pageNames = [
  'Mangalik Prasango',
  'Shubh Vivah',
  'Sangeet Sandhya',
  'Lagnotsav',
  'Parinay Utsav',
  'Contact & Thanks',
  'Family Details',
];

// ─────────────────────────────────────────────────
// 🔥 HELPER: Generate all 7 pages of elements
// ─────────────────────────────────────────────────
List<TemplateElement> buildBaseElements({
  Color primaryColor = Colors.black,
  Color textColor = Colors.black,
  String fontFamily = 'Farsan',
}) {
  return [
    // ════════════════════════════════════════════════
    // 📄 PAGE 0 — Mangalik Prasango
    // ════════════════════════════════════════════════
    TemplateElement(id: 'p0_shlok1', pageIndex: 0, type: ElementType.text,
      content: '॥ Shri Ganeshay Namah ॥', contentGujarati: '॥ શ્રી ગણેશાય નમઃ ॥',
      x: 60, y: 30, width: 240, height: 26, fontSize: 16, fontFamily: fontFamily, color: primaryColor, fontWeight: FontWeight.bold),
    TemplateElement(id: 'p0_shlok2', pageIndex: 0, type: ElementType.text,
      content: '॥ By the grace of Goddess ॥', contentGujarati: '॥ શ્રી સિંધવાઈ માતાની કૃપા ॥',
      x: 60, y: 55, width: 240, height: 26, fontSize: 16, fontFamily: fontFamily, color: primaryColor, fontWeight: FontWeight.bold),
    TemplateElement(id: 'p0_title', pageIndex: 0, type: ElementType.text,
      content: 'Event Details', contentGujarati: 'માંગલિક પ્રસંગો',
      x: 40, y: 100, width: 280, height: 45, fontSize: 30, fontFamily: fontFamily, color: primaryColor, fontWeight: FontWeight.bold),
    TemplateElement(id: 'p0_event1_title', pageIndex: 0, type: ElementType.text,
      content: ':: Ganesh Sthapana ::', contentGujarati: ':: ગણેશ સ્થાપના ::',
      x: 60, y: 170, width: 240, height: 26, fontSize: 18, fontFamily: fontFamily, color: primaryColor, fontWeight: FontWeight.bold),
    TemplateElement(id: 'p0_event1_date', pageIndex: 0, type: ElementType.text,
      content: 'Date: 23/01/2026', contentGujarati: 'તા. ૨૩/૦૧/૨૦૨૬ ને શુક્રવાર',
      x: 60, y: 200, width: 240, height: 24, fontSize: 16, fontFamily: fontFamily, color: textColor),
    TemplateElement(id: 'p0_event1_time', pageIndex: 0, type: ElementType.text,
      content: 'Time: 7:30 AM', contentGujarati: 'સવારે ૭:૩૦ કલાકે',
      x: 60, y: 220, width: 240, height: 24, fontSize: 16, fontFamily: fontFamily, color: textColor),

    TemplateElement(id: 'p0_event2_title', pageIndex: 0, type: ElementType.text,
      content: ':: Mandap Muhurat ::', contentGujarati: ':: મંડપ મુહૂર્ત ::',
      x: 60, y: 260, width: 240, height: 26, fontSize: 18, fontFamily: fontFamily, color: primaryColor, fontWeight: FontWeight.bold),
    TemplateElement(id: 'p0_event2_date', pageIndex: 0, type: ElementType.text,
      content: 'Date: 23/01/2026', contentGujarati: 'તા. ૨૩/૦૧/૨૦૨૬ ને શુક્રવાર',
      x: 60, y: 290, width: 240, height: 24, fontSize: 16, fontFamily: fontFamily, color: textColor),
    TemplateElement(id: 'p0_event2_time', pageIndex: 0, type: ElementType.text,
      content: 'Time: 8:30 AM', contentGujarati: 'સવારે ૮:૩૦ કલાકે',
      x: 60, y: 310, width: 240, height: 24, fontSize: 16, fontFamily: fontFamily, color: textColor),

    TemplateElement(id: 'p0_event3_title', pageIndex: 0, type: ElementType.text,
      content: ':: Grahshanti ::', contentGujarati: ':: ગ્રહશાંતિ ::',
      x: 60, y: 350, width: 240, height: 26, fontSize: 18, fontFamily: fontFamily, color: primaryColor, fontWeight: FontWeight.bold),
    TemplateElement(id: 'p0_event3_date', pageIndex: 0, type: ElementType.text,
      content: 'Date: 23/01/2026', contentGujarati: 'તા. ૨૩/૦૧/૨૦૨૬ ને શુક્રવાર',
      x: 60, y: 380, width: 240, height: 24, fontSize: 16, fontFamily: fontFamily, color: textColor),
    TemplateElement(id: 'p0_event3_time', pageIndex: 0, type: ElementType.text,
      content: 'Time: 10:30 AM', contentGujarati: 'સવારે ૧૦:૩૦ કલાકે',
      x: 60, y: 400, width: 240, height: 24, fontSize: 16, fontFamily: fontFamily, color: textColor),

    TemplateElement(id: 'p0_bhojan_title', pageIndex: 0, type: ElementType.text,
      content: 'Lunch Ceremony', contentGujarati: 'આ શુભ પ્રસંગે યોજેલ ભોજન સમારંભમા',
      x: 30, y: 435, width: 300, height: 24, fontSize: 16, fontFamily: fontFamily, color: textColor),
    TemplateElement(id: 'p0_bhojan_time', pageIndex: 0, type: ElementType.text,
      content: 'Time: 12:00 PM', contentGujarati: 'બપોરે ૧૨:૦૦ કલાકે',
      x: 60, y: 455, width: 240, height: 24, fontSize: 16, fontFamily: fontFamily, color: textColor),
    TemplateElement(id: 'p0_bhojan_guest', pageIndex: 0, type: ElementType.text,
      content: 'Please grace us', contentGujarati: 'આપ શ્રી ........ પધારશોજી',
      x: 60, y: 475, width: 240, height: 24, fontSize: 16, fontFamily: fontFamily, color: textColor),

    TemplateElement(id: 'p0_sthal_title', pageIndex: 0, type: ElementType.text,
      content: ':: Venue ::', contentGujarati: ':: શુભ સ્થળ ::',
      x: 60, y: 515, width: 240, height: 26, fontSize: 18, fontFamily: fontFamily, color: primaryColor, fontWeight: FontWeight.bold),
    TemplateElement(id: 'p0_sthal_address', pageIndex: 0, type: ElementType.text,
      content: 'Venue details', contentGujarati: 'કામધેનુ ગૌ જતન લોન્સ ૭ રીસોર્ટ,\nબાયોનિકસ સ્કુલની બાજુમાં,\nકેનાલ રોડ, લાડવી ગામ, સુરત.',
      x: 30, y: 545, width: 300, height: 60, fontSize: 15, fontFamily: fontFamily, color: textColor, textAlign: TextAlign.center),


    // ════════════════════════════════════════════════
    // 📄 PAGE 1 — Shubh Vivah
    // ════════════════════════════════════════════════
    TemplateElement(id: 'ganesh_image', pageIndex: 1, type: ElementType.image,
      content: 'Ganesh', x: 140, y: 30, width: 80, height: 80, assetPath: 'assets/images/ganesh1.png', isEditable: false),
    TemplateElement(id: 'p1_shlok', pageIndex: 1, type: ElementType.text,
      content: '॥ Vakratunda Mahakaya... ॥', contentGujarati: '॥ વક્રતુંડ મહાકાય સૂર્યકોટી સમપ્રભ\nનિર્વિઘ્નં કુરુમેદેવ સર્વકાર્યેષુસર્વદા ॥',
      x: 40, y: 120, width: 280, height: 40, fontSize: 13, fontFamily: fontFamily, color: textColor, fontWeight: FontWeight.bold, textAlign: TextAlign.center),
    TemplateElement(id: 'p1_title', pageIndex: 1, type: ElementType.text,
      content: 'Shubh Vivah', contentGujarati: 'શુભ વિવાહ',
      x: 60, y: 180, width: 240, height: 45, fontSize: 40, fontFamily: fontFamily, color: primaryColor, fontWeight: FontWeight.bold, textAlign: TextAlign.center),
    
    TemplateElement(id: 'p1_bride', pageIndex: 1, type: ElementType.text,
      content: 'Chi. Harmi', contentGujarati: 'ચિ. હાર્મી',
      x: 30, y: 260, width: 140, height: 40, fontSize: 32, fontFamily: fontFamily, color: primaryColor, fontWeight: FontWeight.bold, textAlign: TextAlign.center),
    TemplateElement(id: 'p1_sang', pageIndex: 1, type: ElementType.text,
      content: 'with', contentGujarati: 'સંગ',
      x: 160, y: 300, width: 40, height: 30, fontSize: 20, fontFamily: fontFamily, color: textColor, fontWeight: FontWeight.bold, textAlign: TextAlign.center),
    TemplateElement(id: 'p1_groom', pageIndex: 1, type: ElementType.text,
      content: 'Chi. Kishan', contentGujarati: 'ચિ. કિશન',
      x: 190, y: 340, width: 140, height: 40, fontSize: 32, fontFamily: fontFamily, color: primaryColor, fontWeight: FontWeight.bold, textAlign: TextAlign.center),
    
    TemplateElement(id: 'p1_date', pageIndex: 1, type: ElementType.text,
      content: 'Date: 23/01/2026', contentGujarati: 'તા. ૨૩/૦૧/૨૦૨૬, શુક્રવાર',
      x: 40, y: 410, width: 280, height: 26, fontSize: 16, fontFamily: fontFamily, color: textColor, fontWeight: FontWeight.bold, textAlign: TextAlign.center),
    TemplateElement(id: 'p1_snehi', pageIndex: 1, type: ElementType.text,
      content: 'To, .........................', contentGujarati: 'સ્નેહી શ્રી, ...........................................',
      x: 40, y: 450, width: 280, height: 26, fontSize: 15, fontFamily: fontFamily, color: textColor, textAlign: TextAlign.center),
    
    TemplateElement(id: 'p1_nimantrak_title', pageIndex: 1, type: ElementType.text,
      content: 'Inviter', contentGujarati: 'નિમંત્રક',
      x: 100, y: 510, width: 160, height: 28, fontSize: 20, fontFamily: fontFamily, color: primaryColor, fontWeight: FontWeight.bold, textAlign: TextAlign.center),
    TemplateElement(id: 'p1_nimantrak_name', pageIndex: 1, type: ElementType.text,
      content: 'Kamleshkumar Patel...', contentGujarati: 'કમલેશકુમાર કાંતિલાલ પટેલ\nવીણાબેન કમલેશકુમાર પટેલ\n૧૨, વિશ્વરૂપા સોસાયટી,\nસુમુલડેરી રોડ, સુરત.',
      x: 40, y: 545, width: 280, height: 80, fontSize: 14, fontFamily: fontFamily, color: textColor, textAlign: TextAlign.center),

    // ════════════════════════════════════════════════
    // 📄 PAGE 2 — Sangeet Sandhya
    // ════════════════════════════════════════════════
    TemplateElement(id: 'p2_shlok', pageIndex: 2, type: ElementType.text,
      content: '॥ Shri Ganeshay Namah ॥', contentGujarati: '॥ શ્રી ગણેશાય નમઃ ॥',
      x: 60, y: 40, width: 240, height: 26, fontSize: 16, fontFamily: fontFamily, color: primaryColor, fontWeight: FontWeight.bold),
    TemplateElement(id: 'p2_title', pageIndex: 2, type: ElementType.text,
      content: 'Sangeet Sandhya', contentGujarati: 'સંગીત સંધ્યા',
      x: 40, y: 80, width: 280, height: 45, fontSize: 36, fontFamily: fontFamily, color: primaryColor, fontWeight: FontWeight.bold),
    TemplateElement(id: 'p2_quote', pageIndex: 2, type: ElementType.text,
      content: 'Music and joy...', contentGujarati: 'સંગીતના સૂર શરણાઈના સૂરમાં ઢળવા આતુર છે,\nરાધા-કિશન સમા મારી બહેન-જીજા\nપ્રેમના તાંતણે ઝૂમવા આતુર છે, આ "રાસ લીલા" નાં\nઅવસરે તમારા સંગાથ સંગ રમવા "ચિ.હાર્મી" આતુર છે,\n"સંગીત સંધ્યા" ના મધુર પ્રસંગે આપના આગમનને વધાવવા\nપટેલ પરિવાર આતુર છે.',
      x: 20, y: 150, width: 320, height: 110, fontSize: 14, fontFamily: fontFamily, color: textColor, textAlign: TextAlign.center),
    
    TemplateElement(id: 'p2_bride', pageIndex: 2, type: ElementType.text,
      content: 'Chi. Harmi', contentGujarati: 'ચિ. હાર્મી',
      x: 50, y: 280, width: 100, height: 35, fontSize: 26, fontFamily: fontFamily, color: primaryColor, fontWeight: FontWeight.bold),
    TemplateElement(id: 'p2_sang', pageIndex: 2, type: ElementType.text,
      content: 'with', contentGujarati: 'સંગ',
      x: 160, y: 285, width: 40, height: 26, fontSize: 18, fontFamily: fontFamily, color: textColor, fontWeight: FontWeight.bold),
    TemplateElement(id: 'p2_groom', pageIndex: 2, type: ElementType.text,
      content: 'Chi. Kishan', contentGujarati: 'ચિ. કિશન',
      x: 210, y: 280, width: 100, height: 35, fontSize: 26, fontFamily: fontFamily, color: primaryColor, fontWeight: FontWeight.bold),
    
    TemplateElement(id: 'p2_invite', pageIndex: 2, type: ElementType.text,
      content: 'You are invited...', contentGujarati: 'સૂર હિંડોળે ઝુલાવશું, સૂર નૃત્ય સંધ્યામાં\nઆવવાનું ભાવભર્યું નિમંત્રણ છે.',
      x: 40, y: 340, width: 280, height: 40, fontSize: 15, fontFamily: fontFamily, color: textColor, textAlign: TextAlign.center),
    TemplateElement(id: 'p2_date_time', pageIndex: 2, type: ElementType.text,
      content: 'Date and Time', contentGujarati: 'શુક્રવાર, તા. ૨૩-૦૧-૨૦૨૬ નાં રોજ\nસાંજે ૬:૦૦ કલાકે',
      x: 60, y: 390, width: 240, height: 40, fontSize: 15, fontFamily: fontFamily, color: textColor, textAlign: TextAlign.center),
    
    TemplateElement(id: 'p2_divider', pageIndex: 2, type: ElementType.divider,
      x: 120, y: 440, width: 120, height: 4, color: primaryColor, isEditable: false),
    
    TemplateElement(id: 'p2_bhojan_title', pageIndex: 2, type: ElementType.text,
      content: ':: Dinner ::', contentGujarati: ':: સ્વરૂચિ ભોજન સમારંભ ::',
      x: 60, y: 460, width: 240, height: 26, fontSize: 18, fontFamily: fontFamily, color: primaryColor, fontWeight: FontWeight.bold),
    TemplateElement(id: 'p2_bhojan_time', pageIndex: 2, type: ElementType.text,
      content: 'Time: 7:30 PM', contentGujarati: 'સાંજે ૭:૩૦ કલાકે\nઆપશ્રી ........ પધારશોજી',
      x: 60, y: 490, width: 240, height: 40, fontSize: 15, fontFamily: fontFamily, color: textColor, textAlign: TextAlign.center),
    
    TemplateElement(id: 'p2_sthal_title', pageIndex: 2, type: ElementType.text,
      content: ':: Venue ::', contentGujarati: ':: શુભ સ્થળ ::',
      x: 60, y: 540, width: 240, height: 26, fontSize: 18, fontFamily: fontFamily, color: primaryColor, fontWeight: FontWeight.bold),
    TemplateElement(id: 'p2_sthal_address', pageIndex: 2, type: ElementType.text,
      content: 'Venue details', contentGujarati: 'કામધેનુ ગૌ જતન લોન્સ ૭ રીસોર્ટ,\nબાયોનિકસ સ્કુલની બાજુમાં,\nકેનાલ રોડ, લાડવી ગામ, સુરત.',
      x: 40, y: 570, width: 280, height: 60, fontSize: 15, fontFamily: fontFamily, color: textColor, textAlign: TextAlign.center),


    // ════════════════════════════════════════════════
    // 📄 PAGE 3 — Lagnotsav
    // ════════════════════════════════════════════════
    TemplateElement(id: 'p3_shlok', pageIndex: 3, type: ElementType.text,
      content: '॥ Om Namah Shivay ॥', contentGujarati: '॥ ૐ નમઃ શિવાય ॥',
      x: 60, y: 40, width: 240, height: 26, fontSize: 16, fontFamily: fontFamily, color: textColor, fontWeight: FontWeight.bold),
    TemplateElement(id: 'p3_title', pageIndex: 3, type: ElementType.text,
      content: 'Lagnotsav', contentGujarati: 'લગ્નોત્સવ',
      x: 60, y: 90, width: 240, height: 45, fontSize: 40, fontFamily: fontFamily, color: primaryColor, fontWeight: FontWeight.bold),
    TemplateElement(id: 'p3_invite_text1', pageIndex: 3, type: ElementType.text,
      content: 'We invite you...', contentGujarati: 'સહર્ષ ખુશાલી સાથે જણાવવાનું કે\nઅમારા કુળદેવી શ્રી ઉમિયા માતાની અસીમ કૃપા થી\nવામજ નિવાસી (હાલ સુરત)\nકમલેશકુમાર કાંતિલાલ પટેલ અને વિણાબેન કમલેશકુમાર પટેલ\nની સુપુત્રી',
      x: 20, y: 160, width: 320, height: 100, fontSize: 14, fontFamily: fontFamily, color: textColor, textAlign: TextAlign.center, fontWeight: FontWeight.w600),
    
    TemplateElement(id: 'p3_bride', pageIndex: 3, type: ElementType.text,
      content: 'Chi. Harmi', contentGujarati: 'ચિ. હાર્મી',
      x: 40, y: 280, width: 140, height: 40, fontSize: 32, fontFamily: fontFamily, color: primaryColor, fontWeight: FontWeight.bold),
    TemplateElement(id: 'p3_sang', pageIndex: 3, type: ElementType.text,
      content: 'with', contentGujarati: 'સંગ',
      x: 160, y: 330, width: 40, height: 30, fontSize: 20, fontFamily: fontFamily, color: textColor, fontWeight: FontWeight.bold),
    TemplateElement(id: 'p3_groom', pageIndex: 3, type: ElementType.text,
      content: 'Chi. Kishan', contentGujarati: 'ચિ. કિશન',
      x: 180, y: 360, width: 140, height: 40, fontSize: 32, fontFamily: fontFamily, color: primaryColor, fontWeight: FontWeight.bold),
    
    TemplateElement(id: 'p3_parents', pageIndex: 3, type: ElementType.text,
      content: 'Parents details...', contentGujarati: 'જોષીપુરા નિવાસી (હાલ સુરત)\nઅ.સૌ. નીલાબેન અને શ્રી રાજેશભાઈ નરસિંહભાઈ પટેલ\nના સુપુત્ર સાથે',
      x: 30, y: 440, width: 300, height: 60, fontSize: 14, fontFamily: fontFamily, color: textColor, textAlign: TextAlign.center, fontWeight: FontWeight.w600),
    TemplateElement(id: 'p3_date_long', pageIndex: 3, type: ElementType.text,
      content: 'Date...', contentGujarati: 'સંવત ૨૦૮૨ ને મહાસુદ ૬ ને શનિવાર તા. ૨૪/૦૧/૨૦૨૬\nના શુભદિને નિર્ધાર્યા છે.',
      x: 30, y: 510, width: 300, height: 40, fontSize: 14, fontFamily: fontFamily, color: textColor, textAlign: TextAlign.center, fontWeight: FontWeight.bold),
    TemplateElement(id: 'p3_footer', pageIndex: 3, type: ElementType.text,
      content: 'Please come...', contentGujarati: 'આ શુભ પ્રસંગે નવયુગલને આશીર્વાદ થી ભીંજવવા\nઆપશ્રી ને પધારવા ભાવભર્યું હરખનું તેડુ પાઠવી એ છીએ.',
      x: 20, y: 560, width: 320, height: 40, fontSize: 14, fontFamily: fontFamily, color: textColor, textAlign: TextAlign.center, fontWeight: FontWeight.bold),


    // ════════════════════════════════════════════════
    // 📄 PAGE 4 — Parinay Utsav
    // ════════════════════════════════════════════════
    TemplateElement(id: 'p4_shlok', pageIndex: 4, type: ElementType.text,
      content: '॥ Shri Ganeshay Namah ॥', contentGujarati: '॥ શ્રી ગણેશાય નમઃ ॥',
      x: 60, y: 40, width: 240, height: 26, fontSize: 14, fontFamily: fontFamily, color: textColor, fontWeight: FontWeight.bold),
    TemplateElement(id: 'p4_title', pageIndex: 4, type: ElementType.text,
      content: 'Parinay Utsav', contentGujarati: 'પરિણય ઉત્સવ',
      x: 60, y: 80, width: 240, height: 45, fontSize: 36, fontFamily: fontFamily, color: primaryColor, fontWeight: FontWeight.bold),
    TemplateElement(id: 'p4_quote', pageIndex: 4, type: ElementType.text,
      content: 'Marriage quote...', contentGujarati: 'લગ્ન એ બે આત્માનું મિલન છે.\nસ્વર્ગમાં રચાય છે. અને પૃથ્વી પર ઉજવાય છે.',
      x: 40, y: 140, width: 280, height: 40, fontSize: 14, fontFamily: fontFamily, color: textColor, textAlign: TextAlign.center),
    
    TemplateElement(id: 'p4_bride', pageIndex: 4, type: ElementType.text,
      content: 'Chi. Harmi', contentGujarati: 'ચિ. હાર્મી',
      x: 50, y: 195, width: 100, height: 35, fontSize: 26, fontFamily: fontFamily, color: primaryColor, fontWeight: FontWeight.bold),
    TemplateElement(id: 'p4_sang', pageIndex: 4, type: ElementType.text,
      content: 'with', contentGujarati: 'સંગ',
      x: 160, y: 200, width: 40, height: 26, fontSize: 18, fontFamily: fontFamily, color: textColor, fontWeight: FontWeight.bold),
    TemplateElement(id: 'p4_groom', pageIndex: 4, type: ElementType.text,
      content: 'Chi. Kishan', contentGujarati: 'ચિ. કિશન',
      x: 210, y: 195, width: 100, height: 35, fontSize: 26, fontFamily: fontFamily, color: primaryColor, fontWeight: FontWeight.bold),
    
    TemplateElement(id: 'p4_invite2', pageIndex: 4, type: ElementType.text,
      content: 'Invite text...', contentGujarati: 'ના શુભ લગ્ન પ્રસંગે આયોજીત શુભવિવાહ સમારંભ માં\nશનિવાર તા. ૨૪/૦૧/૨૦૨૬ ના રોજ',
      x: 30, y: 250, width: 300, height: 40, fontSize: 14, fontFamily: fontFamily, color: textColor, textAlign: TextAlign.center),

    // Grid for events
    TemplateElement(id: 'p4_event1_title', pageIndex: 4, type: ElementType.text,
      content: ':: Jaan Aagman ::', contentGujarati: ':: જાન આગમન ::',
      x: 20, y: 310, width: 150, height: 26, fontSize: 16, fontFamily: fontFamily, color: primaryColor, fontWeight: FontWeight.bold),
    TemplateElement(id: 'p4_event1_datetime', pageIndex: 4, type: ElementType.text,
      content: 'Date & Time', contentGujarati: 'તા. ૨૪/૦૧/૨૦૨૬ ને શનિવાર\nસાંજે ૫:૦૦ કલાકે',
      x: 20, y: 340, width: 150, height: 40, fontSize: 13, fontFamily: fontFamily, color: textColor, textAlign: TextAlign.center),

    TemplateElement(id: 'p4_event2_title', pageIndex: 4, type: ElementType.text,
      content: ':: Hast Melap ::', contentGujarati: ':: હસ્ત મેળાપ ::',
      x: 190, y: 310, width: 150, height: 26, fontSize: 16, fontFamily: fontFamily, color: primaryColor, fontWeight: FontWeight.bold),
    TemplateElement(id: 'p4_event2_datetime', pageIndex: 4, type: ElementType.text,
      content: 'Date & Time', contentGujarati: 'તા. ૨૪/૦૧/૨૦૨૬ ને શનિવાર\nસાંજે ૬:૩૦ કલાકે',
      x: 190, y: 340, width: 150, height: 40, fontSize: 13, fontFamily: fontFamily, color: textColor, textAlign: TextAlign.center),

    TemplateElement(id: 'p4_bhojan_title', pageIndex: 4, type: ElementType.text,
      content: ':: Bhojan ::', contentGujarati: ':: સ્વરૂચિ ભોજન ::',
      x: 20, y: 410, width: 150, height: 26, fontSize: 16, fontFamily: fontFamily, color: primaryColor, fontWeight: FontWeight.bold),
    TemplateElement(id: 'p4_bhojan_time', pageIndex: 4, type: ElementType.text,
      content: 'Time', contentGujarati: 'સાંજે ૭:૩૦ કલાકે\nઆપશ્રી ........ પધારશોજી',
      x: 20, y: 440, width: 150, height: 40, fontSize: 13, fontFamily: fontFamily, color: textColor, textAlign: TextAlign.center),

    TemplateElement(id: 'p4_sthal_title', pageIndex: 4, type: ElementType.text,
      content: ':: Lagn Sthal ::', contentGujarati: ':: લગ્ન સ્થળ ::',
      x: 190, y: 410, width: 150, height: 26, fontSize: 16, fontFamily: fontFamily, color: primaryColor, fontWeight: FontWeight.bold),
    TemplateElement(id: 'p4_sthal_address', pageIndex: 4, type: ElementType.text,
      content: 'Venue address', contentGujarati: 'કામધેનુ ગૌ જતન લોન્સ ૭ રીસોર્ટ,\nબાયોનિકસ સ્કુલની બાજુમાં,\nકેનાલ રોડ, લાડવી ગામ, સુરત.',
      x: 180, y: 440, width: 170, height: 60, fontSize: 12, fontFamily: fontFamily, color: textColor, textAlign: TextAlign.center),


    // ════════════════════════════════════════════════
    // 📄 PAGE 5 — Pratikshama (Contact & Thanks)
    // ════════════════════════════════════════════════
    TemplateElement(id: 'p5_shlok', pageIndex: 5, type: ElementType.text,
      content: '॥ Shri Ganeshay Namah ॥', contentGujarati: '॥ શ્રી ગણેશાય નમઃ ॥',
      x: 60, y: 40, width: 240, height: 26, fontSize: 14, fontFamily: fontFamily, color: textColor, fontWeight: FontWeight.bold),
    TemplateElement(id: 'p5_header', pageIndex: 5, type: ElementType.text,
      content: 'Waiting for you...', contentGujarati: 'આપ સ્નેહીજનોની પ્રતિક્ષામાં',
      x: 40, y: 80, width: 280, height: 30, fontSize: 20, fontFamily: fontFamily, color: textColor, fontWeight: FontWeight.w600),
    TemplateElement(id: 'p5_family_title', pageIndex: 5, type: ElementType.text,
      content: 'Patel Family', contentGujarati: 'શ્રી પટેલ પરિવાર',
      x: 40, y: 120, width: 280, height: 45, fontSize: 36, fontFamily: fontFamily, color: primaryColor, fontWeight: FontWeight.bold),
    
    TemplateElement(id: 'p5_msg1', pageIndex: 5, type: ElementType.text,
      content: 'Accept this digital invite...', contentGujarati: 'આ ભાવભર્યું આમંત્રણ રૂબરૂ મળ્યા તુલ્ય સમજી',
      x: 30, y: 180, width: 300, height: 26, fontSize: 15, fontFamily: fontFamily, color: textColor, fontWeight: FontWeight.bold),
    TemplateElement(id: 'p5_ok', pageIndex: 5, type: ElementType.text,
      content: 'OK', contentGujarati: 'OK',
      x: 140, y: 220, width: 80, height: 35, fontSize: 26, fontFamily: fontFamily, color: primaryColor, fontWeight: FontWeight.bold),
    TemplateElement(id: 'p5_msg2', pageIndex: 5, type: ElementType.text,
      content: 'reply this way', contentGujarati: 'એવો જવાબ આપશો.',
      x: 60, y: 265, width: 240, height: 26, fontSize: 15, fontFamily: fontFamily, color: textColor, fontWeight: FontWeight.bold),
    TemplateElement(id: 'p5_msg3', pageIndex: 5, type: ElementType.text,
      content: 'Thank you...', contentGujarati: 'આ ડિજીટલ આમંત્રણ સ્વીકાર્યું તે બદલ\nઆપનો ખૂબ ખૂબ આભાર...',
      x: 40, y: 300, width: 280, height: 40, fontSize: 15, fontFamily: fontFamily, color: textColor, textAlign: TextAlign.center, fontWeight: FontWeight.w600),
    
    TemplateElement(id: 'p5_nimantrak_title', pageIndex: 5, type: ElementType.text,
      content: ':: Nimantrak ::', contentGujarati: ':: નિમંત્રક ::',
      x: 80, y: 360, width: 200, height: 26, fontSize: 18, fontFamily: fontFamily, color: primaryColor, fontWeight: FontWeight.bold),
    TemplateElement(id: 'p5_nimantrak_names', pageIndex: 5, type: ElementType.text,
      content: 'Names...', contentGujarati: 'સ્વ. ચંદ્રકાન્તભાઈ રામભાઈ પટેલ\nશ્રી પિયુષભાઈ રામભાઈ પટેલ\nશ્રી ચિંતનભાઈ પિયુષભાઈ પટેલ',
      x: 40, y: 395, width: 280, height: 60, fontSize: 14, fontFamily: fontFamily, color: textColor, textAlign: TextAlign.center, fontWeight: FontWeight.w600),
    
    TemplateElement(id: 'p5_no_gifts', pageIndex: 5, type: ElementType.text,
      content: 'No gifts please', contentGujarati: 'ચાંદલો અને ભેટ અસ્વીકાર્ય છે.',
      x: 40, y: 480, width: 280, height: 26, fontSize: 16, fontFamily: fontFamily, color: primaryColor, fontWeight: FontWeight.bold),


    // ════════════════════════════════════════════════
    // 📄 PAGE 6 — Family Details
    // ════════════════════════════════════════════════
    TemplateElement(id: 'p6_shlok', pageIndex: 6, type: ElementType.text,
      content: '॥ Shri Ganeshay Namah ॥', contentGujarati: '॥ શ્રી ગણેશાય નમઃ ॥',
      x: 60, y: 30, width: 240, height: 26, fontSize: 14, fontFamily: fontFamily, color: textColor, fontWeight: FontWeight.bold),
    
    TemplateElement(id: 'p6_title1', pageIndex: 6, type: ElementType.text,
      content: ':: Snehdhin ::', contentGujarati: ':: સ્નેહાધિન ::',
      x: 80, y: 70, width: 200, height: 26, fontSize: 18, fontFamily: fontFamily, color: primaryColor, fontWeight: FontWeight.bold),
    TemplateElement(id: 'p6_list1a', pageIndex: 6, type: ElementType.text,
      content: 'Names', contentGujarati: 'સ્વ. રામભાઈ સોમનાથ પટેલ\nસ્વ. કેશવલાલ સોમનાથ પટેલ\nસ્વ. રમણલાલ મગનદાસ પટેલ\nશ્રી શંભુભાઈ કાશીરામ પટેલ\nશ્રી બળદેવભાઈ અંબાલાલ પટેલ\nશ્રી ભગુભાઈ આત્મારામભાઈ પટેલ\nશ્રી ભરતભાઈ કેશવલાલ પટેલ',
      x: 20, y: 110, width: 150, height: 110, fontSize: 11, fontFamily: fontFamily, color: textColor, textAlign: TextAlign.left),
    TemplateElement(id: 'p6_list1b', pageIndex: 6, type: ElementType.text,
      content: 'Names', contentGujarati: 'સ્વ. સોમનાથ બોઘદાસ પટેલ\nસ્વ. અંબાલાલ સોમનાથ પટેલ\nસ્વ. આત્મારામભાઈ સોમનાથ પટેલ\nસ્વ. ધનાભાઈ રમણભાઈ પટેલ\nશ્રી વિનોદભાઈ શંભુભાઈ પટેલ\nશ્રી વસંતભાઈ રમણભાઈ પટેલ\nશ્રી ચેતનભાઈ કેશવભાઈ પટેલ',
      x: 180, y: 110, width: 160, height: 110, fontSize: 11, fontFamily: fontFamily, color: textColor, textAlign: TextAlign.left),
    
    TemplateElement(id: 'p6_title2', pageIndex: 6, type: ElementType.text,
      content: ':: Darshanabhilashi ::', contentGujarati: ':: દર્શનાભિલાષી ::',
      x: 80, y: 240, width: 200, height: 26, fontSize: 18, fontFamily: fontFamily, color: primaryColor, fontWeight: FontWeight.bold),
    TemplateElement(id: 'p6_list2a', pageIndex: 6, type: ElementType.text,
      content: 'Names', contentGujarati: 'શ્રી યોગેશ ભગવાનભાઈ પટેલ\nશ્રી વિપુલ બળદેવભાઈ પટેલ\nશ્રી પ્રીતેશ બળદેવભાઈ પટેલ\nશ્રી હર્ષદ ભગવાનભાઈ પટેલ\nસ્વ. હાર્દિક ધનાભાઈ પટેલ\nશ્રી સાગર ભરતભાઈ પટેલ\nશ્રી ગૌરાગ ભરતભાઈ પટેલ',
      x: 20, y: 280, width: 150, height: 110, fontSize: 11, fontFamily: fontFamily, color: textColor, textAlign: TextAlign.left),
    TemplateElement(id: 'p6_list2b', pageIndex: 6, type: ElementType.text,
      content: 'Names', contentGujarati: 'શ્રી આકાશ વિનોદભાઈ પટેલ\nશ્રી હર્ષ ચેતનભાઈ પટેલ\nશ્રી આર્ય રાકેશભાઈ પટેલ\nશ્રી દેવ વિપુલભાઈ પટેલ\nશ્રી આનંદ યોગેશભાઈ પટેલ\nશ્રી હેત હર્ષદભાઈ પટેલ\nશ્રી સ્વયં વસંતભાઈ પટેલ',
      x: 180, y: 280, width: 160, height: 110, fontSize: 11, fontFamily: fontFamily, color: textColor, textAlign: TextAlign.left),

    TemplateElement(id: 'p6_title3', pageIndex: 6, type: ElementType.text,
      content: ':: Mameru Mosal ::', contentGujarati: ':: મામેરુ મોસાળ ::',
      x: 80, y: 410, width: 200, height: 26, fontSize: 18, fontFamily: fontFamily, color: primaryColor, fontWeight: FontWeight.bold),
    TemplateElement(id: 'p6_list3', pageIndex: 6, type: ElementType.text,
      content: 'Names', contentGujarati: 'પટેલ હર્ષદભાઈ કાન્તિલાલ\nસ્વ. પટેલ મનીષભાઈ કાન્તિલાલ\nપટેલ દેવેન્દ્રભાઈ અંબાલાલ',
      x: 40, y: 440, width: 280, height: 50, fontSize: 12, fontFamily: fontFamily, color: textColor, textAlign: TextAlign.center),

    TemplateElement(id: 'p6_title4', pageIndex: 6, type: ElementType.text,
      content: ':: Masi & Foi ::', contentGujarati: ':: માસી અને ફોઈ ના લાડલા ::',
      x: 60, y: 500, width: 240, height: 26, fontSize: 18, fontFamily: fontFamily, color: primaryColor, fontWeight: FontWeight.bold),
    TemplateElement(id: 'p6_list4', pageIndex: 6, type: ElementType.text,
      content: 'Names', contentGujarati: 'શૌર્ય ભાવિનકુમાર પટેલ\nશ્રીવાંશ ભાવિનકુમાર પટેલ\nમયાંશ ચિંતનભાઈ પટેલ',
      x: 40, y: 530, width: 280, height: 50, fontSize: 12, fontFamily: fontFamily, color: textColor, textAlign: TextAlign.center),
    
    TemplateElement(id: 'p6_title5', pageIndex: 6, type: ElementType.text,
      content: ':: Tahuko ::', contentGujarati: ':: ટહૂકો ::',
      x: 80, y: 590, width: 200, height: 26, fontSize: 18, fontFamily: fontFamily, color: primaryColor, fontWeight: FontWeight.bold),
    TemplateElement(id: 'p6_tahuko_text', pageIndex: 6, type: ElementType.text,
      content: 'Poem...', contentGujarati: 'ઠુમક ઠુમક ચાલતા જાય, લગ્ન ગીત ગાતા જાય,\nકોઈ પૂછે ક્યાં ચાલ્યા\nઆ ભૂલકા મલકી મલકી કેહતા જાય,\nઅમે તો અમારા ફોઈ અને દીદી ના લગ્ન માં જઈએ છીએ .......\nખુશી, કીર્તન, કેવલ, ક્રિષ્ના, હેત્વી, સ્વરા, મિરાંશ',
      x: 20, y: 620, width: 320, height: 80, fontSize: 11, fontFamily: fontFamily, color: textColor, textAlign: TextAlign.center),

  ];
}
