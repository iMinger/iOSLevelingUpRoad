//
//  AppDelegate.m
//  MultiThread
//
//  Created by minger on 2021/11/15.
//

#import "AppDelegate.h"
#import "ViewController.h"
@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    
    self.window                    = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.rootViewController = [[UINavigationController alloc]initWithRootViewController:[ViewController new]];
    self.window.backgroundColor    = [UIColor whiteColor];
    [self.window makeKeyAndVisible];
    return YES;
}





@end
