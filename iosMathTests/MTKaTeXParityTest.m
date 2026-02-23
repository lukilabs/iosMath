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

#pragma mark - Phase 3: Cancel

- (void)testCancel
{
    [self assertParses:@"\\cancel{x}"];
    MTMathList *list = [self parseNoError:@"\\cancel{x}"];
    MTMathAtom *atom = list.atoms[0];
    XCTAssertEqual(atom.type, kMTMathAtomCancel);
    MTCancel *cancel = (MTCancel *)atom;
    XCTAssertEqual(cancel.cancelType, kMTCancelForward);
    XCTAssertNotNil(cancel.innerList);
}

- (void)testBCancel
{
    [self assertParses:@"\\bcancel{x}"];
    MTMathList *list = [self parseNoError:@"\\bcancel{x}"];
    MTCancel *cancel = (MTCancel *)list.atoms[0];
    XCTAssertEqual(cancel.cancelType, kMTCancelBackward);
}

- (void)testXCancel
{
    [self assertParses:@"\\xcancel{x + y}"];
    MTMathList *list = [self parseNoError:@"\\xcancel{x}"];
    MTCancel *cancel = (MTCancel *)list.atoms[0];
    XCTAssertEqual(cancel.cancelType, kMTCancelCross);
}

- (void)testSout
{
    [self assertParses:@"\\sout{old text}"];
    MTMathList *list = [self parseNoError:@"\\sout{x}"];
    MTCancel *cancel = (MTCancel *)list.atoms[0];
    XCTAssertEqual(cancel.cancelType, kMTCancelStrikethrough);
}

#pragma mark - Phase 3: Stacking

- (void)testOverset
{
    [self assertParses:@"\\overset{\\sim}{=}"];
    [self assertParses:@"\\overset{n}{\\rightarrow}"];
}

- (void)testUnderset
{
    [self assertParses:@"\\underset{n \\to \\infty}{\\lim}"];
}

- (void)testStackrel
{
    [self assertParses:@"\\stackrel{?}{=}"];
}

#pragma mark - Phase 3: Arrow and Brace Accents

- (void)testOverArrows
{
    [self assertParses:@"\\overrightarrow{AB}"];
    [self assertParses:@"\\overleftarrow{AB}"];
    [self assertParses:@"\\overleftrightarrow{AB}"];
}

- (void)testOverUnderBrace
{
    [self assertParses:@"\\overbrace{a + b + c}"];
    [self assertParses:@"\\underbrace{x + y}"];
}

#pragma mark - Phase 3: Box Variants

- (void)testFbox
{
    [self assertParses:@"\\fbox{text}"];
    MTMathList *list = [self parseNoError:@"\\fbox{x}"];
    XCTAssertEqual(list.atoms[0].type, kMTMathAtomBoxed);
}

- (void)testColorbox
{
    [self assertParses:@"\\colorbox{yellow}{x + y}"];
}

- (void)testFcolorbox
{
    [self assertParses:@"\\fcolorbox{red}{yellow}{x + y}"];
}

#pragma mark - Phase 3: Fraction/Binom Variants

- (void)testDfracTfrac
{
    [self assertParses:@"\\dfrac{a}{b}"];
    [self assertParses:@"\\tfrac{a}{b}"];
    // Verify they produce fractions
    MTMathList *list = [self parseNoError:@"\\dfrac{1}{2}"];
    XCTAssertTrue(list.atoms.count > 0);
    XCTAssertEqual(list.atoms[0].type, kMTMathAtomFraction);
}

- (void)testCfrac
{
    [self assertParses:@"\\cfrac{1}{1 + \\cfrac{1}{2}}"];
}

- (void)testDbinomTbinom
{
    [self assertParses:@"\\dbinom{n}{k}"];
    [self assertParses:@"\\tbinom{n}{k}"];
    MTMathList *list = [self parseNoError:@"\\dbinom{n}{k}"];
    XCTAssertEqual(list.atoms[0].type, kMTMathAtomFraction);
}

#pragma mark - Phase 3: Lap

