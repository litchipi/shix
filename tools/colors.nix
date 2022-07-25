pkgs: let
  lib = pkgs.lib;
in rec {
  tohex = {r, g, b, ...}: let
    f = x: lib.strings.toLower (lib.strings.fixedWidthString 2 "0" (lib.trivial.toHexString x));
  in
    "${f r}${f g}${f b}";
  
  basic = {
    black = {r=0; g=0; b=0;};
    white = {r=255; g=255; b=255;};
    gray = n: {r=n; g=n; b=n;};
  };

  escape_code = ''\033['';
  ansi = { r, g, b }: with builtins;
    escape_code + ''38;2;${toString r};${toString g};${toString b}m'';
  reset = escape_code + "0m";
  
  style = {
    bold = reset + escape_code + "1m";
    italic = reset + escape_code + "3m";
    underline = reset + escape_code + "4m";
    reverse = reset + escape_code + "7m";
    striked = reset + escape_code + "9m";
    double_underline = reset + escape_code + "21m";
  };

  text_contrast = {r, g, b, ...}: let
    redlum = builtins.div (r*1000) 1944;
    greenlum = builtins.div (g*1000) 1504;
    bluelum = builtins.div (b*1000) 11000;
    luminance = redlum + greenlum + bluelum;
  in if (builtins.trace luminance luminance) > 115 then basic.black else basic.white;
}
