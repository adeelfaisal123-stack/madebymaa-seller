import '../data/seller_agreement_content.dart';

class SellerAgreementContext {
  const SellerAgreementContext({
    required this.sellerName,
    required this.kitchenName,
    required this.place,
    required this.agreementDate,
  });

  final String sellerName;
  final String kitchenName;
  final String place;
  final String agreementDate;

  String get sellerKitchenLine {
    final seller = sellerName.trim();
    final kitchen = kitchenName.trim();
    if (seller.isNotEmpty && kitchen.isNotEmpty) {
      return '$seller / $kitchen';
    }
    if (kitchen.isNotEmpty) return kitchen;
    if (seller.isNotEmpty) return seller;
    return '—';
  }

  List<String> get highlightValues {
    final values = <String>{
      agreementDate.trim(),
      sellerKitchenLine,
      if (kitchenName.trim().isNotEmpty) kitchenName.trim(),
      if (sellerName.trim().isNotEmpty) sellerName.trim(),
      if (place.trim().isNotEmpty) place.trim(),
    };
    values.removeWhere((value) => value.isEmpty || value == '—');
    final sorted = values.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    return sorted;
  }
}

class AgreementTextSegment {
  const AgreementTextSegment(this.text, {this.highlight = false});

  final String text;
  final bool highlight;
}

String formatAgreementDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

String personalizeSellerAgreement(
  String template,
  SellerAgreementContext context,
) {
  return buildAgreementSegments(template, context)
      .map((segment) => segment.text)
      .join();
}

List<AgreementTextSegment> buildAgreementSegments(
  String template,
  SellerAgreementContext context,
) {
  final base = template.trim().isEmpty ? sellerAgreementDefaultContent : template;

  if (!base.contains('Date:-__________') && !base.contains('[Kitchen Name]')) {
    return highlightKnownValues(base, context);
  }

  var segments = <AgreementTextSegment>[AgreementTextSegment(base)];
  segments = _replacePlaceholder(
    segments,
    'Date:-__________',
    'Date:- ',
    context.agreementDate,
  );
  segments = _replacePlaceholder(
    segments,
    'Seller Name/kitchen name:- ________________________________________________________________',
    'Seller Name/kitchen name:- ',
    context.sellerKitchenLine,
  );
  segments = _replacePlaceholder(
    segments,
    '[Kitchen Name]',
    '',
    context.kitchenName.trim().isNotEmpty ? context.kitchenName.trim() : '—',
  );
  segments = _replacePlaceholder(
    segments,
    '[Seller Name & Signature]',
    '',
    context.sellerName.trim().isNotEmpty ? context.sellerName.trim() : '—',
  );
  segments = _replaceFooterPlaceholders(segments, context);
  return segments;
}

List<AgreementTextSegment> highlightKnownValues(
  String text,
  SellerAgreementContext context,
) {
  var segments = <AgreementTextSegment>[AgreementTextSegment(text)];
  for (final value in context.highlightValues) {
    segments = _highlightValueInSegments(segments, value);
  }
  return segments;
}

List<AgreementTextSegment> _replaceFooterPlaceholders(
  List<AgreementTextSegment> input,
  SellerAgreementContext context,
) {
  final place = context.place.trim().isNotEmpty ? context.place.trim() : '—';
  final result = <AgreementTextSegment>[];

  for (final segment in input) {
    if (segment.highlight) {
      result.add(segment);
      continue;
    }

    final pattern = RegExp(r'Date:-\s*\nPlace:-');
    final text = segment.text;
    final match = pattern.firstMatch(text);
    if (match == null) {
      result.add(segment);
      continue;
    }

    var cursor = 0;
    for (final hit in pattern.allMatches(text)) {
      if (hit.start > cursor) {
        result.add(AgreementTextSegment(text.substring(cursor, hit.start)));
      }
      result.addAll([
        AgreementTextSegment('Date:- '),
        AgreementTextSegment(context.agreementDate, highlight: true),
        AgreementTextSegment('\nPlace:- '),
        AgreementTextSegment(place, highlight: true),
      ]);
      cursor = hit.end;
    }

    if (cursor < text.length) {
      result.add(AgreementTextSegment(text.substring(cursor)));
    }
  }

  return result;
}

List<AgreementTextSegment> _replacePlaceholder(
  List<AgreementTextSegment> input,
  String placeholder,
  String prefix,
  String value,
) {
  final result = <AgreementTextSegment>[];

  for (final segment in input) {
    if (segment.highlight || !segment.text.contains(placeholder)) {
      result.add(segment);
      continue;
    }

    var remaining = segment.text;
    var index = remaining.indexOf(placeholder);
    while (index != -1) {
      if (index > 0) {
        result.add(AgreementTextSegment(remaining.substring(0, index)));
      }
      if (prefix.isNotEmpty) {
        result.add(AgreementTextSegment(prefix));
      }
      result.add(AgreementTextSegment(value, highlight: true));
      remaining = remaining.substring(index + placeholder.length);
      index = remaining.indexOf(placeholder);
    }

    if (remaining.isNotEmpty) {
      result.add(AgreementTextSegment(remaining));
    }
  }

  return result;
}

List<AgreementTextSegment> _highlightValueInSegments(
  List<AgreementTextSegment> input,
  String value,
) {
  if (value.isEmpty) return input;

  final result = <AgreementTextSegment>[];
  for (final segment in input) {
    if (segment.highlight || !segment.text.contains(value)) {
      result.add(segment);
      continue;
    }

    var remaining = segment.text;
    var index = remaining.indexOf(value);
    while (index != -1) {
      if (index > 0) {
        result.add(AgreementTextSegment(remaining.substring(0, index)));
      }
      result.add(AgreementTextSegment(value, highlight: true));
      remaining = remaining.substring(index + value.length);
      index = remaining.indexOf(value);
    }

    if (remaining.isNotEmpty) {
      result.add(AgreementTextSegment(remaining));
    }
  }

  return result;
}

/// Groups segments into lines for PDF layout while preserving highlights.
List<List<AgreementTextSegment>> groupAgreementSegmentsByLine(
  List<AgreementTextSegment> segments,
) {
  final lines = <List<AgreementTextSegment>>[];
  var current = <AgreementTextSegment>[];

  for (final segment in segments) {
    final parts = segment.text.split('\n');
    for (var i = 0; i < parts.length; i++) {
      if (parts[i].isNotEmpty) {
        current.add(
          AgreementTextSegment(parts[i], highlight: segment.highlight),
        );
      }
      if (i < parts.length - 1) {
        lines.add(current);
        current = <AgreementTextSegment>[];
      }
    }
  }

  if (current.isNotEmpty) {
    lines.add(current);
  }

  return lines;
}
