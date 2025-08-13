// lib/core/service_locator.dart
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myproject2/data/services/auth_service.dart';
import 'package:myproject2/data/services/attendance_service.dart';
import 'package:myproject2/data/services/face_recognition_service.dart';
import 'package:myproject2/core/constants/app_constants.dart';

final GetIt serviceLocator = GetIt.instance;

/// Initialize all services and dependencies
Future<void> setupServiceLocator() async {
  try {
    print('🔧 Setting up service locator...');
    
    // Register external dependencies first
    await _registerExternalDependencies();
    
    // Register core services
    _registerCoreServices();
    
    // Register business services
    _registerBusinessServices();
    
    // Register utility services
    _registerUtilityServices();
    
    // Verify all services are registered
    _verifyServiceRegistration();
    
    print('✅ Service locator setup completed');
  } catch (e) {
    print('❌ Service locator setup failed: $e');
    rethrow;
  }
}

/// Register external dependencies that need async initialization
Future<void> _registerExternalDependencies() async {
  // SharedPreferences
  final sharedPreferences = await SharedPreferences.getInstance();
  serviceLocator.registerSingleton<SharedPreferences>(sharedPreferences);
  
  // Add other external dependencies here
  // e.g., Firebase, Analytics, Crash Reporting, etc.
}

/// Register core application services
void _registerCoreServices() {
  // Authentication Service
  serviceLocator.registerLazySingleton<AuthService>(
    () => AuthService(),
    dispose: (service) => service.dispose(),
  );
  
  // Face Service
  serviceLocator.registerLazySingleton<FaceService>(
    () => FaceService(),
    dispose: (service) => service.dispose(),
  );
  
  // Face Recognition Service (ML/AI)
  serviceLocator.registerLazySingleton<FaceRecognitionService>(
    () => FaceRecognitionService(),
    dispose: (service) => service.dispose(),
  );
  
  // Attendance Service
  serviceLocator.registerLazySingleton<AttendanceService>(
    () => AttendanceService(),
    dispose: (service) => service.dispose(),
  );
}

/// Register business logic services
void _registerBusinessServices() {
  // Navigation Service
  serviceLocator.registerLazySingleton<NavigationService>(
    () => NavigationService(),
  );
  
  // Storage Service
  serviceLocator.registerLazySingleton<StorageService>(
    () => StorageService(serviceLocator<SharedPreferences>()),
  );
  
  // Notification Service
  serviceLocator.registerLazySingleton<NotificationService>(
    () => NotificationService(),
    dispose: (service) => service.dispose(),
  );
  
  // Analytics Service
  if (AppConstants.enableAnalytics) {
    serviceLocator.registerLazySingleton<AnalyticsService>(
      () => AnalyticsService(),
      dispose: (service) => service.dispose(),
    );
  }
  
  // Crash Reporting Service
  if (AppConstants.enableCrashReporting) {
    serviceLocator.registerLazySingleton<CrashReportingService>(
      () => CrashReportingService(),
    );
  }
}

/// Register utility services
void _registerUtilityServices() {
  // Logger Service
  serviceLocator.registerLazySingleton<LoggerService>(
    () => LoggerService(),
  );
  
  // Validation Service
  serviceLocator.registerLazySingleton<ValidationService>(
    () => ValidationService(),
  );
  
  // File Service
  serviceLocator.registerLazySingleton<FileService>(
    () => FileService(),
  );
  
  // Network Service
  serviceLocator.registerLazySingleton<NetworkService>(
    () => NetworkService(),
    dispose: (service) => service.dispose(),
  );
  
  // Permission Service
  serviceLocator.registerLazySingleton<PermissionService>(
    () => PermissionService(),
  );
}

/// Verify that all critical services are properly registered
void _verifyServiceRegistration() {
  final criticalServices = [
    AuthService,
    FaceService,
    AttendanceService,
    NavigationService,
    StorageService,
    LoggerService,
  ];
  
  for (final serviceType in criticalServices) {
    if (!serviceLocator.isRegistered(instance: serviceType)) {
      throw ServiceLocatorException('Critical service $serviceType is not registered');
    }
  }
  
  print('✅ All critical services verified');
}

/// Clean up all services (call this when app is terminated)
Future<void> disposeServiceLocator() async {
  try {
    print('🧹 Disposing service locator...');
    await serviceLocator.reset(dispose: true);
    print('✅ Service locator disposed');
  } catch (e) {
    print('❌ Error disposing service locator: $e');
  }
}

