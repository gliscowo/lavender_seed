import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:lavender_seed/book.dart';
import 'package:path/path.dart' as p;

final _identifierRegex = RegExp(r"[a-z0-9_.\-]+:[a-z0-9/._\-]+");

void main(List<String> args) async {
  final parsedArgs = (ArgParser()
        ..addOption("page-mappings",
            abbr: "m", help: "The location of a JSON file containing mappings for custom page types")
        ..addOption("language", abbr: "l", help: "The language to convert, not specified for 'en_us'"))
      .parse(args);

  if (parsedArgs.rest case [var bookJsonPath, var outPath, var outBookId, ...]) {
    if (!_identifierRegex.hasMatch(outBookId)) {
      throw ArgumentError.value(outBookId, "output book identifier");
    }

    final customMappings = parsedArgs.wasParsed("page-mappings")
        ? jsonDecode(File(parsedArgs["page-mappings"]).readAsStringSync()) as Map<String, dynamic>
        : const <String, dynamic>{};

    final stopwatch = Stopwatch()..start();
    final book =
        await Book.load(File(bookJsonPath), parsedArgs.wasParsed("language") ? parsedArgs["language"] : "en_us");

    print(
      "Loaded book '${book.definition.name}' in ${(stopwatch.elapsedMicroseconds / 1000).toStringAsFixed(3)}ms",
    );

    print(" - ${book.categories.length} Categories");
    print(book.categories.map((e) => "   - ${e.category.name}").join("\n"));

    print(" - ${book.entries.length} Entries");
    print(book.entries.map((e) => "   - ${e.entry.name}").join("\n"));
    print("");

    final outDir =
        parsedArgs.wasParsed("language") ? Directory(p.join(outPath, parsedArgs["language"])) : Directory(outPath);

    stopwatch.reset();
    book.convert(outDir, outBookId, customPageMappings: customMappings);
    print("Converted successfully in ${(stopwatch.elapsedMicroseconds / 1000).toStringAsFixed(3)}ms");
  } else {
    print("Usage: ${Platform.executable} <path/to/book.json> <output/path> <output_book:identifier>");
  }
}
