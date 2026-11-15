// =============================================================================
// CarLog Riverpod State Management Providers
// Reactive bindings for Database, DAOs, Sync Engine & User Authentication
// =============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../data/local/database.dart';
import '../data/local/daos/vehicle_dao.dart';
import '../data/local/daos/maintenance_dao.dart';
import '../data/local/daos/fuel_dao.dart';
import '../data/local/daos/symptom_dao.dart';
import '../data/local/daos/inventory_dao.dart';
import '../data/sync/sync_engine.dart';
import '../core/network/api_client.dart';
import '../core/network/connectivity_guard.dart';

// -----------------------------------------------------------------------------
// 1. Core Services Providers
// -----------------------------------------------------------------------------

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});

final vehicleDaoProvider = Provider<VehicleDao>((ref) {
  return VehicleDao(ref.watch(databaseProvider));
});

final maintenanceDaoProvider = Provider<MaintenanceDao>((ref) {
  return MaintenanceDao(ref.watch(databaseProvider));
});

final fuelDaoProvider = Provider<FuelDao>((ref) {
  return FuelDao(ref.watch(databaseProvider));
});

final symptomDaoProvider = Provider<SymptomDao>((ref) {
  return SymptomDao(ref.watch(databaseProvider));
});

final inventoryDaoProvider = Provider<InventoryDao>((ref) {
  return InventoryDao(ref.watch(databaseProvider));
});

final syncEngineProvider = Provider<SyncEngine>((ref) {
  return SyncEngine(
    db: ref.watch(databaseProvider),
    apiClient: ref.watch(apiClientProvider),
  );
});

// -----------------------------------------------------------------------------
// 2. Authentication State Management
// -----------------------------------------------------------------------------

class AuthUserState {
  final String? id;
  final String? email;
  final String? fullName;
  final bool isAuthenticated;
  final bool isEmailVerified;
  final bool isLoading;
  final String? errorMessage;

  AuthUserState({
    this.id,
    this.email,
    this.fullName,
    this.isAuthenticated = false,
    this.isEmailVerified = false,
    this.isLoading = false,
    this.errorMessage,
  });

  AuthUserState copyWith({
    String? id,
    String? email,
    String? fullName,
    bool? isAuthenticated,
    bool? isEmailVerified,
    bool? isLoading,
    String? errorMessage,
  }) {
    return AuthUserState(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthUserState> {
  final ApiClient _apiClient;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  AuthNotifier(this._apiClient) : super(AuthUserState()) {
    checkInitialAuth();
  }

  Future<void> checkInitialAuth() async {
    final token = await _storage.read(key: 'access_token');
    final userId = await _storage.read(key: 'user_id');
    final email = await _storage.read(key: 'user_email');
    final fullName = await _storage.read(key: 'user_name');

    if (token != null && token.isNotEmpty && userId != null) {
      state = state.copyWith(
        id: userId,
        email: email,
        fullName: fullName,
        isAuthenticated: true,
        isEmailVerified: true,
      );
    }
  }

  Future<bool> register(String fullName, String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final res = await _apiClient.dio.post('/auth/register', data: {
        'full_name': fullName,
        'email': email,
        'password': password,
      });

      if (res.statusCode == 201) {
        state = state.copyWith(
          email: email,
          fullName: fullName,
          isLoading: false,
          isEmailVerified: false,
        );
        return true;
      }
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> verifyEmail(String email, String code) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final res = await _apiClient.dio.post('/auth/verify-email', data: {
        'email': email,
        'code': code,
      });

      if (res.statusCode == 200 && res.data?['data'] != null) {
        final data = res.data['data'];
        final user = data['user'];
        final tokens = data['tokens'];

        await _storage.write(key: 'access_token', value: tokens['access_token']);
        await _storage.write(key: 'refresh_token', value: tokens['refresh_token']);
        await _storage.write(key: 'user_id', value: user['id']);
        await _storage.write(key: 'user_email', value: user['email']);
        await _storage.write(key: 'user_name', value: user['full_name']);

        state = state.copyWith(
          id: user['id'],
          email: user['email'],
          fullName: user['full_name'],
          isAuthenticated: true,
          isEmailVerified: true,
          isLoading: false,
        );
        return true;
      }
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final res = await _apiClient.dio.post('/auth/login', data: {
        'email': email,
        'password': password,
      });

      if (res.statusCode == 200 && res.data?['data'] != null) {
        final data = res.data['data'];
        final user = data['user'];
        final tokens = data['tokens'];

        await _storage.write(key: 'access_token', value: tokens['access_token']);
        await _storage.write(key: 'refresh_token', value: tokens['refresh_token']);
        await _storage.write(key: 'user_id', value: user['id']);
        await _storage.write(key: 'user_email', value: user['email']);
        await _storage.write(key: 'user_name', value: user['full_name']);

        state = state.copyWith(
          id: user['id'],
          email: user['email'],
          fullName: user['full_name'],
          isAuthenticated: true,
          isEmailVerified: true,
          isLoading: false,
        );
        return true;
      }
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> googleSignIn(String idToken) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final res = await _apiClient.dio.post('/auth/google', data: {'id_token': idToken});
      if (res.statusCode == 200 && res.data?['data'] != null) {
        final data = res.data['data'];
        final user = data['user'];
        final tokens = data['tokens'];

        await _storage.write(key: 'access_token', value: tokens['access_token']);
        await _storage.write(key: 'refresh_token', value: tokens['refresh_token']);
        await _storage.write(key: 'user_id', value: user['id']);
        await _storage.write(key: 'user_email', value: user['email']);
        await _storage.write(key: 'user_name', value: user['full_name']);

        state = state.copyWith(
          id: user['id'],
          email: user['email'],
          fullName: user['full_name'],
          isAuthenticated: true,
          isEmailVerified: true,
          isLoading: false,
        );
        return true;
      }
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<void> logout() async {
    await _storage.deleteAll();
    state = AuthUserState();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthUserState>((ref) {
  return AuthNotifier(ref.watch(apiClientProvider));
});

// -----------------------------------------------------------------------------
// 3. UI & Dashboard Providers
// -----------------------------------------------------------------------------

final selectedVehicleIdProvider = StateProvider<String?>((ref) => null);

final vehiclesStreamProvider = StreamProvider<List<VehiclesTableData>>((ref) {
  final auth = ref.watch(authProvider);
  final userId = auth.id ?? 'default_user';
  return ref.watch(vehicleDaoProvider).watchAllVehicles(userId);
});

final pendingSyncCountProvider = FutureProvider<int>((ref) async {
  return await ref.watch(vehicleDaoProvider).countPendingSyncRows();
});

final networkConnectivityProvider = StreamProvider<bool>((ref) async* {
  yield await ConnectivityGuard.hasInternet();
  // Poll or check periodically
  while (true) {
    await Future.delayed(const Duration(seconds: 10));
    yield await ConnectivityGuard.hasInternet();
  }
});
