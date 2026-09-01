import 'dart:io';
import 'package:hive/hive.dart';

void main() async {
  var path = Directory.current.path + '/test_hive';
  Hive.init(path);
  var box = await Hive.openBox('testBox');
  
  print('Trying to put null...');
  try {
    await box.put('user_name', null);
    print('Put null succeeded!');
  } catch (e) {
    print('Caught error synchronously: $e');
  }

  print('Trying to put a valid string...');
  try {
    await box.put('degree_code', 'BTECH');
    print('Put string succeeded!');
  } catch (e) {
    print('Caught error on string put: $e');
  }
}
