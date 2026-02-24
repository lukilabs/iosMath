//
//  MTMathListBuilder.m
//  iosMath
//
//  Created by Kostub Deshmukh on 8/28/13.
//  Copyright (C) 2013 MathChat
//   
//  This software may be modified and distributed under the terms of the
//  MIT license. See the LICENSE file for details.
//

#import "MTMathListBuilder.h"
#import "MTMathAtomFactory.h"

NSString *const MTParseError = @"ParseError";

@interface MTEnvProperties : NSObject

@property (nonatomic, readonly) NSString* envName;
@property (nonatomic) BOOL ended;
@property (nonatomic) NSInteger numRows;

@end

@implementation MTEnvProperties

- (instancetype)initWithName:(NSString*) name
{
    self = [super init];
    if (self) {
        _envName = name;
        _numRows = 0;
        _ended = NO;
    }
    return self;
}

@end

/// Stores a user-defined macro definition.
@interface MTMacroDefinition : NSObject
@property (nonatomic) NSString* expansion;
@property (nonatomic) NSUInteger numParameters;
@end

@implementation MTMacroDefinition
@end

@implementation MTMathListBuilder {
    unichar* _chars;
    int _currentChar;
    NSUInteger _length;
    MTInner* _currentInnerAtom;
    MTEnvProperties* _currentEnv;
    MTFontStyle _currentFontStyle;
    BOOL _spacesAllowed;
    NSMutableDictionary<NSString*, MTMacroDefinition*>* _macros;
    NSUInteger _expansionDepth;
}

- (instancetype)initWithString:(NSString *)str
{
    self = [super init];
    if (self) {
        _error = nil;
        _chars = malloc(sizeof(unichar)*str.length);
        _length = str.length;
        [str getCharacters:_chars range:NSMakeRange(0, str.length)];
        _currentChar = 0;
        _currentFontStyle = kMTFontStyleDefault;
        _macros = [NSMutableDictionary dictionary];
        _expansionDepth = 0;
        [self setupBuiltinMacros];
    }
    return self;
}

- (void)dealloc
{
    free(_chars);
}

- (BOOL) hasCharacters
{
    return _currentChar < _length;
}

// gets the next character and moves the pointer ahead
- (unichar) getNextCharacter
{
    NSAssert([self hasCharacters], @"Retrieving character at index %d beyond length %lu", _currentChar, (unsigned long)_length);
    return _chars[_currentChar++];
}

- (void) unlookCharacter
{
    NSAssert(_currentChar > 0, @"Unlooking when at the first character.");
    _currentChar--;
}

- (MTMathList *)build
{
    MTMathList* list = [self buildInternal:false];
    if ([self hasCharacters] && !_error) {
        // something went wrong most likely braces mismatched
        NSString* errorMessage = [NSString stringWithFormat:@"Mismatched braces: %@", [NSString stringWithCharacters:_chars length:_length]];
        [self setError:MTParseErrorMismatchBraces message:errorMessage];
    }
    if (_error) {
        return nil;
    }
    return list;
}

- (MTMathList*) buildInternal:(BOOL) oneCharOnly
{
    return [self buildInternal:oneCharOnly stopChar:0];
}

- (MTMathList*)buildInternal:(BOOL) oneCharOnly stopChar:(unichar) stop
{
    MTMathList* list = [MTMathList new];
    NSAssert(!(oneCharOnly && (stop > 0)), @"Cannot set both oneCharOnly and stopChar.");
    MTMathAtom* prevAtom = nil;
    while([self hasCharacters]) {
        if (_error) {
            // If there is an error thus far then bail out.
            return nil;
        }
        MTMathAtom* atom = nil;
        unichar ch = [self getNextCharacter];
        if (oneCharOnly) {
            if (ch == '^' || ch == '}' || ch == '_' || ch == '&') {
                // this is not the character we are looking for.
                // They are meant for the caller to look at.
                [self unlookCharacter];
                return list;
            }
        }
        // If there is a stop character, keep scanning till we find it
        if (stop > 0 && ch == stop) {
            return list;
        }
        
        if (ch == '^') {
            NSAssert(!oneCharOnly, @"This should have been handled before");
            
            if (!prevAtom || prevAtom.superScript || !prevAtom.scriptsAllowed) {
                // If there is no previous atom, or if it already has a superscript
                // or if scripts are not allowed for it, then add an empty node.
                prevAtom = [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@""];
                [list addAtom:prevAtom];
            }
            // this is a superscript for the previous atom
            // note: if the next char is the stopChar it will be consumed by the ^ and so it doesn't count as stop
            prevAtom.superScript = [self buildInternal:true];
            continue;
        } else if (ch == '_') {
            NSAssert(!oneCharOnly, @"This should have been handled before");
            
            if (!prevAtom || prevAtom.subScript || !prevAtom.scriptsAllowed) {
                // If there is no previous atom, or if it already has a subcript
                // or if scripts are not allowed for it, then add an empty node.
                prevAtom = [MTMathAtom atomWithType:kMTMathAtomOrdinary value:@""];
                [list addAtom:prevAtom];
            }
            // this is a subscript for the previous atom
            // note: if the next char is the stopChar it will be consumed by the _ and so it doesn't count as stop
            prevAtom.subScript = [self buildInternal:true];
            continue;
        } else if (ch == '{') {
            // this puts us in a recursive routine, and sets oneCharOnly to false and no stop character
            MTMathList* sublist = [self buildInternal:false stopChar:'}'];
            prevAtom = [sublist.atoms lastObject];
            [list append:sublist];
            if (oneCharOnly) {
                return list;
            }
            continue;
        } else if (ch == '}') {
            NSAssert(!oneCharOnly, @"This should have been handled before");
            NSAssert(stop == 0, @"This should have been handled before");
            // We encountered a closing brace when there is no stop set, that means there was no
            // corresponding opening brace.
            NSString* errorMessage = @"Mismatched braces.";
            [self setError:MTParseErrorMismatchBraces message:errorMessage];
            return nil;
        } else if (ch == '\\') {
            // \ means a command
            NSString* command = [self readCommand];
            MTMathList* done = [self stopCommand:command list:list stopChar:stop];
            if (done) {
                return done;
            } else if (_error) {
                return nil;
            }
            if ([self applyModifier:command atom:prevAtom]) {
                continue;
            }
            MTFontStyle fontStyle = [MTMathAtomFactory fontStyleWithName:command];
            if (fontStyle != NSNotFound) {
                BOOL oldSpacesAllowed = _spacesAllowed;
                // Text has special consideration where it allows spaces without escaping.
                _spacesAllowed = [command isEqualToString:@"text"];
                MTFontStyle oldFontStyle = _currentFontStyle;
                _currentFontStyle = fontStyle;
                MTMathList* sublist = [self buildInternal:true];
                // Restore the font style.
                _currentFontStyle = oldFontStyle;
                _spacesAllowed = oldSpacesAllowed;

                prevAtom = [sublist.atoms lastObject];
                [list append:sublist];
                if (oneCharOnly) {
                    return list;
                }
                continue;
            }
            atom = [self atomForCommand:command];
            if (atom == nil) {
                // this was an unknown command,
                // we flag an error and return
                // (note setError will not set the error if there is already one, so we flag internal error
                // in the odd case that an _error is not set.
                [self setError:MTParseErrorInternalError message:@"Internal error"];
                return nil;
            }
        } else if (ch == '&') {
            // used for column separation in tables
            NSAssert(!oneCharOnly, @"This should have been handled before");
            if (_currentEnv) {
                return list;
            } else {
                // Create a new table with the current list and a default env
                MTMathAtom* table = [self buildTable:nil firstList:list row:NO];
                return [MTMathList mathListWithAtoms:table, nil];
            }
        } else if (_spacesAllowed && ch == ' ') {
            // If spaces are allowed then spaces do not need escaping with a \ before being used.
            atom = [MTMathAtomFactory atomForLatexSymbolName:@" "];
        } else {
            atom = [MTMathAtomFactory atomForCharacter:ch];
            if (!atom) {
                // Not a recognized character
                continue;
            }
        }
        NSAssert(atom != nil, @"Atom shouldn't be nil");
        atom.fontStyle = _currentFontStyle;
        [list addAtom:atom];
        prevAtom = atom;
        
        if (oneCharOnly) {
            // we consumed our onechar
            return list;
        }
    }
    if (stop > 0) {
        if (stop == '}') {
            // We did not find a corresponding closing brace.
            [self setError:MTParseErrorMismatchBraces message:@"Missing closing brace"];
        } else {
            // we never found our stop character
            NSString* errorMessage = [NSString stringWithFormat:@"Expected character not found: %d", stop];
            [self setError:MTParseErrorCharacterNotFound message:errorMessage];
        }
    }
    return list;
}

