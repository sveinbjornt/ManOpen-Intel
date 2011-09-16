
#import "ManDocument.h"
#import <AppKit/AppKit.h>
#import "ManDocumentController.h"
#import "PrefPanelController.h"
#import "FindPanelController.h"
#import "NSData+Utils.h"

#ifdef MACOS_X
/* Sigh, NSTypesetter is not in OPENSTEP, and is not part of AppKit.h in MacOS X */
#import <AppKit/NSTypesetter.h>

#ifndef NSFoundationVersionNumber10_3
#define NSFoundationVersionNumber10_3 500.0
#endif
#define IsPanther() (floor(NSFoundationVersionNumber) >= NSFoundationVersionNumber10_3)
#define IsPantherOrEarlier() (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber10_3)
#endif

#ifdef OPENSTEP
@interface NSValue (ManOpenRangeAdditions)
+ (NSValue *)valueWithRange:(NSRange)range;
- (NSRange)rangeValue;
@end
@implementation NSValue (ManOpenRangeAdditions)
+ (NSValue *)valueWithRange:(NSRange)range {
    return [self valueWithBytes:&range objCType:@encode(NSRange)];
}
- (NSRange)rangeValue {
    NSRange range;
    [self getValue:&range];
    return range;
}
@end
#endif

@interface ManTextView : NSTextView
- (void)scrollRangeToTop:(NSRange)charRange;
@end

@implementation ManDocument

- initWithName:(NSString *)name
	section:(NSString *)section
	manPath:(NSString *)manPath
	title:(NSString *)title
{
    ManDocumentController *docController = [ManDocumentController sharedDocumentController];
    NSMutableString *command = [docController manCommandWithManPath:manPath];

    [super init];

    [self setFileType:@"man"];
    [self setShortTitle:title];

    if (section && [section length] > 0)
        [command appendFormat:@" %@", [section lowercaseString]];

    [command appendFormat:@" %@", name];

    [self loadCommand:command];

    return self;
}

- (void)dealloc
{
    [taskData release];
    [shortTitle release];
    [sections release];
    [super dealloc];
}

- (NSString *)windowNibName
{
    return @"ManPage";
}

/*
 * Standard NSDocument method.  We only want to override if we aren't
 * representing an actual file.
 */
- (NSString *)displayName
{
    return ([self fileName] != nil)? [super displayName] : [self shortTitle];
}

- (NSString *)shortTitle
{
    return shortTitle;
}

- (void)setShortTitle:(NSString *)aString
{
    [shortTitle autorelease];
    shortTitle = [aString retain];
}

- (NSText *)textView
{
    return textView;
}

- (void)setupSectionPopup
{
    [sectionPopup removeAllItems];
    [sectionPopup addItemWithTitle:@"Section:"];
    [sectionPopup setEnabled:[sections count] > 0];

    if ([sectionPopup isEnabled])
        [sectionPopup addItemsWithTitles:sections];
}

- (void)addSectionHeader:(NSString *)header range:(NSRange)range
{
    /* Make sure it is a header -- error text sometimes is not Courier, so it gets passed in here. */
    if ([header rangeOfCharacterFromSet:[NSCharacterSet uppercaseLetterCharacterSet]].length > 0 &&
        [header rangeOfCharacterFromSet:[NSCharacterSet lowercaseLetterCharacterSet]].length == 0)
    {
        NSString *label = header;
        int count = 1;

        /* Check for dups (e.g. lesskey(1) ) */
        while ([sections containsObject:label]) {
            count++;
            label = [NSString stringWithFormat:@"%@ [%d]", header, count];
        }

        [sections addObject:label];
        [sectionRanges addObject:[NSValue valueWithRange:range]];
    }
}

