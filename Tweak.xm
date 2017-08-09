#define CHECK_TARGET
#define CHECK_EXCEPTIONS
#import "../PS.h"
#import "../EmojiAttributes/WebCoreSupport/CoreGraphicsSPI.h"
#import <CoreText/CoreText.h>

BOOL isEmoji = NO;

BOOL (*CTFontIsAppleColorEmoji)(CTFontRef);
extern "C" bool CGFontGetGlyphAdvancesForStyle(CGFontRef, CGAffineTransform *, CGFontRenderingStyle, const CGGlyph *, size_t, CGSize *);

CGFloat (*GetEffectiveSize)(void *);
int (*IsAppleColorEmoji)(void *);
int (*_CTFontGetWebKitEmojiRenderMode)();

%hookf(int, IsAppleColorEmoji, void *arg0) {
    return %orig;
}

%hookf(int, _CTFontGetWebKitEmojiRenderMode) {
    return %orig;
}


%hookf(CGFloat, GetEffectiveSize, void *arg0) {
    return %orig;
}

const void *unadjustedPoint;
BOOL overridePoint = NO;

void (*showGlyphsWithAdvances)(const void *, const void *, CGContextRef, const CGGlyph *, const CGSize *, unsigned);
%hookf(void, showGlyphsWithAdvances, const void *point, const void *font, CGContextRef context, const CGGlyph *glyphs, const CGSize *advances, unsigned count) {
    %orig(overridePoint && unadjustedPoint ? unadjustedPoint : point, font, context, glyphs, advances, count);
}

void (*drawGlyphs)(void *, void *, const void *, const void *, int, int, const void *);
%hookf(void, drawGlyphs, void *arg0, void *context, const void *font, const void *glyphBuffer, int from, int numGlyphs, const void *anchorPoint) {
    overridePoint = YES;
    unadjustedPoint = anchorPoint;
    %orig;
    overridePoint = NO;
}

CTFontRef (*FontPlatformData_ctFont)(void *);
%hookf(CTFontRef, FontPlatformData_ctFont, void *arg0) {
    bool *isEmoji;
#if __LP64__
    if (isiOS9Up)
        isEmoji = (bool *)((uint8_t *)arg0 + 0x2B);
    else if (isiOS7Up)
        isEmoji = (bool *)((uint8_t *)arg0 + 0x8);
    else
        isEmoji = (bool *)((uint8_t *)arg0 + 0xC);
#else
    if (isiOS9Up)
        isEmoji = (bool *)((uint8_t *)arg0 + 0x1F);
    else if (isiOS7Up)
        isEmoji = (bool *)((uint8_t *)arg0 + 0x8);
    else
        isEmoji = (bool *)((uint8_t *)arg0 + 0xC);
#endif
    bool forEmoji = *isEmoji;
    *isEmoji = NO;
    CTFontRef font = %orig;
    *isEmoji = forEmoji;
    return font;
}

%group Test_iOS6

CGFloat (*platformWidthForGlyph)(void *, CGGlyph);
%hookf(CGFloat, platformWidthForGlyph, void *arg0, CGGlyph code) {
    CTFontRef font = isiOS7Up ? FontPlatformData_ctFont((void *)((uint8_t *)arg0 + 0x30)) : FontPlatformData_ctFont((void *)((uint8_t *)arg0 + 0x28));
    if (((CTFontIsAppleColorEmoji && CTFontIsAppleColorEmoji(font)) || (CFEqual(CFBridgingRelease(CTFontCopyPostScriptName(font)), CFSTR("AppleColorEmoji"))))) {
        CGFontRenderingStyle style = kCGFontRenderingStyleAntialiasing | kCGFontRenderingStyleSubpixelPositioning | kCGFontRenderingStyleSubpixelQuantization | kCGFontAntialiasingStyleUnfiltered;
        CGFloat pointSize = *(CGFloat *)((uint8_t *)arg0 + 0x38);
        CGSize advance = CGSizeZero;
        CGAffineTransform m = CGAffineTransformMakeScale(pointSize, pointSize);
        CGFontRef cgFont = CTFontCopyGraphicsFont(font, NULL);
        if (!CGFontGetGlyphAdvancesForStyle(cgFont, &m, style, &code, 1, &advance))
            advance.width = 0;
        CFRelease(cgFont);
        return advance.width + 4.0;
    }
    return %orig;
}

%end

/*void (*adjustGlyphsAndAdvances)(void *);
   %hookf(void, adjustGlyphsAndAdvances, void *arg0) {

   }*/

