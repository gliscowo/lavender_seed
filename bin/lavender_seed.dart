import 'dart:io';

import 'package:lavender_seed/book.dart';

final _identifierRegex = RegExp(r"[a-z0-9_.\-]+:[a-z0-9/._\-]+");

void main(List<String> args) async {
  if (args case [var bookJsonPath, var outPath, var outBookId, ...]) {
    if (!_identifierRegex.hasMatch(outBookId)) {
      throw ArgumentError.value(outBookId, "output book identifier");
    }

    final stopwatch = Stopwatch()..start();
    final book = await Book.load(File(bookJsonPath));

    print(
      "Loaded book '${book.definition.name}' in ${(stopwatch.elapsedMicroseconds / 1000).toStringAsFixed(3)}ms",
    );

    print(" - ${book.categories.length} Categories");
    print(book.categories.map((e) => "   - ${e.category.name}").join("\n"));

    print(" - ${book.entries.length} Entries");
    print(book.entries.map((e) => "   - ${e.entry.name}").join("\n"));
    print("");

    stopwatch.reset();
    book.convert(Directory(outPath), outBookId);
    print("Converted successfully in ${(stopwatch.elapsedMicroseconds / 1000).toStringAsFixed(3)}ms");
  } else {
    print("Usage: ${Platform.executable} <path/to/book.json> <output/path> <output:book_identifier>");
  }
}
