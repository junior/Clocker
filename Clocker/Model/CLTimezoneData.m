//
//  CLTimezoneData.m
//  Clocker
//
//  Created by Abhishek Banthia on 12/22/15.
//
//

#import "CLAPI.h"
#import "CLTimezoneData.h"
#import "CommonStrings.h"
#import "DateTools.h"
#import "PanelController.h"
#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/IOKitLib.h>
#include "EDSunriseSet.h"

@implementation CLTimezoneData

-(instancetype)initWithDictionary:(NSDictionary *)dictionary
{
    self = [super init];
    
    if (self)
    {
        self.customLabel = dictionary[CLCustomLabel];
        self.timezoneID = dictionary[CLTimezoneID];
        self.latitude = dictionary[@"latitude"];
        self.longitude = dictionary[@"longitude"];
        self.place_id = dictionary[CLPlaceIdentifier];
        self.formattedAddress = dictionary[CLTimezoneName];
        self.isFavourite = [NSNumber numberWithInt:NSOffState];
        self.selectionType = CLCitySelection;
    }
    
    return self;
}

+ (void)setInitialTimezoneData
{
    CLTimezoneData *newData = [self new];
    newData.timezoneID = [[NSTimeZone systemTimeZone] name];
    newData.formattedAddress = newData.timezoneID;
    
    [newData saveObjectToPreferences];
}

- (BOOL)saveObjectToPreferences
{
    
    NSData *encodedObject = [NSKeyedArchiver archivedDataWithRootObject:self];
    NSMutableArray *array = [NSMutableArray new];
    [array addObject:encodedObject];
    
    [[NSUserDefaults standardUserDefaults] setObject:array forKey:CLDefaultPreferenceKey];
    
    return YES;
}

+ (instancetype)getCustomObject:(NSData *)encodedData
{
    
    if (encodedData)
    {
        if ([encodedData isKindOfClass:[NSDictionary class]])
        {
            CLTimezoneData *newObject = [[self alloc] initWithDictionary:(NSDictionary *)encodedData];
            return newObject;
        }
        CLTimezoneData *object = [NSKeyedUnarchiver unarchiveObjectWithData:encodedData];
        return object;
        
    }
    
    return nil;
    
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:self.place_id forKey:@"place_id"];
    [coder encodeObject:self.formattedAddress forKey:@"formattedAddress"];
    [coder encodeObject:self.customLabel forKey:@"customLabel"];
    [coder encodeObject:self.timezoneID forKey:@"timezoneID"];
    [coder encodeObject:self.nextUpdate forKey:@"nextUpdate"];
    [coder encodeObject:self.latitude forKey:@"latitude"];
    [coder encodeObject:self.longitude forKey:@"longitude"];
    [coder encodeObject:self.isFavourite forKey:@"isFavourite"];
    [coder encodeObject:self.sunriseTime forKey:@"sunriseTime"];
    [coder encodeObject:self.sunsetTime forKey:@"sunsetTime"];
    [coder encodeInteger:self.selectionType forKey:@"selectionType"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    
    if (self)
    {
        self.place_id = [coder decodeObjectForKey:@"place_id"];
        self.formattedAddress = [coder decodeObjectForKey:@"formattedAddress"];
        self.customLabel = [coder decodeObjectForKey:@"customLabel"];
        self.timezoneID = [coder decodeObjectForKey:@"timezoneID"];
        self.nextUpdate = [coder decodeObjectForKey:@"nextUpdate"];
        self.latitude = [coder decodeObjectForKey:@"latitude"];
        self.longitude = [coder decodeObjectForKey:@"longitude"];
        self.isFavourite = [coder decodeObjectForKey:@"isFavourite"];
        self.sunriseTime = [coder decodeObjectForKey:@"sunriseTime"];
        self.sunsetTime = [coder decodeObjectForKey:@"sunsetTime"];
        self.selectionType = [coder decodeIntegerForKey:@"selectionType"];
    }
    
    return self;
}

-(NSString *)description
{
    return [NSString stringWithFormat:@"TimezoneID: %@\nFormatted Address: %@\nCustom Label: %@\nLatitude: %@\nLongitude:%@\nPlaceID: %@\nisFavourite: %@\nSunrise Time: %@\nSunset Time: %@\nSelection Type: %zd", self.timezoneID,
            self.formattedAddress,
            self.customLabel,
            self.latitude,
            self.longitude,
            self.place_id,
            self.isFavourite,
            self.sunriseTime,
            self.sunsetTime,
            self.selectionType];
}