- (void)showData
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSTextStorage *storage = nil;
    NSFont        *manFont = ManFont();
    NSColor       *linkColor = ManLinkColor();
    NSColor       *textColor = ManTextColor();
    NSColor       *backgroundColor = ManBackgroundColor();

    if (textView == nil) return;

    if ([taskData isRTFData])
    {
        storage = [[NSTextStorage alloc] initWithRTF:taskData documentAttributes:NULL];
    }
    else if (taskData != nil)
    {
#ifndef OPENSTEP
        storage = [[NSTextStorage alloc] initWithHTML:taskData documentAttributes:NULL];
#endif
    }

    if (storage == nil)
        storage = [[NSTextStorage alloc] init];

    if ([[storage string] rangeOfCharacterFromSet:[NSCharacterSet letterCharacterSet]].length == 0)
    {
        [[storage mutableString] setString:@"\nNo manual entry."];
    }

    if (sections == nil) {
        sections = [[NSMutableArray alloc] init];
        sectionRanges = [[NSMutableArray alloc] init];
    }
    [sections removeAllObjects];
    [sectionRanges removeAllObjects];
    
    /* Convert the attributed string to use the user's chosen font and text color */
    if (storage != nil)
    {
        NSFontManager *manager = [NSFontManager sharedFontManager];
        NSString      *family = [manFont familyName];
        float         size    = [manFont pointSize];
        unsigned      currIndex = 0;

        NS_DURING
        [storage beginEditing];

        while (currIndex < [storage length])
        {
            NSRange currRange;
            NSDictionary *attribs = [storage attributesAtIndex:currIndex effectiveRange:&currRange];
            NSFont       *font = [attribs objectForKey:NSFontAttributeName];
            BOOL isLink = NO;

            /* We mark "sections" with Helvetica fonts */
            if (font != nil && ![[font familyName] isEqualToString:@"Courier"]) {
                [self addSectionHeader:[[storage string] substringWithRange:currRange] range:currRange];
            }

#ifndef OPENSTEP
            isLink = ([attribs objectForKey:NSLinkAttributeName] != nil);
#endif

            if (font != nil && ![[font familyName] isEqualToString:family])
                font = [manager convertFont:font toFamily:family];
            if (font != nil && [font pointSize] != size)
                font = [manager convertFont:font toSize:size];
            if (font != nil)
                [storage addAttribute:NSFontAttributeName value:font range:currRange];

            if (isLink)
                [storage addAttribute:NSForegroundColorAttributeName value:linkColor range:currRange];
            else
                [storage addAttribute:NSForegroundColorAttributeName value:textColor range:currRange];
            
            currIndex = NSMaxRange(currRange);
        }

        [storage endEditing];
        NS_HANDLER
        NSLog(@"Exception during formatting: %@", localException);
        NS_ENDHANDLER

        [[textView layoutManager] replaceTextStorage:storage];
        [[textView window] invalidateCursorRectsForView:textView];
        [storage release];
    }

    [textView setBackgroundColor:backgroundColor];
    [self setupSectionPopup];

    // no need to keep around rtf data
    [taskData release];
    taskData = nil;
    [pool release];
}

- (NSString *)filterCommand
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
#ifdef OPENSTEP
    NSString *tool = @"cat2rtf";
#elif !defined(MACOS_X)
    NSString *tool = @"cat2html";
#else
    /* HTML parser in tiger got slow... RTF is faster, and is usable now that it supports hyperlinks */
    NSString *tool = IsPanther()? @"cat2rtf" : @"cat2html";
#endif
    NSString *command = [[NSBundle mainBundle] pathForResource:tool ofType:nil];

    command = EscapePath(command, YES);
    command = [command stringByAppendingString:@" -lH"]; // generate links, mark headers
    if ([defaults boolForKey:@"UseItalics"])
        command = [command stringByAppendingString:@" -i"];
    if (![defaults boolForKey:@"UseBold"])
        command = [command stringByAppendingString:@" -g"];

    return command;
}

- (void)loadCommand:(NSString *)command
{
    ManDocumentController *docController = [ManDocumentController sharedDocumentController];
    NSString *fullCommand = [NSString stringWithFormat:@"%@ | %@", command, [self filterCommand]];

    [taskData release];
    taskData = nil;
    taskData = [[docController dataByExecutingCommand:fullCommand] retain];

    [self showData];
}

- (void)loadManFile:(NSString *)filename isGzip:(BOOL)isGzip
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *nroffFormat = [defaults stringForKey:@"NroffCommand"];
    NSString *nroffCommand;
    BOOL     hasQuote = ([nroffFormat rangeOfString:@"'%@'"].length > 0);

    /* If Gzip, change the command into a filter of the output of gzcat.  I'm
       getting the feeling that the customizable nroff command is more trouble
       than it's worth, especially now that OSX uses the good version of gnroff */
    if (isGzip)
    {
        NSString *repl = hasQuote? @"'%@'" : @"%@";
        NSRange replRange = [nroffFormat rangeOfString:repl];
        if (replRange.length > 0) {
            NSMutableString *formatCopy = [[nroffFormat mutableCopy] autorelease];
            [formatCopy replaceCharactersInRange:replRange withString:@""];
            nroffFormat = [NSString stringWithFormat:@"/usr/bin/gzip -dc %@ | %@", repl, formatCopy];
        }
    }
    
    nroffCommand = [NSString stringWithFormat:nroffFormat, EscapePath(filename, !hasQuote)];
    [self loadCommand:nroffCommand];
}

