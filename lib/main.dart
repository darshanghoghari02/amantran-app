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
import 'config/api_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Resolve base URL for local testing environment
  await ApiConfig.resolveBaseUrl();

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

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isCheckingAuth = true;
  late final Stream<User?> _authStateStream;

  @override
  void initState() {
    super.initState();
    _authStateStream = FirebaseAuth.instance.authStateChanges();
    _checkAuthToken();
  }

  Future<void> _checkAuthToken() async {
    final userProvider = context.read<UserProvider>();
    // Wait for local configurations to load from SharedPreferences/Hive
    await userProvider.initialization;

    final token = await userProvider.getAuthToken();
    print("🔍 [Main] Checking auth token: ${token != null ? 'Token found' : 'No token'}");
    
    // If JWT token exists, fetch user data from backend BEFORE showing any screen
    if (token != null && token.isNotEmpty) {
      print("✅ [Main] Valid token found, fetching profile from cloud");
      try {
        await userProvider.fetchProfileFromCloud();
      } catch (e) {
        print("⚠️ [Main] Startup profile fetch failed: $e");
      }
    } else {
      print("❌ [Main] No valid token found");
      
      // Check if Firebase user exists but profile is incomplete on startup
      if (FirebaseAuth.instance.currentUser != null) {
        print("✅ [Main] Firebase user found, fetching profile from cloud");
        try {
          await userProvider.fetchProfileFromCloud();
        } catch (e) {
          print("⚠️ [Main] Startup Firebase profile fetch failed: $e");
        }
      }
    }
    
    setState(() {
      _isCheckingAuth = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();

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
      home: _isCheckingAuth
          ? const Scaffold(
              body: Center(
                child: CircularProgressIndicator(color: Color(0xFFF94C66)),
              ),
            )
          : StreamBuilder<User?>(
              stream: _authStateStream,
              builder: (context, snapshot) {
                // Check if user is logged in via Firebase Auth OR has valid JWT token
                final isFirebaseLoggedIn = snapshot.hasData && snapshot.data != null;
                final isJwtLoggedIn = userProvider.isAuthenticated;

                print("🔍 [Main] Auth state check - Firebase: $isFirebaseLoggedIn, JWT: $isJwtLoggedIn");

                if (snapshot.connectionState == ConnectionState.waiting && !isJwtLoggedIn) {
                  return const Scaffold(
                    body: Center(
                      child: CircularProgressIndicator(color: Color(0xFFF94C66)),
                    ),
                  );
                }
                
                // If user has valid JWT token, they are logged in regardless of Firebase state
                if (isJwtLoggedIn) {
                  print("✅ [Main] User logged in via JWT token");
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
                      if (!userProvider.isProfileComplete) {
                        return const CompleteProfileScreen();
                      }
                      return const HomeScreen();
                    },
                  );
                }
                
                // If no JWT token, check Firebase Auth
                if (isFirebaseLoggedIn) {
                  print("✅ [Main] User logged in via Firebase");
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
                      if (!userProvider.isProfileComplete) {
                        return const CompleteProfileScreen();
                      }
                      return const HomeScreen();
                    },
                  );
                }
                
                print("❌ [Main] User not logged in, showing onboarding");
                return const OnboardingIntroScreen();
              },
            ),
    );
  }
}
