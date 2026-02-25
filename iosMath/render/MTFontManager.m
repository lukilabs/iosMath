//
//  MTFontManager.m
//  iosMath
//
//  Created by Kostub Deshmukh on 8/30/13.
//  Copyright (C) 2013 MathChat
//   
//  This software may be modified and distributed under the terms of the
//  MIT license. See the LICENSE file for details.
//

#import "MTFontManager.h"
#import "MTFont+Internal.h"

const int kDefaultFontSize = 20;

@interface MTFontManager ()

@property (nonatomic, nonnull) NSMutableDictionary<NSString*, MTFont*>* nameToFontMap;

@end

@implementation MTFontManager

+ (instancetype) fontManager
{
    static MTFontManager* manager = nil;
    static dispatch_once_t managerToken;
    dispatch_once(&managerToken, ^{
        manager = [MTFontManager new];
    });
    return manager;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.nameToFontMap = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (MTFont *)fontWithName:(NSString *)name size:(CGFloat)size
{
    MTFont* f = self.nameToFontMap[name];
    if (!f) {
        f = [[MTFont alloc] initFontWithName:name size:size];
        self.nameToFontMap[name] = f;
    }
    if (f.fontSize == size) {
        return f;
    } else {
        return [f copyFontWithSize:size];
    }
}

/// Returns a raw font (no fallbacks) for internal use in building fallback chains.
- (MTFont *)rawFontWithName:(NSString *)name size:(CGFloat)size
{
    // Load without caching to avoid circular fallback setup
    return [[MTFont alloc] initFontWithName:name size:size];
}

- (MTFont *)latinModernFontWithSize:(CGFloat)size
{
    MTFont *font = [self fontWithName:@"latinmodern-math" size:size];
    if (!font.fallbackFonts) {
        font.fallbackFonts = @[
            [self rawFontWithName:@"xits-math" size:size],
            [self rawFontWithName:@"texgyretermes-math" size:size]
        ];
    }
    return font;
}

- (MTFont *)xitsFontWithSize:(CGFloat)size
{
    MTFont *font = [self fontWithName:@"xits-math" size:size];
    if (!font.fallbackFonts) {
        font.fallbackFonts = @[
            [self rawFontWithName:@"latinmodern-math" size:size],
            [self rawFontWithName:@"texgyretermes-math" size:size]
        ];
    }
    return font;
}

- (MTFont *)termesFontWithSize:(CGFloat)size
{
    MTFont *font = [self fontWithName:@"texgyretermes-math" size:size];
    if (!font.fallbackFonts) {
        font.fallbackFonts = @[
            [self rawFontWithName:@"latinmodern-math" size:size],
            [self rawFontWithName:@"xits-math" size:size]
        ];
    }
    return font;
}

- (MTFont *)defaultFont
{
    return [self latinModernFontWithSize:kDefaultFontSize];
}

@end
