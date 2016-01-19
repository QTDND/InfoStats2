//
//  IS2WeatherProvider.m
//  InfoStats2
//
//  Created by Matt Clarke on 02/06/2015.
//
//

#import "IS2WeatherProvider.h"
#import <Weather/TWCCityUpdater.h>
#import <objc/runtime.h>
#import <Weather/Weather.h>
#import <notify.h>
#import "IS2Extensions.h"

#define deviceVersion [[[UIDevice currentDevice] systemVersion] floatValue]

@interface WeatherPreferences (iOS7)
- (id)loadSavedCityAtIndex:(int)arg1;
@end

@interface CLLocationManager (iOS8)
+ (void)setAuthorizationStatus:(bool)arg1 forBundleIdentifier:(id)arg2;
- (id)initWithEffectiveBundleIdentifier:(id)arg1;
-(void)requestAlwaysAuthorization;
@end

@interface WeatherLocationManager (iOS7)
@property(retain) CLLocationManager * locationManager;
- (CLLocation*)location;
- (void)setLocationTrackingReady:(bool)arg1 activelyTracking:(bool)arg2;
@end

@interface WeatherLocationManager (iOS8)
- (bool)localWeatherAuthorized;
- (void)_setAuthorizationStatus:(int)arg1;
@end

@interface HourlyForecast (Additions)
@property (nonatomic) unsigned int eventType;
@property (nonatomic, copy) NSString *time;
@property (nonatomic, copy) NSString *detail;
@end

@interface City (iOS7)
@property (assign, nonatomic) unsigned conditionCode;
@property (assign, nonatomic) BOOL isRequestedByFrameworkClient;

+(id)descriptionForWeatherUpdateDetail:(unsigned)arg1;
@end

NSString *WeatherWindSpeedUnitForCurrentLocale();

static City *currentCity;
static IS2WeatherProvider *provider;
static void (^block)();

int notifyToken;
int status;

@implementation IS2WeatherProvider

+(instancetype)sharedInstance {
    if (!provider) {
        [City initialize];
        provider = [[IS2WeatherProvider alloc] init];
        provider.weatherFrameworkBundle = [NSBundle bundleWithPath:@"/System/Library/PrivateFrameworks/Weather.framework"];
    }
    
    return provider;
}

-(void)setupForTweakLoaded {
    [self setCurrentCity];
}

-(id)city {
    return currentCity;
}

// PLEASE do not ever call this directly; it's not exposed publicly in the API for a reason.
-(void)updateWeatherWithCallback:(void (^)(void))callbackBlock {
    self.isUpdating = YES;
    block = callbackBlock;
    
    NSLog(@"*** [InfoStats2] :: Attempting to request weather update.");
    
    // Set status bar indicator going
    
    status = notify_register_dispatch("com.matchstic.infostats2/weatherUpdateCompleted", &notifyToken, dispatch_get_main_queue(), ^(int t) {
        NSLog(@"*** [InfoStats2] :: Weather has been updated, reloading data.");
        
        // it seems that when no data is available, we cannot use extrapolated data for the local
        // weather city. TODO: fix this.
        
        [self setCurrentCity];
        
        // Run callback block!
        block();
        
        self.isUpdating = NO;
        
        notify_cancel(notifyToken); // No need to continue monitoring for this notification, saves battery power.
    });
    
    // Communicate via notify() with daemon for weather updates.
    notify_post("com.matchstic.infostats2/requestWeatherUpdate");
}

-(void)setCurrentCity {
    BOOL localWeather = [CLLocationManager locationServicesEnabled];
    
    if (localWeather) {
        // Local city updated
        currentCity = [[WeatherPreferences sharedPreferences] localWeatherCity];
    } else {
        // First city updated
        if (![[WeatherPreferences sharedPreferences] respondsToSelector:@selector(loadSavedCityAtIndex:)]) {
            // This is untested; I have no idea if this will work, but I hope so.
            @try {
                currentCity = [[[WeatherPreferences sharedPreferences] loadSavedCities] firstObject];
            } @catch (NSException *e) {
                NSLog(@"*** [InfoStats2 | Weather] :: Failed to load first city in Weather.app for reason:\n%@", e);
            }
        } else
            currentCity = [[WeatherPreferences sharedPreferences] loadSavedCityAtIndex:0];
    }
}

