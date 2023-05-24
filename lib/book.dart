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
        "```json\n${_encoder.convert(frontmatter)}\n```\n\n${converter.convert(category.description)}",
      );
    }

    final entryOutPath = p.join(outPath.path, "entries");
    final structureOutPath = p.join(outPath.path, "structures");

    _writeFile(
      p.join(entryOutPath, bookPath),
      "landing_page.md",
      "```json\n${_encoder.convert({"title": definition.name})}\n```\n\n${converter.convert(definition.landingText)}",
    );

    final unknownPageTypes = <String>{};
    for (final (:path, :entry) in entries) {
      final content = StringBuffer();
      for (final (idx, Page(:type, :data)) in entry.pages.indexed) {
        if (customPageMappings[type] case var mapping?) {
          final paramPattern = RegExp(r"\{\{[-_a-zA-Z\d]+}}");
          String map(Match match) {
            final paramName = match.group(0)!.substring(2, match.group(0)!.length - 2);
            if (!data.containsKey(paramName)) throw ArgumentError.value(paramName, "page mapping parameter");

            return data[paramName]!;
          }

          if (mapping case String mapping) {
            content.write("${mapping.replaceAllMapped(paramPattern, map)}\n\n");
          } else if (mapping case List<dynamic> mappings) {
            for (var (idx, mapping) in mappings.cast<String>().indexed) {
              try {
                content.writeln(mapping.replaceAllMapped(paramPattern, map));
              } catch (_) {
                if (idx > 0) continue;
                rethrow;
              }
            }

            content.writeln();
          } else {
            unknownPageTypes.add(type);
          }
        } else {
          switch (type) {
            case "text" || "patchouli:text":
              {}
            case "image" || "patchouli:image":
              content.write("![](${(data["images"]! as List<dynamic>).first})\n\n");
            case "crafting" || "patchouli:crafting":
              content.writeln("<recipe;${data["recipe"]!}>");
              if (data.containsKey("recipe2")) content.writeln("<recipe;${data["recipe2"]!}>");

              content.write("\n");
            case "entity" || "patchouli:entity":
              content.write("<entity;${data["entity"]!}>");
            case "multiblock" || "patchouli:multiblock":
              final multiblock = Multiblock.fromJson(data["multiblock"] as Map<String, dynamic>);
              _writeFile(
                structureOutPath,
                "${p.basenameWithoutExtension(path)}_$idx.json",
                _encoder.convert(multiblock.toLavenderStructure()),
              );

              content.write("<structure;$bookNamespace:${p.basenameWithoutExtension(path)}_$idx>");
            case var unmappedType:
              unknownPageTypes.add(unmappedType);

              final header = "---< Unmapped page type '$unmappedType' >---";

              content.writeln(header);
              content.writeln(_encoder.convert({...data}..remove("text")));
              content.write("---< ${"=" * (header.length - 10)} >---\n\n");
          }
        }

        // TODO support titles
        if (data.containsKey("text")) content.write(converter.convert(data["text"]!));
        content.write("\n\n;;;;;\n\n");
      }

      final frontmatter = {
        "icon": entry.icon,
        "title": entry.name,
        "category": entry.category,
        if (entry.secret) "secret": true,
        if (entry.advancement != null) "required_advancements": [entry.advancement],
        if (entry.extraRecipeMappings.isNotEmpty) "associated_items": entry.extraRecipeMappings.keys.toList()
      };

      var renderedContent = content.toString();
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

  static void _writeFile(String basePath, String file, String content) => File(p.join(basePath, file))
    ..createSync(recursive: true)
    ..writeAsStringSync(content);
}