// ==================== Service Implementations ====================

class NavigationService {
  // TODO: Implement navigation service
  void dispose() {}
}

class StorageService {
  final SharedPreferences _prefs;
  
  StorageService(this._prefs);
  
  // User Preferences
  Future<void> setUserEmail(String email) async {
    await _prefs.setString(AppConstants.userEmailKey, email);
  }
  
  String? getUserEmail() {
    return _prefs.getString(AppConstants.userEmailKey);
  }
  
  Future<void> setUserType(String userType) async {
    await _prefs.setString(AppConstants.userTypeKey, userType);
  }
  
  String? getUserType() {
    return _prefs.getString(AppConstants.userTypeKey);
  }
  
  // App Settings
  Future<void> setThemeMode(String theme) async {
    await _prefs.setString(AppConstants.themeKey, theme);
  }
  
  String getThemeMode() {
    return _prefs.getString(AppConstants.themeKey) ?? 'system';
  }
  
  // Clear all data
  Future<void> clearAll() async {
    await _prefs.clear();
  }
  
  void dispose() {}
}

class NotificationService {
  // TODO: Implement push notifications
  void dispose() {}
}

class AnalyticsService {
  // TODO: Implement analytics tracking
  void dispose() {}
}

class CrashReportingService {
  // TODO: Implement crash reporting
}

class LoggerService {
  void logInfo(String message) {
    if (AppConstants.enableDebugLogging) {
      print('ℹ️ INFO: $message');
    }
  }
  
  void logWarning(String message) {
    if (AppConstants.enableDebugLogging) {
      print('⚠️ WARNING: $message');
    }
  }
  
  void logError(String message, {Object? error, StackTrace? stackTrace}) {
    if (AppConstants.enableDebugLogging) {
      print('❌ ERROR: $message');
      if (error != null) print('Error details: $error');
      if (stackTrace != null) print('Stack trace: $stackTrace');
    }
    
    // In production, send to crash reporting service
    if (AppConstants.enableCrashReporting && serviceLocator.isRegistered<CrashReportingService>()) {
      // serviceLocator<CrashReportingService>().logError(message, error, stackTrace);
    }
  }
  
  void dispose() {}
}

class ValidationService {
  bool isValidEmail(String email) {
    return AppConstants.isValidEmail(email);
  }
  
  bool isValidPassword(String password) {
    return AppConstants.isValidPassword(password);
  }
  
  bool isValidClassId(String classId) {
    return AppConstants.isValidClassId(classId);
  }
  
  bool isValidSchoolId(String schoolId) {
    return AppConstants.isValidSchoolId(schoolId);
  }
  
  String? validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }
  
  String? validateEmail(String? value) {
    if (!isValidEmail(value ?? '')) {
      return 'Please enter a valid email address';
    }
    return null;
  }
  
  String? validatePassword(String? value) {
    if (!isValidPassword(value ?? '')) {
      return 'Password must be at least 6 characters long';
    }
    return null;
  }
  
  void dispose() {}
}

class FileService {
  // TODO: Implement file operations
  void dispose() {}
}

class NetworkService {
  // TODO: Implement network connectivity checking
  void dispose() {}
}

class PermissionService {
  // TODO: Implement permission handling
  void dispose() {}
}

// ==================== Helper Extensions ====================

extension ServiceLocatorExtensions on GetIt {
  /// Check if a service is registered without throwing an exception
  bool isRegistered<T extends Object>({Object? instance, String? instanceName}) {
    try {
      get<T>(instanceName: instanceName);
      return true;
    } catch (e) {
      return false;
    }
  }
}

// Add dispose methods to existing services (extend them)
extension AuthServiceExtension on AuthService {
  void dispose() {
    // Cleanup if needed
  }
}

extension FaceServiceExtension on FaceService {
  void dispose() {
    // Cleanup if needed
  }
}

extension AttendanceServiceExtension on AttendanceService {
  void dispose() {
    // Cleanup if needed
  }
}

// ==================== Custom Exceptions ====================

class ServiceLocatorException implements Exception {
  final String message;
  
  ServiceLocatorException(this.message);
  
  @override
  String toString() => 'ServiceLocatorException: $message';
}