//
//  MTKaTeXParityTest.m
//  iosMath
//
//  Tests for KaTeX feature parity — ensures new commands parse correctly.
//  Note: Typesetter (font-dependent) tests crash in SPM test runner due to
//  CoreGraphics font loading. Run typesetting tests via Xcode instead.
//

@import XCTest;

#import "MTMathListBuilder.h"
#import "MTMathAtomFactory.h"

@interface MTKaTeXParityTest : XCTestCase
@end

@implementation MTKaTeXParityTest

/// Helper: parse the LaTeX string and return the math list, asserting no error.
- (MTMathList *)parseNoError:(NSString *)latex
{
    NSError *error = nil;
    MTMathList *list = [MTMathListBuilder buildFromString:latex error:&error];
    XCTAssertNil(error, @"Parse error for '%@': %@", latex, error);
    XCTAssertNotNil(list, @"Nil math list for '%@'", latex);
    return list;
}

/// Helper: parse and verify atom count is positive.
- (void)assertParses:(NSString *)latex
{
    MTMathList *list = [self parseNoError:latex];
    XCTAssertTrue(list.atoms.count > 0, @"Empty atom list for '%@'", latex);
}

#pragma mark - Phase 1: Negated Relations

- (void)testNegatedRelations
{
    NSArray *commands = @[
        @"\\nless", @"\\ngtr", @"\\nleq", @"\\ngeq",
        @"\\nprec", @"\\nsucc", @"\\nsim", @"\\ncong",
        @"\\nmid", @"\\nparallel", @"\\nvdash", @"\\nvDash",
        @"\\nVDash", @"\\ntriangleleft", @"\\ntriangleright",
        @"\\ntrianglelefteq", @"\\ntrianglerighteq",
        @"\\nleftrightarrow", @"\\nLeftrightarrow"
    ];
    for (NSString *cmd in commands) {
        NSString *latex = [NSString stringWithFormat:@"a %@ b", cmd];
        [self assertParses:latex];
    }
}

#pragma mark - Phase 1: More Relations

- (void)testMoreRelations
{
    NSArray *commands = @[
        @"\\vdash", @"\\dashv", @"\\vDash", @"\\Vdash", @"\\Vvdash",
        @"\\trianglelefteq", @"\\trianglerighteq", @"\\bowtie", @"\\Join",
        @"\\preceq", @"\\succeq", @"\\lesssim", @"\\gtrsim",
        @"\\lessgtr", @"\\gtrless"
    ];
    for (NSString *cmd in commands) {
        NSString *latex = [NSString stringWithFormat:@"a %@ b", cmd];
        [self assertParses:latex];
    }
}

#pragma mark - Phase 1: Misc Symbols

- (void)testMiscSymbols
{
    NSArray *commands = @[
        @"\\diamondsuit", @"\\heartsuit", @"\\clubsuit", @"\\spadesuit",
        @"\\flat", @"\\natural", @"\\sharp", @"\\maltese",
        @"\\dag", @"\\ddag", @"\\checkmark", @"\\complement",
        @"\\nexists", @"\\eth", @"\\Game", @"\\Finv"
    ];
    for (NSString *cmd in commands) {
        [self assertParses:cmd];
    }
}

#pragma mark - Phase 1: More Arrows

- (void)testMoreArrows
{
    NSArray *commands = @[
        @"\\hookrightarrow", @"\\hookleftarrow",
        @"\\twoheadrightarrow", @"\\twoheadleftarrow",
        @"\\rightharpoonup", @"\\rightharpoondown",
        @"\\leftharpoonup", @"\\leftharpoondown",
        @"\\rightleftharpoons", @"\\leftrightharpoons",
        @"\\curvearrowleft", @"\\curvearrowright",
        @"\\circlearrowleft", @"\\circlearrowright",
        @"\\Lsh", @"\\Rsh",
        @"\\looparrowleft", @"\\looparrowright",
        @"\\multimap"
    ];
    for (NSString *cmd in commands) {
        NSString *latex = [NSString stringWithFormat:@"A %@ B", cmd];
        [self assertParses:latex];
    }
}

#pragma mark - Phase 1: More Binary Operators

- (void)testMoreBinaryOps
{
    NSArray *commands = @[
        @"\\barwedge", @"\\veebar",
        @"\\boxplus", @"\\boxminus", @"\\boxtimes", @"\\boxdot",
        @"\\circleddash", @"\\circledcirc", @"\\circledast",
        @"\\intercal", @"\\divideontimes",
        @"\\ltimes", @"\\rtimes", @"\\Cup", @"\\Cap",
        @"\\smallsetminus", @"\\dotplus",
        @"\\leftthreetimes", @"\\rightthreetimes"
    ];
    for (NSString *cmd in commands) {
        NSString *latex = [NSString stringWithFormat:@"a %@ b", cmd];
        [self assertParses:latex];
    }
}

