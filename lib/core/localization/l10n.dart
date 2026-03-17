import 'package:flutter/widgets.dart';
import 'package:second_chat/l10n/app_localizations.dart';

extension L10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}
