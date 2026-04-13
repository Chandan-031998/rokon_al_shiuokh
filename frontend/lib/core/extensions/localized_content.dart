import '../../localization/app_localizations.dart';
import '../../models/category_model.dart';
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