#pragma mark Translations

-(NSString*)nameForCondition:(int)condition {
    switch (condition) {
        case 0:
            return [self.weatherFrameworkBundle localizedStringForKey:@"WeatherConditionTornado" value:@"" table:@"WeatherFrameworkLocalizableStrings"];
        case 1:
            return [self.weatherFrameworkBundle localizedStringForKey:@"WeatherConditionTropicalStorm" value:@"" table:@"WeatherFrameworkLocalizableStrings"];
        case 2:
            return [self.weatherFrameworkBundle localizedStringForKey:@"WeatherConditionHurricane" value:@"" table:@"WeatherFrameworkLocalizableStrings"];
        case 3:
            return [self.weatherFrameworkBundle localizedStringForKey:@"WeatherConditionSevereThunderstorm" value:@"" table:@"WeatherFrameworkLocalizableStrings"];
        case 4:
            return [self.weatherFrameworkBundle localizedStringForKey:@"WeatherConditionThunderstorm" value:@"" table:@"WeatherFrameworkLocalizableStrings"];
        case 5:
            return [self.weatherFrameworkBundle localizedStringForKey:@"WeatherConditionMixedRainAndSnow" value:@"" table:@"WeatherFrameworkLocalizableStrings"];
        case 6:
            return [self.weatherFrameworkBundle localizedStringForKey:@"WeatherConditionMixedRainAndSleet" value:@"" table:@"WeatherFrameworkLocalizableStrings"];
        case 7:
            return [self.weatherFrameworkBundle localizedStringForKey:@"WeatherConditionMixedSnowAndSleet" value:@"" table:@"WeatherFrameworkLocalizableStrings"];
        case 8:
            return [self.weatherFrameworkBundle localizedStringForKey:@"WeatherConditionFreezingDrizzle" value:@"" table:@"WeatherFrameworkLocalizableStrings"];
        case 9:
            return [self.weatherFrameworkBundle localizedStringForKey:@"WeatherConditionDrizzle" value:@"" table:@"WeatherFrameworkLocalizableStrings"];
        case 10:
            return [self.weatherFrameworkBundle localizedStringForKey:@"WeatherConditionFreezingRain" value:@"" table:@"WeatherFrameworkLocalizableStrings"];
        case 11:
            return [self.weatherFrameworkBundle localizedStringForKey:@"WeatherConditionShowers1" value:@"" table:@"WeatherFrameworkLocalizableStrings"];
        case 12:
            return [self.weatherFrameworkBundle localizedStringForKey:@"WeatherConditionRain" value:@"" table:@"WeatherFrameworkLocalizableStrings"];
        case 13:
            return [self.weatherFrameworkBundle localizedStringForKey:@"WeatherConditionSnowFlurries" value:@"" table:@"WeatherFrameworkLocalizableStrings"];
        case 14:
            return [self.weatherFrameworkBundle localizedStringForKey:@"WeatherConditionSnowShowers" value:@"" table:@"WeatherFrameworkLocalizableStrings"];
        case 15:
            return [self.weatherFrameworkBundle localizedStringForKey:@"WeatherConditionBlowingSnow" value:@"" table:@"WeatherFrameworkLocalizableStrings"];
        case 16:
            return [self.weatherFrameworkBundle localizedStringForKey:@"WeatherConditionSnow" value:@"" table:@"WeatherFrameworkLocalizableStrings"];
        case 17:
            return [self.weatherFrameworkBundle localizedStringForKey:@"WeatherConditionHail" value:@"" table:@"WeatherFrameworkLocalizableStrings"];
        case 18:
            return [self.weatherFrameworkBundle localizedStringForKey:@"WeatherConditionSleet" value:@"" table:@"WeatherFrameworkLocalizableStrings"];
        case 19:
            return [self.weatherFrameworkBundle localizedStringForKey:@"WeatherConditionDust" value:@"" table:@"WeatherFrameworkLocalizableStrings"];
        case 20:
            return [self.weatherFrameworkBundle localizedStringForKey:@"WeatherConditionFog" value:@"" table:@"WeatherFrameworkLocalizableStrings"];
        case 21:
            return [self.weatherFrameworkBundle localizedStringForKey:@"WeatherConditionHaze" value:@"" table:@"WeatherFrameworkLocalizableStrings"];
        case 22:
            return [self.weatherFrameworkBundle localizedStringForKey:@"WeatherConditionSmoky" value:@"" table:@"WeatherFrameworkLocalizableStrings"];
        case 23:
            return [self.weatherFrameworkBundle localizedStringForKey:@"WeatherConditionFrigid" value:@"" table:@"WeatherFrameworkLocalizableStrings"];
        case 24:
            return [self.weatherFrameworkBundle localizedStringForKey:@"WeatherConditionWindy" value:@"" table:@"WeatherFrameworkLocalizableStrings"];
        case 25:
            return [self.weatherFrameworkBundle localizedStringForKey:@"WeatherConditionCold" value:@"" table:@"WeatherFrameworkLocalizableStrings"];
        case 26:
            return [self.weatherFrameworkBundle localizedStringForKey:@"WeatherConditionCloudy" value:@"" table:@"WeatherFrameworkLocalizableStrings"];
        case 27:
            return [self.weatherFrameworkBundle localizedStringForKey:@"WeatherConditionMostlyCloudyNight" value:@"" table:@"WeatherFrameworkLocalizableStrings"];
        case 28:
            return [self.weatherFrameworkBundle localizedStringForKey:@"WeatherConditionMostlyCloudyDay" value:@"" table:@"WeatherFrameworkLocalizableStrings"];
        case 29:
            return [self.weatherFrameworkBundle localizedStringForKey:@"WeatherConditionPartlyCloudyNight" value:@"" table:@"WeatherFrameworkLocalizableStrings"];
        case 30:
            return [self.weatherFrameworkBundle localizedStringForKey:@"WeatherConditionPartlyCloudyDay" value:@"" table:@"WeatherFrameworkLocalizableStrings"];
        case 31:
            return [self.weatherFrameworkBundle localizedStringForKey:@"WeatherConditionClearNight" value:@"" table:@"WeatherFrameworkLocalizableStrings"];
        case 32:
            return [self.weatherFrameworkBundle localizedStringForKey:@"WeatherConditionSunny" value:@"" table:@"WeatherFrameworkLocalizableStrings"];
        case 33:
            return [self.weatherFrameworkBundle localizedStringForKey:@"WeatherConditionMostlySunnyNight" value:@"" table:@"WeatherFrameworkLocalizableStrings"];
        case 34:
            return [self.weatherFrameworkBundle localizedStringForKey:@"WeatherConditionMostlySunnyDay" value:@"" table:@"WeatherFrameworkLocalizableStrings"];
        case 35:
            return [self.weatherFrameworkBundle localizedStringForKey:@"WeatherConditionMixedRainAndHail" value:@"" table:@"WeatherFrameworkLocalizableStrings"];
        case 36:
            return [self.weatherFrameworkBundle localizedStringForKey:@"WeatherConditionHot" value:@"" table:@"WeatherFrameworkLocalizableStrings"];
        case 37:
            return [self.weatherFrameworkBundle localizedStringForKey:@"WeatherConditionIsolatedThunderstorms" value:@"" table:@"WeatherFrameworkLocalizableStrings"];
        case 38:
            return [self.weatherFrameworkBundle localizedStringForKey:@"WeatherConditionScatteredThunderstorms" value:@"" table:@"WeatherFrameworkLocalizableStrings"];
        case 39:
            return [self.weatherFrameworkBundle localizedStringForKey:@"WeatherConditionScatteredThunderstorms" value:@"" table:@"WeatherFrameworkLocalizableStrings"];
        case 40:
            return [self.weatherFrameworkBundle localizedStringForKey:@"WeatherConditionScatteredShowers" value:@"" table:@"WeatherFrameworkLocalizableStrings"];
        case 41:
            return [self.weatherFrameworkBundle localizedStringForKey:@"WeatherConditionHeavySnow" value:@"" table:@"WeatherFrameworkLocalizableStrings"];
        case 42:
            return [self.weatherFrameworkBundle localizedStringForKey:@"WeatherConditionScatteredSnowShowers" value:@"" table:@"WeatherFrameworkLocalizableStrings"];
        case 43:
            return [self.weatherFrameworkBundle localizedStringForKey:@"WeatherConditionHeavySnow" value:@"" table:@"WeatherFrameworkLocalizableStrings"];
        case 44:
            return [self.weatherFrameworkBundle localizedStringForKey:@"WeatherConditionPartlyCloudy" value:@"" table:@"WeatherFrameworkLocalizableStrings"];
        case 45:
            return [self.weatherFrameworkBundle localizedStringForKey:@"WeatherConditionThundershowers" value:@"" table:@"WeatherFrameworkLocalizableStrings"];
        case 46:
            return [self.weatherFrameworkBundle localizedStringForKey:@"WeatherConditionSnowShowers" value:@"" table:@"WeatherFrameworkLocalizableStrings"];
        case 47:
            return [self.weatherFrameworkBundle localizedStringForKey:@"WeatherConditionIsolatedThundershowers" value:@"" table:@"WeatherFrameworkLocalizableStrings"];
        default:
            return @"";
    }
}