- (void)testRlap
{
    [self assertParses:@"\\rlap{/}\\quad o"];
    MTMathList *list = [self parseNoError:@"\\rlap{x}"];
    MTPhantom *phantom = (MTPhantom *)list.atoms[0];
    XCTAssertEqual(phantom.phantomType, kMTPhantomLapRight);
}

- (void)testLlap
{
    [self assertParses:@"\\llap{x}"];
    MTMathList *list = [self parseNoError:@"\\llap{x}"];
    MTPhantom *phantom = (MTPhantom *)list.atoms[0];
    XCTAssertEqual(phantom.phantomType, kMTPhantomLapLeft);
}

- (void)testClap
{
    [self assertParses:@"\\clap{x}"];
    MTMathList *list = [self parseNoError:@"\\clap{x}"];
    MTPhantom *phantom = (MTPhantom *)list.atoms[0];
    XCTAssertEqual(phantom.phantomType, kMTPhantomLapCenter);
}

#pragma mark - Phase 3: Environment Variants

- (void)testDcases
{
    [self assertParses:@"\\begin{dcases} x & x > 0 \\\\ -x & x \\leq 0 \\end{dcases}"];
}

- (void)testRcases
{
    [self assertParses:@"\\begin{rcases} x & x > 0 \\\\ -x & x \\leq 0 \\end{rcases}"];
}

- (void)testSmallmatrix
{
    [self assertParses:@"\\begin{smallmatrix} a & b \\\\ c & d \\end{smallmatrix}"];
}

#pragma mark - Phase 3: Combined Stress Test

- (void)testPhase3Combined
{
    NSString *latex = @"\\cancel{a} + \\dfrac{1}{2} + \\overset{\\sim}{=} + \\overrightarrow{AB}";
    [self assertParses:latex];
}

#pragma mark - Phase 4: Extensible Arrows

- (void)testXrightarrow
{
    [self assertParses:@"A \\xrightarrow{\\text{f}} B"];
}

- (void)testXleftarrow
{
    [self assertParses:@"A \\xleftarrow{\\text{g}} B"];
}

- (void)testXrightarrowWithBelow
{
    // \xrightarrow[below]{above}
    [self assertParses:@"A \\xrightarrow[\\beta]{\\alpha} B"];
}

- (void)testXleftarrowWithBelow
{
    [self assertParses:@"A \\xleftarrow[n \\to \\infty]{\\Delta} B"];
}

- (void)testXRightarrow
{
    [self assertParses:@"A \\xRightarrow{\\text{implies}} B"];
}

- (void)testXLeftarrow
{
    [self assertParses:@"A \\xLeftarrow{\\text{implied by}} B"];
}

- (void)testXleftrightarrow
{
    [self assertParses:@"A \\xleftrightarrow{\\sim} B"];
}

- (void)testXLeftrightarrow
{
    [self assertParses:@"A \\xLeftrightarrow{\\text{iff}} B"];
}

- (void)testXhookrightarrow
{
    [self assertParses:@"A \\xhookrightarrow{\\iota} B"];
}

- (void)testXhookleftarrow
{
    [self assertParses:@"A \\xhookleftarrow{} B"];
}

- (void)testXmapsto
{
    [self assertParses:@"x \\xmapsto{f} f(x)"];
}

- (void)testXlongequal
{
    [self assertParses:@"A \\xlongequal{\\text{def}} B"];
}

- (void)testXtwoheadrightarrow
{
    [self assertParses:@"A \\xtwoheadrightarrow{\\pi} B"];
}

- (void)testXtwoheadleftarrow
{
    [self assertParses:@"A \\xtwoheadleftarrow{} B"];
}

- (void)testXrightharpoonup
{
    [self assertParses:@"A \\xrightharpoonup{} B"];
}

- (void)testXleftharpoondown
{
    [self assertParses:@"A \\xleftharpoondown{} B"];
}

