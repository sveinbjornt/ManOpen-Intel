/* AproposDocument.m created by lindberg on Tue 10-Oct-2000 */

#import "AproposDocument.h"
#import <Foundation/NSString.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSData.h>
#import <Foundation/NSUserDefaults.h>
#import <AppKit/NSTableView.h>
#import <AppKit/NSPanel.h>
#import <AppKit/NSPrintOperation.h>
#import "ManDocumentController.h"

@implementation AproposDocument

- (id)initWithString:(NSString *)apropos manPath:(NSString *)manPath title:(NSString *)aTitle
{
    ManDocumentController *docController = [ManDocumentController sharedDocumentController];
    NSMutableString *command = [docController manCommandWithManPath:manPath];
    NSData *output;

    [super init];

    titles = [[NSMutableArray alloc] init];
    descriptions = [[NSMutableArray alloc] init];
    title = [aTitle retain];
    [self setFileType:@"apropos"];

    [command appendString:@" -k"];
#ifdef MACOS_X
    /*
     * Starting on Tiger, man -k doesn't quite work the same as apropos directly.
     * Use apropos then, even on Panther.  Panther/Tiger no longer accept the -M
     * argument, so don't try... we set the MANPATH environment variable, which
     * gives a warning on Panther (stderr; ignored) but not on Tiger.
     */
#ifndef NSFoundationVersionNumber10_3
#define NSFoundationVersionNumber10_3 500.0
#endif
    if (NSFoundationVersionNumber >= NSFoundationVersionNumber10_3) {
        [command setString:@"/usr/bin/apropos"];
        /* Searching for a blank string doesn't work anymore either... use a catchall regex */
        if ([apropos length] == 0)
            apropos = @".";
    }
#endif
    
    [command appendFormat:@" %@", EscapePath(apropos, YES)];
    output = [docController dataByExecutingCommand:command manPath:manPath];
    [self parseOutput:[NSString stringWithCString:[output bytes] length:[output length]]];

    if ([titles count] == 0) {
        NSRunAlertPanel(@"Nothing found", @"No pages related to '%@' found", nil, nil, nil, apropos);
        [self release];
        return nil;
    }

    return self;
}

- (void)dealloc
{
    [title release];
    [titles release];
    [descriptions release];
    [super dealloc];
}

- (NSString *)windowNibName
{
    return @"Apropos";
}

- (NSString *)displayName
{
    return title;
}

- (void)windowControllerDidLoadNib:(NSWindowController *)windowController
{
    NSString *sizeString = [[NSUserDefaults standardUserDefaults] stringForKey:@"AproposWindowSize"];

    [super windowControllerDidLoadNib:windowController];

    if (sizeString != nil)
    {
        NSSize windowSize = NSSizeFromString(sizeString);
        NSWindow *window = [tableView window];
        NSRect frame = [window frame];

        if (windowSize.width > 30.0 && windowSize.height > 30.0) {
            frame.size = windowSize;
            [window setFrame:frame display:NO];
        }
    }

    [tableView setTarget:self];
    [tableView setDoubleAction:@selector(openManPages:)];
    [tableView sizeLastColumnToFit];
}

- (void)parseOutput:(NSString *)output
{
    NSArray *lines = [output componentsSeparatedByString:@"\n"];
    int     i, count = [lines count];

    if ([output length] == 0) return;

    lines = [lines sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
    
    for (i=0; i<count; i++)
    {
        NSString *line = [lines objectAtIndex:i];
        NSRange dashRange;

        if ([line length] == 0) continue;

        dashRange = [line rangeOfString:@"\t\t- "]; //OPENSTEP
        if (dashRange.length == 0)
            dashRange = [line rangeOfString:@"\t- "]; //OPENSTEP
        if (dashRange.length == 0)
            dashRange = [line rangeOfString:@"\t-" options:NSBackwardsSearch|NSAnchoredSearch];
        if (dashRange.length == 0)
            dashRange = [line rangeOfString:@" - "]; //MacOSX
        if (dashRange.length == 0)
            dashRange = [line rangeOfString:@" -" options:NSBackwardsSearch|NSAnchoredSearch];

        if (dashRange.length == 0) continue;

        [titles addObject:[line substringToIndex:dashRange.location]];
        [descriptions addObject:[line substringFromIndex:NSMaxRange(dashRange)]];
    }
}

- (IBAction)saveCurrentWindowSize:(id)sender
{
    NSSize size = [[tableView window] frame].size;
    [[NSUserDefaults standardUserDefaults] setObject:NSStringFromSize(size) forKey:@"AproposWindowSize"];
}

- (IBAction)openManPages:(id)sender
{
    if ([sender clickedRow] >= 0) {
        NSString *manPage = [titles objectAtIndex:[sender clickedRow]];
        [[ManDocumentController sharedDocumentController] openString:manPage oneWordOnly:YES];
    }
}

- (void)printShowingPrintPanel:(BOOL)showPanel
{
    NSPrintOperation *op = [NSPrintOperation printOperationWithView:tableView];
    [op setShowPanels:showPanel];
#ifdef MACOS_X
    [op runOperationModalForWindow:[tableView window] delegate:nil didRunSelector:NULL contextInfo:NULL];
#else
    [op runOperation];
#endif
}

/* NSTableView dataSource */
- (int)numberOfRowsInTableView:(NSTableView *)tableView
{
    return [titles count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
    NSArray *strings = (tableColumn == titleColumn)? titles : descriptions;
    return [strings objectAtIndex:row];
}

@end
