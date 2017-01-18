//
//  RDPushSimuVC.h
//  TestNCEDeom
//
//  Created by Radar on 2016/12/19.
//  Copyright © 2016年 Radar. All rights reserved.
//
// RDPushTool的模拟推送页面，用于测试和模拟推送使用. 真正推送和接收，可以不使用此页面。

//注: 本页面以iphone7plus为标准开发，没有适配iPhone5，部分UI显示可能不正确
//注: 建议通过push方式使用本页面



/* payload默认使用的推送结构
{
    "aps":
    {
        "alert":
        {
            "title":"我是原装标题",
            "subtitle":"我是副标题",
            "body":"it is a beautiful day"
        },
        "badge":1,
        "sound":"default",
        "mutable-content":"1",
        "category":"myNotificationCategory",
        "attach":"https://picjumbo.imgix.net/HNCK8461.jpg?q=40&w=200&sharp=30"
    },
    "goto_page":"cms://page_id=14374"
}
*/



#import <UIKit/UIKit.h>
#import "RDPushTool.h"

@interface RDPushSimuVC : UIViewController

//PS: 模拟器内部会如果不调用此方法，也可以在模拟器内部自行指定任何devicetoken作为推送目标
//PS: 本方法一般使用在appDelegate的 - (void)application:didRegisterForRemoteNotificationsWithDeviceToken: 方法里，获取到注册token以后及时保存，重装app以后token会变，所以必须每次都保存
+ (void)saveAppDeviceToken:(NSString *)deviceToken;  //保存主工程app的devicetoken，用来在本类内部当作默认推送目标使用，


@end