- (void)loadCatFile:(NSString *)filename isGzip:(BOOL)isGzip
{
    NSString *binary = isGzip? @"/usr/bin/gzip -dc" : @"/bin/cat";
    [self loadCommand:[NSString stringWithFormat:@"%@ '%@'", binary, EscapePath(filename, NO)]];
}

- (BOOL)readFromFile:(NSString *)fileName ofType:(NSString *)type
{
    if ([type isEqual:@"man"])
        [self loadManFile:fileName isGzip:NO];
    else if ([type isEqual:@"mangz"])
        [self loadManFile:fileName isGzip:YES];
    else if ([type isEqual:@"cat"])
        [self loadCatFile:fileName isGzip:NO];
    else if ([type isEqual:@"catgz"])
        [self loadCatFile:fileName isGzip:YES];
    else return NO;

    [self setShortTitle:[[fileName lastPathComponent] stringByDeletingPathExtension]];

    return taskData != nil;
}

- (void)windowControllerDidLoadNib:(NSWindowController *)windowController
{
    NSString *sizeString = [[NSUserDefaults standardUserDefaults] stringForKey:@"ManWindowSize"];

    [super windowControllerDidLoadNib:windowController];

    [textView setEditable:NO];
    [textView setSelectable:YES];
    [textView setImportsGraphics:NO];
    [textView setRichText:YES];
#ifdef MACOS_X
    /* The new ATS typesetter in Jaguar causes some weirdnesses... but is fixed in later versions. */
    //if (IsPantherOrEarlier())
      //  [[textView layoutManager] setTypesetter:[NSSimpleHorizontalTypesetter sharedInstance]];
#endif

    if (sizeString != nil)
    {
        NSSize windowSize = NSSizeFromString(sizeString);
        NSWindow *window = [textView window];
        NSRect frame = [window frame];

        if (windowSize.width > 30.0 && windowSize.height > 30.0) {
            frame.size = windowSize;
            [window setFrame:frame display:NO];
        }
    }

    [findSelectionButton setToolTip:@" Find selection "];
    [openSelectionButton setToolTip:@" Open selection "];
    [[findSelectionButton cell] setGradientType:NSGradientConcaveStrong];
    [[openSelectionButton cell] setGradientType:NSGradientConcaveStrong];
#ifdef MACOS_X
    [findSelectionButton setBezelStyle:NSThickerSquareBezelStyle];
    [openSelectionButton setBezelStyle:NSThickerSquareBezelStyle];
    [[sectionPopup cell] setControlSize:NSSmallControlSize];
    [[sectionPopup cell] setFont:[NSFont labelFontOfSize:11.0]];
#endif

    if ([self shortTitle])
        [titleStringField setStringValue:[self shortTitle]];
    [[[textView textStorage] mutableString] setString:@"Loading..."];
    [textView setBackgroundColor:ManBackgroundColor()];
    [textView setTextColor:ManTextColor()];
    [self performSelector:@selector(showData) withObject:nil afterDelay:0.0];

    [[textView window] makeFirstResponder:textView];
#ifndef OPENSTEP
    /* 
     * On OPENSTEP, the NSWindowController *must* be the window delegate, so
     * don't set it. It's OK though since our OPENSTEP implementation for it
     * forwards any unknown messages (including the delegate methods we need)
     * through to us.
     */
    [[textView window] setDelegate:self];
#endif

}

- (IBAction)openSelection:(id)sender
{
    NSRange selectedRange = [textView selectedRange];

    if (selectedRange.length > 0)
    {
        NSString *selectedString = [[textView string] substringWithRange:selectedRange];
        [[ManDocumentController sharedDocumentController] openString:selectedString];
    }
    [[textView window] makeFirstResponder:textView];
}

- (IBAction)findNext:(id)sender        { [[FindPanelController sharedInstance] findNext:sender]; }
- (IBAction)findPrevious:(id)sender    { [[FindPanelController sharedInstance] findPrevious:sender]; }
- (IBAction)enterSelection:(id)sender  { [[FindPanelController sharedInstance] enterSelection:sender]; }
- (IBAction)jumpToSelection:(id)sender { [[FindPanelController sharedInstance] jumpToSelection:sender]; }

- (IBAction)searchForSelection:(id)sender
{
    [self enterSelection:sender];
    [self findNext:sender];
    [[textView window] makeFirstResponder:textView];
}

- (IBAction)displaySection:(id)sender
{
    int section = [sectionPopup indexOfSelectedItem];
    if (section > 0 && section <= [sectionRanges count]) {
        NSRange range = [[sectionRanges objectAtIndex:section-1] rangeValue];
        [textView scrollRangeToTop:range];
    }
}

