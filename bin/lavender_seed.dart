import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:lavender_seed/book.dart';
import 'package:path/path.dart' as p;

import 'version.dart';

final _identifierRegex = RegExp(r"[a-z0-9_.\-]+:[a-z0-9/._\-]+");
const _usage = """
Usage:
  lavender-seed <path/to/book.json> <output/path> <output_book:identifier>

Read the file structure of the given Patchouli book and reproduce it
in the given output path using Lavender-compatible Markdown formatting
and file structure. The given output identifier is used as the identifier of 
the generated book

If there are custom page types present in the book that need to be converted,
a mapping file can be supplied. The mappings in this file can extract data
from the original page JSON using {{key_here}} syntax

Options:
""";

void main(List<String> args) async {
  final argParser = ArgParser()
    ..addOption(
      "language",
      abbr: "l",
      help: "The language to convert",
      defaultsTo: "en_us",
    )
    ..addOption(
      "page-mappings",
      abbr: "m",
      help: "The location of a JSON file containing mappings for custom page types",
    )
    ..addFlag(
      "help",
      negatable: false,
      help: "Print this usage information",
    )
    ..addFlag(
      "version",
      negatable: false,
      hide: true,
    );

  final results = argParser.parse(args);
  if (results.wasParsed("version")) {
    print("lavender-seed v$packageVersion");
    return;
  }

  if (results.rest case [var bookJsonPath, var outPath, var outBookId]) {
    if (!_identifierRegex.hasMatch(outBookId)) {
      print("Not a valid book identifier: $outBookId");
      exitCode = 1;
      return;
    }

    Map<String, dynamic> customMappings;
    try {
      customMappings = results.wasParsed("page-mappings")
          ? jsonDecode(File(results["page-mappings"]).readAsStringSync()) as Map<String, dynamic>
          : const <String, dynamic>{};
    } on Exception catch (e) {
      print("Could not load custom page mappings\n-> $e");
      exitCode = 1;
      return;
    }

    final stopwatch = Stopwatch()..start();

    Book book;
    try {
      book = await Book.load(File(bookJsonPath), results["language"]);
    } on Exception catch (e) {
      print("Failed to load book contents\n-> $e");
      exitCode = 1;
      return;
    }

    print("Loaded book '${book.definition.name}' in ${(stopwatch.elapsedMicroseconds / 1000).toStringAsFixed(3)}ms");

    print(" - ${book.categories.length} Categories");
    print(book.categories.map((e) => "   - ${e.category.name}").join("\n"));

    print(" - ${book.entries.length} Entries");
    print(book.entries.map((e) => "   - ${e.entry.name}").join("\n"));
    print("");

    final outDir = results.wasParsed("language") ? Directory(p.join(outPath, results["language"])) : Directory(outPath);

    try {
      stopwatch.reset();
      book.convert(outDir, outBookId, customPageMappings: customMappings);
    } on Exception catch (e) {
      print("Failed to convert book\n-> $e");
      exitCode = 1;
      return;
    }

    print("Converted successfully in ${(stopwatch.elapsedMicroseconds / 1000).toStringAsFixed(3)}ms");
  } else {
    stdout.write(_usage);
    print(argParser.usage.split("\n").map((e) => "  $e").join("\n"));
    print("version $packageVersion");
  }
}