- (void)testExtensibleArrowAtomType
{
    // Verify the atom type is correct
    NSError *error = nil;
    MTMathList *list = [MTMathListBuilder buildFromString:@"\\xrightarrow{f}" error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(list);
    XCTAssertEqual(list.atoms.count, 1);
    MTMathAtom *atom = list.atoms[0];
    XCTAssertEqual(atom.type, kMTMathAtomExtensibleArrow);
    XCTAssertTrue([atom isKindOfClass:[MTExtensibleArrow class]]);
    MTExtensibleArrow *arrow = (MTExtensibleArrow*)atom;
    XCTAssertEqual(arrow.arrowType, kMTExtensibleArrowRight);
    XCTAssertNotNil(arrow.aboveList);
    XCTAssertNil(arrow.belowList);
}

- (void)testExtensibleArrowWithBothLabels
{
    NSError *error = nil;
    MTMathList *list = [MTMathListBuilder buildFromString:@"\\xrightarrow[g]{f}" error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(list);
    MTExtensibleArrow *arrow = (MTExtensibleArrow*)list.atoms[0];
    XCTAssertNotNil(arrow.aboveList);
    XCTAssertNotNil(arrow.belowList);
}

#pragma mark - Phase 4: Array Environment

- (void)testArrayBasic
{
    [self assertParses:@"\\begin{array}{lcr} a & b & c \\\\ d & e & f \\end{array}"];
}

- (void)testArrayWithVerticalLines
{
    [self assertParses:@"\\begin{array}{|l|c|r|} a & b & c \\\\ d & e & f \\end{array}"];
}

- (void)testArrayColumnAlignments
{
    NSError *error = nil;
    NSString *latex = @"\\begin{array}{lcr} a & b & c \\end{array}";
    MTMathList *list = [MTMathListBuilder buildFromString:latex error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(list);
    // The array is inside the list — find the table atom
    MTMathAtom *atom = list.atoms[0];
    XCTAssertEqual(atom.type, kMTMathAtomTable);
    MTMathTable *table = (MTMathTable*)atom;
    XCTAssertEqual([table getAlignmentForColumn:0], kMTColumnAlignmentLeft);
    XCTAssertEqual([table getAlignmentForColumn:1], kMTColumnAlignmentCenter);
    XCTAssertEqual([table getAlignmentForColumn:2], kMTColumnAlignmentRight);
}

- (void)testArrayVerticalLinePositions
{
    NSError *error = nil;
    NSString *latex = @"\\begin{array}{|l|c|} a & b \\end{array}";
    MTMathList *list = [MTMathListBuilder buildFromString:latex error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(list);
    MTMathTable *table = (MTMathTable*)list.atoms[0];
    XCTAssertEqual(table.verticalLines.count, 3);
    XCTAssertEqual(table.verticalLines[0].integerValue, 0);  // before col 0
    XCTAssertEqual(table.verticalLines[1].integerValue, 1);  // between col 0 and 1
    XCTAssertEqual(table.verticalLines[2].integerValue, 2);  // after col 1
}

#pragma mark - Phase 4: Additional Alignment Environments

- (void)testAlignEnvironment
{
    [self assertParses:@"\\begin{align} x &= 1 \\\\ y &= 2 \\end{align}"];
}

- (void)testAlignStarEnvironment
{
    [self assertParses:@"\\begin{align*} x &= 1 \\\\ y &= 2 \\end{align*}"];
}

- (void)testGatheredEnvironment
{
    [self assertParses:@"\\begin{gathered} x + y \\\\ a + b \\end{gathered}"];
}

#pragma mark - Phase 4: Combined Stress Test

- (void)testPhase4Combined
{
    NSString *latex = @"A \\xrightarrow[\\beta]{\\alpha} B \\xleftarrow{f} C";
    [self assertParses:latex];
}

- (void)testPhase4ArrayAndArrows
{
    NSString *latex = @"\\begin{array}{|c|c|} x & \\xrightarrow{f} \\\\ y & z \\end{array}";
    [self assertParses:latex];
}

#pragma mark - Phase 5: Macro System — \def

- (void)testDefSimple
{
    // \def\foo{x + y} followed by usage
    [self assertParses:@"\\def\\foo{x + y} \\foo"];
}

- (void)testDefWithOneParam
{
    // \def\sq#1{#1^2} then \sq{x}
    [self assertParses:@"\\def\\sq#1{#1^2} \\sq{x}"];
}

- (void)testDefWithTwoParams
{
    // \def\add#1#2{#1 + #2}
    [self assertParses:@"\\def\\add#1#2{#1 + #2} \\add{a}{b}"];
}

- (void)testDefVerifyExpansion
{
    NSError *error = nil;
    NSString *latex = @"\\def\\R{\\mathbb{R}} \\R";
    MTMathList *list = [MTMathListBuilder buildFromString:latex error:&error];
    XCTAssertNil(error, @"Parse error: %@", error);
    XCTAssertNotNil(list);
    // Should contain the zero-width space from \def and the expanded \R
    XCTAssertTrue(list.atoms.count >= 2, @"Expected at least 2 atoms, got %lu", (unsigned long)list.atoms.count);
}

- (void)testDefOverwritesPrevious
{
    // Second \def overwrites the first
    [self assertParses:@"\\def\\x{a} \\def\\x{b} \\x"];
}

#pragma mark - Phase 5: Macro System — \newcommand

- (void)testNewcommandSimple
{
    [self assertParses:@"\\newcommand{\\foo}{x + y} \\foo"];
}

- (void)testNewcommandWithParams
{
    [self assertParses:@"\\newcommand{\\sq}[1]{#1^2} \\sq{x}"];
}

- (void)testNewcommandTwoParams
{
    [self assertParses:@"\\newcommand{\\fr}[2]{\\frac{#1}{#2}} \\fr{a}{b}"];
}

- (void)testRenewcommand
{
    [self assertParses:@"\\renewcommand{\\vec}[1]{\\overrightarrow{#1}} \\vec{AB}"];
}

- (void)testProvidecommandNew
{
    // providecommand defines if not yet defined
    [self assertParses:@"\\providecommand{\\foo}{xyz} \\foo"];
}

- (void)testProvidecommandExisting
{
    // providecommand skips if already defined (e.g., via prior \def)
    [self assertParses:@"\\def\\foo{abc} \\providecommand{\\foo}{xyz} \\foo"];
}

#pragma mark - Phase 5: Macro System — \let

- (void)testLetAlias
{
    [self assertParses:@"\\let\\myint=\\int \\myint_0^1"];
}

- (void)testLetAliasNoEquals
{
    // \let without = separator
    [self assertParses:@"\\let\\mysum\\sum \\mysum_{i=0}^{n}"];
}

- (void)testLetVerifyExpansion
{
    NSError *error = nil;
    NSString *latex = @"\\let\\arrow=\\rightarrow a \\arrow b";
    MTMathList *list = [MTMathListBuilder buildFromString:latex error:&error];
    XCTAssertNil(error, @"Parse error: %@", error);
    XCTAssertNotNil(list);
    // Should have: zero-space, a, rightarrow-atom, b
    XCTAssertTrue(list.atoms.count >= 3);
}

#pragma mark - Phase 5: Macro System — Nested/Recursive

- (void)testNestedMacros
{
    // A macro that uses another macro
    [self assertParses:@"\\def\\inner{x} \\def\\outer{\\inner + y} \\outer"];
}

- (void)testMacroInFraction
{
    [self assertParses:@"\\def\\n{n+1} \\frac{\\n}{2}"];
}

- (void)testMacroWithComplexExpansion
{
    [self assertParses:@"\\newcommand{\\bfrac}[2]{\\frac{\\mathbf{#1}}{\\mathbf{#2}}} \\bfrac{a}{b}"];
}

#pragma mark - Phase 5: Combined Stress Test

- (void)testPhase5Combined
{
    NSString *latex = @"\\def\\R{\\mathbb{R}} \\newcommand{\\norm}[1]{\\left\\|#1\\right\\|} \\let\\ra=\\rightarrow f: \\R \\ra \\R, \\norm{x}";
    [self assertParses:latex];
}

@end
