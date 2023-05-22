import 'dart:convert';
import "dart:io";

import 'package:lavender_seed/parser.dart';
import 'package:lavender_seed/type_models.dart';
import 'package:path/path.dart' as p;

const JsonEncoder _encoder = JsonEncoder.withIndent("    ");

class Book {
  final BookDefinition definition;
  final List<({String path, Entry entry})> entries;
  final List<({String path, Category category})> categories;

  Book._(this.definition, this.entries, this.categories);
  static Future<Book> load(File bookJson) async {
    if (!bookJson.existsSync()) throw FileSystemException("Given book.json file does not exist", bookJson.path);
    final defintion = BookDefinition.fromJson(jsonDecode(bookJson.readAsStringSync()));

    final contentBaseDir = Directory(p.join(bookJson.parent.path, "en_us"));
    if (!contentBaseDir.existsSync()) {
      throw FileSystemException("en_us content directory was not found", contentBaseDir.path);
    }

    final categories = <({String path, Category category})>[];
    final categoryDir = Directory(p.join(contentBaseDir.path, "categories"));

    final entries = <({String path, Entry entry})>[];
    final entryDir = Directory(p.join(contentBaseDir.path, "entries"));

    await Future.wait([
      if (categoryDir.existsSync())
        categoryDir
            .list(recursive: true)
            .where((event) => event is File)
            .cast<File>()
            .where((file) => p.extension(file.path) == ".json")
            .asyncMap((file) => (Future.value(file.path), file.readAsString()).wait)
            .map((event) => (p.relative(event.$1, from: categoryDir.path), jsonDecode(event.$2)))
            .cast<(String, Map<String, dynamic>)>()
            .map((event) => (path: event.$1, category: Category.fromJson(event.$2)))
            .forEach(categories.add),
      if (entryDir.existsSync())
        entryDir
            .list(recursive: true)
            .where((event) => event is File)
            .cast<File>()
            .where((file) => p.extension(file.path) == ".json")
            .asyncMap((file) => (Future.value(file.path), file.readAsString()).wait)
            .map((event) => (p.relative(event.$1, from: entryDir.path), jsonDecode(event.$2)))
            .cast<(String, Map<String, dynamic>)>()
            .map((event) => (path: event.$1, entry: Entry.fromJson(event.$2)))
            .forEach(entries.add)
    ]);

    return Book._(defintion, entries, List.unmodifiable(categories));
  }

  void convert(Directory outPath, String outBookName) {
    if (!outPath.existsSync()) outPath.createSync(recursive: true);

    final booksOutDir = Directory(p.join(outPath.path, "books"));
    if (!booksOutDir.existsSync()) booksOutDir.createSync(recursive: true);

    File(p.join(booksOutDir.path, "$outBookName.json")).writeAsStringSync(_encoder.convert({
      if (definition.bookTexture != null) "texture": definition.bookTexture,
      if (definition.extend != null) "extend": definition.extend,
      if (definition.model != null) "dynamic_book_model": definition.model,
      if (definition.showProgress) "display_completion": true,
    }));

    final converter = PatchouliToMarkdownConverter(definition.macros);

    final categoryOutDir = Directory(p.join(outPath.path, "categories", outBookName));
    if (!categoryOutDir.existsSync()) categoryOutDir.createSync(recursive: true);

    for (final (:path, :category) in categories) {
      final frontmatter = {
        "icon": category.icon,
        "title": category.name,
        if (category.secret) "secret": true,
      };

      File(p.join(categoryOutDir.path, p.setExtension(path, ".md")))
        ..createSync(recursive: true)
        ..writeAsStringSync(
          "```json\n${_encoder.convert(frontmatter)}\n```\n\n${converter.convert(category.description)}",
        );
    }

    final entryOutDir = Directory(p.join(outPath.path, "entries", outBookName));
    if (!entryOutDir.existsSync()) entryOutDir.createSync(recursive: true);

    File(p.join(entryOutDir.path, "landing_page.md")).writeAsStringSync(
      "```json\n${_encoder.convert({"title": definition.name})}\n```\n\n${converter.convert(definition.landingText)}",
    );

    final unknownPageTypes = <String>{};
    for (final (:path, :entry) in entries) {
      final associatedItems = [if (entry.extraRecipeMappings.isNotEmpty) ...entry.extraRecipeMappings.keys];

      final content = StringBuffer();
      for (final Page(:type, :data) in entry.pages) {
        // TODO support titles
        switch (type) {
          case "text" || "patchouli:text":
            content.write(converter.convert(data["text"]!));
          case "image" || "patchouli:image":
            content.write("![](${(data["images"]! as List<dynamic>).first})\n\n");
            if (data.containsKey("text")) content.write(converter.convert(data["text"]!));
          case "crafting" || "patchouli:crafting":
            content.write("<recipe;${data["recipe"]!}>\n");
            associatedItems.add(data["recipe"]!);

            if (data.containsKey("recipe2")) {
              content.write("<recipe;${data["recipe2"]!}>\n");
              associatedItems.add(data["recipe2"]!);
            }

            content.write("\n");
            if (data.containsKey("text")) content.write(converter.convert(data["text"]!));
          case "entity" || "patchouli:entity":
            content.write("<entity;${data["entity"]!}>");
            if (data.containsKey("text")) content.write(converter.convert(data["text"]!));
          case var unknownType:
            unknownPageTypes.add(unknownType);

            final text = data.remove("text") as String?;
            final header = "---< Unknown page type '$unknownType' >---";

            content.writeln(header);
            content.writeln(_encoder.convert(data));
            content.write("---< ${"=" * (header.length - 10)} >---\n\n");

            if (text != null) content.write(converter.convert(text));
        }

        content.write("\n\n;;;;;\n\n");
      }

      final frontmatter = {
        "icon": entry.icon,
        "title": entry.name,
        "category": entry.category,
        if (entry.secret) "secret": true,
        if (entry.advancement != null) "required_advancements": [entry.advancement],
        if (associatedItems.isNotEmpty) "associated_items": associatedItems
      };

      var renderedContent = content.toString();
      renderedContent = renderedContent.substring(0, renderedContent.length - 9);

      File(p.join(entryOutDir.path, p.setExtension(path, ".md")))
        ..createSync(recursive: true)
        ..writeAsStringSync("```json\n${_encoder.convert(frontmatter)}\n```\n\n$renderedContent");
    }

    if (unknownPageTypes.isNotEmpty) {
      print("Encountered ${unknownPageTypes.length} unknown page types while converting:");
      print(unknownPageTypes.map((e) => " - $e").join("\n"));
      print("");
    }
  }
}
