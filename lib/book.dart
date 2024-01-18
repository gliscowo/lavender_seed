import 'dart:convert';
import "dart:io";

import 'package:lavender_seed/converter.dart';
import 'package:lavender_seed/type_models.dart';
import 'package:path/path.dart' as p;

const JsonEncoder _encoder = JsonEncoder.withIndent("  ");

/// A Patchouli book with its 'book.json' metadata, entries and categories
class Book {
  final BookDefinition definition;
  final List<({String path, Entry entry})> entries;
  final List<({String path, Category category})> categories;

  Book._(this.definition, this.entries, this.categories);
  static Future<Book> load(File bookJson, String language) async {
    if (!bookJson.existsSync()) throw FileSystemException("Given book.json file does not exist", bookJson.path);
    final defintion = BookDefinition.fromJson(jsonDecode(bookJson.readAsStringSync()));

    final contentBaseDir = Directory(p.join(bookJson.parent.path, language));
    if (!contentBaseDir.existsSync()) {
      throw FileSystemException("Content directory of language '$language' was not found", contentBaseDir.path);
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

  /// Convert this book to Lavender-formatted Markdown and create the required file
  /// structure in [outPath], using [outBookId] as the book's ID.
  ///
  /// If the book contains non-standard page types, [customPageMappings] may be supplied
  /// with templates for converting the unknown data format to Markdown
  void convert(Directory outPath, String outBookId, {Map<String, dynamic> customPageMappings = const {}}) {
    if (!outPath.existsSync()) outPath.createSync(recursive: true);

    final [bookNamespace, bookPath] = outBookId.split(":");
    final booksOutPath = p.join(outPath.path, "books");
    _writeFile(
      booksOutPath,
      "$bookPath.json",
      _encoder.convert({
        if (definition.bookTexture != null) "texture": definition.bookTexture,
        if (definition.extend != null) "extend": definition.extend,
        if (definition.model != null) "dynamic_book_model": definition.model,
        if (definition.showProgress) "display_completion": true,
        if (definition.openSound != null) "open_sound": definition.openSound,
        if (definition.flipSound != null) "flipping_sound": definition.flipSound,
      }),
    );

    final converter = PatchouliToMarkdownConverter(definition.macros);

    final categoryOutPath = p.join(outPath.path, "categories");

    for (final (:path, :category) in categories) {
      final frontmatter = {
        "icon": category.icon,
        "title": category.name,
        if (category.secret) "secret": true,
      };

      _writeFile(
        p.join(categoryOutPath, bookPath),
        p.setExtension(path, ".md"),
        "```json\n${_encoder.convert(frontmatter)}\n```\n\n${converter.convert(category.description, bookNamespace)}",
      );
    }

    final entryOutPath = p.join(outPath.path, "entries");
    final structureOutPath = p.join(outPath.path, "structures");

    _writeFile(
      p.join(entryOutPath, bookPath),
      "landing_page.md",
      "```json\n${_encoder.convert({
            "title": definition.name
          })}\n```\n\n${converter.convert(definition.landingText, bookNamespace)}",
    );

    final unknownPageTypes = <String>{};
    for (final (:path, :entry) in entries) {
      final entryContent = StringBuffer();
      final associatedItems = entry.extraRecipeMappings.keys.toList();

      for (final (idx, Page(:type, :data)) in entry.pages.indexed) {
        if (customPageMappings[type] case var mapping?) {
          final paramPattern = RegExp(r"\{\{[-_a-zA-Z\d]+}}");
          String map(Match match) {
            final paramName = match[0]!.substring(2, match[0]!.length - 2);
            if (!data.containsKey(paramName)) throw ArgumentError.value(paramName, "page mapping parameter");

            return converter.convert(data[paramName]!, bookNamespace);
          }

          if (mapping case String mapping) {
            entryContent.write("${mapping.replaceAllMapped(paramPattern, map)}\n\n");
          } else if (mapping case List<dynamic> mappings) {
            for (var (idx, mapping) in mappings.cast<String>().indexed) {
              try {
                entryContent.writeln(mapping.replaceAllMapped(paramPattern, map));
              } catch (_) {
                if (idx > 0) continue;
                rethrow;
              }
            }

            entryContent.writeln();
          } else {
            unknownPageTypes.add(type);
          }
        } else {
          try {
            switch (type) {
              case "text" || "patchouli:text":
                {}
              case "crafting" ||
                    "patchouli:crafting" ||
                    "smelting" ||
                    "patchouli:smelting" ||
                    "campfire" ||
                    "patchouli:campfire" ||
                    "smithing" ||
                    "patchouli:smithing" ||
                    "blasting" ||
                    "patchouli:blasting" ||
                    "smoking" ||
                    "patchouli:smoking" ||
                    "stonecutting" ||
                    "patchouli:stonecutting":
                entryContent.writeln("<recipe;${data["recipe"]!}>");
                if (data.containsKey("recipe2")) entryContent.writeln("<recipe;${data["recipe2"]!}>");

                entryContent.write("\n");
              case "image" || "patchouli:image":
                entryContent.write("![](${(data["images"]! as List<dynamic>).first},fit)\n\n");
              case "spotlight" || "patchouli:spotlight":
                entryContent.writeln(
                    "<|item-spotlight@lavender:book_components|item=${_escapeItemStackString(data["item"])}|>");
                if (data["link_recipe"] == true) associatedItems.add(data["item"]);
              case "entity" || "patchouli:entity":
                entryContent.writeln("<entity;${data["entity"]!}>");
              case "multiblock" || "patchouli:multiblock":
                if (data.containsKey("multiblock")) {
                  final multiblock = Multiblock.fromJson(data["multiblock"] as Map<String, dynamic>);
                  _writeFile(
                    structureOutPath,
                    "${p.basenameWithoutExtension(path)}_$idx.json",
                    _encoder.convert(multiblock.toLavenderStructure()),
                  );

                  entryContent.writeln("<structure;$bookNamespace:${p.basenameWithoutExtension(path)}_$idx>");
                } else if (data.containsKey("multiblock_id")) {
                  entryContent.writeln("<structure;${data["multiblock_id"]}>");
                }
              case var unmappedType:
                unknownPageTypes.add(unmappedType);
                _writeRawPageData("Unmapped page type '$unmappedType'", entryContent, data);
            }
          } catch (_) {
            _writeRawPageData("Broken page", entryContent, data);
          }
        }

        if (data.containsKey("title")) {
          entryContent.writeln("<|page-title@lavender:book_components|title=${data["title"]}|>");
        }

        if (data.containsKey("text")) entryContent.write(converter.convert(data["text"]!, bookNamespace));
        entryContent.write("\n\n;;;;;\n\n");
      }

      final frontmatter = {
        "icon": entry.icon,
        "title": entry.name,
        "category": entry.category,
        if (entry.secret) "secret": true,
        if (entry.advancement != null) "required_advancements": [entry.advancement],
        if (entry.extraRecipeMappings.isNotEmpty) "associated_items": associatedItems
      };

      var renderedContent = entryContent.toString();
      renderedContent = renderedContent.substring(0, renderedContent.length - 9);

      _writeFile(
        p.join(entryOutPath, bookPath),
        p.setExtension(path, ".md"),
        "```json\n${_encoder.convert(frontmatter)}\n```\n\n$renderedContent",
      );
    }

    if (unknownPageTypes.isNotEmpty) {
      print("Encountered ${unknownPageTypes.length} unknown page types while converting:");
      print(unknownPageTypes.map((e) => " - $e").join("\n"));
      print("");
    }
  }

  static String _escapeItemStackString(String itemStackString) {
    final resultBuffer = StringBuffer();
    for (var i = 0; i < itemStackString.length; i++) {
      final char = itemStackString[i];
      resultBuffer.write(char == "," ? r"\," : char);
    }

    return resultBuffer.toString();
  }

  static void _writeRawPageData(String message, StringBuffer target, Map<String, dynamic> data) {
    final header = "---< $message >---";

    target.writeln(header);
    target.writeln(_encoder.convert({...data}..remove("text")));
    target.write("---< ${"=" * (header.length - 10)} >---\n\n");
  }

  static void _writeFile(String basePath, String file, String content) => File(p.join(basePath, file))
    ..createSync(recursive: true)
    ..writeAsStringSync(content);
}
