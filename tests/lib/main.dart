import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:tests/account.dart';
import 'package:tests/archive.dart';
import 'package:tests/auth/forgot_password_screen.dart';
import 'package:tests/auth/home_screen.dart';
import 'package:tests/auth/login_screen.dart';
import 'package:tests/auth/signup_screen.dart';
import 'package:tests/auth/wrapper_screen.dart';
import 'package:tests/dashboard.dart';
import 'package:tests/track_usage.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Auth UI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: false),
      initialRoute: '/',
      routes: {
        '/': (_) => const WrapperScreen(),
        '/home': (_) => const HomeScreen(),
        '/login': (_) => const LoginScreen(),
        '/signup': (_) => const SignUpScreen(),
        '/forgot_pswd': (_) => const ForgotPasswordScreen(),
        '/account': (_) => const AccountPage(),
        '/archive': (_) => const ArchivePage(),
        '/track': (_) => const TrackUsagePage(),
        '/dashboard': (_) => const DashboardPage()
      },
    );
  }
}
