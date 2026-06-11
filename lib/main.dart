import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

// 🔴 MODELS
import 'features/guests/data/models/guest_model.dart';
import 'providers/invitation_provider.dart';
import 'providers/language_provider.dart';
import 'providers/user_provider.dart';
import 'providers/favorites_provider.dart';
import 'providers/designs_provider.dart';
import 'providers/app_data_provider.dart';

import 'providers/guest_provider.dart';
import 'providers/subscription_provider.dart';
import 'services/auth_service.dart';

// 🔴 SCREENS
import 'screens/onboarding/onboarding_intro_screen.dart';
import 'screens/home/home_screen.dart';

import 'screens/auth/account_suspended_screen.dart';
import 'screens/auth/complete_profile_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔥 INIT FIREBASE
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    print("Firebase init failed: $e");
  }

  // 🔥 INIT HIVE
  await Hive.initFlutter();
  await AuthService.init();

  // 🧹 CLEAR CACHE FOR DEVELOPMENT SYNC
  try {
    final box = await Hive.openBox('cms_cache');
    await box.clear();
    print("🧹 Hive CMS Cache cleared successfully.");
  } catch (e) {
    print("Error clearing cache: $e");
  }

  // 🔥 REGISTER ADAPTERS
  Hive.registerAdapter(GuestModelAdapter());
  Hive.registerAdapter(FamilySideAdapter());
  Hive.registerAdapter(RsvpStatusAdapter());

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppDataProvider()),
        ChangeNotifierProxyProvider<AppDataProvider, LanguageProvider>(
          create: (_) => LanguageProvider(),
          update: (_, appData, lang) {
            lang!.reconcileWithBackend(appData.languages);
            return lang;
          },
        ),
        ChangeNotifierProxyProvider<LanguageProvider, InvitationProvider>(
          create: (_) => InvitationProvider(),
          update: (_, lang, inv) => inv!..setLanguageProvider(lang),
        ),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProxyProvider<AppDataProvider, FavoritesProvider>(
          create: (_) => FavoritesProvider(),
          update: (_, appData, favorites) => favorites!..setAppDataProvider(appData),
        ),
        ChangeNotifierProxyProvider<AppDataProvider, DesignsProvider>(
          create: (_) => DesignsProvider(),
          update: (_, appData, designs) => designs!..setAppDataProvider(appData),
        ),
        ChangeNotifierProvider(create: (_) => GuestProvider()),
        ChangeNotifierProvider(create: (_) => SubscriptionProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Wedding Kankotri',

      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.red,
        ),
      ),

      // ✅ START FROM ONBOARDING SCREEN OR HOME SCREEN
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(color: Color(0xFFF94C66)),
              ),
            );
          }
          if (snapshot.hasData && snapshot.data != null) {
            return Consumer<UserProvider>(
              builder: (context, userProvider, child) {
                if (userProvider.isLoading) {
                  return const Scaffold(
                    body: Center(
                      child: CircularProgressIndicator(color: Color(0xFFF94C66)),
                    ),
                  );
                }
                if (userProvider.isSuspended) {
                  return const AccountSuspendedScreen();
                }
                if (!userProvider.isSocialOtpVerified) {
                  return const OnboardingIntroScreen();
                }
                if (!userProvider.isProfileComplete) {
                  return const CompleteProfileScreen();
                }
                return const HomeScreen();
              },
            );
          }
          return const OnboardingIntroScreen();
        },
      ),
    );
  }
}
