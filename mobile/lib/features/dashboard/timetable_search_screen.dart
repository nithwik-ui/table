import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/utils.dart';
import '../../core/timetable/timetable_repository.dart';
import '../../widgets/class_details_bottom_sheet.dart';

class TimetableSearchScreen extends StatefulWidget {
  const TimetableSearchScreen({super.key});

  @override
  State<TimetableSearchScreen> createState() => _TimetableSearchScreenState();
}

class _TimetableSearchScreenState extends State<TimetableSearchScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  List<Map<String, dynamic>> _results = [];

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onQueryChanged);
  }

  void _onQueryChanged() {
    final q = _searchCtrl.text;
    setState(() {
      _query = q;
      _results = TimetableRepository.searchClasses(
        TimetableRepository.instance.classes,
        q,
      );
    });
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onQueryChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  List<String> _getQuickSuggestions() {
    final classes = TimetableRepository.instance.classes;
    final Set<String> suggestions = {};
    for (final raw in classes) {
      if (raw is Map) {
        final subj = (raw['subject']?.toString() ?? '').trim();
        if (subj.isNotEmpty) suggestions.add(subj);
      }
      if (suggestions.length >= 6) break;
    }
    return suggestions.toList();
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = _getQuickSuggestions();

    return Scaffold(
      backgroundColor: AppConstants.background,
      appBar: AppBar(
        backgroundColor: AppConstants.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: AppConstants.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Search Timetable',
          style: AppConstants.getHeadline().copyWith(fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: AppConstants.surface,
              padding: const EdgeInsets.fromLTRB(
                AppConstants.paddingContainer,
                8,
                AppConstants.paddingContainer,
                16,
              ),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                style: AppConstants.getBodyLarge(),
                decoration: InputDecoration(
                  hintText: 'Search subject, faculty, or room...',
                  hintStyle: AppConstants.getBodyMedium(
                    color: AppConstants.textMuted,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: AppConstants.primary,
                  ),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.clear_rounded,
                            color: AppConstants.textSecondary,
                          ),
                          onPressed: () => _searchCtrl.clear(),
                        )
                      : null,
                  filled: true,
                  fillColor: AppConstants.background,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusButton),
                    borderSide: BorderSide(color: AppConstants.outline),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusButton),
                    borderSide: BorderSide(color: AppConstants.outline),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusButton),
                    borderSide: BorderSide(color: AppConstants.primary, width: 1.5),
                  ),
                ),
              ),
            ),
            Divider(height: 1, color: AppConstants.outline),
            Expanded(
              child: _query.trim().isEmpty
                  ? ListView(
                      padding: const EdgeInsets.all(AppConstants.paddingContainer),
                      children: [
                        if (suggestions.isNotEmpty) ...[
                          Text(
                            'QUICK SEARCH',
                            style: AppConstants.getLabelSmall(
                              color: AppConstants.textSecondary,
                            ).copyWith(fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: suggestions.map((s) {
                              return ActionChip(
                                backgroundColor: AppConstants.surface,
                                side: BorderSide(color: AppConstants.outline),
                                label: Text(
                                  s,
                                  style: AppConstants.getBodyMedium().copyWith(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                onPressed: () {
                                  _searchCtrl.text = s;
                                  _searchCtrl.selection = TextSelection.fromPosition(
                                    TextPosition(offset: s.length),
                                  );
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 24),
                        ],
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.manage_search_rounded,
                                  size: 48,
                                  color: AppConstants.textMuted,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Find any class instantly',
                                  style: AppConstants.getHeadline().copyWith(fontSize: 16),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Search by subject name, faculty, or classroom.',
                                  style: AppConstants.getBodyMedium(
                                    color: AppConstants.textSecondary,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : _results.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.search_off_rounded,
                                  size: 48,
                                  color: AppConstants.textMuted,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No matching classes found',
                                  style: AppConstants.getHeadline().copyWith(fontSize: 16),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Try searching a different subject, teacher, or room.',
                                  style: AppConstants.getBodyMedium(
                                    color: AppConstants.textSecondary,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(AppConstants.paddingContainer),
                          itemCount: _results.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final c = _results[index];
                            final subject = c['subject']?.toString() ?? 'Class';
                            final dayRaw = c['day']?.toString() ?? '';
                            final day = dayRaw.isNotEmpty
                                ? '${dayRaw[0].toUpperCase()}${dayRaw.substring(1).toLowerCase()}'
                                : 'Scheduled';
                            final start = TimeUtils.format12Hour(
                              c['start_time']?.toString() ?? '',
                            );
                            final end = TimeUtils.format12Hour(
                              c['end_time']?.toString() ?? '',
                            );
                            final room =
                                (c['room']?.toString() ?? 'TBA').split('_')[0].trim();
                            final faculty = (c['faculty']?.toString() ?? '').trim();
                            final ltp = (c['ltp']?.toString() ?? '').trim();
                            final isLab = ltp.toLowerCase().contains('lab') ||
                                ltp.toLowerCase().contains('practical') ||
                                ltp.toUpperCase() == 'P';

                            return Container(
                              decoration: BoxDecoration(
                                color: AppConstants.surface,
                                borderRadius:
                                    BorderRadius.circular(AppConstants.radiusCard),
                                border: Border.all(color: AppConstants.outline),
                                boxShadow: AppConstants.shadowLevel1,
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius:
                                      BorderRadius.circular(AppConstants.radiusCard),
                                  onTap: () {
                                    showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true,
                                      backgroundColor: Colors.transparent,
                                      builder: (ctx) => ClassDetailsBottomSheet(
                                        classEvent: c,
                                        status: 'Scheduled',
                                        dateStr: day,
                                      ),
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              '$day · $start${end.isNotEmpty ? ' – $end' : ''}',
                                              style: AppConstants.getLabelSmall(
                                                color: AppConstants.primary,
                                              ).copyWith(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 12.5,
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 3,
                                              ),
                                              decoration: BoxDecoration(
                                                color: isLab
                                                    ? AppConstants.labBg
                                                    : AppConstants.lectureBg,
                                                borderRadius: BorderRadius.circular(
                                                  AppConstants.radiusTag,
                                                ),
                                              ),
                                              child: Text(
                                                isLab ? 'Lab' : 'Lecture',
                                                style: AppConstants.getLabelSmall(
                                                  color: isLab
                                                      ? AppConstants.labText
                                                      : AppConstants.lectureText,
                                                ).copyWith(fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          subject,
                                          style: AppConstants.getHeadline().copyWith(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Wrap(
                                          spacing: 14,
                                          runSpacing: 4,
                                          children: [
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.place_outlined,
                                                  size: 14,
                                                  color: AppConstants.textMuted,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  room,
                                                  style: AppConstants.getBodyMedium(
                                                    color: AppConstants.textSecondary,
                                                  ).copyWith(fontSize: 13),
                                                ),
                                              ],
                                            ),
                                            if (faculty.isNotEmpty)
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.person_outline_rounded,
                                                    size: 14,
                                                    color: AppConstants.textMuted,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    faculty,
                                                    style: AppConstants.getBodyMedium(
                                                      color: AppConstants.textSecondary,
                                                    ).copyWith(fontSize: 13),
                                                  ),
                                                ],
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