- (NSString *)formatStringShouldContainCity:(BOOL)value
{
    if (self.customLabel.length > 0)
    {
        return self.customLabel;
    }
    
    if ([self.formattedAddress length] > 0)
    {
        return self.formattedAddress;
    }
    else if (self.timezoneID)
    {
        NSString *timezoneID = self.timezoneID;
        
        NSRange range = [timezoneID rangeOfString:@"/"];
        if (range.location != NSNotFound)
        {
            timezoneID = [timezoneID substringWithRange:NSMakeRange(range.location+1, timezoneID.length-1 - range.location)];
        }
        return timezoneID;
    }
    else
    {
        return @"Error";
    }
    
}

- (NSString *)getTimeForTimeZoneWithFutureSliderValue:(NSInteger)futureSliderValue
{
    NSCalendar *currentCalendar = [NSCalendar autoupdatingCurrentCalendar];
    NSDate *newDate = [currentCalendar dateByAddingUnit:NSCalendarUnitMinute
                                                  value:futureSliderValue
                                                 toDate:[NSDate date]
                                                options:kNilOptions];
    NSDateFormatter *dateFormatter = [NSDateFormatter new];
    dateFormatter.dateStyle = kCFDateFormatterNoStyle;
    
    NSNumber *is24HourFormatSelected = [[NSUserDefaults standardUserDefaults] objectForKey:CL24hourFormatSelectedKey];
    
    is24HourFormatSelected.boolValue ? [dateFormatter setDateFormat:@"HH:mm"] : [dateFormatter setDateFormat:@"hh:mm a"];
    
    dateFormatter.timeZone = [NSTimeZone timeZoneWithName:self.timezoneID];
    //In the format 22:10
    
    return [dateFormatter stringFromDate:newDate];
}

