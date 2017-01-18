//
//  ViewController.m
//  TestNCEDeom
//
//  Created by Radar on 2016/11/10.
//  Copyright © 2016年 Radar. All rights reserved.
//

#import "ViewController.h"
#import "RDUserNotifyCenter.h"
#import "RDPushSimuVC.h"
//#import <Dylib/Dylib.h>

@interface ViewController () <RDUserNotifyCenterDelegate>

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.navigationItem.title = @"Main";
    self.view.backgroundColor = [UIColor whiteColor];
    
    
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
    
    
    //推送模拟器入口
    UIButton *pushSimuBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    pushSimuBtn.frame = CGRectMake([UIScreen mainScreen].bounds.size.width-150, 0, 150, 50);
    pushSimuBtn.backgroundColor = [UIColor clearColor];
    [pushSimuBtn setTitle:@"推送模拟器-> " forState:UIControlStateNormal];
    [pushSimuBtn setTitleColor:[UIColor blueColor] forState:UIControlStateNormal];
    pushSimuBtn.titleLabel.font = [UIFont boldSystemFontOfSize:20];
    [pushSimuBtn addTarget:self action:@selector(pushSimuAction:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:pushSimuBtn];
    
    
}

- (void)viewDidAppear:(BOOL)animated
{
//    Person *per = [[Person alloc] init];
//    [per run];
}




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




#pragma mark -
#pragma mark 推送界面相关
- (void)pushSimuAction:(id)sender
{
    RDPushSimuVC *simuVC = [[RDPushSimuVC alloc] init];
    [self.navigationController pushViewController:simuVC animated:YES];
}






@end
