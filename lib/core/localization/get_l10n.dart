import 'package:get/get.dart';
import 'package:second_chat/l10n/app_localizations.dart';

AppLocalizations? getAppL10n() {
  final ctx = Get.context;
  if (ctx == null) return null;
  return AppLocalizations.of(ctx);
}