- (void)retrieveLatitudeAndLongitudeWithSearchString:(NSString *)formattedString
{
    NSString *preferredLanguage = [NSLocale preferredLanguages][0];
    
    if (![CLAPI isUserConnectedToInternet])
    {
        /*Show some kind of information label*/
        return;
    }
    
    NSArray* words = [formattedString componentsSeparatedByCharactersInSet :[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    formattedString = [words componentsJoinedByString:CLEmptyString];
    
    NSString *urlString = [NSString stringWithFormat:CLLocationSearchURL, formattedString, preferredLanguage];
    
    [CLAPI dataTaskWithServicePath:urlString
                          bySender:self
               withCompletionBlock:^(NSError *error, NSDictionary *json) {
                   
                   
                   dispatch_async(dispatch_get_main_queue(), ^{
                       
                       if (error || [json[@"status"] isEqualToString:@"ZERO_RESULTS"])
                       {
                           return;
                       }
                       
                       
                       [json[@"results"] enumerateObjectsUsingBlock:^(NSDictionary *  _Nonnull dictionary, NSUInteger idx, BOOL * _Nonnull stop)
                       {
                           
                           if ([dictionary[CLPlaceIdentifier] isEqualToString:self.place_id])
                           {
                               //We have a match
                               
                               NSDictionary *latLang = [[dictionary objectForKey:@"geometry"] objectForKey:@"location"];
                               self.latitude = [NSString stringWithFormat:@"%@", latLang[@"lat"]];
                               self.longitude = [NSString stringWithFormat:@"%@", latLang[@"lng"]];
                           }
                           
                       }];
                       
                   });
                   
               }];

}

- (NSString *)getLocalCurrentDate
{
    NSDateFormatter *dateFormatter = [NSDateFormatter new];
    dateFormatter.dateStyle = kCFDateFormatterShortStyle;
    dateFormatter.timeStyle = kCFDateFormatterNoStyle;
    dateFormatter.timeZone = [NSTimeZone systemTimeZone];
    
    return [NSDateFormatter localizedStringFromDate:[NSDate date]
                                          dateStyle:NSDateFormatterShortStyle
                                          timeStyle:NSDateFormatterNoStyle];
    
}

- (NSString *)compareSystemDate:(NSString *)systemDate toTimezoneDate:(NSString *)date
{    
    NSDateFormatter *formatter = [NSDateFormatter new];
    formatter.dateFormat = [NSDateFormatter dateFormatFromTemplate:@"MM/dd/yyyy"
                                                           options:0
                                                            locale:[NSLocale currentLocale]];
    
    NSDate *localDate = [formatter dateFromString:systemDate];
    NSDate *timezoneDate = [formatter dateFromString:date];
    
    // Specify which units we would like to use
    NSCalendar *calendar = [NSCalendar autoupdatingCurrentCalendar];
    NSInteger weekday = [calendar component:NSCalendarUnitWeekday fromDate:localDate];
    
    if ([self.nextUpdate isKindOfClass:[NSString class]])
    {
        
        NSUInteger units = NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay;
        NSDateComponents *comps = [[NSCalendar currentCalendar] components:units fromDate:timezoneDate];
        comps.day = comps.day + 1;
        NSDate *tomorrowMidnight = [[NSCalendar currentCalendar] dateFromComponents:comps];
        
        CLTimezoneData *newDataObject = [CLTimezoneData new];
        newDataObject.timezoneID = self.timezoneID;
        newDataObject.formattedAddress = self.formattedAddress;
        newDataObject.latitude = self.latitude;
        newDataObject.longitude = self.longitude;
        newDataObject.customLabel = self.customLabel;
        newDataObject.place_id = self.place_id;
        newDataObject.nextUpdate = tomorrowMidnight;
        newDataObject.isFavourite = [NSNumber numberWithInt:NSOffState];
        
        __block PanelController *panelController;
        
        [[NSApplication sharedApplication].windows enumerateObjectsUsingBlock:^(NSWindow * _Nonnull window, NSUInteger idx, BOOL * _Nonnull stop) {
            if ([window.windowController isMemberOfClass:[PanelController class]])
            {
                panelController = window.windowController;
            }
        }];
        
        [panelController.defaultPreferences replaceObjectAtIndex:[panelController.defaultPreferences indexOfObject:self] withObject:newDataObject];
        [[NSUserDefaults standardUserDefaults] setObject:panelController.defaultPreferences forKey:CLDefaultPreferenceKey];
    }
    
    NSInteger daysApart = [timezoneDate daysFrom:localDate];
    
    if (daysApart == 0) {
        return @"Today";
    }
    else if (daysApart == -1)
    {
        return @"Yesterday";
    }
    else if (daysApart == 1)
    {
        return @"Tomorrow";
    }
    else
    {
        return [self getWeekdayFromInteger:weekday+2];
    }
}

- (NSString *)getDateForTimeZoneWithFutureSliderValue:(NSInteger)futureSliderValue
                                       andDisplayType:(CLDateDisplayType)type
{
    NSCalendar *currentCalendar = [NSCalendar autoupdatingCurrentCalendar];
    NSDate *newDate = [currentCalendar dateByAddingUnit:NSCalendarUnitMinute
                                                  value:futureSliderValue
                                                 toDate:[NSDate date]
                                                options:kNilOptions];
    NSDateFormatter *dateFormatter = [NSDateFormatter new];
    dateFormatter.dateStyle = kCFDateFormatterShortStyle;
    dateFormatter.timeStyle = kCFDateFormatterNoStyle;
    
    dateFormatter.timeZone = [NSTimeZone timeZoneWithName:self.timezoneID];
    
    NSNumber *relativeDayPreference = [[NSUserDefaults standardUserDefaults] objectForKey:CLRelativeDateKey];
    if (relativeDayPreference.integerValue == 0 && type == CLPanelDisplay) {
        return [self compareSystemDate:[self getLocalCurrentDate]
                        toTimezoneDate:[dateFormatter stringFromDate:newDate]];
    }
    else
    {
        NSDateFormatter *formatter = [NSDateFormatter new];
        formatter.dateFormat = [NSDateFormatter dateFormatFromTemplate:@"MM/dd/yyyy" options:0 locale:[NSLocale currentLocale]];
        
        NSDate *convertedDate = [formatter dateFromString:[dateFormatter stringFromDate:newDate]];
        
        NSCalendar *calendar = [NSCalendar autoupdatingCurrentCalendar];
        NSInteger weekday = [calendar component:NSCalendarUnitWeekday fromDate:convertedDate];
        return [self getWeekdayFromInteger:weekday];
    }
}

- (NSString *)getWeekdayFromInteger:(NSInteger)weekdayInteger
{
    
    if (weekdayInteger > 7) {
        weekdayInteger = weekdayInteger - 7;
    }
    
    switch (weekdayInteger) {
        case 1:
            return @"Sunday";
            break;
            
        case 2:
            return @"Monday";
            break;
            
        case 3:
            return @"Tuesday";
            break;
            
        case 4:
            return @"Wednesday";
            break;
            
        case 5:
            return @"Thursday";
            break;
            
        case 6:
            return @"Friday";
            break;
            
        case 7:
            return @"Saturday";
            break;
            
        default:
            return @"Error";
            break;
    }
}

- (NSString *)getMenuTitle
{
    NSMutableString *menuTitle = [NSMutableString new];
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSNumber *shouldCityBeShown = [userDefaults objectForKey:CLShowPlaceInMenu];
    NSNumber *shouldDayBeShown = [userDefaults objectForKey:CLShowDayInMenu];
    NSNumber *shouldDateBeShown = [userDefaults objectForKey:CLShowDateInMenu];
    
    if (shouldCityBeShown.boolValue == 0)
    {
        
        self.customLabel.length > 0 ?
        [menuTitle appendString:self.customLabel] :
        [menuTitle appendString:self.formattedAddress];
        
    }
    
    if (shouldDayBeShown.boolValue == 0)
    {
        NSString *substring = [self getDateForTimeZoneWithFutureSliderValue:0 andDisplayType:CLMenuDisplay];
        
        substring = [substring substringToIndex:3];
        
        if (menuTitle.length > 0)
        {
            [menuTitle appendFormat:@" %@",substring.capitalizedString];
        }
        else
        {
            [menuTitle appendString:substring.capitalizedString];
        }
    }
    
    if (shouldDateBeShown.boolValue == 0)
    {
        NSString *date = [[NSDate date] formattedDateWithFormat:@"MMM dd" timeZone:[NSTimeZone timeZoneWithName:self.timezoneID] locale:[NSLocale currentLocale]];
        
        if (menuTitle.length > 0)
        {
            [menuTitle appendFormat:@" %@",date];
        }
        else
        {
            [menuTitle appendString:date];
        }
    }
    
    menuTitle.length > 0 ?
    [menuTitle appendFormat:@" %@",[self getTimeForTimeZoneWithFutureSliderValue:0]] :
    [menuTitle appendString:[self getTimeForTimeZoneWithFutureSliderValue:0]];
    
    return menuTitle;
}

-(void)initializeSunriseSunsetWithSliderValue:(NSInteger)sliderValue
{
    
    if (!self.latitude || !self.longitude)
    {
        //Retrieve the values using Google Places API
        
        if (self.selectionType == CLTimezoneSelection)
        {
            /* A timezone has been selected*/
            
            NSLog(@"%@", self);
            
            return;
        }
        
        [self retrieveLatitudeAndLongitudeWithSearchString:self.formattedAddress];
        
    }
    
    EDSunriseSet *sunriseSetObject = [EDSunriseSet sunrisesetWithDate:[[NSCalendar autoupdatingCurrentCalendar]
                                                                       dateByAddingUnit:NSCalendarUnitMinute
                                                                       value:sliderValue
                                                                       toDate:[NSDate date]
                                                                       options:kNilOptions]
                                                             timezone:[NSTimeZone timeZoneWithName:self.timezoneID]
                                                             latitude:self.latitude.doubleValue
                                                            longitude:self.longitude.doubleValue];
    self.sunriseTime = sunriseSetObject.sunrise;
    self.sunsetTime = sunriseSetObject.sunset;
}


-(NSString *)getFormattedSunriseOrSunsetTimeAndSliderValue:(NSInteger)sliderValue
{
    /* We have to call this everytime so that we get an updated value everytime! */
    
    [self initializeSunriseSunsetWithSliderValue:sliderValue];
    
    if (!self.sunriseTime && !self.sunsetTime)
    {
        return CLEmptyString;
    }
    
    self.sunriseOrSunset = [self.sunriseTime isLaterThanOrEqualTo:[NSDate date]];
    
    NSDate *newDate = self.sunriseOrSunset ? self.sunriseTime : self.sunsetTime;
    
    NSDateFormatter *dateFormatter = [NSDateFormatter new];
    
    dateFormatter.dateStyle = kCFDateFormatterNoStyle;
    
    [dateFormatter setTimeZone:[NSTimeZone timeZoneWithName:self.timezoneID]];
    
    NSNumber *is24HourFormatSelected = [[NSUserDefaults standardUserDefaults] objectForKey:CL24hourFormatSelectedKey];
    
    is24HourFormatSelected.boolValue ? [dateFormatter setDateFormat:@"HH:mm"] : [dateFormatter setDateFormat:@"hh:mm a"];

    //In the format 22:10
    
    return [dateFormatter stringFromDate:newDate];
    
}

- (NSString *)getFullFledgedDateForTimeWithDate:(NSDate *)date
{
    NSCalendar *currentCalendar = [NSCalendar autoupdatingCurrentCalendar];
    
    NSDate *newDate = [currentCalendar dateByAddingUnit:NSCalendarUnitMinute
                                                  value:0
                                                 toDate:date
                                                options:kNilOptions];
    
    NSDateFormatter *dateFormatter = [NSDateFormatter new];
    
    [dateFormatter setDateFormat:@"yyyy-MM-dd hh:mm a"];
    
    [dateFormatter setTimeZone:[NSTimeZone timeZoneWithName:self.timezoneID]];
    
    return [dateFormatter stringFromDate:newDate];
}

@end
