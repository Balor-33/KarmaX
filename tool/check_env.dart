import 'dart:io';

void main() {
  final file = File('.env');
  if (!file.existsSync()) {
    stdout.writeln('No .env file found in project root.');
    return;
  }

  final lines = file.readAsLinesSync();
  final results = <String, String>{};

  for (final raw in lines) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    if (line.startsWith('#')) continue;

    final idx = line.indexOf('=');
    if (idx <= 0) continue;

    final key = line.substring(0, idx).trim();
    var value = line.substring(idx + 1).trim();

    // Strip trailing comments.
    final hashIdx = value.indexOf('#');
    if (hashIdx != -1) {
      value = value.substring(0, hashIdx).trim();
    }

    // Strip surrounding quotes.
    if (value.length >= 2) {
      final startsQuote = value.startsWith('"') || value.startsWith("'");
      final endsQuote = value.endsWith('"') || value.endsWith("'");
      if (startsQuote && endsQuote) {
        value = value.substring(1, value.length - 1).trim();
      }
    }

    results[key] = value.isEmpty ? 'empty' : 'set';
  }

  if (results.isEmpty) {
    stdout.writeln('No KEY=VALUE entries parsed from .env');
    return;
  }

  for (final key in results.keys.toList()..sort()) {
    stdout.writeln('$key: ${results[key]}');
  }
}
