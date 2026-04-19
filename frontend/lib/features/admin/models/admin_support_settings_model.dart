class AdminSupportSettingsModel {
  final String? contactEmail;
  final String? contactPhone;
  final String? contactAddress;
  final String? supportHours;
  final String? whatsappNumber;
  final String? whatsappLabel;
  final bool paymentCodEnabled;
  final bool paymentCardEnabled;
  final bool paymentBankTransferEnabled;
  final String? paymentCodLabel;
  final String? paymentCardLabel;
  final String? paymentBankTransferLabel;
  final String? paymentCheckoutNotice;
  final String? facebookUrl;
  final String? instagramUrl;
  final String? twitterUrl;
  final String? tiktokUrl;
  final String? snapchatUrl;
  final String? youtubeUrl;

  const AdminSupportSettingsModel({
    this.contactEmail,
    this.contactPhone,
    this.contactAddress,
    this.supportHours,
    this.whatsappNumber,
    this.whatsappLabel,
    this.paymentCodEnabled = true,
    this.paymentCardEnabled = false,
    this.paymentBankTransferEnabled = false,
    this.paymentCodLabel,
    this.paymentCardLabel,
    this.paymentBankTransferLabel,
    this.paymentCheckoutNotice,
    this.facebookUrl,
    this.instagramUrl,
    this.twitterUrl,
    this.tiktokUrl,
    this.snapchatUrl,
    this.youtubeUrl,
  });

  factory AdminSupportSettingsModel.fromJson(Map<String, dynamic> json) {
    String? text(String key) => (json[key] as String?)?.trim();
    return AdminSupportSettingsModel(
      contactEmail: text('contact_email'),
      contactPhone: text('contact_phone'),
      contactAddress: text('contact_address'),
      supportHours: text('support_hours'),
      whatsappNumber: text('whatsapp_number'),
      whatsappLabel: text('whatsapp_label'),
      paymentCodEnabled: json['payment_cod_enabled'] as bool? ?? true,
      paymentCardEnabled: json['payment_card_enabled'] as bool? ?? false,
      paymentBankTransferEnabled:
          json['payment_bank_transfer_enabled'] as bool? ?? false,
      paymentCodLabel: text('payment_cod_label'),
      paymentCardLabel: text('payment_card_label'),
      paymentBankTransferLabel: text('payment_bank_transfer_label'),
      paymentCheckoutNotice: text('payment_checkout_notice'),
      facebookUrl: text('facebook_url'),
      instagramUrl: text('instagram_url'),
      twitterUrl: text('twitter_url'),
      tiktokUrl: text('tiktok_url'),
      snapchatUrl: text('snapchat_url'),
      youtubeUrl: text('youtube_url'),
    );
  }
}
