import '../../localization/app_localizations.dart';
import '../../models/category_model.dart';
import '../../models/cms_page_model.dart';
import '../../models/faq_model.dart';
import '../../models/product_model.dart';

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
