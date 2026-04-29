import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

// 🔴 MODELS
import 'features/guests/data/models/guest_model.dart';
import 'providers/invitation_provider.dart';

// 🔴 SCREENS
import 'screens/home/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔥 INIT HIVE
  await Hive.initFlutter();

  // 🔥 REGISTER ADAPTERS
  Hive.registerAdapter(GuestModelAdapter());
  Hive.registerAdapter(FamilySideAdapter());
  Hive.registerAdapter(RsvpStatusAdapter());

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => InvitationProvider()),
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

      // ✅ START FROM HOME SCREEN
      home: const HomeScreen(),
    );
  }
}
