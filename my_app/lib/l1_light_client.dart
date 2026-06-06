import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class L1Header {
  const L1Header({
    required this.height,
    required this.hash,
    required this.previousHash,
    required this.epochEnd,
  });

  final int height;
  final String hash;
  final String previousHash;
  final DateTime? epochEnd;

  static L1Header fromJson(Map<String, dynamic> json) {
    final epochEndRaw = json['epoch_end']?.toString();
    return L1Header(
      height: int.tryParse(json['block_height']?.toString() ?? '') ?? 0,
      hash: (json['hash'] ?? '').toString(),
      previousHash: (json['previous_hash'] ?? '').toString(),
      epochEnd: epochEndRaw == null ? null : DateTime.tryParse(epochEndRaw),
    );
  }
}

class L1EndpointSnapshot {
  const L1EndpointSnapshot({
    required this.endpoint,
    required this.headers,
    required this.ok,
    this.error,
  });

  final String endpoint;
  final List<L1Header> headers;
  final bool ok;
  final String? error;
}

class L1QuorumResult {
  const L1QuorumResult({
    required this.ok,
    required this.quorumHash,
    required this.quorumCount,
    required this.totalResponding,
    required this.endpoints,
  });

  final bool ok;
  final String? quorumHash;
  final int quorumCount;
  final int totalResponding;
  final List<L1EndpointSnapshot> endpoints;
}

class L1LightClient {
  static const Duration _timeout = Duration(seconds: 20);

  static Future<L1QuorumResult> verifyHeaderQuorum({
    required List<String> rpcEndpoints,
    int depth = 8,
    int minQuorum = 2,
  }) async {
    final snapshots = <L1EndpointSnapshot>[];

    for (final endpoint in rpcEndpoints) {
      final normalized = endpoint.trim();
      if (normalized.isEmpty) {
        continue;
      }

        final url = Uri.parse('${normalized.replaceAll(RegExp(r'/+$'), '')}/blocks?limit=$depth');
      try {
        final response = await http.get(url).timeout(_timeout);
        if (response.statusCode != 200) {
          snapshots.add(
            L1EndpointSnapshot(
              endpoint: normalized,
              headers: const [],
              ok: false,
              error: 'http_${response.statusCode}',
            ),
          );
          continue;
        }

        final decoded = jsonDecode(response.body);
        final list = (decoded is List) ? decoded : <dynamic>[];
        final headers = list
            .whereType<Map<String, dynamic>>()
            .map(L1Header.fromJson)
            .where((header) =>
                header.height > 0 &&
                header.hash.isNotEmpty &&
                header.previousHash.isNotEmpty)
            .toList();

        final continuityOk = _verifyContinuity(headers);
        snapshots.add(
          L1EndpointSnapshot(
            endpoint: normalized,
            headers: headers,
            ok: continuityOk,
            error: continuityOk ? null : 'header_continuity_failed',
          ),
        );
      } on TimeoutException {
        snapshots.add(
          L1EndpointSnapshot(
            endpoint: normalized,
            headers: const [],
            ok: false,
            error: 'timeout',
          ),
        );
      } catch (error) {
        snapshots.add(
          L1EndpointSnapshot(
            endpoint: normalized,
            headers: const [],
            ok: false,
            error: error.toString(),
          ),
        );
      }
    }

    final hashVotes = <String, int>{};
    var totalResponding = 0;
    for (final snapshot in snapshots) {
      if (!snapshot.ok || snapshot.headers.isEmpty) {
        continue;
      }
      totalResponding += 1;
      final latestHash = snapshot.headers.first.hash;
      hashVotes.update(latestHash, (value) => value + 1, ifAbsent: () => 1);
    }

    String? quorumHash;
    var quorumCount = 0;
    hashVotes.forEach((hash, votes) {
      if (votes > quorumCount) {
        quorumHash = hash;
        quorumCount = votes;
      }
    });

    return L1QuorumResult(
      ok: quorumCount >= minQuorum,
      quorumHash: quorumHash,
      quorumCount: quorumCount,
      totalResponding: totalResponding,
      endpoints: snapshots,
    );
  }

  static bool _verifyContinuity(List<L1Header> headers) {
    if (headers.length <= 1) {
      return true;
    }

    for (var i = 0; i < headers.length - 1; i++) {
      final current = headers[i];
      final previous = headers[i + 1];
      final expectedHeight = previous.height + 1;
      if (current.height != expectedHeight) {
        return false;
      }
      if (current.previousHash != previous.hash) {
        return false;
      }
    }

    return true;
  }
}
