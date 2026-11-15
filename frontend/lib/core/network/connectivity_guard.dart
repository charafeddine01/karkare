// =============================================================================
// CarLog Mandatory Online Action Guard & Reason Toast Service
// Verifies real internet connectivity and provides exact failure reasons
// =============================================================================

import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:dio/dio.dart';
import 'toast_service.dart';

class OfflineException implements Exception {
  final String message;
  OfflineException(this.message);
  @override
  String toString() => message;
}

class ConnectivityGuard {
  static final Connectivity _connectivity = Connectivity();
  static final InternetConnection _internetChecker = InternetConnection();

  /// Real internet connectivity verification
  static Future<bool> hasInternet() async {
    try {
      final connectivityResults = await _connectivity.checkConnectivity();
      if (connectivityResults.contains(ConnectivityResult.none)) {
        return false;
      }
      return await _internetChecker.hasInternetAccess;
    } catch (_) {
      return false;
    }
  }

  /// Wraps online-only operations with reason toast notifications
  static Future<T?> run<T>({
    required String featureName,
    required Future<T> Function() action,
    bool showToastOnSuccess = false,
    String? successMessage,
    bool rethrowError = false,
  }) async {
    final online = await hasInternet();

    if (!online) {
      final reasonMsg = 'Offline: $featureName requires an active internet connection. Working from local storage.';
      ToastService.show(reasonMsg, type: ToastType.warning);
      if (rethrowError) {
        throw OfflineException(reasonMsg);
      }
      return null;
    }

    try {
      final result = await action();
      if (showToastOnSuccess && successMessage != null) {
        ToastService.show(successMessage, type: ToastType.success);
      }
      return result;
    } on DioException catch (dioErr) {
      String reason;
      if (dioErr.type == DioExceptionType.connectionTimeout ||
          dioErr.type == DioExceptionType.sendTimeout ||
          dioErr.type == DioExceptionType.receiveTimeout) {
        reason = 'Connection timed out: The remote server took too long to respond. Please try again.';
      } else if (dioErr.error is SocketException || dioErr.type == DioExceptionType.connectionError) {
        reason = 'Connection failed: Unable to resolve remote host. Please check your network connection.';
      } else if (dioErr.response != null && (dioErr.response!.statusCode ?? 0) >= 500) {
        reason = 'Service unavailable: The external registry is temporarily offline.';
      } else if (dioErr.response?.data != null && dioErr.response?.data is Map) {
        final errObj = dioErr.response!.data['error'];
        reason = errObj?['message']?.toString() ?? 'Remote server error: ${dioErr.message}';
      } else {
        reason = 'Network error: ${dioErr.message}';
      }

      ToastService.show(reason, type: ToastType.error);
      if (rethrowError) rethrow;
      return null;
    } catch (e) {
      final msg = 'Operation failed: ${e.toString()}';
      ToastService.show(msg, type: ToastType.error);
      if (rethrowError) rethrow;
      return null;
    }
  }
}
