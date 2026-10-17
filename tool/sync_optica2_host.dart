// Sync Mac en0 LAN IP into lib/config/optica2_host.g.dart (local dev only).
//
// Run when your Wi‑Fi IP changes:
//   dart run tool/sync_optica2_host.dart
//
// Production: edit apiUrl in lib/config/optica2_host.g.dart directly
// (e.g. https://api.yourdomain.com) — sync skips non-local URLs unless --force.
//
// Override Optica2 path: OPTICA2_DIR=/path/to/optica2 dart run tool/sync_optica2_host.dart

import 'dart:io';

const _port = 8000;
const _outFile = 'lib/config/optica2_host.g.dart';

Future<void> main(List<String> args) async {
  final force = args.contains('--force');

  if (!Platform.isMacOS) {
    stderr.writeln('sync_optica2_host: macOS only (uses ipconfig getifaddr en0).');
    exit(1);
  }

  final ip = await _lanIp();
  final baseUrl = 'http://$ip:$_port';

  final file = File(_outFile);
  final previous = file.existsSync() ? file.readAsStringSync() : '';
  final currentUrl = _readApiUrl(previous);

  if (!force && currentUrl != null && !_isLocalDevUrl(currentUrl)) {
    stdout.writeln(
      'Optica2 apiUrl left unchanged (production URL): $currentUrl',
    );
    stdout.writeln('Use --force to overwrite with $baseUrl');
    await _syncSellerPublicUrl(currentUrl);
    await _runOptica2Migrations();
    return;
  }

  final content = '''
// API base URL (no trailing slash).
//
// Production (cPanel): set once, e.g. https://api.yourdomain.com
// Local dev: run `dart run tool/sync_optica2_host.dart` to fill Wi‑Fi IP :8000
//
// Override at build time: flutter run --dart-define=OPTICA2_API_URL=https://...

abstract final class Optica2Host {
  static const apiUrl = '$baseUrl';
}
''';

  await file.writeAsString(content);

  if (currentUrl == baseUrl) {
    stdout.writeln('Optica2 apiUrl unchanged: $baseUrl');
  } else {
    stdout.writeln('Optica2 apiUrl updated: $baseUrl');
    if (previous.isNotEmpty) {
      stdout.writeln('Hot restart or re-run the app to apply.');
    }
  }

  await _syncSellerPublicUrl(baseUrl);
  await _runOptica2Migrations();
  await _warnIfNotReachableOnLan(ip);
}

String? _readApiUrl(String fileContent) {
  for (final line in fileContent.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.startsWith('//')) continue;
    final match = RegExp(
      r"static const apiUrl = '([^']*)'",
    ).firstMatch(trimmed);
    if (match != null) return match.group(1);
  }
  return null;
}

bool _isLocalDevUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.host.isEmpty) return false;
  final host = uri.host.toLowerCase();
  if (host == 'localhost' || host == '127.0.0.1') return true;
  if (host.startsWith('192.168.')) return true;
  if (host == '10.0.2.2') return true;
  return false;
}

/// Keep Laravel KYC image URLs in sync with the seller app host.
Future<void> _syncSellerPublicUrl(String baseUrl) async {
  final optica2Dir = _resolveOptica2Dir();
  if (optica2Dir == null) return;

  final envFile = File('${optica2Dir.path}/.env');
  if (!envFile.existsSync()) return;

  var env = envFile.readAsStringSync();
  const key = 'SELLER_PUBLIC_URL=';
  final line = '$key$baseUrl';

  if (env.contains(RegExp(r'^SELLER_PUBLIC_URL=', multiLine: true))) {
    env = env.replaceAll(
      RegExp(r'^SELLER_PUBLIC_URL=.*$', multiLine: true),
      line,
    );
  } else {
    env = '${env.trimRight()}\n$line\n';
  }

  await envFile.writeAsString(env);
  stdout.writeln('Optica2 SELLER_PUBLIC_URL → $baseUrl');
}

