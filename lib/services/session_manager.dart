class SessionManager {
  static bool isLoggedIn = false;

  static void login() {
    isLoggedIn = true;
  }

  static void logout() {
    isLoggedIn = false;
  }
}