-(NSString*)translatedWindSpeedUnits {
    return [self.weatherFrameworkBundle localizedStringForKey:WeatherWindSpeedUnitForCurrentLocale() value:@"" table:@"WeatherFrameworkLocalizableStrings"];
}

#pragma mark Data access

-(int)currentTemperature {
    int temp = [currentCity.temperature intValue];
    
    // Need to convert to Farenheit ourselves annoyingly
    if (![[WeatherPreferences sharedPreferences] isCelsius])
        temp = ((temp*9)/5) + 32;
    
    return temp;
}

-(NSString*)currentLocation {
    return currentCity.name;
}

-(int)currentCondition {
    if (deviceVersion >= 7.0)
        return currentCity.conditionCode;
    else
        return currentCity.bigIcon;
}

-(NSString*)currentConditionAsString {
    return [self nameForCondition:[self currentCondition]];
}

-(int)highForCurrentDay {
    return [self calculateAverageTempIsHigh:YES];
}

-(int)lowForCurrentDay {
    return [self calculateAverageTempIsHigh:NO];
}

-(int)calculateAverageTempIsHigh:(BOOL)isHigh {
    DayForecast *forecast = [[currentCity dayForecasts] firstObject];
    int temp = [(isHigh ? forecast.high : forecast.low) intValue];
    
    // Need to convert to Farenheit ourselves annoyingly
    if (![[WeatherPreferences sharedPreferences] isCelsius])
        temp = ((temp*9)/5) + 32;
    
    return temp;
}