#pragma mark - Phase 1: Logic Symbols

- (void)testLogicSymbols
{
    [self assertParses:@"\\therefore"];
    [self assertParses:@"\\because"];
    [self assertParses:@"A \\implies B"];
}

#pragma mark - Phase 1: Aliases

- (void)testAliases
{
    [self assertParses:@"A \\implies B"];
    [self assertParses:@"A \\impliedby B"];
    [self assertParses:@"\\varnothing"];
    [self assertParses:@"\\infin"];
    [self assertParses:@"\\isin x"];
    [self assertParses:@"\\empty"];
    [self assertParses:@"A \\sdot B"];
}

#pragma mark - Phase 1: Font Shortcuts

- (void)testFontShortcuts
{
    [self assertParses:@"\\it{x}"];
    [self assertParses:@"\\sf{x}"];
    [self assertParses:@"\\tt{x}"];
    [self assertParses:@"\\Bbb{R}"];
    [self assertParses:@"\\boldsymbol{x}"];
    [self assertParses:@"\\textbf{bold}"];
    [self assertParses:@"\\textit{italic}"];
    [self assertParses:@"\\textrm{roman}"];
    [self assertParses:@"\\textsf{sans}"];
    [self assertParses:@"\\texttt{mono}"];
}

#pragma mark - Phase 1: operatorname

- (void)testOperatorname
{
    [self assertParses:@"\\operatorname{argmax}_{x} f(x)"];
    [self assertParses:@"\\operatorname{tr}(A)"];
    [self assertParses:@"\\operatorname{Hom}(A, B)"];
}

#pragma mark - Phase 1: Additional Large Operators

- (void)testAdditionalLargeOps
{
    [self assertParses:@"\\iint_{D} f(x,y) dA"];
    [self assertParses:@"\\iiint_{V} f dV"];
}

#pragma mark - Representative Complex Formulas (parse only)

- (void)testQuadraticFormula
{
    [self assertParses:@"x = \\frac{-b \\pm \\sqrt{b^2 - 4ac}}{2a}"];
}

- (void)testEulerIdentity
{
    [self assertParses:@"e^{i\\pi} + 1 = 0"];
}

- (void)testSummation
{
    [self assertParses:@"\\sum_{n=1}^{\\infty} \\frac{1}{n^2} = \\frac{\\pi^2}{6}"];
}

- (void)testIntegral
{
    [self assertParses:@"\\int_{0}^{\\infty} e^{-x^2} dx = \\frac{\\sqrt{\\pi}}{2}"];
}

- (void)testMatrix
{
    [self assertParses:@"\\begin{pmatrix} a & b \\\\ c & d \\end{pmatrix}"];
}

- (void)testNestedFractions
{
    [self assertParses:@"\\frac{1}{1+\\frac{1}{1+\\frac{1}{x}}}"];
}

- (void)testBinomialCoefficient
{
    [self assertParses:@"\\binom{n}{k} = \\frac{n!}{k!(n-k)!}"];
}

- (void)testTrigIdentity
{
    [self assertParses:@"\\sin^2\\theta + \\cos^2\\theta = 1"];
}

- (void)testSetTheory
{
    [self assertParses:@"A \\cup (B \\cap C) = (A \\cup B) \\cap (A \\cup C)"];
}

- (void)testLogic
{
    [self assertParses:@"\\forall x \\in \\mathbb{R}, \\exists y : x + y = 0"];
}

- (void)testLimits
{
    [self assertParses:@"\\lim_{x \\to \\infty} \\left(1 + \\frac{1}{x}\\right)^x = e"];
}

- (void)testProductNotation
{
    [self assertParses:@"\\prod_{i=1}^{n} x_i"];
}

- (void)testGreekAlphabet
{
    [self assertParses:@"\\alpha \\beta \\gamma \\delta \\epsilon \\zeta \\eta \\theta"];
    [self assertParses:@"\\Gamma \\Delta \\Theta \\Lambda \\Xi \\Pi \\Sigma \\Phi \\Psi \\Omega"];
}

- (void)testFontStyles
{
    [self assertParses:@"\\mathbb{R} \\mathcal{L} \\mathfrak{g} \\mathsf{ABC} \\mathtt{code}"];
}

- (void)testAccents
{
    [self assertParses:@"\\hat{x} \\bar{y} \\dot{z} \\tilde{w} \\vec{v}"];
}

- (void)testSqrt
{
    [self assertParses:@"\\sqrt[3]{x^3 + y^3}"];
}

#pragma mark - Combined Phase 1 Stress Test