/// Phones need Laravel on 0.0.0.0; default `artisan serve` is localhost-only.
Future<void> _warnIfNotReachableOnLan(String ip) async {
  final origin = 'http://$ip:$_port';
  final uri = Uri.parse('$origin/api/seller/maps-config');

  try {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 2);
    final request = await client.getUrl(uri);
    final response = await request.close();
    await response.drain();
    client.close();
    if (response.statusCode == 200) {
      stdout.writeln('Optica2 API reachable on LAN: $origin');
      return;
    }
    stderr.writeln(
      'Optica2 on port $_port returned HTTP ${response.statusCode} at $ip.',
    );
  } catch (_) {
    // fall through to warning
  }

  stderr.writeln('');
  stderr.writeln('⚠ Optica2 is not reachable at $origin from this network.');
  stderr.writeln('  Your phone cannot use localhost — start Laravel with:');
  stderr.writeln('');
  stderr.writeln('  cd "<optica2>" && php artisan serve --host=0.0.0.0 --port=$_port');
  stderr.writeln('');
  stderr.writeln('  (Stop any existing `php artisan serve` that only binds to 127.0.0.1.)');
  stderr.writeln('');
  stderr.writeln('  Phone on USB? Also run: adb reverse tcp:8000 tcp:8000');
}

Future<void> _runOptica2Migrations() async {
  final optica2Dir = _resolveOptica2Dir();
  if (optica2Dir == null) {
    stderr.writeln(
      'Optica2: could not find Laravel project. Set OPTICA2_DIR or create tool/optica2_dir',
    );
    exit(1);
  }

  final artisan = File('${optica2Dir.path}/artisan');
  if (!artisan.existsSync()) {
    stderr.writeln('Optica2: artisan not found at ${optica2Dir.path}');
    exit(1);
  }

  stdout.writeln('Optica2: running migrations in ${optica2Dir.path} …');
  final result = await Process.run(
    'php',
    ['artisan', 'migrate', '--force', '--no-interaction'],
    workingDirectory: optica2Dir.path,
  );

  final output = '${result.stdout}${result.stderr}'.trim();
  if (output.isNotEmpty) {
    stdout.writeln(output);
  }

  if (result.exitCode != 0) {
    stderr.writeln('Optica2: migrate failed (exit ${result.exitCode})');
    exit(result.exitCode);
  }

  final link = await Process.run(
    'php',
    ['artisan', 'storage:link', '--force'],
    workingDirectory: optica2Dir.path,
  );
  final linkOut = '${link.stdout}${link.stderr}'.trim();
  if (linkOut.isNotEmpty) {
    stdout.writeln(linkOut);
  }
}

Directory? _resolveOptica2Dir() {
  final env = Platform.environment['OPTICA2_DIR']?.trim();
  if (env != null && env.isNotEmpty) {
    final dir = Directory(env);
    if (dir.existsSync()) return dir.absolute;
  }

  final projectRoot = Directory.current;
  final fromFile = File('tool/optica2_dir');
  if (fromFile.existsSync()) {
    final line = fromFile.readAsStringSync().trim().split('\n').first.trim();
    if (line.isNotEmpty) {
      final dir = Directory(line);
      if (dir.existsSync()) return dir.absolute;
    }
  }

  final candidates = [
    projectRoot.uri.resolve('../../Ecommerce Websites/optica2/'),
    projectRoot.uri.resolve('../optica2/'),
  ];

  for (final uri in candidates) {
    final dir = Directory.fromUri(uri);
    if (File('${dir.path}/artisan').existsSync()) {
      return dir.absolute;
    }
  }

  return null;
}

Future<String> _lanIp() async {
  for (final iface in ['en0', 'en1']) {
    final result = await Process.run('ipconfig', ['getifaddr', iface]);
    if (result.exitCode == 0) {
      final ip = (result.stdout as String).trim();
      if (_isIpv4(ip)) return ip;
    }
  }
  stderr.writeln('Could not read en0/en1 IP; keeping 192.168.1.6');
  return '192.168.1.6';
}

bool _isIpv4(String value) {
  final parts = value.split('.');
  if (parts.length != 4) return false;
  for (final p in parts) {
    final n = int.tryParse(p);
    if (n == null || n < 0 || n > 255) return false;
  }
  return true;
}
