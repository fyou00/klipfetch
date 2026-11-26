class NetscapeCookieEntry {
  const NetscapeCookieEntry({
    required this.domain,
    required this.includeSubdomains,
    required this.path,
    required this.secure,
    required this.expiry,
    required this.name,
    required this.value,
    required this.httpOnly,
  });

  final String domain;
  final bool includeSubdomains;
  final String path;
  final bool secure;
  final String expiry;
  final String name;
  final String value;
  final bool httpOnly;

  String toNetscapeLine() {
    final normalizedDomain = domain.trim().toLowerCase();
    final prefix = httpOnly ? '#HttpOnly_' : '';
    return '$prefix$normalizedDomain\t'
        '${includeSubdomains ? "TRUE" : "FALSE"}\t'
        '$path\t'
        '${secure ? "TRUE" : "FALSE"}\t'
        '$expiry\t'
        '$name\t'
        '$value';
  }
}

class NetscapeCookieSummary {
  const NetscapeCookieSummary({
    required this.totalCount,
    required this.matchedDomainCount,
    required this.hasAuthCookie,
    required this.cookieNames,
  });

  final int totalCount;
  final int matchedDomainCount;
  final bool hasAuthCookie;
  final List<String> cookieNames;
}

List<NetscapeCookieEntry> parseNetscapeCookies(String raw) {
  final entries = <NetscapeCookieEntry>[];
  for (final rawLine in raw.split(RegExp(r'\r?\n'))) {
    final trimmed = rawLine.trim();
    if (trimmed.isEmpty || trimmed.startsWith('# Netscape')) {
      continue;
    }

    final isHttpOnly = trimmed.startsWith('#HttpOnly_');
    final effective =
        isHttpOnly ? trimmed.substring('#HttpOnly_'.length) : trimmed;
    if (effective.startsWith('#')) {
      continue;
    }

    final parts = effective.split('\t');
    if (parts.length < 7) {
      continue;
    }

    final domain = parts[0].trim();
    final name = parts[5].trim();
    final value = parts.sublist(6).join('\t').trim();
    if (domain.isEmpty || name.isEmpty) {
      continue;
    }

    entries.add(
      NetscapeCookieEntry(
        domain: domain,
        includeSubdomains: parts[1].trim().toUpperCase() == 'TRUE',
        path: parts[2].trim().isEmpty ? '/' : parts[2].trim(),
        secure: parts[3].trim().toUpperCase() == 'TRUE',
        expiry: parts[4].trim().isEmpty ? '2147483647' : parts[4].trim(),
        name: name,
        value: value,
        httpOnly: isHttpOnly,
      ),
    );
  }
  return entries;
}

bool domainMatchesFilter(String rawDomain, List<String> allowedDomains) {
  if (allowedDomains.isEmpty) return true;
  final host = rawDomain.trim().replaceFirst(RegExp(r'^\.+'), '').toLowerCase();
  if (host.isEmpty) return false;
  for (final candidate in allowedDomains) {
    final clean =
        candidate.trim().replaceFirst(RegExp(r'^\.+'), '').toLowerCase();
    if (host == clean || host.endsWith('.$clean')) {
      return true;
    }
  }
  return false;
}

String validateAndFilterNetscape(
  String raw,
  List<String> allowedDomains,
) {
  final parsed = parseNetscapeCookies(raw);
  if (parsed.isEmpty) {
    throw const FormatException(
      'No valid Netscape cookie entries found. Export cookies in Netscape cookies.txt format.',
    );
  }

  final filtered = parsed
      .where((entry) => domainMatchesFilter(entry.domain, allowedDomains))
      .toList(growable: false);
  if (filtered.isEmpty) {
    throw FormatException(
      'None of the provided cookies match ${allowedDomains.join(", ")}.',
    );
  }

  final buffer = StringBuffer('# Netscape HTTP Cookie File\n');
  for (final entry in filtered) {
    buffer.writeln(entry.toNetscapeLine());
  }
  return buffer.toString();
}

NetscapeCookieSummary summarizeNetscape(
  String raw, {
  List<String> allowedDomains = const [],
  List<String> authCookieNames = const [],
}) {
  final parsed = parseNetscapeCookies(raw);
  final matched = allowedDomains.isEmpty
      ? parsed
      : parsed
          .where((e) => domainMatchesFilter(e.domain, allowedDomains))
          .toList(growable: false);

  final authSet = authCookieNames.map((n) => n.toLowerCase()).toSet();
  var hasAuth = false;
  final names = <String>[];
  for (final entry in matched) {
    names.add(entry.name);
    if (authSet.contains(entry.name.toLowerCase())) {
      hasAuth = true;
    }
  }

  return NetscapeCookieSummary(
    totalCount: parsed.length,
    matchedDomainCount: matched.length,
    hasAuthCookie: hasAuth,
    cookieNames: List.unmodifiable(names),
  );
}

/// Builds a safe diagnostic summary listing cookie counts and key names only.
/// Raw cookie token values are never included.
String redactCookiePreview(
  String raw, {
  List<String> allowedDomains = const [],
}) {
  final parsed = parseNetscapeCookies(raw);
  final matched = allowedDomains.isEmpty
      ? parsed
      : parsed
          .where((e) => domainMatchesFilter(e.domain, allowedDomains))
          .toList(growable: false);
  if (matched.isEmpty) return '0 cookies';
  final names = matched.map((e) => e.name).toSet().take(6).join(', ');
  return '${matched.length} cookies ($names)';
}