-(int)currentWindSpeed {
    return currentCity.windSpeed;
}

-(BOOL)isCelsius {
    return [[WeatherPreferences sharedPreferences] isCelsius];
}

-(BOOL)isWindSpeedMph {
    // TODO: Work out whether wind speed is in mph.
    return NO;
}

-(int)currentDewPoint {
    return (int)currentCity.dewPoint;
}

-(int)currentHumidity {
    return (int)currentCity.humidity;
}

-(int)currentWindChill {
    return [currentCity.windChill intValue];
}

-(int)currentVisibilityPercent {
    return (int)currentCity.visibility;
}

-(int)currentChanceOfRain {
    
}

-(int)currentlyFeelsLike {
    return (int)currentCity.feelsLike;
}

-(NSString*)intTimeToString:(int)input {
    NSString *string = @"";
    if (input < 100) {
        string = [NSString stringWithFormat:@"00%d", input];
    } else if (input < 1000) {
        string = [NSString stringWithFormat:@"0%d", input];
    } else {
        string = [NSString stringWithFormat:@"%d", input];
    }
    
    // Split string, and insert :
    
    string = [NSString stringWithFormat:@"%hu%hu:%hu%hu", [string characterAtIndex:0], [string characterAtIndex:1], [string characterAtIndex:2], [string characterAtIndex:3]];
    
    return string;
}

