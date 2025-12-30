import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

class CloudFunctionsService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Manually trigger the update of store listings (hot, new, clearance)
  Future<Map<String, dynamic>> manuallyTriggerUpdate() async {
    try {
      final callable = _functions.httpsCallable('manuallyTriggerUpdate');
      final result = await callable.call();
      
      debugPrint('[CloudFunctionsService] Manual update result: ${result.data}');
      
      return {
        'success': result.data['success'] ?? false,
        'message': result.data['message'] ?? 'Update completed',
      };
    } on FirebaseFunctionsException catch (e) {
      debugPrint('[CloudFunctionsService] Firebase Functions error: ${e.code} - ${e.message}');
      return {
        'success': false,
        'message': e.message ?? 'Failed to update listings',
      };
    } catch (e) {
      debugPrint('[CloudFunctionsService] Unexpected error: $e');
      return {
        'success': false,
        'message': 'An unexpected error occurred',
      };
    }
  }
}
