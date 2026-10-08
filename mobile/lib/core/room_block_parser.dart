class RoomBlockParser {
  /// Extracts a normalized block name (e.g. 'Block 1', 'Block 10', 'Block 11') from a room name.
  ///
  /// Correctly handles:
  /// - '10003-B_BL10-GF' -> 'Block 10'
  /// - '10003B_BL10-GF' -> 'Block 10'
  /// - '1001-BL1-GF' -> 'Block 1'
  /// - '1001BL1-GF' -> 'Block 1'
  /// - '11202-A-BL11-SF' -> 'Block 11'
  /// - 'BF-1' -> 'Block 1'
  /// - 'BF-2' -> 'Block 2'
  /// - 'BF1' -> 'Block 1'
  /// - '10003B_BL10-GF [BL10]' -> 'Block 10'
  ///
  /// Critical Guarantee: 'BL10' will NEVER match as 'Block 1'.
  /// Never derives a block from the first digit of a room number.
  static String extractBlock(String roomName) {
    if (roomName.trim().isEmpty) return 'Other';

    // 1. Check for explicit bracket notation if appended by backend: [BL10] or [Block 10]
    final bracketMatch = RegExp(
      r'\[(?:Block\s*)?(?:BL|BF)?[-_]?(\d+)\]',
      caseSensitive: false,
    ).firstMatch(roomName);
    if (bracketMatch != null) {
      return 'Block ${bracketMatch.group(1)}';
    }

    // 2. Standard BL or BF block identifier: BL1, BL10, BF-1, BF2, etc.
    // Uses greedy \d+ to match all digits (e.g. '10' in BL10, '11' in BL11).
    final blockMatch = RegExp(
      r'(?:BL|BF)[-_]?(\d+)',
      caseSensitive: false,
    ).firstMatch(roomName);
    if (blockMatch != null) {
      return 'Block ${blockMatch.group(1)}';
    }

    return 'Other';
  }

  /// Cleans room name for display by stripping redundant bracket markers.
  /// E.g. '10003B_BL10-GF [BL10]' -> '10003B_BL10-GF'
  static String cleanRoomName(String roomName) {
    return roomName.replaceAll(RegExp(r'\s*\[.*?\]\s*'), '').trim();
  }

  /// Natural comparator for sorting block strings.
  /// Sorts numerically: 'Block 1', 'Block 2', ..., 'Block 10', 'Block 11', with 'Other' last.
  static int compareBlocks(String a, String b) {
    if (a == b) return 0;
    if (a == 'Other') return 1;
    if (b == 'Other') return -1;

    final numA = int.tryParse(RegExp(r'\d+').firstMatch(a)?.group(0) ?? '');
    final numB = int.tryParse(RegExp(r'\d+').firstMatch(b)?.group(0) ?? '');

    if (numA != null && numB != null) {
      return numA.compareTo(numB);
    }
    if (numA != null) return -1;
    if (numB != null) return 1;
    return a.compareTo(b);
  }
}
