import 'package:supabase_flutter/supabase_flutter.dart';

class AuthServer {
  final SupabaseClient _supabase = Supabase.instance.client;

  //sign in
  Future<AuthResponse> siginWithEmailPassword(
      String email, String password) async {
    return await _supabase.auth
        .signInWithPassword(password: password, email: email);
  }

  //sigh up
  Future<AuthResponse> sigUpWithEmailPassword(
      String email, String password) async {
    return await _supabase.auth.signUp(password: password, email: email);
  }

  //sigh out
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  //get uest email
  String? getCurrentUserEmail() {
    final session = _supabase.auth.currentSession;
    final user = session?.user;
    return user?.email;
  }
}
