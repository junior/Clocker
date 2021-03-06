//
//  CLParentPanelController.m
//  Clocker
//
//  Created by Abhishek Banthia on 4/4/16.
//
//

#import "CLParentPanelController.h"
#import "CLRatingCellView.h"
#import "CLTimezoneData.h"
#import "CommonStrings.h"
#import "CLOneWindowController.h"
#import <pop/POP.h>

@interface CLParentPanelController ()

@end

@implementation CLParentPanelController

- (void)awakeFromNib
{
     [super awakeFromNib];
    
    if ([[[NSUserDefaults standardUserDefaults] objectForKey:CLThemeKey] isKindOfClass:[NSString class]]) {
        [[NSUserDefaults standardUserDefaults] setObject:@0 forKey:CLThemeKey];
    }
    
    NSNumber *theme = [[NSUserDefaults standardUserDefaults] objectForKey:CLThemeKey];
    
    if (theme.integerValue == 1)
    {
        self.shutdownButton.image = [NSImage imageNamed:@"PowerIcon-White"];
        self.preferencesButton.image = [NSImage imageNamed:@"Settings-White"];
    }
    else
    {
        self.shutdownButton.image = [NSImage imageNamed:@"PowerIcon"];
        self.preferencesButton.image = [NSImage imageNamed:NSImageNameActionTemplate];
    }
    
    self.mainTableview.selectionHighlightStyle = NSTableViewSelectionHighlightStyleNone;
    
   
}

- (void) updateDefaultPreferences
{
    
    NSArray *defaultZones = [[NSUserDefaults standardUserDefaults] objectForKey:CLDefaultPreferenceKey];
    
    self.defaultPreferences = self.defaultPreferences == nil ? [[NSMutableArray alloc] initWithArray:defaultZones] : [NSMutableArray arrayWithArray:defaultZones];
    
    self.scrollViewHeight.constant = self.showReviewCell ?
    (self.defaultPreferences.count+1)*55+40 : self.defaultPreferences.count*55 + 30;
    
    NSNumber *displayFutureSlider = [[NSUserDefaults standardUserDefaults] objectForKey:CLDisplayFutureSliderKey];
    
    /*No Future Slider when no timezones duh*/
    
    self.futureSlider.hidden = [displayFutureSlider isEqualToNumber:[NSNumber numberWithInteger:1]] || (self.defaultPreferences.count == 0) ? YES : NO;
    
    [self updatePanelColor];
}

- (void)updatePanelColor
{
    NSNumber *theme = [[NSUserDefaults standardUserDefaults] objectForKey:CLThemeKey];
    if (theme.integerValue == 1)
    {
        [self.mainTableview setBackgroundColor:[NSColor blackColor]];
        self.window.alphaValue = 0.90;
    }
    else
    {
        [self.mainTableview setBackgroundColor:[NSColor whiteColor]];
        self.window.alphaValue = 1;
    }
}


- (void)showOptions:(BOOL)value
{
    
    if (self.defaultPreferences.count == 0)
    {
        value = YES;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.shutdownButton.hidden = !value;
        self.preferencesButton.hidden = !value;
        
    });
    
}


- (IBAction)sliderMoved:(id)sender
{
    NSCalendar *currentCalendar = [NSCalendar autoupdatingCurrentCalendar];
    NSDate *newDate = [currentCalendar dateByAddingUnit:NSCalendarUnitMinute
                                                  value:self.futureSliderValue
                                                 toDate:[NSDate date]
                                                options:kNilOptions];
    
    self.dateFormatter.dateStyle = kCFDateFormatterNoStyle;
    self.dateFormatter.timeStyle = kCFDateFormatterShortStyle;
    
    NSString *relativeDate = [currentCalendar isDateInToday:newDate] ? @"Today" : @"Tomorrow";
    
    NSString *helper = [self.dateFormatter stringFromDate:newDate];
    
    NSHelpManager *helpManager = [NSHelpManager sharedHelpManager];
    
    NSPoint pointInScreen = [NSEvent mouseLocation];
    pointInScreen.y -= 5;
    NSAttributedString *attributedString = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@ %@", relativeDate, helper]];
    [NSHelpManager setContextHelpModeActive:YES];
    [helpManager setContextHelp:attributedString forObject:self.futureSlider];
    [helpManager showContextHelpForObject:self.futureSlider locationHint:pointInScreen];
    
    [self.mainTableview reloadData];
}

- (void)removeContextHelpForSlider
{
    NSEvent *newEvent = [NSEvent mouseEventWithType:NSLeftMouseDown
                                           location:self.window.mouseLocationOutsideOfEventStream
                                      modifierFlags:0
                                          timestamp:0
                                       windowNumber:self.window.windowNumber
                                            context:self.window.graphicsContext
                                        eventNumber:0
                                         clickCount:1
                                           pressure:0];
    [NSApp postEvent:newEvent atStart:NO];
    newEvent = [NSEvent mouseEventWithType:NSLeftMouseUp
                                  location:self.window.mouseLocationOutsideOfEventStream
                             modifierFlags:0
                                 timestamp:0
                              windowNumber:self.window.windowNumber
                                   context:self.window.graphicsContext
                               eventNumber:0
                                clickCount:1
                                  pressure:0];
    
    [NSApp postEvent:newEvent atStart:NO];
}

#pragma mark -
#pragma mark Preferences Target-Action
#pragma mark -

- (IBAction)openPreferences:(id)sender
{
    [self openPreferenceWindowWithValue:NO];
}

- (void)openPreferenceWindowWithValue:(BOOL)value
{
    self.oneWindow = [CLOneWindowController sharedWindow];
    
    [self.oneWindow showWindow:nil];
    
    CGRect originalFrame = self.oneWindow.window.frame;
    
    CGRect oldFrame = CGRectMake(self.oneWindow.window.frame.origin.x, 730,self.oneWindow.window.frame.size.width, self.oneWindow.window.frame.size.height);
    
   
    
    [self performBoundsAnimationWithOldRect:oldFrame andNewRect:originalFrame andShouldOpenTimezonePanel:value];
    
    [NSApp activateIgnoringOtherApps:YES];
}


- (void)performBoundsAnimationWithOldRect:(CGRect)fromRect andNewRect:(CGRect)newRect andShouldOpenTimezonePanel:(BOOL)shouldOpen
{
     [self.oneWindow.window setFrame:fromRect display:NO animate:NO];
    
    self.window.contentView.wantsLayer = YES;
    POPSpringAnimation *anim = [POPSpringAnimation animationWithPropertyNamed:kPOPWindowFrame];
    anim.toValue = [NSValue valueWithCGRect:newRect];
    anim.springSpeed = 1;
    [self.oneWindow.window pop_addAnimation:anim forKey:@"popBounds"];
    
    anim.completionBlock = ^(POPAnimation *animation, BOOL finished)
    {
        if (finished && shouldOpen)
        {
            [self.oneWindow.preferencesView addTimeZone:self];
        }
    };
}



@end