- (IBAction)saveCurrentWindowSize:(id)sender
{
    NSSize size = [[textView window] frame].size;
    [[NSUserDefaults standardUserDefaults] setObject:NSStringFromSize(size) forKey:@"ManWindowSize"];
}

/* Always use global page layout */
- (IBAction)runPageLayout:(id)sender
{
    [[NSApplication sharedApplication] runPageLayout:sender];
}

- (void)printShowingPrintPanel:(BOOL)showPanel
{
    NSPrintOperation *operation = [NSPrintOperation printOperationWithView:textView];
    NSPrintInfo      *printInfo = [operation printInfo];

    [printInfo setVerticallyCentered:NO];
    [printInfo setHorizontallyCentered:YES];
    [printInfo setHorizontalPagination:NSFitPagination];
    [operation setShowPanels:showPanel];

#ifdef MACOS_X
    [operation runOperationModalForWindow:[textView window] delegate:nil didRunSelector:NULL contextInfo:NULL];
#else
    [operation runOperation];
#endif
}

- (BOOL)validateMenuItem:(NSMenuItem *)item
{
    if (![[FindPanelController sharedInstance] validateMenuItem:item]) return NO;
    return [super validateMenuItem:item];
}

- (BOOL)textView:(NSTextView *)aTextView clickedOnLink:(id)link atIndex:(unsigned)charIndex
{
    NSString *page = nil;

    /* On Tiger, NSURL, Panther and before, NSString */
    if ([link isKindOfClass:[NSString class]] && [link hasPrefix:@"manpage:"])
        page = [link substringFromIndex:8];
#ifndef OPENSTEP
    if ([link isKindOfClass:[NSURL class]])
        page = [link resourceSpecifier];
#endif

    if (page == nil)
        return NO;
    [[ManDocumentController sharedDocumentController] openString:page];
    return YES;
}

- (void)textView:(NSTextView *)textView clickedOnCell:(id <NSTextAttachmentCell>)cell inRect:(NSRect)cellFrame
{
    NSString *filename = nil;

    /* NSHelpAttachment stores the string in the fileName variable */
    if ([[cell attachment] respondsToSelector:@selector(fileName)])
        filename = [(id)[cell attachment] fileName];

    if ([filename hasPrefix:@"manpage:"]) {
        filename = [filename substringFromIndex:8];
        [[ManDocumentController sharedDocumentController] openString:filename];
    }
}

- (void)windowDidUpdate:(NSNotification *)notification
{
    /* Disable the Open Selection button if there's no selection to work on */
    [openSelectionButton setEnabled:([textView selectedRange].length > 0)];
}

- (BOOL)windowShouldZoom:(NSWindow *)window toFrame:(NSRect)newFrame
{
    return YES;
}

- (NSRect)windowWillUseStandardFrame:(NSWindow *)window defaultFrame:(NSRect)newFrame
{
    NSScrollView *scrollView = [textView enclosingScrollView];
    NSRect currentFrame = [window frame];
    NSRect desiredFrame;
    NSSize textSize;
    NSRect scrollRect;
    NSRect contentRect;

    /* Get the text's natural size */
    textSize = [[textView textStorage] size];
    textSize.width += ([textView textContainerInset].width * 2) + 10; //add a little extra padding
    [textView sizeToFit];
    textSize.height = NSHeight([textView frame]); //this seems to be more accurate

    /* Get the size the scrollView should be based on that */
    scrollRect.origin = NSZeroPoint;
    scrollRect.size = [NSScrollView frameSizeForContentSize:textSize
                                      hasHorizontalScroller:[scrollView hasHorizontalScroller]
                                        hasVerticalScroller:[scrollView hasVerticalScroller]
                                                 borderType:[scrollView borderType]];

    /* Get the window's content size -- basically the scrollView size plus our title area */
    contentRect = scrollRect;
    contentRect.size.height += NSHeight([[window contentView] frame]) - NSHeight([scrollView frame]);

    /* Get the desired window frame size */
    desiredFrame = [NSWindow frameRectForContentRect:contentRect styleMask:[window styleMask]];

    /* Set the origin based on window's current location */
    desiredFrame.origin.x = currentFrame.origin.x;
    desiredFrame.origin.y = NSMaxY(currentFrame) - NSHeight(desiredFrame);

    /* NSWindow will clip this rect to the actual available screen area */
    return desiredFrame;
}

@end

#ifdef MACOS_X
#import <ApplicationServices/ApplicationServices.h>
#else
#import <AppKit/psops.h>
#endif

@implementation ManTextView

