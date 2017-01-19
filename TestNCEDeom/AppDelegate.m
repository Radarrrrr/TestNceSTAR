//
//  AppDelegate.m
//  TestNCEDeom
//
//  Created by Radar on 2016/11/10.
//  Copyright © 2016年 Radar. All rights reserved.
//

#import "AppDelegate.h"
#import <UserNotifications/UserNotifications.h>
#import "ViewController.h"
#import "RDPushSimuVC.h"
#import "RDUserNotifyCenter.h"
#import <Home/Home.h>


@interface AppDelegate () <RDUserNotifyCenterDelegate>

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.

    //创建框架
    HomeViewController *mainVC = [[HomeViewController alloc] init];
    UINavigationController *mainNav = [[UINavigationController alloc] initWithRootViewController:mainVC];
    mainNav.navigationBarHidden = NO;
    mainNav.navigationBar.translucent = NO; //不要导航条模糊，为了让页面从导航条下部是0开始，如果为YES，则从屏幕顶部开始是0
    self.window.rootViewController = mainNav;
    
    
    //注册和使用通知相关-----------------------------------------------------------------------------------------------------
    //注册
    [[RDUserNotifyCenter sharedCenter] registerUserNotification:self completion:^(BOOL success) {
        //do sth..
    }];
    
    //绑定action到category
    [[RDUserNotifyCenter sharedCenter] prepareBindingActions];
    [[RDUserNotifyCenter sharedCenter] appendAction:@"action_enter" actionTitle:@"进去看看" options:UNNotificationActionOptionForeground toCategory:@"myNotificationCategory"];
    [[RDUserNotifyCenter sharedCenter] appendAction:@"action_exit" actionTitle:@"关闭" options:UNNotificationActionOptionDestructive toCategory:@"myNotificationCategory"];
    [[RDUserNotifyCenter sharedCenter] bindingActions];
    //---------------------------------------------------------------------------------------------------------------------
    
    
    
    //清空本地通知badge数量
    [UIApplication sharedApplication].applicationIconBadgeNumber = 0;
    
    
    return YES;
}


- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
}


- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}


- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
}


- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}


- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}





/***********************************************************************************************************/
#pragma mark - APNS
- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
{
//    NSString *newToken1 = [NSString stringWithFormat:@"%@",deviceToken];
//    //NSString *newToken2 = [newToken1 substringWithRange:NSMakeRange(1, [newToken1 length]-2)];
//    //NSString *newToken3 = [newToken2 stringByReplacingOccurrencesOfString:@" " withString:@""];
//    NSLog(@"Received token from Apple: %@",newToken1);
    
    NSString *deviceTokenStr = [[[[deviceToken description]
                                 stringByReplacingOccurrencesOfString:@"<" withString:@""]
                                 stringByReplacingOccurrencesOfString:@">" withString:@""]
                                 stringByReplacingOccurrencesOfString:@" " withString:@""];
    NSLog(@"deviceTokenSt:%@",deviceTokenStr);
    
    //给推送模拟器存一份
    [RDPushSimuVC saveAppDeviceToken:deviceTokenStr];
}

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error 
{
    NSLog(@"register APNS failed reason: %@", error.description);
}
/***********************************************************************************************************/



#pragma mark -
#pragma mark RDUserNotifyCenterDelegate 相关返回方法
- (void)didReceiveNotificationResponse:(UNNotificationResponse*)response content:(UNNotificationContent*)content isLocal:(BOOL)blocal
{
    NSString     *actionID      = response.actionIdentifier;
    //    NSString     *categoryID    = content.categoryIdentifier;
    //    NSDictionary *userInfo      = content.userInfo;
    
    
    if([actionID isEqualToString:@"com.apple.UNNotificationDefaultActionIdentifier"])
    {
        //点击内容窗口进来的
        NSLog(@"点击内容窗口进来的");
    }
    else
    {
        //点击自定义Action按钮进来的
        NSLog(@"点击自定义Action按钮进来的 actionID: %@", actionID);
    }
}



@end
