enum TimetableState {
  empty,
  loading,
  cached,
  syncing,
  fresh,
  stale,
  error,
}

class TimetableMetadata {
  final DateTime? lastUpdated;
  final String source;
  final int version;
  final bool isStale;
  final String? errorMessage;

  const TimetableMetadata({
    this.lastUpdated,
    this.source = 'cache',
    this.version = 3,
    this.isStale = false,
    this.errorMessage,
  });

  TimetableMetadata copyWith({
    DateTime? lastUpdated,
    String? source,
    int? version,
    bool? isStale,
    String? errorMessage,
  }) {
    return TimetableMetadata(
      lastUpdated: lastUpdated ?? this.lastUpdated,
      source: source ?? this.source,
      version: version ?? this.version,
      isStale: isStale ?? this.isStale,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  Map<String, dynamic> toJson() => {
    'lastUpdated': lastUpdated?.toIso8601String(),
    'source': source,
    'version': version,
    'isStale': isStale,
    'errorMessage': errorMessage,
  };

  factory TimetableMetadata.fromJson(Map<String, dynamic> json) => TimetableMetadata(
    lastUpdated: json['lastUpdated'] != null ? DateTime.tryParse(json['lastUpdated'] as String) : null,
    source: json['source'] as String? ?? 'cache',
    version: json['version'] as int? ?? 3,
    isStale: json['isStale'] as bool? ?? false,
    errorMessage: json['errorMessage'] as String?,
  );
}
