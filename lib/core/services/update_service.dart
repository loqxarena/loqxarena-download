import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';

class UpdateService {
  static Future<Map<String, dynamic>?> checkForUpdate() async {
    try {
      // 1. Get current installed version
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      String currentVersion = packageInfo.version; // e.g., "1.0.0"

      // 2. Get latest required version from Firebase
      DocumentSnapshot snap = await FirebaseFirestore.instance.collection('settings').doc('app_config').get();
      
      if (snap.exists && snap.data() != null) {
        final data = snap.data() as Map<String, dynamic>;
        String latestVersion = data['latestVersion'] ?? "1.0.0";
        String updateUrl = data['updateUrl'] ?? "https://yourwebsite.com/download";
        bool forceUpdate = data['forceUpdate'] ?? true;

        // 3. Compare Versions
        if (_isUpdateRequired(currentVersion, latestVersion) && forceUpdate) {
          return {
            'updateRequired': true,
            'updateUrl': updateUrl,
          };
        }
      }
      return {'updateRequired': false};
    } catch (e) {
      // If network fails, let them in (don't lock them out due to a bad connection)
      return {'updateRequired': false};
    }
  }

  // Helper to accurately compare versions like "1.0.2" vs "1.0.12"
  static bool _isUpdateRequired(String current, String latest) {
    List<int> currentParts = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    List<int> latestParts = latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    for (int i = 0; i < 3; i++) {
      int c = i < currentParts.length ? currentParts[i] : 0;
      int l = i < latestParts.length ? latestParts[i] : 0;
      if (l > c) return true; // Latest is higher, update required
      if (l < c) return false; // Current is higher
    }
    return false; // They are exactly equal
  }
}