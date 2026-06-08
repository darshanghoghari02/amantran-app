# 🌸 Nimantran (Wedding Kankotri Maker App) - Complete Flow & Architecture Guide

यह दस्तावेज़ इस Flutter एप्लीकेशन के पूरे वर्किंग फ्लो (Flow), डेटा सोर्स (Data Sources), लोकल डेटाबेस (Local Database) और अनुमतियों (Permissions) की पूरी विस्तृत जानकारी देता है।

---

## 📌 1. एप्लीकेशन का मुख्य उद्देश्य (App Overview)
यह एक **Gujarati Wedding Kankotri (Invitation Card) Maker App** है। इसके ज़रिये यूज़र्स शादी (Wedding), सगाई (Engagement), और सीमंत संस्कार (Baby Shower) के लिए सुंदर गुजराती और अंग्रेजी निमंत्रण पत्र (Invitation Cards) बना सकते हैं, उन्हें कस्टमाइज़ कर सकते हैं, गेस्ट लिस्ट मैनेज कर सकते हैं और डिजिटल कार्ड शेयर कर सकते हैं।

---

## 🔄 2. एप्लीकेशन का पूरा फ्लो (Complete User Flow & Navigation)

जब कोई यूज़र ऐप खोलता है, तो नीचे दिए गए सीक्वेंस के अनुसार ऐप काम करता है:

```mermaid
graph TD
    Start([App Launched]) --> Init[Initialize Firebase & Hive DB]
    Init --> CheckSession{Is User Logged In?}
    
    %% Session Checking
    CheckSession -- No, First Time -- > Intro[Onboarding Intro Screen]
    CheckSession -- Has Recent Account but Logged Out --> Login[Login / Signup Screen]
    CheckSession -- Yes, Active Session --> Home[Home Dashboard Screen]
    
    Intro --> Login
    Login -->|Phone OTP Verification| Home
    
    %% Home & Core Flow
    Home --> TabSelect{Select Category}
    TabSelect -->|Wedding / Engagement / Baby Shower| TemplateList[Select Card Template]
    
    TemplateList --> FormFill[Fill Invitation Form]
    FormFill -->|Auto Transliterate Eng to Guj| CanvasEditor[Canvas Card Editor]
    
    CanvasEditor -->|Drag, Move, Font Style, Color| Preview[Card Preview & PDF Export]
    Preview --> Share[Share via WhatsApp / Social Media]
    
    %% Guests Flow
    Home --> GuestManage[Guest List & RSVP Tracker]
    GuestManage -->|Import Contacts / Manual| GuestList[Manage Invites & RSVP Status]
    GuestList -->|Update Status| SendInvite[Share Custom Invite Link]
```

### 📱 स्क्रीन और उनके नेविगेशन का विवरण (Screen-by-Step Flow):

1. **ऐप इनिशियलाइजेशन (Initialization):**
   * ऐप शुरू होते ही `main.dart` में **Firebase** और **Hive Database** इनिशियलाइज होते हैं।
   * `UserProvider` चेक करता है कि क्या डिवाइस में पहले से कोई एक्टिव लॉगिन सेशन (Active Login Session) सेव है।

2. **ऑनबोर्डिंग और लॉगिन (Onboarding & Auth):**
   * **फर्स्ट टाइम यूज़र:** `OnboardingIntroScreen` दिखाई देती है जहाँ ऐप के मुख्य फ़ीचर्स समझाए जाते हैं।
   * **लॉगिन स्क्रीन:** यूज़र अपने फोन नंबर से लॉगिन/साइनअप करता है। यहाँ Firebase OTP authentication या `AuthService` का उपयोग होता है। हाल ही में लॉग इन किए गए अकाउंट्स (Recent Accounts) भी दिखाई देते हैं ताकि आसानी से दोबारा लॉगिन किया जा सके।

3. **होम डैशबोर्ड (Home Dashboard Screen):**
   * लॉगिन के बाद यूज़र `HomeScreen` पर पहुँचता है।
   * यहाँ तीन मुख्य टैब हैं: **Wedding**, **Engagement**, और **Baby Shower**।
   * होम स्क्रीन पर यूज़र को अपने ड्राफ्ट (Drafts), कम्पलीट किए गए कार्ड्स (Completed Designs), और आमंत्रित मेहमानों के RSVP आंकड़े (Total, Pending, Sent, Viewed invites) दिखते हैं।

4. **टेम्पलेट चयन (Template Selection):**
   * यूज़र 9 अलग-अलग आकर्षक थीम्स में से एक टेम्पलेट चुनता है (उदा. Classic, Royal, Traditional, Mandala, Blue आदि)।