%ctor {
    if (_isTarget(TargetTypeGUINoExtension, @[@"com.apple.WebKit.WebContent"])) {
        MSImageRef ctref = MSGetImageByName(realPath2(@"/System/Library/Frameworks/CoreText.framework/CoreText"));
        MSImageRef wcref = MSGetImageByName(realPath2(@"/System/Library/PrivateFrameworks/WebCore.framework/WebCore"));
        GetEffectiveSize = (CGFloat (*)(void *))MSFindSymbol(ctref, "__ZNK5TFont16GetEffectiveSizeEv");
        IsAppleColorEmoji = (int (*)(void *))MSFindSymbol(ctref, "__ZNK5TFont17IsAppleColorEmojiEv");
        _CTFontGetWebKitEmojiRenderMode = (int (*)())MSFindSymbol(ctref, "_CTFontGetWebKitEmojiRenderMode");
        if (IsAppleColorEmoji == NULL)
            IsAppleColorEmoji = (int (*)(void *))MSFindSymbol(ctref, "__ZNK9TBaseFont17IsAppleColorEmojiEv");
        CTFontIsAppleColorEmoji = (BOOL (*)(CTFontRef))MSFindSymbol(ctref, "_CTFontIsAppleColorEmoji");
        showGlyphsWithAdvances = (void (*)(const void *, const void *, CGContextRef, const CGGlyph *, const CGSize *, unsigned))MSFindSymbol(wcref, "__ZNK7WebCore11FontCascade10drawGlyphsEPNS_15GraphicsContextEPKNS_4FontERKNS_11GlyphBufferEiiRKNS_10FloatPointE");
        if (showGlyphsWithAdvances == NULL)
            showGlyphsWithAdvances = (void (*)(const void *, const void *, CGContextRef, const CGGlyph *, const CGSize *, unsigned))MSFindSymbol(wcref, "__ZN7WebCoreL22showGlyphsWithAdvancesERKNS_10FloatPointEPKNS_14SimpleFontDataEP9CGContextPKtPK6CGSizem");
        drawGlyphs = (void (*)(void *, void *, const void *, const void *, int, int, const void *))MSFindSymbol(wcref, "__ZNK7WebCore11FontCascade10drawGlyphsEPNS_15GraphicsContextEPKNS_4FontERKNS_11GlyphBufferEiiRKNS_10FloatPointE");
        if (drawGlyphs == NULL)
            drawGlyphs = (void (*)(void *, void *, const void *, const void *, int, int, const void *))MSFindSymbol(wcref, "__ZNK7WebCore11FontCascade10drawGlyphsEPNS_15GraphicsContextEPKNS_4FontERKNS_11GlyphBufferEiiRKNS_10FloatPointEb");
        if (drawGlyphs == NULL)
            drawGlyphs = (void (*)(void *, void *, const void *, const void *, int, int, const void *))MSFindSymbol(wcref, "__ZNK7WebCore4Font10drawGlyphsEPNS_15GraphicsContextEPKNS_14SimpleFontDataERKNS_11GlyphBufferEiiRKNS_10FloatPointE");
        if (drawGlyphs == NULL)
            drawGlyphs = (void (*)(void *, void *, const void *, const void *, int, int, const void *))MSFindSymbol(wcref, "__ZNK7WebCore4Font10drawGlyphsEPNS_15GraphicsContextEPKNS_14SimpleFontDataERKNS_11GlyphBufferEiiRKNS_10FloatPointEb");
        FontPlatformData_ctFont = (CTFontRef (*)(void *))MSFindSymbol(wcref, "__ZNK7WebCore16FontPlatformData6ctFontEv");
        platformWidthForGlyph = (CGFloat (*)(void *, CGGlyph))MSFindSymbol(wcref, "__ZNK7WebCore4Font21platformWidthForGlyphEt");
        if (platformWidthForGlyph == NULL)
            platformWidthForGlyph = (CGFloat (*)(void *, CGGlyph))MSFindSymbol(wcref, "__ZNK7WebCore14SimpleFontData21platformWidthForGlyphEt");
        //adjustGlyphsAndAdvances = (void (*)(void *))MSFindSymbol(wcref, "__ZN7WebCore21ComplexTextController23adjustGlyphsAndAdvancesEv");
        HBLogDebug(@"Found GetEffectiveSize: %d", GetEffectiveSize != NULL);
        HBLogDebug(@"Found IsAppleColorEmoji: %d", IsAppleColorEmoji != NULL);
        HBLogDebug(@"Found _CTFontGetWebKitEmojiRenderMode: %d", _CTFontGetWebKitEmojiRenderMode != NULL);
        HBLogDebug(@"Found showGlyphsWithAdvances: %d", showGlyphsWithAdvances != NULL);
        HBLogDebug(@"Found drawGlyphs: %d", drawGlyphs != NULL);
        HBLogDebug(@"Found FontPlatformData_ctFont: %d", FontPlatformData_ctFont != NULL);
        HBLogDebug(@"Found platformWidthForGlyph: %d", platformWidthForGlyph != NULL);
        //HBLogDebug(@"Found adjustGlyphsAndAdvances: %d", adjustGlyphsAndAdvances != NULL);
        %init;
        if (!isiOS7Up) {
            %init(Test_iOS6);
        }
    }
}
