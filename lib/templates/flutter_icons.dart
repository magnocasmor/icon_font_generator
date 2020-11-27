const String base = '''
// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:flutter/widgets.dart' show immutable, IconData;

@immutable
class %CLASS_NAME% {
%INDENT%static const _fontFamily = "%CLASS_NAME%";

%INDENT%
%CONTENT%
}
''';

const String icon = '%INDENT%static const IconData %ICON_NAME% = '
    'IconData(0x%ICON_CODE%, fontFamily: _fontFamily);';

const String package = '\n%INDENT%%INDENT%%INDENT%%INDENT%'
    '%INDENT%fontPackage: \'%PACKAGE_NAME%\',';