-(NSString*)sunsetTime {
    return [self intTimeToString:currentCity.sunsetTime];
}

-(NSString*)sunriseTime {
    return [self intTimeToString:currentCity.sunriseTime];
}

-(NSDate*)lastUpdateTime {
    return currentCity.updateTime;
}

-(CGFloat)currentLatitude {
    return currentCity.latitude;
}

-(CGFloat)currentLongitude {
    return currentCity.longitude;
}

-(CGFloat)currentPressure {
    return currentCity.pressure;
}

// Degrees
-(int)windDirection {
    return currentCity.windDirection;
}

-(NSArray*)dayForecastsForCurrentLocation {
    // The widget developer will be assuming this is the upcoming forecast for the week
    NSMutableArray *array = currentCity.dayForecasts;
    
    return array;
}

-(NSString*)dayForecastsForCurrentLocationJSON {
    NSMutableString *string = [@"[" mutableCopy];
    
    int i = 0;
    for (DayForecast *forecast in [[self dayForecastsForCurrentLocation] copy]) {
        i++;
        [string appendString:@"{"];
        
        [string appendFormat:@"\"dayNumber\":%d,", forecast.dayNumber];
        [string appendFormat:@"\"dayOfWeek\":%d,", forecast.dayOfWeek];
        [string appendFormat:@"\"condition\":%d,", forecast.icon];
        
        // Convert high and low to farenheit as needed
        int lattemp;
        if ([[WeatherPreferences sharedPreferences] isCelsius])
            lattemp = [forecast.high intValue];
        else
            lattemp = (([forecast.high intValue]*9)/5) + 32;
        [string appendFormat:@"\"high\":%d,", lattemp];
        
        if ([[WeatherPreferences sharedPreferences] isCelsius])
            lattemp = [forecast.low intValue];
        else
            lattemp = (([forecast.low intValue]*9)/5) + 32;
        [string appendFormat:@"\"low\":%d", lattemp];
        
        [string appendFormat:@"}%@", (i == [self dayForecastsForCurrentLocation].count ? @"" : @",")];
    }
    
    [string appendString:@"]"];
    
    return string;
}

-(NSString*)hourlyForecastsForCurrentLocationJSON {
    NSMutableString *string = [@"[" mutableCopy];
    
    int i = 0;
    for (HourlyForecast *forecast in [[self hourlyForecastsForCurrentLocation] copy]) {
        i++;
        [string appendString:@"{"];
        
        if ([forecast respondsToSelector:@selector(time24Hour)]) {
            [string appendFormat:@"\"time\":\"%@\",", forecast.time24Hour];
        } else {
            [string appendFormat:@"\"time\":\"%@\",", forecast.time];
        }
        
        // Convert temperature to farenheit
        NSString *detail;
        if ([forecast respondsToSelector:@selector(temperature)]) {
            detail = forecast.temperature;
        } else {
            detail = forecast.detail;
        }
        
        int lattemp;
        if ([[WeatherPreferences sharedPreferences] isCelsius])
            lattemp = [detail intValue];
        else
            lattemp = (([detail intValue]*9)/5) + 32;
        
        [string appendFormat:@"\"temperature\":%d,", lattemp];
        [string appendFormat:@"\"condition\":%d,", forecast.conditionCode];
        [string appendFormat:@"\"percentPrecipitation\":%d", (int)forecast.percentPrecipitation];
        
        [string appendFormat:@"}%@", (i == [self hourlyForecastsForCurrentLocation].count ? @"" : @",")];
    }
    
    [string appendString:@"]"];
    
    return string;
}

-(NSArray*)hourlyForecastsForCurrentLocation {
    NSMutableArray *array = currentCity.hourlyForecasts;
    
    return array;
}

@end
