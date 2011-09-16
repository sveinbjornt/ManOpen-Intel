
#import "SystemType.h"
#ifdef OPENSTEP
#import "NSDocument.h"
#else
#import <AppKit/NSDocument.h>
#endif

@class ManTextView;
@class NSTextField, NSText, NSButton, NSPopUpButton;

@interface ManDocument : NSDocument
{
    NSString *shortTitle;
    NSData *taskData;
    NSMutableArray *sections;
    NSMutableArray *sectionRanges;

    IBOutlet ManTextView *textView;
    IBOutlet NSTextField *titleStringField;
    IBOutlet NSButton    *findSelectionButton;
    IBOutlet NSButton    *openSelectionButton;
    IBOutlet NSPopUpButton *sectionPopup;
}

- initWithName:(NSString *)name section:(NSString *)section manPath:(NSString *)manPath title:(NSString *)title;

- (NSString *)shortTitle;
- (void)setShortTitle:(NSString *)aString;

- (NSText *)textView;

- (void)loadCommand:(NSString *)command;

- (IBAction)saveCurrentWindowSize:(id)sender;
- (IBAction)openSelection:(id)sender;
- (IBAction)searchForSelection:(id)sender;
- (IBAction)displaySection:(id)sender;

@end
