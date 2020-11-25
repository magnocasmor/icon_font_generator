import 'dart:convert';
import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:icon_font_generator/generate_flutter_class.dart';
import 'package:icon_font_generator/templates/npm_package.dart';
import 'package:icon_font_generator/utils.dart';
import 'package:path/path.dart' as path;

void main(List<String> args) async {
  final runner = CommandRunner('icon_font_generator', 'Generate you own fonts')
    ..addCommand(GenerateCommand());
  try {
    await runner.run(['gen', ...args]);
  } on UsageException catch (error) {
    print(error);
    exit(1);
  }
}

class GenerateCommand extends Command {
  GenerateCommand() {
    argParser
      ..addOption(
        'from',
        abbr: 'f',
        help: 'Input dir with svg\'s',
      )
      ..addOption(
        'out-font',
        help: 'Output icon font',
      )
      ..addOption(
        'out-flutter',
        help: 'Output flutter icon class',
      )
      ..addOption(
        'class-name',
        help: 'Flutter class name \ family for generating file',
      )
      ..addOption(
        'height',
        help: 'Fixed font height value',
        defaultsTo: '512',
      )
      ..addOption(
        'ascent',
        help: 'Offset applied to the baseline',
        defaultsTo: '240',
      )
      ..addOption(
        'package',
        help: 'Name of package for generated icon data (if another package)',
      )
      ..addOption(
        'indent',
        help: 'Indent for generating dart file, for example: ' ' ',
        defaultsTo: '  ',
      )
      ..addFlag(
        'mono',
        help: 'Make font monospace',
        defaultsTo: true,
      )
      ..addFlag(
        'normalize',
        help: 'Normalize icons sizes',
        defaultsTo: false,
      );
  }

  @override
  String get name => 'gen';

  @override
  String get description => 'Generate you own fonts';

  @override
  Future<void> run() async {
    final nodeCheckResult = await Process.run('node', ['--version'], runInShell: true);
    if (nodeCheckResult.exitCode != 0) {
      print('Please install Node.JS. Recommended v10+');
    }

    if (argResults['from'] == null ||
        argResults['out-font'] == null ||
        argResults['out-flutter'] == null ||
        argResults['class-name'] == null) {
      print('--from, --out-font, --out-flutter, '
          '--class-name args required!');
      exit(1);
    }

    final genRootDir = Directory.fromUri(Platform.script.resolve('..'));

    final npmPackage = File(path.join(genRootDir.path, 'package.json'));
    if (!npmPackage.existsSync()) {
      await npmPackage.writeAsString(npmPackageTemplate);
    }

    final tempSourceDirectory = Directory.fromUri(genRootDir.uri.resolve('temp_icons'));
    final tempOutDirectory = Directory.fromUri(genRootDir.uri.resolve('temp_font'));
    final iconsMap = File.fromUri(genRootDir.uri.resolve('map.json'));
    if (tempSourceDirectory.existsSync()) {
      await tempSourceDirectory.delete(recursive: true);
    }
    if (tempOutDirectory.existsSync()) {
      await tempOutDirectory.delete(recursive: true);
    }
    if (iconsMap.existsSync()) {
      await iconsMap.delete();
    }

    final nodeInstallDependencies = await Process.start(
      'npm',
      ['install'],
      workingDirectory: genRootDir.path,
      runInShell: true,
    );
    await stdout.addStream(nodeInstallDependencies.stdout);

    // icon-font-generator reguires package: `ttf2woff2`
    // we do not need him and requires a python
    final String gypErr = 'gyp ERR!';
    await stderr.addStream(
        nodeInstallDependencies.stderr.where((bytes) => !utf8.decode(bytes).contains(gypErr)));

    final sourceIconsDirectory =
        Directory.fromUri(Directory.current.uri.resolve(argResults['from'].replaceAll('\\', '/')));
    final outIconsFile =
        File.fromUri(Directory.current.uri.resolve(argResults['out-font'].replaceAll('\\', '/')));
    final outFlutterClassFile = File.fromUri(
        Directory.current.uri.resolve(argResults['out-flutter'].replaceAll('\\', '/')));

    await tempSourceDirectory.create();
    await tempOutDirectory.create();

    await copyDirectory(
      sourceIconsDirectory,
      tempSourceDirectory,
    );

    // gen font
    final generateFont = await Process.start(
      path.join(
        genRootDir.path,
        'node_modules/.bin/icon-font-generator${Platform.isWindows ? '.cmd' : ''}',
      ),
      [
        path.absolute(path.join(tempSourceDirectory.path, '*.svg')),
        '--codepoint',
        '0xe000',
        '--css',
        'false',
        '--html',
        'false',
        '--height',
        argResults['height'],
        '--ascent',
        argResults['ascent'],
        '--mono',
        argResults['mono'].toString(),
        '--normalize',
        argResults['normalize'].toString(),
        '--name',
        path.basenameWithoutExtension(argResults['out-font']),
        '--out',
        path.absolute(tempOutDirectory.path),
        '--jsonpath',
        'map.json',
        '--types',
        'ttf',
      ],
      workingDirectory: genRootDir.path,
      runInShell: true,
    );

    await stdout.addStream(generateFont.stdout.map((bytes) {
      var message = utf8.decode(bytes);
      if (message == '\x1b[32mDone\x1b[39m\n') {
        message = '\x1b[32mSuccess generated font\x1b[39m\n';
      }
      return utf8.encode(message);
    }));
    final String stdlib = 'Invalid member of stdlib';
    await stderr
        .addStream(generateFont.stderr.where((bytes) => !utf8.decode(bytes).contains(stdlib)));

    if (!outIconsFile.existsSync()) {
      await outIconsFile.create(recursive: true);
    }

    await File(path.join(
      tempOutDirectory.path,
      path.basename(argResults['out-font']),
    )).copy(outIconsFile.path);

    final generateClassResult = await generateFlutterClass(
      iconMap: iconsMap,
      className: argResults['class-name'],
      packageName: argResults['package'],
      indent: argResults['indent'],
    );

    if (!outFlutterClassFile.existsSync()) {
      await outFlutterClassFile.create(recursive: true);
    }

    await outFlutterClassFile.writeAsString(generateClassResult.content);
    print('Successful generated '
        '\x1b[33m${path.basename(outFlutterClassFile.path)}\x1b[0m '
        'with \x1b[32m${generateClassResult.iconsCount}\x1b[0m icons'
        '\x1b[32m saved!\x1b[0m');

    await tempSourceDirectory.delete(recursive: true);
    await tempOutDirectory.delete(recursive: true);
    await iconsMap.delete();
  }
}
