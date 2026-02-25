//
//  MathUILabel.m
//  iosMath
//
//  Created by Kostub Deshmukh on 8/26/13.
//  Copyright (C) 2013 MathChat
//
//  This software may be modified and distributed under the terms of the
//  MIT license. See the LICENSE file for details.
//

#import "MTMathUILabel.h"
#import "MTMathListDisplay.h"
#import "MTFontManager.h"
#import "MTMathListBuilder.h"
#import "MTTypesetter.h"

@implementation MTMathUILabel {
    MTLabel* _errorLabel;
    BOOL _needsTypesetting;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self initCommon];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self initCommon];
    }
    return self;
}

- (void) initCommon
{
    self.layer.geometryFlipped = YES;  // For ease of interaction with the CoreText coordinate system.
    _needsTypesetting = YES;
    // default font size
    _fontSize = 20;
    _contentInsets = MTEdgeInsetsZero;
    _labelMode = kMTMathUILabelModeDisplay;
    MTFont* font = [MTFontManager fontManager].defaultFont;
    self.font = font;
    _textAlignment = kMTTextAlignmentLeft;
    _displayList = nil;
    _displayErrorInline = true;
    self.backgroundColor = [MTColor clearColor];
    
    _textColor = [MTColor blackColor];
    _errorLabel = [[MTLabel alloc] init];
    _errorLabel.hidden = YES;
    _errorLabel.layer.geometryFlipped = YES;
    _errorLabel.textColor = [MTColor redColor];
    [self addSubview:_errorLabel];
}

#if !TARGET_OS_IPHONE
- (void)setNeedsLayout
{
    [self setNeedsLayout:YES];
}

- (void)setNeedsDisplay
{
    [self setNeedsDisplay:YES];
}

- (BOOL)isFlipped
{
    return NO;
}
#endif

- (void) _invalidateTypesetting
{
    _needsTypesetting = YES;
    _displayList = nil;
    [self invalidateIntrinsicContentSize];
    [self setNeedsLayout];
}

- (void) _ensureDisplayList
{
    if (!_needsTypesetting) {
        return;
    }
    if (_mathList) {
        _displayList = [MTTypesetter createLineForMathList:_mathList font:_font style:self.currentStyle];
        _displayList.textColor = _textColor;
    } else {
        _displayList = nil;
    }
    _needsTypesetting = NO;
}

- (void)setFont:(MTFont*)font
{
    NSParameterAssert(font);
    _font = font;
    [self _invalidateTypesetting];
}

- (void)setFontSize:(CGFloat)fontSize
{
    _fontSize = fontSize;
    MTFont* font = [_font copyFontWithSize:_fontSize];
    self.font = font;
}

- (void)setContentInsets:(MTEdgeInsets)contentInsets
{
    _contentInsets = contentInsets;
    // Content insets don't affect the display list, only positioning/sizing.
    [self invalidateIntrinsicContentSize];
    [self setNeedsLayout];
}

- (void) setMathList:(MTMathList *)mathList
{
    _mathList = mathList;
    _error = nil;
    _latex = [MTMathListBuilder mathListToString:mathList];
    [self _invalidateTypesetting];
}

- (void)setLatex:(NSString *)latex
{
    _latex = latex;
    _error = nil;
    NSError* error = nil;
    _mathList = [MTMathListBuilder buildFromString:latex error:&error];
    if (error) {
        _mathList = nil;
        _error = error;
        _errorLabel.text = error.localizedDescription;
        _errorLabel.frame = self.bounds;
        _errorLabel.hidden = !self.displayErrorInline;
    } else {
        _errorLabel.hidden = YES;
    }
    [self _invalidateTypesetting];
}

- (void)setLabelMode:(MTMathUILabelMode)labelMode
{
    _labelMode = labelMode;
    [self _invalidateTypesetting];
}

- (void)setTextColor:(MTColor *)textColor
{
    NSParameterAssert(textColor);
    _textColor = textColor;
    _displayList.textColor = textColor;
    [self setNeedsDisplay];
}

- (void)setTextAlignment:(MTTextAlignment)textAlignment
{
    _textAlignment = textAlignment;
    // Alignment doesn't affect the display list, only positioning.
    [self invalidateIntrinsicContentSize];
    [self setNeedsLayout];
}

- (MTLineStyle) currentStyle
{
    switch (_labelMode) {
        case kMTMathUILabelModeDisplay:
            return kMTLineStyleDisplay;
        case kMTMathUILabelModeText:
            return kMTLineStyleText;
    }
}

// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(MTRect)rect
{
    [super drawRect:rect];
    
    if (!_mathList) {
        return;
    }
    
    // Drawing code
    CGContextRef context = MTGraphicsGetCurrentContext();
    CGContextSaveGState(context);
    
    [_displayList draw:context];
    
    CGContextRestoreGState(context);
}

- (void) layoutSubviews
{
    [self _ensureDisplayList];
    if (_displayList) {
        // Determine x position based on alignment
        CGFloat textX = 0;
        switch (self.textAlignment) {
            case kMTTextAlignmentLeft:
                textX = self.contentInsets.left;
                break;
            case kMTTextAlignmentCenter:
                textX = (self.bounds.size.width - self.contentInsets.left - self.contentInsets.right - _displayList.width) / 2 + self.contentInsets.left;
                break;
            case kMTTextAlignmentRight:
                textX = (self.bounds.size.width - _displayList.width - self.contentInsets.right);
                break;
        }

        CGFloat availableHeight = self.bounds.size.height - self.contentInsets.bottom - self.contentInsets.top;
        // center things vertically
        CGFloat ascent = _usesVisualBounds ? _displayList.visualAscent : _displayList.ascent;
        CGFloat descent = _usesVisualBounds ? _displayList.visualDescent : _displayList.descent;
        CGFloat height = ascent + descent;
        if (height < _fontSize/2) {
            // Set the height to the half the size of the font
            height = _fontSize/2;
        }
        CGFloat textY = (availableHeight - height) / 2 + descent + self.contentInsets.bottom;
        _displayList.position = CGPointMake(textX, textY);
    }
    _errorLabel.frame = self.bounds;
    [self setNeedsDisplay];
}

#if !TARGET_OS_IPHONE
- (void)layout
{
    [self layoutSubviews];
    [super layout];
}
#endif

- (CGSize) sizeThatFits:(CGSize)size
{
    [self _ensureDisplayList];

    CGFloat ascent = _usesVisualBounds ? _displayList.visualAscent : _displayList.ascent;
    CGFloat descent = _usesVisualBounds ? _displayList.visualDescent : _displayList.descent;
    size.width = _displayList.width + self.contentInsets.left + self.contentInsets.right;
    size.height = ascent + descent + self.contentInsets.top + self.contentInsets.bottom;
    return size;
}

- (CGSize) intrinsicContentSize
{
    return [self sizeThatFits:CGSizeZero];
}

@end
