//
//  MTFont+Internal.h
//  iosMath
//
//  Created by Kostub Deshmukh on 5/20/16.
//
//  This software may be modified and distributed under the terms of the
//  MIT license. See the LICENSE file for details.
//

#import "MTFont.h"
#import "MTFontMathTable.h"

/** This category add functions to MTFont that are meant to be internal
 to this library for rendering purposes. */
@interface MTFont (Internal)

/** Load the font with a given name. This is the designated initializer. */
- (nonnull instancetype) initFontWithName:(nonnull NSString*) name size:(CGFloat) size;

/** Access to the raw CTFontRef if needed. */
@property (nonatomic, readonly, nonnull) CTFontRef ctFont;

/** The font math table. */
@property (nonatomic, readonly, nonnull) MTFontMathTable* mathTable;

/** Fallback fonts to try when a glyph is not found in the primary font.
 Set by MTFontManager. Each font is at the same point size. */
@property (nonatomic, nullable) NSArray<MTFont *> *fallbackFonts;

/** Returns the name of the given glyph or null if the glyph
 is not associated with the font. */
- (nullable NSString*) getGlyphName:(CGGlyph) glyph;

/** Returns a glyph associated with the given name. */
- (CGGlyph) getGlyphWithName:(nonnull NSString*) glyphName;

@end
