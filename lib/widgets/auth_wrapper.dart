import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/login_screen.dart';
import '../screens/home_screen.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  User? _user;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _getInitialSession();
    _listenToAuthChanges();
  }

  Future<void> _getInitialSession() async {
    final session = Supabase.instance.client.auth.currentSession;
    setState(() {
      _user = session?.user;
      _isLoading = false;
    });
  }

  void _listenToAuthChanges() {
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;
      
      setState(() {
        _user = session?.user;
      });

      if (event == AuthChangeEvent.signedIn) {
        // User signed in
        print('User signed in: ${_user?.email ?? _user?.phone}');
      } else if (event == AuthChangeEvent.signedOut) {
        // User signed out
        print('User signed out');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return _user != null ? const HomeScreen() : const LoginScreen();
  }
}
