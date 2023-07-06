{ lib, ...}: let
  pow =
    let
      pow' = base: exponent: value:
        if exponent == 0
        then 1
        else if exponent <= 1
        then value
        else (pow' base (exponent - 1) (value * base));
    in base: exponent: pow' base exponent base;


  # Taken from https://gist.github.com/corpix/f761c82c9d6fdbc1b3846b37e1020e11
  hexToDec = v:
  let
    hexToInt = {
      "0" = 0; "1" = 1;  "2" = 2;
      "3" = 3; "4" = 4;  "5" = 5;
      "6" = 6; "7" = 7;  "8" = 8;
      "9" = 9; "a" = 10; "b" = 11;
      "c" = 12;"d" = 13; "e" = 14;
      "f" = 15;
    };
    chars = lib.strings.stringToCharacters v;
    charsLen = builtins.length chars;
  in
    lib.lists.foldl
      (a: v: a + v)
      0
      (lib.lists.imap0
        (k: v: hexToInt."${v}" * (pow 16 (charsLen - k - 1)))
        chars);

in rec {
  default_colors = {
    primary = {r=255; g=0; b=0;};
    secondary = {r=255; g=255; b=0;};
    tertiary = {r=0; g=255; b=0;};
    highlight = {r=0; g=255; b=255;};
    active = {r=0; g=0; b=255;};
    inactive = {r=128; g=0; b=0;};
  };

  create_palette = colors: builtins.mapAttrs (name: value:
    if builtins.isString value
        then fromhex value
        else value
  ) colors;

  tohex = {r, g, b, ...}: let
    f = x: lib.strings.toLower (lib.strings.fixedWidthString 2 "0" (lib.trivial.toHexString x));
  in
    "${f r}${f g}${f b}";

  fromhex = hex_raw: let
    hex = lib.strings.toLower (lib.strings.removePrefix "#" hex_raw);
    col = idx: hexToDec (builtins.substring idx 2 hex);
  in
    { r = col 0; g = col 2; b = col 4; };

  basic = {
    black = {r=0; g=0; b=0;};
    white = {r=255; g=255; b=255;};
    gray = n: {r=n; g=n; b=n;};
  };

  escape_code = ''\033['';
  ansi = { r, g, b }: escape_code + ''38;2;${toString r};${toString g};${toString b}m'';
  reset = escape_code + "0m";

  style = {
    bold = escape_code + "1m";
    italic = escape_code + "3m";
    underline = escape_code + "4m";
    reverse = escape_code + "7m";
    striked = escape_code + "9m";
    double_underline = escape_code + "21m";
  };

  text_contrast = {r, g, b, ...}: let
    redlum = builtins.div (r*1000) 1944;
    greenlum = builtins.div (g*1000) 1504;
    bluelum = builtins.div (b*1000) 11000;
    luminance = redlum + greenlum + bluelum;
  in if luminance > 115 then basic.black else basic.white;
}
