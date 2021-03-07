import 'package:shared_preferences/shared_preferences.dart';

// Code from :https://codesource.io/getting-started-with-shared-preferences-in-flutter/

class StorageUtil {
  static StorageUtil _storageUtil;
  static SharedPreferences _preferences;

  static Future<StorageUtil> getInstance() async {
    if (_storageUtil == null) {
      // keep local instance till it is fully initialized.
      var secureStorage = StorageUtil._();
      await secureStorage._init();
      _storageUtil = secureStorage;
    }
    return _storageUtil;
  }

  StorageUtil._();
  Future _init() async {
    _preferences = await SharedPreferences.getInstance();
  }

  // get string
  static String getString(String key, {String defValue = ''}) {
    if (_preferences == null) return defValue;
    return _preferences.getString(key) ?? defValue;
  }

  // put string
  static Future<bool> putString(String key, String value) {
    if (_preferences == null) return null;
    return _preferences.setString(key, value);
  }
}

class LocationFunctions {
  static const BASE32_CODES = '0123456789bcdefghjkmnpqrstuvwxyz';

  static String encode(var latitude, var longitude, var numberOfChars) {
    //encode to GeoHash
    var chars = [], bits = 0, bitsTotal = 0, hashValue = 0;
    double maxLat = 90, minLat = -90, maxLon = 180, minLon = -180, mid;

    while (chars.length < numberOfChars) {
      if (bitsTotal % 2 == 0) {
        mid = (maxLon + minLon) / 2;
        if (longitude > mid) {
          hashValue = (hashValue << 1) + 1;
          minLon = mid;
        } else {
          hashValue = (hashValue << 1) + 0;
          maxLon = mid;
        }
      } else {
        mid = (maxLat + minLat) / 2;
        if (latitude > mid) {
          hashValue = (hashValue << 1) + 1;
          minLat = mid;
        } else {
          hashValue = (hashValue << 1) + 0;
          maxLat = mid;
        }
      }

      bits++;
      bitsTotal++;
      if (bits == 5) {
        var code = BASE32_CODES[hashValue];
        chars.add(code);
        bits = 0;
        hashValue = 0;
      }
    }
    return chars.join('');
  }
}
