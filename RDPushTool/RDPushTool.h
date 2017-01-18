//
//  RDPushTool.h
//  TestNCEDeom
//
//  Created by Radar on 2016/12/15.
//  Copyright © 2016年 Radar. All rights reserved.
//
// 消息推送工具类
// 本类为单实例，api很简单不多介绍了

//注1: 必须修改本类初始化参数，设定开发和发布证书的文件名称和密码，并将该证书放在本类目录下面或者主工程目录下面，随工程一起打包
//注2: 通过接收NOTIFICATION_RDPUSHTOOL_REPORT对应的广播来获取连接、推送等状态的log
//注3: 通过appDelegate类中的 -application:didRegisterForRemoteNotificationsWithDeviceToken: 方法来获取deviceToken




#import <Foundation/Foundation.h>




#pragma mark -
#pragma mark 一些初始化参数配置
static NSString * const pkcs12FileName_development = @"pusher.p12";         //开发证书名      //Export your push certificate and key in PKCS12 format to pusher.p12 in the root of the project directory.
static NSString * const pkcs12Password_development = @"123456";             //证书密码      //Set the password of this .p12 file

static NSString * const pkcs12FileName_production  = @"pusher_production.p12";  //发布证书名
static NSString * const pkcs12Password_production  = @"123456";                 //证书密码




//log report的广播发送和接收标志宏
#define NOTIFICATION_RDPUSHTOOL_REPORT @"notification_rdpushtool_report"

//log report的状态宏
#define RDPushTool_report_status_readP12fail        @"读取P12文件失败"
#define RDPushTool_report_status_importP12fail      @"加载P12文件失败"
#define RDPushTool_report_status_disonnected        @"断开连接"
#define RDPushTool_report_status_connecting         @"正在连接"
#define RDPushTool_report_status_Connectsuccess     @"APNs连接成功"
#define RDPushTool_report_status_Connectfailure     @"APNs连接失败"
#define RDPushTool_report_status_pushing            @"payload推送中"
#define RDPushTool_report_status_pushsuccess        @"推送成功"
#define RDPushTool_report_status_pushfailure        @"推送失败"




#pragma mark -
#pragma mark PTConnectReport类  
typedef enum {
    PTConnectReportStatusConnecting       = 0,
    PTConnectReportStatusConnectSuccess   = 1,
    PTConnectReportStatusConnectFailure   = 2
} PTConnectReportStatus;

@interface PTConnectReport : NSObject

@property (nonatomic)       PTConnectReportStatus status;  //当前连接状态
@property (nonatomic, copy) NSString *summary;             //当前连接状态的描述文字

@end



#pragma mark -
#pragma mark PTPushReport类  
typedef enum {
    PTPushReportStatusPushing       = 0,
    PTPushReportStatusPushSuccess   = 1,
    PTPushReportStatusPushFailure   = 2
} PTPushReportStatus;

@interface PTPushReport : NSObject

@property (nonatomic)       PTPushReportStatus status;  //当前推送状态
@property (nonatomic, copy) NSDictionary *payload;      //推送的内容payload
@property (nonatomic, copy) NSString *deviceToken;      //当前推送目标的devicetoken
@property (nonatomic, copy) NSString *summary;          //当前推送状态的描述文字

@end






#pragma mark -
#pragma mark 主类
@interface RDPushTool : NSObject  
    
//单实例
+ (instancetype)sharedTool;


- (void)connect:(void(^)(PTConnectReport *report))completion; //连接到APNs，异步完成，通过返回状态判断是否连接成功 //PS: report不会为nil，外部可以不用判断容错
- (void)disconnect;                                //从APNs断开连结, 顺序完成，不需要异步处理

- (void)pushPayload:(NSDictionary *)payloadDic toToken:(NSString *)deviceToken completion:(void(^)(PTPushReport *report))completion; //推送消息，返回是否推送成功，可以连续推送，里边有队列，//PS: report不会为nil，外部可以不用判断容错


@end







