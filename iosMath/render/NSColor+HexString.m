//
//  NSColor+HexString.m
//  iosMath
//
//  Created by Markus Sähn on 21/03/2017.
//
//

#import "NSColor+HexString.h"

#if !TARGET_OS_IPHONE
@implementation NSColor (HexString)

+ (NSDictionary<NSString*, NSString*> *)namedColorMap {
    static NSDictionary* map = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        map = @{
            // Standard LaTeX xcolor named colors
            @"red":        @"#FF0000",
            @"green":      @"#00FF00",
            @"blue":       @"#0000FF",
            @"cyan":       @"#00FFFF",
            @"magenta":    @"#FF00FF",
            @"yellow":     @"#FFFF00",
            @"black":      @"#000000",
            @"white":      @"#FFFFFF",
            @"gray":       @"#808080",
            @"darkgray":   @"#404040",
            @"lightgray":  @"#BFBFBF",
            @"brown":      @"#BF8040",
            @"lime":       @"#BFFF00",
            @"olive":      @"#808000",
            @"orange":     @"#FF8000",
            @"pink":       @"#FFB3B3",
            @"purple":     @"#BF0040",
            @"teal":       @"#008080",
            @"violet":     @"#800080",
        };
    });
    return map;
}

+ (NSColor *)colorFromHexString:(NSString *)hexString {
    if (hexString.length == 0) {
        return nil;
    }

    // Resolve named colors to hex
    if ([hexString characterAtIndex:0] != '#') {
        NSString* hex = [self namedColorMap][hexString.lowercaseString];
        if (hex) {
            hexString = hex;
        } else {
            return nil;
        }
    }

    unsigned rgbValue = 0;

    NSScanner *scanner = [NSScanner scannerWithString:hexString];
    [scanner setScanLocation:1];

    [scanner scanHexInt:&rgbValue];
    return [NSColor colorWithRed:((rgbValue & 0xFF0000) >> 16)/255.0 green:((rgbValue & 0xFF00) >> 8)/255.0 blue:(rgbValue & 0xFF)/255.0 alpha:1.0];
}

@end
#endif