static NSCursor *linkCursor = nil;

+ (void)initialize
{
    NSImage *linkImage;
    NSString *path;

    path = [[NSBundle mainBundle] pathForResource:@"LinkCursor" ofType:@"tiff"];
    linkImage = [[NSImage alloc] initWithContentsOfFile: path];
    linkCursor = [[NSCursor alloc] initWithImage:linkImage hotSpot:NSMakePoint(6.0, 1.0)];
    [linkCursor setOnMouseEntered:YES];
    [linkImage release];
}

- (void)resetCursorRects
{
    NSTextContainer *container = [self textContainer];
    NSLayoutManager *layout    = [self layoutManager];
    NSTextStorage *storage     = [self textStorage];
    NSRect visible = [self visibleRect];
    int currIndex = 0;

    [super resetCursorRects];

    while (currIndex < [storage length])
    {
        NSRange currRange;
        NSDictionary *attribs = [storage attributesAtIndex:currIndex effectiveRange:&currRange];
        BOOL isLinkSection;

#ifdef OPENSTEP
        isLinkSection = [attribs objectForKey:NSAttachmentAttributeName] != nil;
#else
        isLinkSection = [attribs objectForKey:NSLinkAttributeName] != nil;
#endif
        if (isLinkSection)
        {
            NSRect *rects;
            NSRange ignoreRange = {NSNotFound, 0};
            unsigned rectCount = 0;
            int i;

            rects = [layout rectArrayForCharacterRange:currRange
                            withinSelectedCharacterRange:ignoreRange
                            inTextContainer:container
                            rectCount:&rectCount];

            for (i=0; i<rectCount; i++)
                if (NSIntersectsRect(visible, rects[i]))
                    [self addCursorRect:rects[i] cursor:linkCursor];
        }

        currIndex = NSMaxRange(currRange);
    }
}

- (void)scrollRangeToTop:(NSRange)charRange
{
    NSLayoutManager *layout = [self layoutManager];
    NSRange glyphRange = [layout glyphRangeForCharacterRange:charRange actualCharacterRange:NULL];
    NSRect rect = [layout boundingRectForGlyphRange:glyphRange inTextContainer:[self textContainer]];
    float height = NSHeight([self visibleRect]);

    if (height > 0)
        rect.size.height = height;

    [self scrollRectToVisible:rect];
}

/* Make space page down (and shift/alt-space page up) */
- (void)keyDown:(NSEvent *)event
{
    if ([[event charactersIgnoringModifiers] isEqual:@" "])
    {
         if ([event modifierFlags] & (NSShiftKeyMask|NSAlternateKeyMask))
             [self pageUp:self];
         else
             [self pageDown:self];
    }
    else
    {
        [super keyDown:event];
    }
}

/* 
 * Draw page numbers when printing. This method is kinda odd... the normal
 * NSString drawing methods don't work. When I lockFocus on a view it does, but
 * it then appears the transformation matrix is altered in that the page is
 * translated a half page down (even worse, so is the clipping rect). Looking
 * back at old example code, this method seemed more designed to have explicit
 * PostScript drawing code work, so on MacOS X I tried some raw CoreGraphics
 * calls to render right to the graphics context without calling lockFocus on
 * anything, and it works fine. Very annoying though -- not sure if this can be
 * considered a bug in the NSString drawing code or not. NSBezierPath works fine
 * for what it's worth.
 */
- (void)drawPageBorderWithSize:(NSSize)size
{
    NSFont *font = ManFont();
    int currPage = [[NSPrintOperation currentOperation] currentPage];
    NSString *str = [NSString stringWithFormat:@"%d", currPage];
    float strWidth = [font widthOfString:str];
    NSPoint point = NSMakePoint(size.width/2 - strWidth/2, 20.0);

#ifdef MACOS_X
    CGContextRef context = [[NSGraphicsContext currentContext] graphicsPort];
    
    CGContextSaveGState(context);
    CGContextSetTextMatrix(context, CGAffineTransformIdentity);
    CGContextSetTextDrawingMode(context, kCGTextFill);  //needed?
    CGContextSetGrayFillColor(context, 0.0, 1.0);
    CGContextSelectFont(context, [[font fontName] cString], [font pointSize], kCGEncodingMacRoman);
    CGContextShowTextAtPoint(context, point.x, point.y, [str cString], [str cStringLength]);
    CGContextRestoreGState(context);
#else
    PSgsave();
    PSsetgray(0.0);
    PSselectfont([[font fontName] cString], [font pointSize]);
    PSmoveto(point.x, point.y);
    PSshow([str cString]);
    PSgrestore();
#endif
}

@end
