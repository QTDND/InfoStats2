//
//  IS2DaemonListener.m
//  
//
//  Created by Matt Clarke on 06/03/2016.
//
//

#import "IS2DaemonListener.h"
#import <notify.h>

static int weatherToken;
static int locationToken;

@implementation IS2DaemonListener

- (void)timerFireMethod:(NSTimer *)timer {
    int status, check;
    static char first = 0;
    if (!first) {
        status = notify_register_check("com.matchstic.infostats2/requestWeatherUpdate", &weatherToken);
        if (status != NOTIFY_STATUS_OK) {
            fprintf(stderr, "registration failed (%u)\n", status);
            return;
        }
        
        status = notify_register_check("com.matchstic.infostats2/requestLocationIntervalUpdate", &locationToken);
        if (status != NOTIFY_STATUS_OK) {
            fprintf(stderr, "registration failed (%u)\n", status);
            return;
        }
        
        first = 1;
        
        return; // We don't want to update the things on the first run, only when requested.
    }
    
    status = notify_check(weatherToken, &check);
    if (status == NOTIFY_STATUS_OK && check != 0) {
        NSLog(@"*** [InfoStats2 | Weather] :: Weather update request received.");
        
        dispatch_async(dispatch_get_main_queue(), ^(void){
            [self.weatherProvider updateWeather];
        });
    }
    
    status = notify_check(locationToken, &check);
    if (status == NOTIFY_STATUS_OK && check != 0) {
        NSLog(@"*** [InfoStats2 | Location] :: Location interval modification request received.");
        
        // Will have to pass values BACK via CPDistributedMessagingCenter
        uint64_t incoming;
        notify_get_state(locationToken, &incoming);
        
        dispatch_async(dispatch_get_main_queue(), ^(void){
            if (incoming == 7) {
                [self.locationProvider requestLocationUpdate];
            } else {
                [self.locationProvider setLocationUpdateInterval:incoming];
            }
        });
    }
}

@end