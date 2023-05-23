import 'package:json_annotation/json_annotation.dart';

part 'type_models.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake)
class BookDefinition {
  final String name;
  final String landingText;
  final String? bookTexture;
  final String? model;
  @JsonKey(defaultValue: true)
  final bool showProgress;
  @JsonKey(defaultValue: {})
  final Map<String, String> macros;
  final String? extend;

  BookDefinition(
      this.name, this.landingText, this.bookTexture, this.model, this.showProgress, this.macros, this.extend);

  Map<String, dynamic> toJson() => _$BookDefinitionToJson(this);
  factory BookDefinition.fromJson(Map<String, dynamic> json) => _$BookDefinitionFromJson(json);
}

@JsonSerializable()
class Category {
  final String name;
  final String description;
  final String icon;
  final String? parent;
  @JsonKey(defaultValue: false)
  final bool secret;

  Category(this.name, this.description, this.icon, this.parent, this.secret);

  Map<String, dynamic> toJson() => _$CategoryToJson(this);
  factory Category.fromJson(Map<String, dynamic> json) => _$CategoryFromJson(json);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class Entry {
  final String name;
  final String category;
  final String icon;
  final List<Page> pages;
  final String? advancement;
  @JsonKey(defaultValue: false)
  final bool secret;
  @JsonKey(defaultValue: {})
  final Map<String, int> extraRecipeMappings;

  Entry(this.name, this.category, this.icon, this.pages, this.advancement, this.secret, this.extraRecipeMappings);

  Map<String, dynamic> toJson() => _$EntryToJson(this);
  factory Entry.fromJson(Map<String, dynamic> json) => _$EntryFromJson(json);
}

class Page {
  final String type;
  final Map<String, dynamic> data;

  Page(this.type, this.data);

  Map<String, dynamic> toJson() => data;
  factory Page.fromJson(Map<String, dynamic> json) => Page(json["type"] as String, json);
}

@JsonSerializable()
class Multiblock {
  static final _replacementPattern = RegExp(r"[_ ]");

  final Map<String, String> mapping;
  final List<List<String>> pattern;

  Multiblock(this.mapping, this.pattern);

  Map<String, dynamic> toJson() => _$MultiblockToJson(this);
  factory Multiblock.fromJson(Map<String, dynamic> json) => _$MultiblockFromJson(json);

  Map<String, dynamic> toLavenderStructure() {
    final keys = {...mapping};
    final layers = [...pattern];

    if (!keys.containsKey("_") && layers.any((layer) => layer.any((row) => row.contains("_") || row.contains(" ")))) {
      for (var layer in layers) {
        for (var i = 0; i < layer.length; i++) {
          layer[i] = layer[i].replaceAllMapped(_replacementPattern, (match) => match.group(0) == "_" ? " " : "_");
        }
      }
    }

    return {"keys": keys, "layers": layers};
  }
}
