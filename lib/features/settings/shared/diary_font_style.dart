import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum DiaryFontStyle { fraunces, literata, instrument }

extension DiaryFontStyleDetails on DiaryFontStyle {
  String get label => switch (this) {
    DiaryFontStyle.fraunces => 'Default',
    DiaryFontStyle.literata => 'Fancy',
    DiaryFontStyle.instrument => 'Instrument',
  };

  String get description => switch (this) {
    DiaryFontStyle.fraunces => 'Elegant and comfortable',
    DiaryFontStyle.literata => 'Expressive and personal',
    DiaryFontStyle.instrument => 'Classic and literary',
  };

  String get storageValue => name;

  static DiaryFontStyle fromStorage(String? value) {
    return DiaryFontStyle.values.firstWhere(
      (font) => font.storageValue == value,
      orElse: () => DiaryFontStyle.fraunces,
    );
  }

  TextStyle titleStyle(TextStyle? baseStyle) {
    return switch (this) {
      DiaryFontStyle.fraunces => GoogleFonts.fraunces(textStyle: baseStyle),
      DiaryFontStyle.literata => GoogleFonts.literata(
        textStyle: baseStyle,
        fontStyle: FontStyle.italic,
      ),
      DiaryFontStyle.instrument => GoogleFonts.instrumentSerif(
        textStyle: baseStyle,
      ),
    };
  }

  TextStyle bodyStyle(TextStyle? baseStyle) {
    return switch (this) {
      DiaryFontStyle.fraunces => GoogleFonts.geist(textStyle: baseStyle),
      DiaryFontStyle.literata => GoogleFonts.comicNeue(textStyle: baseStyle),
      DiaryFontStyle.instrument => GoogleFonts.geist(textStyle: baseStyle),
    };
  }
}
