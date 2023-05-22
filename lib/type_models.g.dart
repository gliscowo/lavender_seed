// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'type_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BookDefinition _$BookDefinitionFromJson(Map<String, dynamic> json) =>
    BookDefinition(
      json['name'] as String,
      json['landing_text'] as String,
      json['book_texture'] as String?,
      json['model'] as String?,
      json['show_progress'] as bool?,
      (json['macros'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, e as String),
          ) ??
          {},
      json['extend'] as String?,
    );

Map<String, dynamic> _$BookDefinitionToJson(BookDefinition instance) =>
    <String, dynamic>{
      'name': instance.name,
      'landing_text': instance.landingText,
      'book_texture': instance.bookTexture,
      'model': instance.model,
      'show_progress': instance.showProgress,
      'macros': instance.macros,
      'extend': instance.extend,
    };

Category _$CategoryFromJson(Map<String, dynamic> json) => Category(
      json['name'] as String,
      json['description'] as String,
      json['icon'] as String,
      json['parent'] as String?,
      json['secret'] as bool? ?? false,
    );

Map<String, dynamic> _$CategoryToJson(Category instance) => <String, dynamic>{
      'name': instance.name,
      'description': instance.description,
      'icon': instance.icon,
      'parent': instance.parent,
      'secret': instance.secret,
    };

Entry _$EntryFromJson(Map<String, dynamic> json) => Entry(
      json['name'] as String,
      json['category'] as String,
      json['icon'] as String,
      (json['pages'] as List<dynamic>)
          .map((e) => Page.fromJson(e as Map<String, dynamic>))
          .toList(),
      json['advancement'] as String?,
      json['secret'] as bool? ?? false,
      (json['extra_recipe_mappings'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, e as int),
          ) ??
          {},
    );

Map<String, dynamic> _$EntryToJson(Entry instance) => <String, dynamic>{
      'name': instance.name,
      'category': instance.category,
      'icon': instance.icon,
      'pages': instance.pages,
      'advancement': instance.advancement,
      'secret': instance.secret,
      'extra_recipe_mappings': instance.extraRecipeMappings,
    };
