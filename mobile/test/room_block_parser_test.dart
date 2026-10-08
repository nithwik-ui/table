import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/room_block_parser.dart';

void main() {
  group('RoomBlockParser Tests', () {
    test('Correctly extracts standard BL blocks', () {
      expect(RoomBlockParser.extractBlock('1001-BL1-GF'), 'Block 1');
      expect(RoomBlockParser.extractBlock('1001BL1-GF'), 'Block 1');
      expect(RoomBlockParser.extractBlock('2005-BL2-GF'), 'Block 2');
      expect(RoomBlockParser.extractBlock('3011-BL3-GF'), 'Block 3');
      expect(RoomBlockParser.extractBlock('4101-BL4-GF'), 'Block 4');
      expect(RoomBlockParser.extractBlock('5007-B_BL5-GF'), 'Block 5');
      expect(RoomBlockParser.extractBlock('6103-BL6-FF'), 'Block 6');
      expect(RoomBlockParser.extractBlock('7003-B_BL7-GF'), 'Block 7');
      expect(RoomBlockParser.extractBlock('8001-B_BL8-GF'), 'Block 8');
    });

    test('CRITICAL: BL10 and BL11 are never parsed as Block 1', () {
      expect(RoomBlockParser.extractBlock('10003-B_BL10-GF'), 'Block 10');
      expect(RoomBlockParser.extractBlock('10003B_BL10-GF'), 'Block 10');
      expect(RoomBlockParser.extractBlock('10102-B_BL10-FF'), 'Block 10');
      expect(RoomBlockParser.extractBlock('11202-A-BL11-SF'), 'Block 11');
      expect(RoomBlockParser.extractBlock('11202-B-BL11-SF'), 'Block 11');
    });

    test('Correctly extracts BF blocks', () {
      expect(RoomBlockParser.extractBlock('BF-1'), 'Block 1');
      expect(RoomBlockParser.extractBlock('BF-2'), 'Block 2');
      expect(RoomBlockParser.extractBlock('BF1'), 'Block 1');
      expect(RoomBlockParser.extractBlock('BF2'), 'Block 2');
    });

    test('Correctly extracts bracketed block tags', () {
      expect(RoomBlockParser.extractBlock('10003B_BL10-GF [BL10]'), 'Block 10');
      expect(RoomBlockParser.extractBlock('Some Room [Block 3]'), 'Block 3');
    });

    test('Falls back to Other for rooms without block identifiers', () {
      expect(RoomBlockParser.extractBlock('3013_A'), 'Block 3' == 'Other' ? 'Other' : 'Other');
      expect(RoomBlockParser.extractBlock('001'), 'Other');
      expect(RoomBlockParser.extractBlock(''), 'Other');
    });

    test('Cleans display room name without bracket tags', () {
      expect(
        RoomBlockParser.cleanRoomName('10003B_BL10-GF [BL10]'),
        '10003B_BL10-GF',
      );
      expect(
        RoomBlockParser.cleanRoomName('1001-BL1-GF'),
        '1001-BL1-GF',
      );
    });

    test('Natural block comparator orders blocks correctly', () {
      final blocks = ['Block 10', 'Block 1', 'Other', 'Block 11', 'Block 2', 'Block 3'];
      blocks.sort(RoomBlockParser.compareBlocks);

      expect(blocks, ['Block 1', 'Block 2', 'Block 3', 'Block 10', 'Block 11', 'Other']);
    });
  });
}
