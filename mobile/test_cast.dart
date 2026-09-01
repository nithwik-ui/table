void main() {
  dynamic hiveMap = <dynamic, dynamic>{'a': 1, 'b': 2};
  try {
    Map<String, dynamic> casted = hiveMap as Map<String, dynamic>;
    print("Cast succeeded!");
  } catch (e) {
    print("CRASH: $e");
  }
}