- (NSString*) readString
{
    // a string of all upper and lower case characters.
    NSMutableString* mutable = [NSMutableString string];
    while([self hasCharacters]) {
        unichar ch = [self getNextCharacter];
        if ((ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z')) {
            [mutable appendString:[NSString stringWithCharacters:&ch length:1]];
        } else {
            // we went too far
            [self unlookCharacter];
            break;
        }
    }
    return mutable;
}

- (NSString*) readColor
{
    if (![self expectCharacter:'{']) {
        // We didn't find an opening brace, so no env found.
        [self setError:MTParseErrorCharacterNotFound message:@"Missing {"];
        return nil;
    }
    
    // Ignore spaces and nonascii.
    [self skipSpaces];

    // a string of all upper and lower case characters.
    NSMutableString* mutable = [NSMutableString string];
    while([self hasCharacters]) {
        unichar ch = [self getNextCharacter];
        if (ch == '#' || (ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z') || (ch >= '0' && ch <= '9')) {
            [mutable appendString:[NSString stringWithCharacters:&ch length:1]];
        } else {
            // we went too far
            [self unlookCharacter];
            break;
        }
    }

    if (![self expectCharacter:'}']) {
        // We didn't find an closing brace, so invalid format.
        [self setError:MTParseErrorCharacterNotFound message:@"Missing }"];
        return nil;
    }
    return mutable;
}

- (NSString*) readOperatorName
{
    if (![self expectCharacter:'{']) {
        return nil;
    }
    NSMutableString* name = [NSMutableString string];
    while ([self hasCharacters]) {
        unichar ch = [self getNextCharacter];
        if (ch == '}') {
            break;
        }
        // Allow letters, digits, and spaces in operator names (e.g. "lim sup")
        [name appendString:[NSString stringWithCharacters:&ch length:1]];
    }
    if (name.length == 0) {
        return nil;
    }
    return name;
}

- (void) skipSpaces
{
    while ([self hasCharacters]) {
        unichar ch = [self getNextCharacter];
        if (ch < 0x21 || ch > 0x7E) {
            // skip non ascii characters and spaces
            continue;
        } else {
            [self unlookCharacter];
            return;
        }
    }
}

#define MTAssertNotSpace(ch) NSAssert((ch) >= 0x21 && (ch) <= 0x7E, @"Expected non space character %c", (ch));

- (BOOL) expectCharacter:(unichar) ch
{
    MTAssertNotSpace(ch);
    [self skipSpaces];
    
    if ([self hasCharacters]) {
        unichar c = [self getNextCharacter];
        MTAssertNotSpace(c);
        if (c == ch) {
            return YES;
        } else {
            [self unlookCharacter];
            return NO;
        }
    }
    return NO;
}

- (NSString*) readCommand
{
    static NSSet<NSNumber*>* singleCharCommands = nil;
    if (!singleCharCommands) {
        NSArray* singleChars = @[ @'{', @'}', @'$', @'#', @'%', @'_', @'|', @' ', @',', @'>', @';', @'!', @'\\' ];
        singleCharCommands = [[NSSet alloc] initWithArray:singleChars];
    }
    if ([self hasCharacters]) {
        // Check if we have a single character command.
        unichar ch = [self getNextCharacter];
        // Single char commands
        if ([singleCharCommands containsObject:@(ch)]) {
            return [NSString stringWithCharacters:&ch length:1];
        } else {
            // not a known single character command
            [self unlookCharacter];
        }
    }
    // otherwise a command is a string of all upper and lower case characters.
    return [self readString];
}

- (NSString*) readDelimiter
{
    // Ignore spaces and nonascii.
    [self skipSpaces];
    while([self hasCharacters]) {
        unichar ch = [self getNextCharacter];
        MTAssertNotSpace(ch);
        if (ch == '\\') {
            // \ means a command
            NSString* command = [self readCommand];
            if ([command isEqualToString:@"|"]) {
                // | is a command and also a regular delimiter. We use the || command to
                // distinguish between the 2 cases for the caller.
                return @"||";
            }
            return command;
        } else {
            return [NSString stringWithCharacters:&ch length:1];
        }
    }
    // We ran out of characters for delimiter
    return nil;
}

- (NSString*) readEnvironment
{
    if (![self expectCharacter:'{']) {
        // We didn't find an opening brace, so no env found.
        [self setError:MTParseErrorCharacterNotFound message:@"Missing {"];
        return nil;
    }
    
    // Ignore spaces and nonascii.
    [self skipSpaces];
    NSString* env = [self readString];
    // Accept trailing * for starred environments (e.g. align*)
    if ([self hasCharacters]) {
        unichar next = [self getNextCharacter];
        if (next == '*') {
            env = [env stringByAppendingString:@"*"];
        } else {
            [self unlookCharacter];
        }
    }

    if (![self expectCharacter:'}']) {
        // We didn't find an closing brace, so invalid format.
        [self setError:MTParseErrorCharacterNotFound message:@"Missing }"];
        return nil;
    }
    return env;
}

- (MTMathAtom*) getBoundaryAtom:(NSString*) delimiterType
{
    NSString* delim = [self readDelimiter];
    if (!delim) {
        NSString* errorMessage = [NSString stringWithFormat:@"Missing delimiter for \\%@", delimiterType];
        [self setError:MTParseErrorMissingDelimiter message:errorMessage];
        return nil;
    }
    MTMathAtom* boundary = [MTMathAtomFactory boundaryAtomForDelimiterName:delim];
    if (!boundary) {
        NSString* errorMessage = [NSString stringWithFormat:@"Invalid delimiter for \\%@: %@", delimiterType, delim];
        [self setError:MTParseErrorInvalidDelimiter message:errorMessage];
        return nil;
    }
    return boundary;
}

- (MTMathAtom*) atomForCommand:(NSString*) command
{
    MTMathAtom* atom = [MTMathAtomFactory atomForLatexSymbolName:command];
    if (atom) {
        return atom;
    }
    MTAccent* accent = [MTMathAtomFactory accentWithName:command];
    if (accent) {
        // The command is an accent
        accent.innerList = [self buildInternal:true];
        return accent;
    } else if ([command isEqualToString:@"frac"]) {
        // A fraction command has 2 arguments
        MTFraction* frac = [MTFraction new];
        frac.numerator = [self buildInternal:true];
        frac.denominator = [self buildInternal:true];
        return frac;
    } else if ([command isEqualToString:@"binom"]) {
        // A binom command has 2 arguments
        MTFraction* frac = [[MTFraction alloc] initWithRule:NO];
        frac.numerator = [self buildInternal:true];
        frac.denominator = [self buildInternal:true];
        frac.leftDelimiter = @"(";
        frac.rightDelimiter = @")";
        return frac;
    } else if ([command isEqualToString:@"sqrt"]) {
        // A sqrt command with one argument
        MTRadical* rad = [MTRadical new];
        unichar ch = [self getNextCharacter];
        if (ch == '[') {
            // special handling for sqrt[degree]{radicand}
            rad.degree = [self buildInternal:false stopChar:']'];
            rad.radicand = [self buildInternal:true];
        } else {
            [self unlookCharacter];
            rad.radicand = [self buildInternal:true];
        }
        return rad;
    } else if ([command isEqualToString:@"left"]) {
        // Save the current inner while a new one gets built.
        MTInner* oldInner = _currentInnerAtom;
        _currentInnerAtom = [MTInner new];
        _currentInnerAtom.leftBoundary = [self getBoundaryAtom:@"left"];
        if (!_currentInnerAtom.leftBoundary) {
            return nil;
        }
        _currentInnerAtom.innerList = [self buildInternal:false];
        if (!_currentInnerAtom.rightBoundary) {
            // A right node would have set the right boundary so we must be missing the right node.
            NSString* errorMessage = @"Missing \\right";
            [self setError:MTParseErrorMissingRight message:errorMessage];
            return nil;
        }
        // reinstate the old inner atom.
        MTInner* newInner = _currentInnerAtom;
        _currentInnerAtom = oldInner;
        return newInner;
    } else if ([command isEqualToString:@"overline"]) {
        // The overline command has 1 arguments
        MTOverLine* over = [MTOverLine new];
        over.innerList = [self buildInternal:true];
        return over;
    } else if ([command isEqualToString:@"underline"]) {
        // The underline command has 1 arguments
        MTUnderLine* under = [MTUnderLine new];
        under.innerList = [self buildInternal:true];
        return under;
    } else if ([command isEqualToString:@"begin"]) {
        NSString* env = [self readEnvironment];
        if (!env) {
            return nil;
        }
        // For array environment, read column specifier {lcr|...}
        NSArray<NSNumber*>* columnAlignments = nil;
        NSArray<NSNumber*>* verticalLinePositions = nil;
        if ([env isEqualToString:@"array"]) {
            [self readArrayColumnSpec:&columnAlignments verticalLines:&verticalLinePositions];
        }
        MTMathAtom* table = [self buildTable:env firstList:nil row:NO];
        // Apply column spec to array table
        if ([env isEqualToString:@"array"] && table && [table isKindOfClass:[MTMathTable class]]) {
            MTMathTable* mathTable = (MTMathTable*)table;
            if (columnAlignments) {
                for (NSInteger i = 0; i < columnAlignments.count; i++) {
                    [mathTable setAlignment:(MTColumnAlignment)[columnAlignments[i] integerValue] forColumn:i];
                }
            }
            if (verticalLinePositions) {
                for (NSNumber* pos in verticalLinePositions) {
                    [mathTable addVerticalLineAtColumn:pos.integerValue];
                }
            }
        }
        return table;
    } else if ([command isEqualToString:@"color"]) {
        // A color command has 2 arguments
        MTMathColor* mathColor = [[MTMathColor alloc] init];
        mathColor.colorString = [self readColor];
        mathColor.innerList = [self buildInternal:true];
        return mathColor;
    } else if ([command isEqualToString:@"phantom"]) {
        MTPhantom* phantom = [[MTPhantom alloc] initWithPhantomType:kMTPhantomFull];
        phantom.innerList = [self buildInternal:true];
        return phantom;
    } else if ([command isEqualToString:@"hphantom"]) {
        MTPhantom* phantom = [[MTPhantom alloc] initWithPhantomType:kMTPhantomHorizontal];
        phantom.innerList = [self buildInternal:true];
        return phantom;
    } else if ([command isEqualToString:@"vphantom"]) {
        MTPhantom* phantom = [[MTPhantom alloc] initWithPhantomType:kMTPhantomVertical];
        phantom.innerList = [self buildInternal:true];
        return phantom;
    } else if ([command isEqualToString:@"smash"]) {
        // Check for optional [t] or [b] argument
        MTPhantomType smashType = kMTPhantomSmashBoth;
        if ([self hasCharacters]) {
            unichar next = [self getNextCharacter];
            if (next == '[') {
                // Read the option
                if ([self hasCharacters]) {
                    unichar option = [self getNextCharacter];
                    if (option == 't') {
                        smashType = kMTPhantomSmashTop;
                    } else if (option == 'b') {
                        smashType = kMTPhantomSmashBottom;
                    }
                    // Skip the closing ]
                    if ([self hasCharacters]) {
                        unichar closing = [self getNextCharacter];
                        if (closing != ']') {
                            [self unlookCharacter];
                        }
                    }
                }
            } else {
                [self unlookCharacter];
            }
        }
        MTPhantom* phantom = [[MTPhantom alloc] initWithPhantomType:smashType];
        phantom.innerList = [self buildInternal:true];
        return phantom;
    } else if ([command isEqualToString:@"boxed"] || [command isEqualToString:@"fbox"]) {
        MTBoxed* boxed = [[MTBoxed alloc] init];
        boxed.innerList = [self buildInternal:true];
        return boxed;
    } else if ([command isEqualToString:@"cancel"]) {
        MTCancel* cancel = [[MTCancel alloc] initWithCancelType:kMTCancelForward];
        cancel.innerList = [self buildInternal:true];
        return cancel;
    } else if ([command isEqualToString:@"bcancel"]) {
        MTCancel* cancel = [[MTCancel alloc] initWithCancelType:kMTCancelBackward];
        cancel.innerList = [self buildInternal:true];
        return cancel;
    } else if ([command isEqualToString:@"xcancel"]) {
        MTCancel* cancel = [[MTCancel alloc] initWithCancelType:kMTCancelCross];
        cancel.innerList = [self buildInternal:true];
        return cancel;
    } else if ([command isEqualToString:@"sout"]) {
        MTCancel* cancel = [[MTCancel alloc] initWithCancelType:kMTCancelStrikethrough];
        cancel.innerList = [self buildInternal:true];
        return cancel;
    } else if ([command isEqualToString:@"colorbox"]) {
        // \colorbox{color}{content} — parse color, create boxed (approximate)
        NSString* color = [self readColor];
        (void)color;  // Color rendering deferred — renders as boxed for now
        MTBoxed* boxed = [[MTBoxed alloc] init];
        boxed.innerList = [self buildInternal:true];
        return boxed;
    } else if ([command isEqualToString:@"fcolorbox"]) {
        // \fcolorbox{bordercolor}{bgcolor}{content} — parse both colors, create boxed
        NSString* borderColor = [self readColor];
        NSString* bgColor = [self readColor];
        (void)borderColor;
        (void)bgColor;
        MTBoxed* boxed = [[MTBoxed alloc] init];
        boxed.innerList = [self buildInternal:true];
        return boxed;
    } else if ([command isEqualToString:@"rlap"]) {
        MTPhantom* phantom = [[MTPhantom alloc] initWithPhantomType:kMTPhantomLapRight];
        phantom.innerList = [self buildInternal:true];
        return phantom;
    } else if ([command isEqualToString:@"llap"]) {
        MTPhantom* phantom = [[MTPhantom alloc] initWithPhantomType:kMTPhantomLapLeft];
        phantom.innerList = [self buildInternal:true];
        return phantom;
    } else if ([command isEqualToString:@"clap"]) {
        MTPhantom* phantom = [[MTPhantom alloc] initWithPhantomType:kMTPhantomLapCenter];
        phantom.innerList = [self buildInternal:true];
        return phantom;
    } else if ([command isEqualToString:@"overset"] || [command isEqualToString:@"stackrel"]) {
        // \overset{top}{base} and \stackrel{top}{base}
        MTMathList* top = [self buildInternal:true];
        MTMathList* base = [self buildInternal:true];
        MTInner* inner = [MTInner new];
        inner.innerList = base;
        inner.superScript = top;
        inner.limits = YES;
        return inner;
    } else if ([command isEqualToString:@"underset"]) {
        // \underset{bottom}{base}
        MTMathList* bottom = [self buildInternal:true];
        MTMathList* base = [self buildInternal:true];
        MTInner* inner = [MTInner new];
        inner.innerList = base;
        inner.subScript = bottom;
        inner.limits = YES;
        return inner;
    } else if ([command isEqualToString:@"dfrac"]) {
        MTFraction* frac = [MTFraction new];
        MTMathList* num = [self buildInternal:true];
        [num insertAtom:[[MTMathStyle alloc] initWithStyle:kMTLineStyleDisplay] atIndex:0];
        frac.numerator = num;
        MTMathList* denom = [self buildInternal:true];
        [denom insertAtom:[[MTMathStyle alloc] initWithStyle:kMTLineStyleDisplay] atIndex:0];
        frac.denominator = denom;
        return frac;
    } else if ([command isEqualToString:@"tfrac"]) {
        MTFraction* frac = [MTFraction new];
        MTMathList* num = [self buildInternal:true];
        [num insertAtom:[[MTMathStyle alloc] initWithStyle:kMTLineStyleText] atIndex:0];
        frac.numerator = num;
        MTMathList* denom = [self buildInternal:true];
        [denom insertAtom:[[MTMathStyle alloc] initWithStyle:kMTLineStyleText] atIndex:0];
        frac.denominator = denom;
        return frac;
    } else if ([command isEqualToString:@"cfrac"]) {
        // Continued fraction — display style, centered numerator
        MTFraction* frac = [MTFraction new];
        MTMathList* num = [self buildInternal:true];
        [num insertAtom:[[MTMathStyle alloc] initWithStyle:kMTLineStyleDisplay] atIndex:0];
        frac.numerator = num;
        MTMathList* denom = [self buildInternal:true];
        [denom insertAtom:[[MTMathStyle alloc] initWithStyle:kMTLineStyleDisplay] atIndex:0];
        frac.denominator = denom;
        return frac;
    } else if ([command isEqualToString:@"dbinom"]) {
        MTFraction* frac = [[MTFraction alloc] initWithRule:NO];
        MTMathList* num = [self buildInternal:true];
        [num insertAtom:[[MTMathStyle alloc] initWithStyle:kMTLineStyleDisplay] atIndex:0];
        frac.numerator = num;
        MTMathList* denom = [self buildInternal:true];
        [denom insertAtom:[[MTMathStyle alloc] initWithStyle:kMTLineStyleDisplay] atIndex:0];
        frac.denominator = denom;
        frac.leftDelimiter = @"(";
        frac.rightDelimiter = @")";
        return frac;
    } else if ([command isEqualToString:@"tbinom"]) {
        MTFraction* frac = [[MTFraction alloc] initWithRule:NO];
        MTMathList* num = [self buildInternal:true];
        [num insertAtom:[[MTMathStyle alloc] initWithStyle:kMTLineStyleText] atIndex:0];
        frac.numerator = num;
        MTMathList* denom = [self buildInternal:true];
        [denom insertAtom:[[MTMathStyle alloc] initWithStyle:kMTLineStyleText] atIndex:0];
        frac.denominator = denom;
        frac.leftDelimiter = @"(";
        frac.rightDelimiter = @")";
        return frac;
    } else if ([command isEqualToString:@"tiny"] || [command isEqualToString:@"scriptsize"]) {
        return [[MTMathStyle alloc] initWithStyle:kMTLineStyleScriptScript];
    } else if ([command isEqualToString:@"footnotesize"] || [command isEqualToString:@"small"]) {
        return [[MTMathStyle alloc] initWithStyle:kMTLineStyleScript];
    } else if ([command isEqualToString:@"normalsize"]) {
        return [[MTMathStyle alloc] initWithStyle:kMTLineStyleText];
    } else if ([command isEqualToString:@"large"] || [command isEqualToString:@"Large"]) {
        return [[MTMathStyle alloc] initWithStyle:kMTLineStyleText];
    } else if ([command isEqualToString:@"LARGE"] || [command isEqualToString:@"huge"] || [command isEqualToString:@"Huge"]) {
        return [[MTMathStyle alloc] initWithStyle:kMTLineStyleDisplay];
    } else if ([command isEqualToString:@"big"] || [command isEqualToString:@"Big"]
               || [command isEqualToString:@"bigg"] || [command isEqualToString:@"Bigg"]) {
        // \big — ordinary delimiter (no l/r/m distinction)
        NSString* delim = [self readDelimiter];
        if (!delim) {
            NSString* errorMessage = [NSString stringWithFormat:@"Missing delimiter for \\%@", command];
            [self setError:MTParseErrorMissingDelimiter message:errorMessage];
            return nil;
        }
        MTMathAtom* atom = [MTMathAtomFactory atomForLatexSymbolName:delim];
        if (!atom) {
            // Try as a boundary delimiter
            atom = [MTMathAtomFactory boundaryAtomForDelimiterName:delim];
            if (atom) {
                atom = [MTMathAtom atomWithType:kMTMathAtomOrdinary value:atom.nucleus];
            }
        }
        if (!atom) {
            atom = [MTMathAtom atomWithType:kMTMathAtomOrdinary value:delim];
        }
        return atom;
    } else if ([command isEqualToString:@"bigl"] || [command isEqualToString:@"Bigl"]
               || [command isEqualToString:@"biggl"] || [command isEqualToString:@"Biggl"]) {
        NSString* delim = [self readDelimiter];
        if (!delim) {
            NSString* errorMessage = [NSString stringWithFormat:@"Missing delimiter for \\%@", command];
            [self setError:MTParseErrorMissingDelimiter message:errorMessage];
            return nil;
        }
        MTMathAtom* boundary = [MTMathAtomFactory boundaryAtomForDelimiterName:delim];
        NSString* nucleus = boundary ? boundary.nucleus : delim;
        return [MTMathAtom atomWithType:kMTMathAtomOpen value:nucleus];
    } else if ([command isEqualToString:@"bigr"] || [command isEqualToString:@"Bigr"]
               || [command isEqualToString:@"biggr"] || [command isEqualToString:@"Biggr"]) {
        NSString* delim = [self readDelimiter];
        if (!delim) {
            NSString* errorMessage = [NSString stringWithFormat:@"Missing delimiter for \\%@", command];
            [self setError:MTParseErrorMissingDelimiter message:errorMessage];
            return nil;
        }
        MTMathAtom* boundary = [MTMathAtomFactory boundaryAtomForDelimiterName:delim];
        NSString* nucleus = boundary ? boundary.nucleus : delim;
        return [MTMathAtom atomWithType:kMTMathAtomClose value:nucleus];
    } else if ([command isEqualToString:@"bigm"] || [command isEqualToString:@"Bigm"]
               || [command isEqualToString:@"biggm"] || [command isEqualToString:@"Biggm"]) {
        NSString* delim = [self readDelimiter];
        if (!delim) {
            NSString* errorMessage = [NSString stringWithFormat:@"Missing delimiter for \\%@", command];
            [self setError:MTParseErrorMissingDelimiter message:errorMessage];
            return nil;
        }
        MTMathAtom* boundary = [MTMathAtomFactory boundaryAtomForDelimiterName:delim];
        NSString* nucleus = boundary ? boundary.nucleus : delim;
        return [MTMathAtom atomWithType:kMTMathAtomRelation value:nucleus];
    } else if ([command hasPrefix:@"x"] && [self isExtensibleArrowCommand:command]) {
        return [self buildExtensibleArrow:command];
    } else if ([command isEqualToString:@"operatorname"] || [command isEqualToString:@"operatorname*"]) {
        BOOL limits = [command isEqualToString:@"operatorname*"];
        // If the * variant wasn't matched as a single command, check for trailing *
        if (!limits && [self hasCharacters]) {
            unichar next = [self getNextCharacter];
            if (next == '*') {
                limits = YES;
            } else {
                [self unlookCharacter];
            }
        }
        NSString* operatorName = [self readOperatorName];
        if (!operatorName) {
            NSString* errorMessage = @"Missing argument for \\operatorname";
            [self setError:MTParseErrorCharacterNotFound message:errorMessage];
            return nil;
        }
        return [MTMathAtomFactory operatorWithName:operatorName limits:limits];
    } else if ([command isEqualToString:@"tag"]) {
        // Check for \tag* variant (star is not part of the command name)
        if ([self hasCharacters]) {
            unichar next = [self getNextCharacter];
            if (next != '*') {
                [self unlookCharacter];
            }
        }
        return [self parseTagCommand];
    } else if ([command isEqualToString:@"notag"]) {
        // No-op — iosMath has no auto-numbering
        return [[MTMathSpace alloc] initWithSpace:0];
    } else if ([command isEqualToString:@"def"] || [command isEqualToString:@"gdef"]) {
        return [self parseDefCommand];
    } else if ([command isEqualToString:@"newcommand"] || [command isEqualToString:@"renewcommand"]
               || [command isEqualToString:@"providecommand"]) {
        return [self parseNewcommand:command];
    } else if ([command isEqualToString:@"let"]) {
        return [self parseLetCommand];
    } else {
        // Check user-defined macros before reporting error
        MTMathAtom* expanded = [self expandMacro:command];
        if (expanded) {
            return expanded;
        }
        NSString* errorMessage = [NSString stringWithFormat:@"Invalid command \\%@", command];
        [self setError:MTParseErrorInvalidCommand message:errorMessage];
        return nil;
    }
}

- (MTMathList*) stopCommand:(NSString*) command list:(MTMathList*) list stopChar:(unichar) stopChar
{
    static NSDictionary<NSString*, NSArray*>* fractionCommands = nil;
    if (!fractionCommands) {
        fractionCommands = @{ @"over" : @[],
                              @"atop" : @[],
                              @"choose" : @[ @"(", @")"],
                              @"brack" : @[ @"[", @"]"],
                              @"brace" : @[ @"{", @"}"]};
    }
    if ([command isEqualToString:@"right"]) {
        if (!_currentInnerAtom) {
            NSString* errorMessage = @"Missing \\left";
            [self setError:MTParseErrorMissingLeft message:errorMessage];
            return nil;
        }
        _currentInnerAtom.rightBoundary = [self getBoundaryAtom:@"right"];
        if (!_currentInnerAtom.rightBoundary) {
            return nil;
        }
        // return the list read so far.
        return list;
    } else if ([fractionCommands objectForKey:command]) {
        MTFraction* frac = nil;
        if ([command isEqualToString:@"over"]) {
            frac = [[MTFraction alloc] init];
        } else {
            frac = [[MTFraction alloc] initWithRule:NO];
        }
        NSArray* delims = [fractionCommands objectForKey:command];
        if (delims.count == 2) {
            frac.leftDelimiter = delims[0];
            frac.rightDelimiter = delims[1];
        }
        frac.numerator = list;
        frac.denominator = [self buildInternal:NO stopChar:stopChar];
        if (_error) {
            return nil;
        }
        MTMathList* fracList = [MTMathList new];
        [fracList addAtom:frac];
        return fracList;
    } else if ([command isEqualToString:@"\\"] || [command isEqualToString:@"cr"]) {
        if (_currentEnv) {
            // Stop the current list and increment the row count
            _currentEnv.numRows++;
            return list;
        } else {
            // Create a new table with the current list and a default env
            MTMathAtom* table = [self buildTable:nil firstList:list row:YES];
            return [MTMathList mathListWithAtoms:table, nil];
        }
    } else if ([command isEqualToString:@"end"]) {
        if (!_currentEnv) {
            NSString* errorMessage = @"Missing \\begin";
            [self setError:MTParseErrorMissingBegin message:errorMessage];
            return nil;
        }
        NSString* env = [self readEnvironment];
        if (!env) {
            return nil;
        }
        if (![env isEqualToString:_currentEnv.envName])
        {
            NSString* errorMessage = [NSString stringWithFormat:@"Begin environment name %@ does not match end name: %@", _currentEnv.envName, env];
            [self setError:MTParseErrorInvalidEnv message:errorMessage];
            return nil;
        }
        // Finish the current environment.
        _currentEnv.ended = YES;
        return list;
    }
    return nil;
}

// Applies the modifier to the atom. Returns true if modifier applied.
- (BOOL) applyModifier:(NSString*) modifier atom:(MTMathAtom*) atom
{
    if ([modifier isEqualToString:@"limits"]) {
        if (atom.type != kMTMathAtomLargeOperator) {
            NSString* errorMessage = [NSString stringWithFormat:@"limits can only be applied to an operator."];
            [self setError:MTParseErrorInvalidLimits message:errorMessage];
        } else {
            MTLargeOperator* op = (MTLargeOperator*) atom;
            op.limits = YES;
        }
        return true;
    } else if ([modifier isEqualToString:@"nolimits"]) {
        if (atom.type != kMTMathAtomLargeOperator) {
            NSString* errorMessage = [NSString stringWithFormat:@"nolimits can only be applied to an operator."];
            [self setError:MTParseErrorInvalidLimits message:errorMessage];
            return YES;
        } else {
            MTLargeOperator* op = (MTLargeOperator*) atom;
            op.limits = NO;
        }
        return true;
    }
    return false;
}

#pragma mark - Tag

/// Parse \tag{text} — renders as right-spaced parenthesized text: \qquad\text{(text)}
- (MTMathAtom*) parseTagCommand
{
    NSString* tagText = [self readRawBraceGroup];
    if (!tagText) return nil;

    // Build the tag as: \qquad\text{(tagText)}
    NSString* expansion = [NSString stringWithFormat:@"\\qquad\\text{(%@)}", tagText];
    MTMathListBuilder* subBuilder = [[MTMathListBuilder alloc] initWithString:expansion];
    subBuilder->_macros = _macros;
    subBuilder->_expansionDepth = _expansionDepth;
    MTMathList* result = [subBuilder build];

    if (subBuilder.error) {
        if (!_error) _error = subBuilder.error;
        return nil;
    }
    if (!result || result.atoms.count == 0) {
        return [[MTMathSpace alloc] initWithSpace:0];
    }
    if (result.atoms.count == 1) {
        return result.atoms[0];
    }
    MTInner* inner = [MTInner new];
    inner.innerList = result;
    return inner;
}

#pragma mark - Built-in Macros

- (void)defineMacro:(NSString*)name params:(NSUInteger)n expansion:(NSString*)exp
{
    MTMacroDefinition* m = [[MTMacroDefinition alloc] init];
    m.expansion = exp;
    m.numParameters = n;
    _macros[name] = m;
}

- (void)setupBuiltinMacros
{
    // Braket notation
    [self defineMacro:@"bra" params:1 expansion:@"\\langle #1 |"];
    [self defineMacro:@"ket" params:1 expansion:@"| #1 \\rangle"];
    [self defineMacro:@"braket" params:1 expansion:@"\\langle #1 \\rangle"];
    [self defineMacro:@"Bra" params:1 expansion:@"\\left\\langle #1 \\right|"];
    [self defineMacro:@"Ket" params:1 expansion:@"\\left| #1 \\right\\rangle"];
    [self defineMacro:@"Set" params:1 expansion:@"\\left\\{ #1 \\right\\}"];

    // Physics package
    [self defineMacro:@"abs" params:1 expansion:@"\\left| #1 \\right|"];
    [self defineMacro:@"norm" params:1 expansion:@"\\left\\| #1 \\right\\|"];
    [self defineMacro:@"qty" params:1 expansion:@"\\left( #1 \\right)"];
    [self defineMacro:@"dd" params:1 expansion:@"\\mathrm{d}#1"];
    [self defineMacro:@"dv" params:2 expansion:@"\\frac{\\mathrm{d}#1}{\\mathrm{d}#2}"];
    [self defineMacro:@"pdv" params:2 expansion:@"\\frac{\\partial #1}{\\partial #2}"];
    [self defineMacro:@"grad" params:0 expansion:@"\\nabla"];
    [self defineMacro:@"curl" params:0 expansion:@"\\nabla \\times"];
    [self defineMacro:@"divergence" params:0 expansion:@"\\nabla \\cdot"];
    [self defineMacro:@"cross" params:0 expansion:@"\\times"];
    [self defineMacro:@"vb" params:1 expansion:@"\\mathbf{#1}"];
    [self defineMacro:@"vu" params:1 expansion:@"\\hat{\\mathbf{#1}}"];

    // mathtools symbols (composite approximations)
    [self defineMacro:@"coloneqq" params:0 expansion:@":\\!\\!="];
    [self defineMacro:@"Coloneqq" params:0 expansion:@"::\\!\\!="];
    [self defineMacro:@"eqqcolon" params:0 expansion:@"=\\!\\!:"];
    [self defineMacro:@"colonapprox" params:0 expansion:@":\\!\\!\\approx"];
    [self defineMacro:@"dblcolon" params:0 expansion:@":\\!\\!:"];

    // Proof trees (simple approximation using fraction bar)
    [self defineMacro:@"infer" params:2 expansion:@"\\dfrac{#2}{#1}"];
}

#pragma mark - Macro System

/// Read the raw text of a brace-delimited group (without parsing it as math).
/// Returns the text between { and }, not including the braces.
- (NSString*) readRawBraceGroup
{
    [self skipSpaces];
    if (![self hasCharacters]) return nil;

    unichar ch = [self getNextCharacter];
    if (ch != '{') {
        [self unlookCharacter];
        [self setError:MTParseErrorCharacterNotFound message:@"Missing {"];
        return nil;
    }

    NSMutableString* result = [NSMutableString string];
    NSInteger braceDepth = 1;
    while ([self hasCharacters] && braceDepth > 0) {
        ch = [self getNextCharacter];
        if (ch == '{') {
            braceDepth++;
            [result appendString:@"{"];
        } else if (ch == '}') {
            braceDepth--;
            if (braceDepth > 0) {
                [result appendString:@"}"];
            }
        } else {
            [result appendString:[NSString stringWithCharacters:&ch length:1]];
        }
    }
    if (braceDepth != 0) {
        [self setError:MTParseErrorMismatchBraces message:@"Missing }"];
        return nil;
    }
    return result;
}

/// Parse \def\commandname#1#2{expansion}
- (MTMathAtom*) parseDefCommand
{
    [self skipSpaces];
    // Read the command name being defined: \commandname
    if (![self hasCharacters]) {
        [self setError:MTParseErrorInvalidCommand message:@"Missing command name after \\def"];
        return nil;
    }
    unichar ch = [self getNextCharacter];
    if (ch != '\\') {
        [self setError:MTParseErrorInvalidCommand message:@"\\def must be followed by a command (\\name)"];
        return nil;
    }
    NSString* name = [self readCommand];
    if (!name) {
        [self setError:MTParseErrorInvalidCommand message:@"Missing command name after \\def\\"];
        return nil;
    }

    // Count parameter tokens: #1, #2, etc.
    NSUInteger numParams = 0;
    while ([self hasCharacters]) {
        ch = [self getNextCharacter];
        if (ch == '#') {
            if ([self hasCharacters]) {
                unichar digit = [self getNextCharacter];
                if (digit >= '1' && digit <= '9') {
                    NSUInteger paramNum = digit - '0';
                    numParams = MAX(numParams, paramNum);
                }
            }
        } else if (ch == '{') {
            // Start of the expansion body — unlook so readRawBraceGroup can handle it
            [self unlookCharacter];
            break;
        } else {
            // Ignore other pattern chars
        }
    }

    // Read the expansion body
    NSString* expansion = [self readRawBraceGroup];
    if (!expansion) return nil;

    MTMacroDefinition* macro = [[MTMacroDefinition alloc] init];
    macro.expansion = expansion;
    macro.numParameters = numParams;
    _macros[name] = macro;

    // Return a zero-width space so the parse loop has something non-nil
    return [[MTMathSpace alloc] initWithSpace:0];
}

/// Parse \newcommand{\name}[numParams]{expansion}
- (MTMathAtom*) parseNewcommand:(NSString*) variant
{
    [self skipSpaces];
    // Read command name: {\name} or \name
    NSString* name = nil;
    if ([self hasCharacters]) {
        unichar ch = [self getNextCharacter];
        if (ch == '{') {
            // Read \name inside braces
            if ([self hasCharacters]) {
                ch = [self getNextCharacter];
                if (ch == '\\') {
                    name = [self readCommand];
                }
            }
            if (![self expectCharacter:'}']) {
                [self setError:MTParseErrorCharacterNotFound message:@"Missing } after command name"];
                return nil;
            }
        } else if (ch == '\\') {
            name = [self readCommand];
        } else {
            [self unlookCharacter];
        }
    }
    if (!name) {
        [self setError:MTParseErrorInvalidCommand message:[NSString stringWithFormat:@"Missing command name for \\%@", variant]];
        return nil;
    }

    // providecommand: skip if already defined (as built-in or macro)
    if ([variant isEqualToString:@"providecommand"]) {
        if ([_macros objectForKey:name] ||
            [MTMathAtomFactory atomForLatexSymbolName:name]) {
            // Command already exists — skip the rest (read and discard)
            [self skipSpaces];
            if ([self hasCharacters]) {
                unichar ch = [self getNextCharacter];
                if (ch == '[') {
                    // Skip optional parameter count
                    while ([self hasCharacters]) {
                        if ([self getNextCharacter] == ']') break;
                    }
                } else {
                    [self unlookCharacter];
                }
            }
            (void)[self readRawBraceGroup];  // Discard expansion body
            return [[MTMathSpace alloc] initWithSpace:0];
        }
    }

    // Read optional [numParams]
    NSUInteger numParams = 0;
    [self skipSpaces];
    if ([self hasCharacters]) {
        unichar ch = [self getNextCharacter];
        if (ch == '[') {
            NSMutableString* numStr = [NSMutableString string];
            while ([self hasCharacters]) {
                ch = [self getNextCharacter];
                if (ch == ']') break;
                [numStr appendString:[NSString stringWithCharacters:&ch length:1]];
            }
            numParams = (NSUInteger)[numStr integerValue];
        } else {
            [self unlookCharacter];
        }
    }

    // Read {expansion}
    NSString* expansion = [self readRawBraceGroup];
    if (!expansion) return nil;

    MTMacroDefinition* macro = [[MTMacroDefinition alloc] init];
    macro.expansion = expansion;
    macro.numParameters = numParams;
    _macros[name] = macro;

    return [[MTMathSpace alloc] initWithSpace:0];
}

/// Parse \let\alias=\original or \let\alias\original
- (MTMathAtom*) parseLetCommand
{
    [self skipSpaces];
    if (![self hasCharacters]) {
        [self setError:MTParseErrorInvalidCommand message:@"Missing command after \\let"];
        return nil;
    }

    // Read the alias: \alias
    unichar ch = [self getNextCharacter];
    if (ch != '\\') {
        [self setError:MTParseErrorInvalidCommand message:@"\\let must be followed by a command"];
        return nil;
    }
    NSString* alias = [self readCommand];

    // Skip optional =
    [self skipSpaces];
    if ([self hasCharacters]) {
        ch = [self getNextCharacter];
        if (ch != '=') {
            [self unlookCharacter];
        }
    }

    // Read the original: \original
    [self skipSpaces];
    if (![self hasCharacters]) {
        [self setError:MTParseErrorInvalidCommand message:@"Missing command after \\let\\alias"];
        return nil;
    }
    ch = [self getNextCharacter];
    if (ch != '\\') {
        [self setError:MTParseErrorInvalidCommand message:@"\\let alias must reference a command"];
        return nil;
    }
    NSString* original = [self readCommand];

    // Create a macro that simply expands to the original command
    MTMacroDefinition* macro = [[MTMacroDefinition alloc] init];
    macro.expansion = [NSString stringWithFormat:@"\\%@", original];
    macro.numParameters = 0;
    _macros[alias] = macro;

    return [[MTMathSpace alloc] initWithSpace:0];
}

/// Attempt to expand a user-defined macro. Returns nil if no macro with this name exists.
- (MTMathAtom*) expandMacro:(NSString*) name
{
    MTMacroDefinition* macro = _macros[name];
    if (!macro) return nil;

    // Check expansion depth
    static const NSUInteger kMaxExpansionDepth = 1000;
    if (_expansionDepth >= kMaxExpansionDepth) {
        [self setError:MTParseErrorInvalidCommand message:@"Maximum macro expansion depth exceeded"];
        return nil;
    }
    _expansionDepth++;

    // Read arguments from the current stream
    NSMutableArray<NSString*>* args = [NSMutableArray array];
    for (NSUInteger i = 0; i < macro.numParameters; i++) {
        NSString* arg = [self readRawBraceGroup];
        if (!arg) {
            _expansionDepth--;
            return nil;
        }
        [args addObject:arg];
    }

    // Perform parameter substitution: #1 → arg[0], #2 → arg[1], etc.
    NSString* expanded = macro.expansion;
    for (NSUInteger i = 0; i < args.count; i++) {
        NSString* placeholder = [NSString stringWithFormat:@"#%lu", (unsigned long)(i + 1)];
        expanded = [expanded stringByReplacingOccurrencesOfString:placeholder withString:args[i]];
    }

    // Parse the expanded string using a new builder that shares our macros
    MTMathListBuilder* subBuilder = [[MTMathListBuilder alloc] initWithString:expanded];
    subBuilder->_macros = _macros;
    subBuilder->_expansionDepth = _expansionDepth;
    MTMathList* result = [subBuilder build];
    _expansionDepth--;

    if (subBuilder.error) {
        if (!_error) _error = subBuilder.error;
        return nil;
    }
    if (!result || result.atoms.count == 0) {
        return [[MTMathSpace alloc] initWithSpace:0];
    }

    // Wrap multiple atoms in an MTInner so we return a single atom
    if (result.atoms.count == 1) {
        return result.atoms[0];
    }
    MTInner* inner = [MTInner new];
    inner.innerList = result;
    return inner;
}

- (void) readArrayColumnSpec:(NSArray<NSNumber*>**)alignments verticalLines:(NSArray<NSNumber*>**)vLines
{
    [self skipSpaces];
    if (![self hasCharacters]) return;

    unichar next = [self getNextCharacter];
    if (next != '{') {
        [self unlookCharacter];
        return;
    }

    NSMutableArray<NSNumber*>* aligns = [NSMutableArray array];
    NSMutableArray<NSNumber*>* lines = [NSMutableArray array];
    NSInteger colIndex = 0;

    while ([self hasCharacters]) {
        unichar ch = [self getNextCharacter];
        if (ch == '}') break;
        if (ch == 'l') {
            [aligns addObject:@(kMTColumnAlignmentLeft)];
            colIndex++;
        } else if (ch == 'c') {
            [aligns addObject:@(kMTColumnAlignmentCenter)];
            colIndex++;
        } else if (ch == 'r') {
            [aligns addObject:@(kMTColumnAlignmentRight)];
            colIndex++;
        } else if (ch == '|') {
            [lines addObject:@(colIndex)];
        }
        // Ignore other characters (spaces, etc.)
    }

    if (alignments) *alignments = aligns;
    if (vLines) *vLines = lines;
}

- (BOOL) isExtensibleArrowCommand:(NSString*) command
{
    static NSSet* arrowCommands = nil;
    if (!arrowCommands) {
        arrowCommands = [NSSet setWithArray:@[
            @"xrightarrow", @"xleftarrow", @"xleftrightarrow",
            @"xRightarrow", @"xLeftarrow", @"xLeftrightarrow",
            @"xhookrightarrow", @"xhookleftarrow", @"xmapsto",
            @"xlongequal", @"xtwoheadrightarrow", @"xtwoheadleftarrow",
            @"xrightharpoonup", @"xrightharpoondown",
            @"xleftharpoonup", @"xleftharpoondown",
        ]];
    }
    return [arrowCommands containsObject:command];
}

- (MTMathAtom*) buildExtensibleArrow:(NSString*) command
{
    static NSDictionary<NSString*, NSNumber*>* arrowTypes = nil;
    if (!arrowTypes) {
        arrowTypes = @{
            @"xrightarrow" : @(kMTExtensibleArrowRight),
            @"xleftarrow" : @(kMTExtensibleArrowLeft),
            @"xleftrightarrow" : @(kMTExtensibleArrowLeftRight),
            @"xRightarrow" : @(kMTExtensibleArrowDoubleRight),
            @"xLeftarrow" : @(kMTExtensibleArrowDoubleLeft),
            @"xLeftrightarrow" : @(kMTExtensibleArrowDoubleLeftRight),
            @"xhookrightarrow" : @(kMTExtensibleArrowHookRight),
            @"xhookleftarrow" : @(kMTExtensibleArrowHookLeft),
            @"xmapsto" : @(kMTExtensibleArrowMapsTo),
            @"xlongequal" : @(kMTExtensibleArrowLongEqual),
            @"xtwoheadrightarrow" : @(kMTExtensibleArrowTwoHeadRight),
            @"xtwoheadleftarrow" : @(kMTExtensibleArrowTwoHeadLeft),
            @"xrightharpoonup" : @(kMTExtensibleArrowRightHarpoonUp),
            @"xrightharpoondown" : @(kMTExtensibleArrowRightHarpoonDown),
            @"xleftharpoonup" : @(kMTExtensibleArrowLeftHarpoonUp),
            @"xleftharpoondown" : @(kMTExtensibleArrowLeftHarpoonDown),
        };
    }
    MTExtensibleArrowType arrowType = (MTExtensibleArrowType)[arrowTypes[command] unsignedIntegerValue];
    MTExtensibleArrow* arrow = [[MTExtensibleArrow alloc] initWithArrowType:arrowType];

    // Read optional [below] argument
    if ([self hasCharacters]) {
        unichar next = [self getNextCharacter];
        if (next == '[') {
            arrow.belowList = [self buildInternal:NO stopChar:']'];
        } else {
            [self unlookCharacter];
        }
    }

    // Read required {above} argument
    arrow.aboveList = [self buildInternal:true];
    return arrow;
}

- (void) setError:(MTParseErrors) code message:(NSString*) message
{
    // Only record the first error.
    if (!_error) {
        _error = [NSError errorWithDomain:MTParseError code:code userInfo:@{ NSLocalizedDescriptionKey : message }];
    }
}

- (MTMathAtom*) buildTable:(NSString*) env firstList:(MTMathList*) firstList row:(BOOL) isRow
{
    // Save the current env till an new one gets built.
    MTEnvProperties* oldEnv = _currentEnv;
    _currentEnv = [[MTEnvProperties alloc] initWithName:env];
    NSInteger currentRow = 0;
    NSInteger currentCol = 0; // Current Col is actually the next one...
    NSMutableArray<NSMutableArray<MTMathList*>*>* rows = [NSMutableArray array];
    rows[0] = [NSMutableArray array];
    if (firstList) {
        rows[currentRow][currentCol] = firstList;
        if (isRow) {
            _currentEnv.numRows++;
            currentRow++;
            rows[currentRow] = [NSMutableArray array];
        } else {
            currentCol++;
        }
    }
    while (!_currentEnv.ended && [self hasCharacters]) {
        MTMathList* list = [self buildInternal:NO];
        if (!list) {
            // If there is an error building the list, bail out early.
            return nil;
        }
        
        NSInteger safeCurrentRow = MIN(currentRow, rows.count - 1);
        NSInteger safeCurrentCol = MIN(currentCol, rows[safeCurrentRow].count);
        if (safeCurrentRow != currentRow) {
            [self setError:MTParseErrorMissingEnd message:@"Row Index out of bounds! Don't do this!"];
            return nil;
        }
        
        if (safeCurrentCol != currentCol) {
            [self setError:MTParseErrorMissingEnd message:@"Col Index out of bounds! Don't do this!"];
            return nil;
        }
        
        rows[currentRow][currentCol] = list;
        currentCol++;
        if (_currentEnv.numRows > currentRow) {
            currentRow = _currentEnv.numRows;
            if (rows.count > currentRow) {
                rows[currentRow] = [NSMutableArray array];
            } else {
                [rows addObject:[NSMutableArray array]];
            }
            currentCol = 0;
        }
    }
    if (!_currentEnv.ended && _currentEnv.envName) {
        [self setError:MTParseErrorMissingEnd message:@"Missing \\end"];
        return nil;
    }
    NSError* error;
    MTMathAtom* table = [MTMathAtomFactory tableWithEnvironment:_currentEnv.envName rows:rows error:&error];
    if (!table && !_error) {
        _error = error;
        return nil;
    }
    // reinstate the old env.
    _currentEnv = oldEnv;
    return table;
}

+ (NSDictionary*) spaceToCommands
{
    static NSDictionary* spaceToCommands = nil;
    if (!spaceToCommands) {
        spaceToCommands = @{
                            @3 : @",",
                            @4 : @">",
                            @5 : @";",
                            @(-3) : @"!",
                            @18 : @"quad",
                            @36 : @"qquad",
                    };
    }
    return spaceToCommands;
}

+ (NSDictionary*) styleToCommands
{
    static NSDictionary* styleToCommands = nil;
    if (!styleToCommands) {
        styleToCommands = @{
                            @(kMTLineStyleDisplay) : @"displaystyle",
                            @(kMTLineStyleText) : @"textstyle",
                            @(kMTLineStyleScript) : @"scriptstyle",
                            @(kMTLineStyleScriptScript) : @"scriptscriptstyle",
                            };
    }
    return styleToCommands;
}

+ (MTMathList *)buildFromString:(NSString *)str
{
    MTMathListBuilder* builder = [[MTMathListBuilder alloc] initWithString:str];
    return builder.build;
}

+ (MTMathList *)buildFromString:(NSString *)str error:(NSError *__autoreleasing *)error
{
    MTMathListBuilder* builder = [[MTMathListBuilder alloc] initWithString:str];
    MTMathList* output = [builder build];
    if (builder.error) {
        if (error) {
            *error = builder.error;
        }
        return nil;
    }
    return output;
}

+ (NSString*) delimToString:(MTMathAtom*) delim
{
    NSString* command = [MTMathAtomFactory delimiterNameForBoundaryAtom:delim];
    if (command) {
        NSArray<NSString*>* singleChars = @[ @"(", @")", @"[", @"]", @"<", @">", @"|", @".", @"/"];
        if ([singleChars containsObject:command]) {
            return command;
        } else if ([command isEqualToString:@"||"]) {
            return @"\\|"; // special case for ||
        } else {
            return [NSString stringWithFormat:@"\\%@", command];
        }
    }
    return @"";
}

+ (NSString *)mathListToString:(MTMathList *)ml
{
    NSMutableString* str = [NSMutableString string];
    MTFontStyle currentfontStyle = kMTFontStyleDefault;
    for (MTMathAtom* atom in ml.atoms) {
        if (currentfontStyle != atom.fontStyle) {
            if (currentfontStyle != kMTFontStyleDefault) {
                // close the previous font style.
                [str appendString:@"}"];
            }
            if (atom.fontStyle != kMTFontStyleDefault) {
                // open new font style
                NSString* fontStyleName = [MTMathAtomFactory fontNameForStyle:atom.fontStyle];
                [str appendFormat:@"\\%@{", fontStyleName];
            }
            currentfontStyle = atom.fontStyle;
        }
        if (atom.type == kMTMathAtomFraction) {
            MTFraction* frac = (MTFraction*) atom;
            if (frac.hasRule) {
                [str appendFormat:@"\\frac{%@}{%@}", [self mathListToString:frac.numerator], [self mathListToString:frac.denominator]];
            } else {
                NSString* command = nil;
                if (!frac.leftDelimiter && !frac.rightDelimiter) {
                    command = @"atop";
                } else if ([frac.leftDelimiter isEqualToString:@"("] && [frac.rightDelimiter isEqualToString:@")"]) {
                    command = @"choose";
                } else if ([frac.leftDelimiter isEqualToString:@"{"] && [frac.rightDelimiter isEqualToString:@"}"]) {
                    command = @"brace";
                } else if ([frac.leftDelimiter isEqualToString:@"["] && [frac.rightDelimiter isEqualToString:@"]"]) {
                    command = @"brack";
                } else {
                    command = [NSString stringWithFormat:@"atopwithdelims%@%@", frac.leftDelimiter, frac.rightDelimiter];
                }
                [str appendFormat:@"{%@ \\%@ %@}", [self mathListToString:frac.numerator], command, [self mathListToString:frac.denominator]];
            }
        } else if (atom.type == kMTMathAtomRadical) {
            [str appendString:@"\\sqrt"];
            MTRadical* rad = (MTRadical*) atom;
            if (rad.degree) {
                [str appendFormat:@"[%@]", [self mathListToString:rad.degree]];
            }
            [str appendFormat:@"{%@}", [self mathListToString:rad.radicand]];
        } else if (atom.type == kMTMathAtomInner) {
            MTInner* inner = (MTInner*) atom;
            if (inner.leftBoundary || inner.rightBoundary) {
                if (inner.leftBoundary) {
                    [str appendFormat:@"\\left%@ ", [self delimToString:inner.leftBoundary]];
                } else {
                    [str appendString:@"\\left. "];
                }
                [str appendString:[self mathListToString:inner.innerList]];
                if (inner.rightBoundary) {
                    [str appendFormat:@"\\right%@ ", [self delimToString:inner.rightBoundary]];
                } else {
                    [str appendString:@"\\right. "];
                }
            } else {
                [str appendFormat:@"{%@}", [self mathListToString:inner.innerList]];
            }
        } else if (atom.type == kMTMathAtomTable) {
            MTMathTable* table = (MTMathTable*) atom;
            if (table.environment) {
                [str appendFormat:@"\\begin{%@}", table.environment];
            }
            for (int i = 0; i < table.numRows; i++) {
                NSArray<MTMathList*>* row = table.cells[i];
                for (int j = 0; j < row.count; j++) {
                    MTMathList* cell = row[j];
                    if ([table.environment isEqualToString:@"matrix"]) {
                        if (cell.atoms.count >= 1 && cell.atoms[0].type == kMTMathAtomStyle) {
                            // remove the first atom.
                            NSArray* atoms = [cell.atoms subarrayWithRange:NSMakeRange(1, cell.atoms.count-1)];
                            cell = [MTMathList mathListWithAtomsArray:atoms];
                        }
                    }
                    if ([table.environment isEqualToString:@"eqalign"] || [table.environment isEqualToString:@"aligned"] || [table.environment isEqualToString:@"split"]) {
                        if (j == 1 && cell.atoms.count >= 1 && cell.atoms[0].type == kMTMathAtomOrdinary && cell.atoms[0].nucleus.length == 0) {
                            // Empty nucleus added for spacing. Remove it.
                            NSArray* atoms = [cell.atoms subarrayWithRange:NSMakeRange(1, cell.atoms.count-1)];
                            cell = [MTMathList mathListWithAtomsArray:atoms];
                        }
                    }
                    [str appendString:[self mathListToString:cell]];
                    if (j < row.count - 1) {
                        [str appendString:@"&"];
                    }
                }
                if (i < table.numRows - 1) {
                    [str appendString:@"\\\\ "];
                }
            }
            if (table.environment) {
                [str appendFormat:@"\\end{%@}", table.environment];
            }
        } else if (atom.type == kMTMathAtomOverline) {
            [str appendString:@"\\overline"];
            MTOverLine* over = (MTOverLine*) atom;
            [str appendFormat:@"{%@}", [self mathListToString:over.innerList]];
        } else if (atom.type == kMTMathAtomUnderline) {
            [str appendString:@"\\underline"];
            MTUnderLine* under = (MTUnderLine*) atom;
            [str appendFormat:@"{%@}", [self mathListToString:under.innerList]];
        } else if (atom.type == kMTMathAtomAccent) {
            MTAccent* accent = (MTAccent*) atom;
            [str appendFormat:@"\\%@{%@}", [MTMathAtomFactory accentName:accent], [self mathListToString:accent.innerList]];
        } else if (atom.type == kMTMathAtomLargeOperator) {
            MTLargeOperator* op = (MTLargeOperator*) atom;
            NSString* command = [MTMathAtomFactory latexSymbolNameForAtom:atom];
            MTLargeOperator* originalOp = (MTLargeOperator*) [MTMathAtomFactory atomForLatexSymbolName:command];
            [str appendFormat:@"\\%@ ", command];
            if (originalOp.limits != op.limits) {
                if (op.limits) {
                    [str appendString:@"\\limits "];
                } else {
                    [str appendString:@"\\nolimits "];
                }
            }
        } else if (atom.type == kMTMathAtomSpace) {
            MTMathSpace* space = (MTMathSpace*) atom;
            NSDictionary* spaceToCommands = [MTMathListBuilder spaceToCommands];
            NSString* command = spaceToCommands[@(space.space)];
            if (command) {
                [str appendFormat:@"\\%@ ", command];
            } else {
                [str appendFormat:@"\\mkern%.1fmu", space.space];
            }
        } else if (atom.type == kMTMathAtomStyle) {
            MTMathStyle* style = (MTMathStyle*) atom;
            NSDictionary* styleToCommands = [MTMathListBuilder styleToCommands];
            NSString* command = styleToCommands[@(style.style)];
            [str appendFormat:@"\\%@ ", command];
        } else if (atom.nucleus.length == 0) {
            [str appendString:@"{}"];
        } else if ([atom.nucleus isEqualToString:@"\u2236"]) {
            // math colon
            [str appendString:@":"];
        } else if ([atom.nucleus isEqualToString:@"\u2212"]) {
            // math minus
            [str appendString:@"-"];
        } else {
            NSString* command = [MTMathAtomFactory latexSymbolNameForAtom:atom];
            if (command) {
                [str appendFormat:@"\\%@ ", command];
            } else {
                [str appendString:atom.nucleus];
            }
        }

        if (atom.superScript) {
            [str appendFormat:@"^{%@}", [self mathListToString:atom.superScript]];
        }
        
        if (atom.subScript) {
            [str appendFormat:@"_{%@}", [self mathListToString:atom.subScript]];
        }
    }
    if (currentfontStyle != kMTFontStyleDefault) {
        [str appendString:@"}"];
    }
    return [str copy];
}

@end
