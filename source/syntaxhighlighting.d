module syntaxhighlighting;

private:
import filebuffer : Row;
import std.regex;
import std.array;

static immutable dKeywords = [
    "abstract", "alias", "align", "asm", "assert", "auto",
    "bool", "break", "byte", "case", "cast", "catch", "char",
    "class", "const", "continue", "dchar", "debug", "default",
    "delegate", "deprecated", "do", "double", "else", "enum",
    "export", "extern", "false", "final", "finally", "float",
    "for", "foreach", "foreach_reverse", "function", "goto", "if",
    "immutable", "import", "in", "inout", "int", "interface",
    "invariant", "is", "lazy", "long", "macro", "mixin", "module",
    "new", "nothrow", "null", "out", "override", "package",
    "pragma", "private", "protected", "public", "pure", "real",
    "ref", "return", "scope", "shared", "short", "static",
    "struct", "super", "switch", "synchronized", "template",
    "this", "throw", "true", "try", "typeid", "typeof"
];

enum dKeywordRegex = ctRegex!("\\b(" ~ dKeywords.join("|") ~ ")\\b");

enum dNumberRegex = ctRegex!(`(?x)
    0[bB][01_]+
  | 0[oO][0-7_]+
  | 0[xX][0-9A-Fa-f_]+
  | \d[\d_]*(\.\d[\d_]*)?([eE][+\-]?\d[\d_]*)?
`);

enum dOperatorRegex = ctRegex!(`(?x)
    (\+\+|--|<<=|>>=|>>>|<<|>>|\+=|-=|\*=|/=|%=|&=|\|=|\^=|==|!=|<=|>=|&&|\|\|)
  | [+\-*/%&|^~!=<>?:]
`);

void dSyntax(ref Row[] fileBuf) {
    for(size_t i = 0; i < fileBuf.length; i++) {
        fileBuf[i].clearHighlighting();
        foreach (m; matchAll(fileBuf[i]._data, dKeywordRegex)) {
            fileBuf[i].highlight(m.pre.length, m.hit.length, EditorHighlight.KEYWORD);
        }
        foreach (m; matchAll(fileBuf[i]._data, dNumberRegex)) {
            fileBuf[i].highlight(m.pre.length, m.hit.length, EditorHighlight.NUMBER);
        }
        foreach (m; matchAll(fileBuf[i]._data, dOperatorRegex)) {
            fileBuf[i].highlight(m.pre.length, m.hit.length, EditorHighlight.OPERATOR);
        }
    }
}

public:

enum EditorHighlight : char {
    NORMAL = 0,
    NUMBER,
    STRING,
    KEYWORD,
    IDENTIFIER,
    COMMENT,
    OPERATOR,
    PUNCTUATION,
}

void doHighlighting(ref Row[] fileBuf, string filename) {
    import std.path;
    import std.string;
    
    if(filename.extension() == ".d") {
        dSyntax(fileBuf);
    }
}