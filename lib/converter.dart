/// Patchouli's built-in list of macros, this is combined with any book-specific
/// macros to form the final macro set used during conversion
const _defaultMacros = {
  r"$(obf)": r"$(k)",
  r"$(bold)": r"$(l)",
  r"$(strike)": r"$(m)",
  r"$(italic)": r"$(o)",
  r"$(italics)": r"$(o)",
  r"$(list": r"$(li",
  r"$(reset)": r"$()",
  r"$(clear)": r"$()",
  r"$(2br)": r"$(br2)",
  r"$(p)": r"$(br2)",
  r"/$": r"$()",
  r"<br>": r"$(br)",
  r"$(nocolor)": r"$(0)",
  r"$(item)": r"$(d)",
  r"$(thing)": r"$(6)",
};

/// Parser and Markdown-generator implemenation used for converting
/// each individual page of the supplied Patchouli book
class PatchouliToMarkdownConverter {
  final Map<String, String> _macros;

  PatchouliToMarkdownConverter(Map<String, String> macros) : _macros = {..._defaultMacros, ...macros};

  /// Convert Patchouli-formatted [input] into Markdown-formatted
  /// output, assuming all namespace-less links point into [namespace]
  String convert(String input, String namespace) {
    final output = StringBuffer();
    final spans = <Span>[];

    for (var MapEntry(key: macro, value: expansion) in _macros.entries) {
      input = input.replaceAll(macro, expansion);
    }

    final reader = StringReader(input);
    while (reader.hasNext) {
      if (reader.tryConsume(r"$()")) {
        while (spans.isNotEmpty) {
          output.write(spans.removeLast().end());
        }
      } else if (reader.tryConsume(r"$(")) {
        final code = reader.readUntil(")");
        if (code == null) throw ParsingError("Expected ')' or formatting code", reader);

        switch (code) {
          case "br":
            output.write("\n\n");
          case "br2":
            output.write("\n\n\n");
          case "playername":
            output.write("{yellow}<playername here>{}");
          case "/l":
            final linkSpan = spans.reversed.cast<Span?>().firstWhere((e) => e is LinkSpan, orElse: () => null);
            if (linkSpan == null) throw ParsingError("No link to terminate", reader, offset: -3);

            spans.remove(linkSpan);
            output.write(linkSpan.end());
          default:
            if (code.startsWith("k:")) {
              output.write("<keybind;key.${code.substring(2)}>");
            } else if (code.startsWith("li")) {
              final indent = code.length < 3 ? 0 : int.tryParse(code.substring(2));
              if (indent == null) throw ParsingError("Expected an integer or nothing", reader, offset: -2);

              output.write("\n${"    " * (indent - 1)}- ");
            } else if (ColorFormattingSpan.tryParse(code) case var span?) {
              spans.add(span);
              output.write(span.begin());
            } else if (BasicFormattingSpan.tryParse(code) case var span?) {
              spans.add(span);
              output.write(span.begin());
            } else if (LinkSpan.tryParse(code, namespace) case var span?) {
              spans.add(span);
              output.write(span.begin());
            }
        }
      } else {
        output.write(reader.next);
      }
    }

    while (spans.isNotEmpty) {
      output.write(spans.removeLast().end());
    }

    return output.toString();
  }
}

class StringReader {
  final String string;
  int _cursor = 0;

  StringReader(this.string);

  int get cursor => _cursor;

  String get peek => string[_cursor];
  String? get next => _cursor < string.length ? string[_cursor++] : null;

  bool get hasNext => _cursor < string.length;

  String? peekOffset(int offset) {
    final charIndex = _cursor + offset;
    return charIndex >= 0 && charIndex < string.length ? string[charIndex] : null;
  }

  String? readUntil(String delimiter, [bool skipDelimiter = true]) {
    var read = StringBuffer();
    if (tryMatch((_) {
      while (hasNext) {
        if (peek == delimiter) {
          if (skipDelimiter) next;
          return true;
        }

        read.write(next);
      }

      return false;
    })) {
      return read.toString();
    } else {
      return null;
    }
  }

  bool tryMatch(bool Function(StringReader) matcher) {
    int cursorPos = _cursor;
    if (!matcher(this)) {
      _cursor = cursorPos;
      return false;
    } else {
      return true;
    }
  }

  bool tryConsume(String toConsume) {
    return tryMatch((_) {
      for (var codeUnit in toConsume.codeUnits) {
        if (next != String.fromCharCode(codeUnit)) return false;
      }

      return true;
    });
  }
}

/// Error implementation with sufficient context to pretty-print
/// the error including its precise location for the user
class ParsingError extends Error {
  final String _message;
  final StringReader _reader;
  final int _offset;

  ParsingError(this._message, this._reader, {int offset = 0}) : _offset = offset;

  @override
  String toString() {
    return [
      "ParsingError",
      _reader.string,
      "${" " * (_reader.cursor + _offset)}^",
      "${" " * (_reader.cursor + _offset)}$_message",
      "",
    ].join("\n");
  }
}

sealed class Span {
  String begin();
  String end();
}

class BasicFormattingSpan extends Span {
  static const _mappings = {
    "l": "**",
    "m": "~~",
    "n": "__",
    "o": "*",
  };

  final String operator;

  BasicFormattingSpan._(this.operator);
  static BasicFormattingSpan? tryParse(String code) {
    return _mappings.containsKey(code) ? BasicFormattingSpan._(_mappings[code]!) : null;
  }

  @override
  String begin() => operator;
  @override
  String end() => operator;
}

class ColorFormattingSpan extends Span {
  static final _colorRegex = RegExp("#[0-9a-fA-F]{3,6}");
  static const _mappings = {
    "0": "black",
    "1": "dark_blue",
    "2": "dark_green",
    "3": "dark_aqua",
    "4": "dark_red",
    "5": "dark_purple",
    "6": "gold",
    "7": "gray",
    "8": "dark_gray",
    "9": "blue",
    "a": "green",
    "b": "aqua",
    "c": "red",
    "d": "light_purple",
    "e": "yellow",
    "f": "white"
  };

  final String color;

  ColorFormattingSpan._(this.color);
  static ColorFormattingSpan? tryParse(String code) {
    if (_mappings.containsKey(code)) return ColorFormattingSpan._(_mappings[code]!);

    if (_colorRegex.hasMatch(code)) {
      if (code.length < 7) {
        code = "#${code[1] * 2}${code[2] * 2}${code[3] * 2}";
      }

      return ColorFormattingSpan._(code);
    }

    return null;
  }

  @override
  String begin() => "{$color}";
  @override
  String end() => "{}";
}

class LinkSpan extends Span {
  final String linkTarget;

  LinkSpan._(this.linkTarget);
  static LinkSpan? tryParse(String code, String namespace) {
    if (!code.startsWith("l:")) return null;

    final link = code.substring(2);
    return LinkSpan._(link.startsWith("https://") ? link : "^${_canonicalizeLink(namespace, link)}");
  }

  static String _canonicalizeLink(String namespace, String link) {
    if (link.contains(":")) return link;
    return "$namespace:$link";
  }

  @override
  String begin() => "[";
  @override
  String end() => "]($linkTarget)";
}