5. **फॉर्म फिलिंग और ऑटो-ट्रांसलेशन (Details Form & Transliteration):**
   * कार्ड चुनने के बाद यूज़र दूल्हा-दुल्हन का नाम, माता-पिता का नाम, शादी की तारीख, स्थान (Venue) और इवेंट्स की जानकारी भरता है।
   * **Transliteration Engine:** जब यूज़र इंग्लिश में कुछ टाइप करता है, तो बैकग्राउंड में वह ऑटोमेटिकली सही गुजराती अक्षरों (उदा. "Harmi" -> "હાર્મી") में ट्रांसलेट (Transliterate) हो जाता है।

6. **कैनवास कार्ड एडिटर (Canvas Drag-and-Drop Editor):**
   * यह ऐप का सबसे शक्तिशाली हिस्सा है। यहाँ कार्ड के 7 अलग-अलग पेजों को लाइव एडिट किया जा सकता है:
     * *Cover Page, Welcome & Invitation, Pre-Wedding Events, Sangeet Sandhya, Shubh Vivah, Family Details, Contact & Thanks.*
   * यूज़र कैनवास पर किसी भी टेक्स्ट पर क्लिक करके उसका **Font, Size, Alignment, Color, Line Height, Opacity, Rotation** बदल सकता है और टेक्स्ट को ड्रैग करके उसकी जगह (Coordinates) बदल सकता है।
   * गणेश जी के लोगो (Ganesh presets) या गूगल मैप आइकॉन को छोटा-बड़ा और मूव किया जा सकता है।

7. **प्रीव्यू और एक्सपोर्ट (Preview, PDF & Share):**
   * यूज़र पूरे कार्ड को स्लाइडर के रूप में देख सकता है।
   * **PDF Export:** कार्ड को HD PDF में एक्सपोर्ट किया जा सकता है या सीधे प्रिंट किया जा सकता है (`printing` और `pdf` पैकेज की मदद से)।
   * **Direct Share:** कार्ड का लिंक या इमेज सीधे WhatsApp पर भेजी जा सकती है।

8. **गेस्ट लिस्ट और RSVP ट्रैकर (Guest & RSVP Management):**
   * यूज़र अपने मेहमानों की लिस्ट बनाता है।
   * मेहमानों को सीधे फोन के कॉन्टैक्ट्स (Device Contacts) से इम्पोर्ट किया जा सकता है।
   * हर मेहमान का RSVP स्टेटस ट्रैक किया जा सकता है: `Pending`, `Sent`, या `Viewed`।
   * यहाँ से डायरेक्ट कस्टमाइज़्ड आमंत्रण मैसेज जनरेट करके व्हाट्सएप पर भेजा जा सकता है।

---

## 💾 3. लोकल डेटाबेस और स्टोरेज (Local Database & Storage)

यूज़र फोन में जो भी बदलाव करता है (जैसे कार्ड एडिट करना, गेस्ट जोड़ना, लॉगिन सेशन), वे सभी **Hive Database** (एक सुपर-फ़ास्ट लोकल की-वैल्यू स्टोर) में सेव होते हैं।

ऐप में उपयोग होने वाले **Hive Boxes** की पूरी सूची और उनका डेटा स्ट्रक्चर:

| Hive Box Name | Purpose (उपयोग) | Saved Data Structure (डेटा फ़ॉर्मेट) |
| :--- | :--- | :--- |
| **`user_session_box`** | एक्टिव यूज़र के लॉगिन सेशन को सेव रखने के लिए ताकि बार-बार लॉगिन न करना पड़े। | `{ "name": String, "phone": String, "email": String, "profileImagePath": String? }` |
| **`recent_accounts_box`** | एक ही फोन में लॉगिन किए गए पिछले 5 अकाउंट्स की जानकारी रखने के लिए। | `List<Map>` - प्रत्येक मैप में Name, Phone, Email, और Profile Image की डिटेल्स होती हैं। |
| **`favorite_templates_box`** | यूज़र द्वारा पसंदीदा (Favorite) किए गए टेम्पलेट्स की लिस्ट स्टोर करने के लिए। | `List<String>` - पसंदीदा टेम्पलेट की IDs (e.g. `'theme_1'`, `'theme_2'`) |
| **`active_guests_box`** | मेहमानों की सूची (Guest List) और उनके RSVP स्टेटस को स्टोर करने के लिए। | `List<Map>` - `{ "id": String, "name": String, "phone": String, "note": String, "rsvpStatus": String (pending/sent/viewed) }` |
| **`user_designs_box`** | यूज़र द्वारा एडिट किए गए निमंत्रण पत्रों के ड्राफ्ट्स (Drafts) और कंप्लीटेड कार्ड्स को सेव करने के लिए। | `List<Map>` (UserDesign JSON) - टेम्पलेट ID, आख़िरी बार अपडेट का समय, Draft स्थिति, और कैनवास के सभी एलिमेंट्स (जैसे X/Y निर्देशांक, फॉन्ट, कलर, साइज आदि) का पूरा JSON ऐरे। |