- (void)testAllNewSymbolsInOneExpression
{
    // Verify no conflicts between old and new symbols
    NSString *latex = @"\\nless \\vdash \\heartsuit \\hookrightarrow \\barwedge \\therefore \\iint";
    [self assertParses:latex];
}

#pragma mark - Phase 2: Phantom

- (void)testPhantom
{
    [self assertParses:@"a \\phantom{b} c"];
    // Verify atom type
    MTMathList *list = [self parseNoError:@"\\phantom{x}"];
    XCTAssertTrue(list.atoms.count > 0);
    MTMathAtom *atom = list.atoms[0];
    XCTAssertEqual(atom.type, kMTMathAtomPhantom);
    MTPhantom *phantom = (MTPhantom *)atom;
    XCTAssertEqual(phantom.phantomType, kMTPhantomFull);
    XCTAssertNotNil(phantom.innerList);
}

- (void)testHPhantom
{
    [self assertParses:@"a \\hphantom{b} c"];
    MTMathList *list = [self parseNoError:@"\\hphantom{x}"];
    MTPhantom *phantom = (MTPhantom *)list.atoms[0];
    XCTAssertEqual(phantom.phantomType, kMTPhantomHorizontal);
}

- (void)testVPhantom
{
    [self assertParses:@"a \\vphantom{b} c"];
    MTMathList *list = [self parseNoError:@"\\vphantom{x}"];
    MTPhantom *phantom = (MTPhantom *)list.atoms[0];
    XCTAssertEqual(phantom.phantomType, kMTPhantomVertical);
}

#pragma mark - Phase 2: Smash

- (void)testSmash
{
    [self assertParses:@"\\smash{x^2}"];
    MTMathList *list = [self parseNoError:@"\\smash{x}"];
    MTPhantom *phantom = (MTPhantom *)list.atoms[0];
    XCTAssertEqual(phantom.phantomType, kMTPhantomSmashBoth);
}

- (void)testSmashTop
{
    [self assertParses:@"\\smash[t]{x^2}"];
    MTMathList *list = [self parseNoError:@"\\smash[t]{x}"];
    MTPhantom *phantom = (MTPhantom *)list.atoms[0];
    XCTAssertEqual(phantom.phantomType, kMTPhantomSmashTop);
}

- (void)testSmashBottom
{
    [self assertParses:@"\\smash[b]{x^2}"];
    MTMathList *list = [self parseNoError:@"\\smash[b]{x}"];
    MTPhantom *phantom = (MTPhantom *)list.atoms[0];
    XCTAssertEqual(phantom.phantomType, kMTPhantomSmashBottom);
}

#pragma mark - Phase 2: Boxed

- (void)testBoxed
{
    [self assertParses:@"\\boxed{a + b = c}"];
    MTMathList *list = [self parseNoError:@"\\boxed{x}"];
    XCTAssertTrue(list.atoms.count > 0);
    MTMathAtom *atom = list.atoms[0];
    XCTAssertEqual(atom.type, kMTMathAtomBoxed);
    MTBoxed *boxed = (MTBoxed *)atom;
    XCTAssertNotNil(boxed.innerList);
}

#pragma mark - Phase 2: Size Presets

- (void)testSizePresets
{
    NSArray *commands = @[
        @"\\tiny", @"\\scriptsize", @"\\footnotesize", @"\\small",
        @"\\normalsize", @"\\large", @"\\Large", @"\\LARGE",
        @"\\huge", @"\\Huge"
    ];
    for (NSString *cmd in commands) {
        NSString *latex = [NSString stringWithFormat:@"%@ x", cmd];
        [self assertParses:latex];
    }
}

#pragma mark - Phase 2: Big Delimiters

- (void)testBigDelimiters
{
    [self assertParses:@"\\bigl( x \\bigr)"];
    [self assertParses:@"\\Bigl( x \\Bigr)"];
    [self assertParses:@"\\biggl( x \\biggr)"];
    [self assertParses:@"\\Biggl( x \\Biggr)"];
    [self assertParses:@"\\big( x \\big)"];
    [self assertParses:@"\\bigm| x"];
}

- (void)testBigDelimitersWithNamedDelims
{
    [self assertParses:@"\\bigl\\langle x \\bigr\\rangle"];
    [self assertParses:@"\\bigl\\{ x \\bigr\\}"];
    [self assertParses:@"\\bigl[ x \\bigr]"];
}

#pragma mark - Phase 2: Combined Stress Test

- (void)testPhase2Combined
{
    // Mix phantom, smash, boxed, size, and big delimiters
    NSString *latex = @"\\phantom{a} + \\smash{b^2} + \\boxed{c} + \\Bigl( x \\Bigr)";
    [self assertParses:latex];
}

@end
