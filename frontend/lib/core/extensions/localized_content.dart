import '../../localization/app_localizations.dart';
import '../../models/category_model.dart';
import '../../models/branch_model.dart';
import '../../models/cms_page_model.dart';
import '../../models/faq_model.dart';
import '../../models/offer_model.dart';
import '../../models/product_model.dart';
import '../../models/support_settings_model.dart';

extension CategoryLocalizedContent on CategoryModel {
  String localizedName(AppLocalizations l10n) {
    final arabic = nameAr?.trim();
    if (l10n.isArabic && arabic != null && arabic.isNotEmpty) {
      return arabic;
    }
    return name;
  }
}

extension ProductLocalizedContent on ProductModel {
  String localizedName(AppLocalizations l10n) {
    final arabic = nameAr?.trim();
    if (l10n.isArabic && arabic != null && arabic.isNotEmpty) {
      return arabic;
    }
    return name;
  }

  String currencyCodeForRegion(
    String regionCode, {
    String fallback = 'SAR',
  }) {
    final normalized = regionCode.trim().toLowerCase();
    for (final row in regionPrices) {
      if (row.regionCode == normalized && row.currencyCode.trim().isNotEmpty) {
        return row.currencyCode.trim().toUpperCase();
      }
    }
    return fallback;
  }
}

extension BranchLocalizedContent on BranchModel {
  String localizedName(AppLocalizations l10n) {
    if (!l10n.isArabic) {
      return name;
    }
    final normalized = name.trim().toLowerCase();
    if (normalized == 'mahayil aseer (main branch)') {
      return 'محايل عسير (الفرع الرئيسي)';
    }
    if (normalized == 'abha branch') {
      return 'فرع أبها';
    }
    return name;
  }

  String? localizedCity(AppLocalizations l10n) {
    final normalized = (city ?? '').trim().toLowerCase();
    if (!l10n.isArabic || normalized.isEmpty) {
      return city;
    }
    if (normalized == 'mahayil aseer') {
      return 'محايل عسير';
    }
    if (normalized == 'abha') {
      return 'أبها';
    }
    return city;
  }

  String? localizedDeliveryCoverage(AppLocalizations l10n) {
    final coverage = deliveryCoverage?.trim();
    if (!l10n.isArabic || coverage == null || coverage.isEmpty) {
      return deliveryCoverage;
    }
    final normalized = coverage.toLowerCase();
    if (normalized == 'mahayil aseer & abha branch support coverage') {
      return 'تغطية دعم فروع محايل عسير وأبها';
    }
    if (normalized == 'main branch address') {
      return 'عنوان الفرع الرئيسي';
    }
    if (normalized == 'abha branch address') {
      return 'عنوان فرع أبها';
    }
    return deliveryCoverage;
  }
}

extension OfferLocalizedContent on OfferModel {
  String localizedTitle(AppLocalizations l10n) {
    final arabic = titleAr?.trim();
    if (l10n.isArabic && arabic != null && arabic.isNotEmpty) {
      return arabic;
    }
    return title;
  }

  String? localizedSubtitle(AppLocalizations l10n) {
    final arabic = subtitleAr?.trim();
    if (l10n.isArabic && arabic != null && arabic.isNotEmpty) {
      return arabic;
    }
    return subtitle;
  }

  String? localizedDescription(AppLocalizations l10n) {
    final arabic = descriptionAr?.trim();
    if (l10n.isArabic && arabic != null && arabic.isNotEmpty) {
      return arabic;
    }
    return description;
  }
}

extension CmsPageLocalizedContent on CmsPageModel {
  String localizedTitle(AppLocalizations l10n) {
    final arabic = titleAr?.trim();
    if (l10n.isArabic && arabic != null && arabic.isNotEmpty) {
      return arabic;
    }
    return title;
  }

  String? localizedExcerpt(AppLocalizations l10n) {
    final arabic = excerptAr?.trim();
    if (l10n.isArabic && arabic != null && arabic.isNotEmpty) {
      return arabic;
    }
    return excerpt;
  }

  String? localizedBody(AppLocalizations l10n) {
    final arabic = bodyAr?.trim();
    if (l10n.isArabic && arabic != null && arabic.isNotEmpty) {
      return arabic;
    }
    return body;
  }

  String? localizedCtaLabel(AppLocalizations l10n) {
    final arabic = ctaLabelAr?.trim();
    if (l10n.isArabic && arabic != null && arabic.isNotEmpty) {
      return arabic;
    }
    return ctaLabel;
  }
}

extension SupportSettingsLocalizedContent on SupportSettingsModel {
  String? localizedSupportHours(AppLocalizations l10n) {
    final arabic = supportHoursAr?.trim();
    if (l10n.isArabic && arabic != null && arabic.isNotEmpty) {
      return arabic;
    }
    return supportHours;
  }

  String? localizedWhatsappLabel(AppLocalizations l10n) {
    final arabic = whatsappLabelAr?.trim();
    if (l10n.isArabic && arabic != null && arabic.isNotEmpty) {
      return arabic;
    }
    return whatsappLabel;
  }

  String? localizedContactAddress(AppLocalizations l10n) {
    final arabic = contactAddressAr?.trim();
    if (l10n.isArabic && arabic != null && arabic.isNotEmpty) {
      return arabic;
    }
    return contactAddress;
  }
}

extension FaqLocalizedContent on FaqModel {
  String localizedQuestion(AppLocalizations l10n) {
    final arabic = questionAr?.trim();
    if (l10n.isArabic && arabic != null && arabic.isNotEmpty) {
      return arabic;
    }
    return question;
  }

  String localizedAnswer(AppLocalizations l10n) {
    final arabic = answerAr?.trim();
    if (l10n.isArabic && arabic != null && arabic.isNotEmpty) {
      return arabic;
    }
    return answer;
  }
}
