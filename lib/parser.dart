class _ParsingState {
  final List<Span> spans = [];
  bool expectsClosingParen = false;
}

String patchouliToMarkdown(String patchouliFormatted) {
  final output = StringBuffer();
  final state = _ParsingState();

  final reader = StringReader(patchouliFormatted);

  while (reader.hasNext) {
    if (state.expectsClosingParen && reader.peek != ")") {
      throw FormatException("Missing closing parenthesis of formatting code");
    }

    if (reader.tryConsume(r"$(")) {
      final next = reader.peek;
      switch (next) {
        case "l" || "m" || "n" || "o":
          state.spans.add(BasicFormattingSpan.ofFormattingCode(next));
      }
    }
  }

  return output.toString();
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
    return tryMatch((reader) {
      for (var codeUnit in toConsume.codeUnits) {
        if (reader.next != String.fromCharCode(codeUnit)) return false;
      }

      return true;
    });
  }
}

sealed class Span {
  final StringBuffer _content = StringBuffer();
  void append(String content) => _content.write(content);

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
  factory BasicFormattingSpan.ofFormattingCode(String code) => BasicFormattingSpan._(_mappings[code] ?? "");

  @override
  String begin() => "$operator$_content";
  @override
  String end() => operator;
}

class ColorFormattingSpan extends Span {
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
    "f": "white",
  };

  final String color;

  ColorFormattingSpan._(this.color);
  factory ColorFormattingSpan.ofColorCode(String code) => ColorFormattingSpan._(_mappings[code]!);
  factory ColorFormattingSpan.ofHexCode(String hexCode) => ColorFormattingSpan._("#$hexCode");

  @override
  String begin() => "{$color}$_content";
  @override
  String end() => "{}";
}
