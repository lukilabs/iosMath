//
//  MTFont.m
//  iosMath
//
//  Created by Kostub Deshmukh on 5/18/16.
//
//  This software may be modified and distributed under the terms of the
//  MIT license. See the LICENSE file for details.
//

#import "MTFont.h"
#import "MTFont+Internal.h"

@interface MTFont ()

@property (nonatomic) CGFontRef defaultCGFont;
@property (nonatomic) CTFontRef ctFont;
@property (nonatomic) MTFontMathTable* mathTable;
@property (nonatomic) NSDictionary* rawMathTable;
@property (nonatomic, nullable) NSArray<MTFont *> *fallbackFonts;

@end

@implementation MTFont

- (instancetype)initFontWithName:(NSString *)name size:(CGFloat)size
{
    self = [super init];
    if (self ) {
        // CTFontCreateWithName does not load the complete math font, it only has about half the glyphs of the full math font.
        // In particular it does not have the math italic characters which breaks our variable rendering.
        // So we first load a CGFont from the file and then convert it to a CTFont.

        NSBundle* bundle = [MTFont fontBundle];
        NSString* fontPath = [bundle pathForResource:name ofType:@"otf"];
        CGDataProviderRef fontDataProvider = CGDataProviderCreateWithFilename(fontPath.UTF8String);
        _defaultCGFont = CGFontCreateWithDataProvider(fontDataProvider);
        CFRelease(fontDataProvider);

        _ctFont = CTFontCreateWithGraphicsFont(self.defaultCGFont, size, nil, nil);

        NSString* mathTablePlist = [bundle pathForResource:name ofType:@"plist"];
        NSDictionary* dict = [NSDictionary dictionaryWithContentsOfFile:mathTablePlist];
        self.rawMathTable = dict;
        self.mathTable = [[MTFontMathTable alloc] initWithFont:self mathTable:_rawMathTable];
    }
    return self;
}

+ (NSBundle*) fontBundle
{
#ifdef SWIFTPM_MODULE_BUNDLE
    return SWIFTPM_MODULE_BUNDLE;
#endif
    // Uses bundle for class so that this can be access by the unit tests.
    return [NSBundle bundleWithURL:[[NSBundle bundleForClass:[self class]] URLForResource:@"mathFonts" withExtension:@"bundle"]];
}

- (MTFont *)copyFontWithSize:(CGFloat)size
{
    MTFont* copyFont = [[[self class] alloc] init];
    copyFont.defaultCGFont = self.defaultCGFont;
    // Retain the shared CGFont since dealloc will release it
    CGFontRetain(copyFont.defaultCGFont);
    CTFontRef newCtFont = CTFontCreateWithGraphicsFont(self.defaultCGFont, size, nil, nil);
    copyFont.ctFont = newCtFont;
    copyFont.rawMathTable = self.rawMathTable;
    copyFont.mathTable = [[MTFontMathTable alloc] initWithFont:copyFont mathTable:copyFont.rawMathTable];
    CFRelease(newCtFont);
    // Propagate fallback fonts at the new size
    if (self.fallbackFonts) {
        NSMutableArray<MTFont *> *resizedFallbacks = [NSMutableArray arrayWithCapacity:self.fallbackFonts.count];
        for (MTFont *fb in self.fallbackFonts) {
            [resizedFallbacks addObject:[fb copyFontWithSize:size]];
        }
        copyFont.fallbackFonts = resizedFallbacks;
    }
    return copyFont;
}

-(NSString*) getGlyphName:(CGGlyph) glyph
{
    NSString* name = CFBridgingRelease(CGFontCopyGlyphNameForGlyph(self.defaultCGFont, glyph));
    return name;
}

- (CGGlyph)getGlyphWithName:(NSString *)glyphName
{
    return CGFontGetGlyphWithGlyphName(self.defaultCGFont, (__bridge CFStringRef) glyphName);
}

- (CGFloat)fontSize
{
    return CTFontGetSize(self.ctFont);
}

- (void)dealloc
{
    CGFontRelease(self.defaultCGFont);
    CFRelease(self.ctFont);
}
@end
