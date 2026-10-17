class SellerFaq {
  const SellerFaq({
    required this.id,
    required this.question,
    required this.answer,
    required this.sortOrder,
  });

  final int id;
  final String question;
  final String answer;
  final int sortOrder;

  factory SellerFaq.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    return SellerFaq(
      id: rawId is int ? rawId : (rawId is num ? rawId.toInt() : 0),
      question: (json['question'] as String?)?.trim() ?? '',
      answer: (json['answer'] as String?)?.trim() ?? '',
      sortOrder: json['sort_order'] is int
          ? json['sort_order'] as int
          : (json['sort_order'] is num
              ? (json['sort_order'] as num).toInt()
              : 0),
    );
  }
}

class SellerHelpSupport {
  const SellerHelpSupport({
    required this.title,
    required this.subtitle,
    required this.body,
    required this.hours,
    required this.phone,
    required this.email,
    required this.whatsapp,
    required this.faqs,
  });

  final String title;
  final String subtitle;
  final String body;
  final String hours;
  final String phone;
  final String email;
  final String whatsapp;
  final List<SellerFaq> faqs;

  static const empty = SellerHelpSupport(
    title: 'Help & Support',
    subtitle: '',
    body: '',
    hours: '',
    phone: '',
    email: '',
    whatsapp: '',
    faqs: [],
  );

  factory SellerHelpSupport.fromJson(Map<String, dynamic> json) {
    final faqsJson = json['faqs'];
    final faqs = faqsJson is List
        ? faqsJson
            .whereType<Map<String, dynamic>>()
            .map(SellerFaq.fromJson)
            .where((faq) => faq.question.isNotEmpty)
            .toList()
        : <SellerFaq>[];

    return SellerHelpSupport(
      title: (json['title'] as String?)?.trim().isNotEmpty == true
          ? (json['title'] as String).trim()
          : 'Help & Support',
      subtitle: (json['subtitle'] as String?)?.trim() ?? '',
      body: (json['body'] as String?)?.trim() ?? '',
      hours: (json['hours'] as String?)?.trim() ?? '',
      phone: (json['phone'] as String?)?.trim() ?? '',
      email: (json['email'] as String?)?.trim() ?? '',
      whatsapp: (json['whatsapp'] as String?)?.trim() ?? '',
      faqs: faqs,
    );
  }

  bool get hasContact =>
      phone.isNotEmpty || email.isNotEmpty || whatsapp.isNotEmpty;

  bool get hasFaqs => faqs.isNotEmpty;
}