---

## 🌐 4. डेटा कहाँ से आ रहा है? (Data Sources)

ऐप का डेटा मुख्य रूप से इन 5 सोर्सेज से आता है:

1. **स्टेटिक टेम्पलेट्स और एसेट्स (Static Assets):**
   * बेस लेआउट और डिफ़ॉल्ट कार्ड की डिज़ाइन `lib/data/templates/` में कोड की हुई हैं (जैसे `theme_1_classic.dart` से `theme_9_mandala.dart`)।
   * बैकग्राउंड इमेजेज, गणेश जी की तस्वीरें, और शादी के स्पेशल गुजराती फॉन्ट्स (उदा. *KAP011, Rasa, Hind Vadodara, Farsan*) लोकल `assets/` फोल्डर से लोड होते हैं।
   
2. **यूज़र इनपुट (User Inputs):**
   * निमंत्रण फॉर्म और कैनवास एडिटर में यूज़र जो जानकारी डालता है और स्टाइल सेट करता है।

3. **लॉजिकल ट्रांसलिट्रेशन एपीआई (Transliteration API):**
   * अंग्रेजी टेक्स्ट को गुजराती में ऑन-द-फ्लाई बदलने के लिए `transliteration_engine.dart` का इस्तेमाल किया जाता है, जो ट्रांसलेशन डेटा लाता है।

4. **डिवाइस कॉन्टैक्ट्स (Device Contacts):**
   * गेस्ट लिस्ट बनाते समय डेटा सीधे यूज़र के फोन की कॉन्टैक्ट बुक (Address Book) से आता है।

5. **लोकल हाइव डेटाबेस (Hive DB):**
   * पहले से सेव किए गए ड्राफ्ट, सेटिंग्स और गेस्ट डिटेल्स लोकल स्टोरेज से लोड होते हैं।

---

## 🔑 5. ऐप कौन-कौन सी परमिशन ले रहा है? (App Permissions)

एप्लीकेशन सुचारू रूप से काम करने के लिए फोन से निम्नलिखित अनुमतियाँ (Permissions) लेता है:

### 🤖 Android (AndroidManifest.xml में):
* **`android.permission.INTERNET`**: 
  * *क्यों चाहिए?* Firebase ऑथेंटिकेशन, ऑनलाइन इमेजेज लोड करने और अंग्रेजी से गुजराती ट्रांसलिट्रेशन एपीआई एक्सेस करने के लिए।
* **`android.permission.READ_CONTACTS`** & **`android.permission.WRITE_CONTACTS`**: 
  * *क्यों चाहिए?* यूज़र के फोन से गेस्ट लिस्ट में सीधे कांटेक्ट इम्पोर्ट करने के लिए और गेस्ट डिटेल्स सिंक करने के लिए।

### 🍏 iOS (Info.plist में):
* **`NSContactsUsageDescription`**:
  * *क्यों चाहिए?* "This app needs contacts access to import guest invitations." (यूज़र के कॉन्टैक्ट्स एक्सेस करके आसानी से कार्ड इनविटेशन भेजने के लिए)।

### ⚡ रनटाइम परमिशन हैंडलिंग (Dynamic Permissions):
* ऐप `permission_handler` पैकेज का उपयोग करता है। जब भी यूज़र कॉन्टैक्ट्स इम्पोर्ट करने की कोशिश करता है, ऐप स्क्रीन पर पॉप-अप दिखाकर परमिशन मांगता है। परमिशन मिलने पर ही कॉन्टैक्ट्स लोड होते हैं।

---

## 🎨 6. कैनवास और डिज़ाइन का रिफ्लेक्शन (How Editor Works)
जब यूज़र फॉर्म में बदलाव करता है या कैनवास पर ड्रैग करता है, तो `InvitationProvider` में `syncToElements` मेथड कॉल होती है:
1. यह फॉर्म के डेटा (जैसे वर/वधू का नाम, तारीख, स्थान) को लेकर कैनवास के विशिष्ट पेजों पर मौजूद `TemplateElement` में रिफ्लेक्ट कर देती है।
2. **TextPainter** की मदद से यह टेक्स्ट की वास्तविक चौड़ाई और ऊंचाई को नापती है ताकि स्क्रीन से बाहर टेक्स्ट ओवरफ्लो न हो और अलाइनमेंट बिल्कुल सेंटर में रहे।
3. यूज़र जैसे ही "Save" दबाता है, `DesignsProvider` हाइव बॉक्स (`user_designs_box`) में पूरी स्टेट को JSON में कन्वर्ट करके परमानेंटली सुरक्षित कर देता है।

---
*यह डॉक्यूमेंट Nimantran विवाह कंकोत्तरी ऐप के पूरे आर्किटेक्चर को समझने के लिए सबसे बेस्ट गाइड है।*
