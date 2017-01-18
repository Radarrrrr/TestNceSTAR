//
//  RDPushTool.m
//  TestNCEDeom
//
//  Created by Radar on 2016/12/15.
//  Copyright © 2016年 Radar. All rights reserved.
//

#import "RDPushTool.h"
#import "NWHub.h"
#import "NWLCore.h"
#import "NWNotification.h"
#import "NWPusher.h"
#import "NWSSLConnection.h"
#import "NWSecTools.h"



//工具宏
#define PTSTRVALID(str)   [RDPushTool checkStringValid:str]   //检查一个字符串是否有效



#pragma mark -
#pragma mark PTConnectReport类  
@implementation PTConnectReport 
@end


#pragma mark -
#pragma mark PTPushReport类  
@implementation PTPushReport 
@end




#pragma mark -
#pragma mark 主类
@interface RDPushTool () <NWHubDelegate>

@property (nonatomic, strong) NWHub *hub;
@property (nonatomic) NSUInteger index;
@property (nonatomic) dispatch_queue_t serial;

@property (nonatomic) NWIdentityRef identity;
@property (nonatomic) NWCertificateRef certificate;

@property (nonatomic, copy) void(^pushCompletionBlock)(PTPushReport *report);

@end



@implementation RDPushTool

- (id)init{
    self = [super init];
    if(self){
        //do something
        [self initProperties];
    }
    return self;
}

+ (instancetype)sharedTool
{
    static dispatch_once_t onceToken;
    static RDPushTool *tool;
    dispatch_once(&onceToken, ^{
        tool = [[RDPushTool alloc] init];
    });
    return tool;
}





#pragma mark -
#pragma mark 内部配套工具方法
+ (BOOL)checkStringValid:(NSString *)string
{
    if(!string) return NO;
    if(![string isKindOfClass:[NSString class]]) return NO;
    if([string compare:@""] == NSOrderedSame) return NO;
    if([string compare:@"(null)"] == NSOrderedSame) return NO;
    
    return YES;
}

+ (NSString *)jsonFromDictionary:(NSDictionary *)dic
{
    //本类内部只需要字典和字符串之间转换，不考虑数组
    if(!dic || ![dic isKindOfClass:[NSDictionary class]]) return nil;
    
    NSString *jsonString = nil;
    
    if([NSJSONSerialization isValidJSONObject:dic])  
    {   
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dic options:NSJSONWritingPrettyPrinted error:nil];  
        jsonString =[[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];  
    }  
    
    return jsonString;
}

+ (NSDictionary *)dictionaryFromJson:(NSString *)json
{
    if(!PTSTRVALID(json)) return nil;
    
    NSData *jsonData = [json dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:jsonData options:kNilOptions error:nil];  
    
    return dic;
}

- (void)broadCastToolReportStatus:(NSString *)status summary:(NSString *)summary
{
    //@{@"status":"xxxxx", @"summary":"xxxxx"}
    
    if(!PTSTRVALID(status)) return;
    
    NSMutableDictionary *reportDic = [[NSMutableDictionary alloc] init];
    
    [reportDic setObject:status forKey:@"status"];
    if(PTSTRVALID(summary))
    {
        [reportDic setObject:summary forKey:@"summary"];
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_RDPUSHTOOL_REPORT object:reportDic userInfo:nil];
}




#pragma mark -
#pragma mark 内部使用的数据相关方法
- (void)initProperties
{
    //初始化一些属性
    self.serial = dispatch_queue_create("RDPushTool", DISPATCH_QUEUE_SERIAL);
    [self loadCertificate];
    
}
- (void)loadCertificate
{
    NSString *p12FileName = nil;
    NSString *p12Password = nil;
    
#ifdef DEBUG
    p12FileName = pkcs12FileName_development;
    p12Password = pkcs12Password_development;
#else
    p12FileName = pkcs12FileName_production;
    p12Password = pkcs12Password_production;
#endif
    
    
    NSURL *url = [NSBundle.mainBundle URLForResource:p12FileName withExtension:nil];
    NSData *pkcs12 = [NSData dataWithContentsOfURL:url];
    NSError *error = nil;
    
    NSArray *ids = [NWSecTools identitiesWithPKCS12Data:pkcs12 password:p12Password error:&error];
    if (!ids) {
        NSLog(@"Unable to read p12 file: %@", error.localizedDescription);
        
        [self broadCastToolReportStatus:RDPushTool_report_status_readP12fail summary:error.localizedDescription];
        
        return;
    }
    for (NWIdentityRef identity in ids) {
        NSError *error = nil;
        NWCertificateRef certificate = [NWSecTools certificateWithIdentity:identity error:&error];
        if (!certificate) {
            NSLog(@"Unable to import p12 file: %@", error.localizedDescription);
                        
            [self broadCastToolReportStatus:RDPushTool_report_status_importP12fail summary:error.localizedDescription];
            
            return;
        }
        
        self.identity = identity;
        self.certificate = certificate;
    }
}





#pragma mark -
#pragma mark 连结及推送操作相关
- (void)connect:(void(^)(PTConnectReport *report))completion
{    
    //连结APNs
    if(_hub)
    {
        if(completion)
        {
            PTConnectReport *report = [[PTConnectReport alloc] init];
            report.status = PTConnectReportStatusConnectSuccess;
            report.summary = @"connect success!...";
            
            completion(report);
        }
        return; 
    }
    
    NWEnvironment preferredEnvironment = [self preferredEnvironmentForCertificate:_certificate];
    [self connectingToEnvironment:preferredEnvironment completion:^(PTConnectReport *report) {
        if(completion)
        {
            completion(report);
        }
    }];
}

- (void)disconnect
{
    //从APNs断开连结
    if(_hub)
    {
        [_hub disconnect]; 
        self.hub = nil;
    }
    NSLog(@"Disconnected");
    
    [self broadCastToolReportStatus:RDPushTool_report_status_disonnected summary:nil];
    
}


- (NWEnvironment)preferredEnvironmentForCertificate:(NWCertificateRef)certificate
{
    //自动根据证书类型，返回环境类型，devlopment或者是production
    NWEnvironmentOptions environmentOptions = [NWSecTools environmentOptionsForCertificate:certificate];
    return (environmentOptions & NWEnvironmentOptionSandbox) ? NWEnvironmentSandbox : NWEnvironmentProduction;
}

- (void)connectingToEnvironment:(NWEnvironment)environment completion:(void(^)(PTConnectReport *report))completion
{    
    __block PTConnectReport *report = [[PTConnectReport alloc] init];
    
    //连接到对应的环境    
    NSLog(@"Connecting..");
    
    NSString *apnsServer = [NWSecTools summaryWithCertificate:_certificate];
    NSString *apnsEnviro = descriptionForEnvironent(environment);
    NSString *summary = [NSString stringWithFormat:@"%@ (%@)", apnsServer, apnsEnviro];
    
    [self broadCastToolReportStatus:RDPushTool_report_status_connecting summary:summary];
    
    report.status = PTConnectReportStatusConnecting;
    report.summary = summary;
    if(completion)
    {
        completion(report);
    }
    
    
    //连接结果
    dispatch_async(_serial, ^{
        NSError *error = nil;
        
        NWHub *hub = [NWHub connectWithDelegate:self identity:_identity environment:environment error:&error];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            NSString *msgStatus = nil;
            NSString *msgSummary = nil;
            
            if(hub) 
            {                
                self.hub = hub;
                NSLog(@"Connected to APN: %@", summary);

                msgStatus = RDPushTool_report_status_Connectsuccess;
                msgSummary = summary;
                
                report.status = PTConnectReportStatusConnectSuccess;
                report.summary = summary;
            } 
            else 
            {
                NSLog(@"Unable to connect: %@", error.localizedDescription);

                msgStatus = RDPushTool_report_status_Connectfailure;
                msgSummary = error.localizedDescription;
                
                
                report.status = PTConnectReportStatusConnectFailure;
                report.summary = error.localizedDescription;
            }
            
            [self broadCastToolReportStatus:msgStatus summary:msgSummary];
            
            if(completion)
            {
                completion(report);
            }
    
        });
    });
}


- (void)pushThePayload:(NSDictionary *)payloadDic toToken:(NSString *)deviceToken completion:(void(^)(PTPushReport *report))completion
{
    //如果连接都没有建立起来
    if(!_hub)
    {
        NSLog(@"push failure...no connection with apns!");
        
        PTPushReport *report = [[PTPushReport alloc] init];
        report.payload = payloadDic;
        report.deviceToken = deviceToken;
        report.status = PTPushReportStatusPushFailure;
        report.summary = @"push failure，no connection with apns!";
                
        [self broadCastToolReportStatus:RDPushTool_report_status_pushfailure summary:@"没有与APNs建立连接"];
        
        if(completion)
        {
            completion(report);
        }
        
        return;
    }
    
    
    //接一下block
    self.pushCompletionBlock = completion;
    
    //创建report
    __block PTPushReport *report = [[PTPushReport alloc] init];
    report.payload = payloadDic;
    report.deviceToken = deviceToken;
    
    //推送payload
    if(!payloadDic || ![payloadDic isKindOfClass:[NSDictionary class]] || !PTSTRVALID(deviceToken)) 
    {
        NSLog(@"push failure...input parameters error!");
        
        [self broadCastToolReportStatus:RDPushTool_report_status_pushfailure summary:@"传入参数错误"];
        
        report.status = PTPushReportStatusPushFailure;
        report.summary = @"push failure，input parameters error!";
        if(completion)
        {
            completion(report);
        }
        
        return;
    }
    
    
    //设定参数    
    NSString *payload = [RDPushTool jsonFromDictionary:payloadDic];
    NSString *token = deviceToken;
    
    
    //开始推送
    NSLog(@"Pushing..");
        
    [self broadCastToolReportStatus:RDPushTool_report_status_pushing summary:nil];
    
    report.status = PTPushReportStatusPushing;
    report.summary = @"payload pushing...";
    if(completion)
    {
        completion(report);
    }
    
    
    //获取推送结果
    dispatch_async(_serial, ^{
        NSUInteger failed = [_hub pushPayload:payload token:token]; 
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC));
        dispatch_after(popTime, _serial, ^(void){
            
            dispatch_async(dispatch_get_main_queue(), ^{
                BOOL pushed = NO;
                NSString *msgStatus = RDPushTool_report_status_pushfailure;
                
                report.status = PTPushReportStatusPushFailure;
                report.summary = @"payload push failure...";
                
                NSUInteger failed2 = failed + [_hub readFailed];
                if(!failed2) 
                {
                    pushed = YES;
                    
                    NSLog(@"Payload has been pushed");
                    msgStatus = RDPushTool_report_status_pushsuccess;
                    
                    report.status = PTPushReportStatusPushSuccess;
                    report.summary = @"payload push success!...";
                }
                                
                [self broadCastToolReportStatus:msgStatus summary:nil];
                
                if(completion)
                {
                    completion(report);
                }
            });
            
        });
    });
}


- (void)pushPayload:(NSDictionary *)payloadDic toToken:(NSString *)deviceToken completion:(void(^)(PTPushReport *report))completion
{
    __weak RDPushTool *weakSelf = self;
    
    [self pushThePayload:payloadDic toToken:deviceToken completion:^(PTPushReport *pushReport) {
        
        __strong RDPushTool *sSelf = weakSelf;
        if(pushReport.status == PTPushReportStatusPushing || pushReport.status == PTPushReportStatusPushSuccess)
        {
            //推送中或者推送成功，直接返回
            if(completion)
            {
                completion(pushReport);
            }
        }
        else
        {
            //如果推送失败，则重连一次，重新推送
            [sSelf disconnect];
            [sSelf connect:^(PTConnectReport *connectReport) {
                
                __strong RDPushTool *ssSelf = sSelf;
                if(connectReport.status == PTConnectReportStatusConnectSuccess)
                {
                    //如果重连成功，则再次推送，这次不管推送成功与否，都返回
                    [ssSelf pushThePayload:payloadDic toToken:deviceToken completion:^(PTPushReport *report) {
                        if(completion)
                        {
                            completion(report);
                        }
                    }];
                }
                else if(connectReport.status == PTConnectReportStatusConnectFailure)
                {
                    //如果重连失败，则返回推送失败
                    if(completion)
                    {
                        completion(pushReport);
                    }
                }
                else
                {
                    //do nothing
                }
            }];
        }
    }];
    
}




#pragma mark -
#pragma mark NWHubDelegate返回方法
- (void)notification:(NWNotification *)notification didFailWithError:(NSError *)error
{
    //推送失败进这里
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"Notification error: %@", error.localizedDescription);
                
        [self broadCastToolReportStatus:RDPushTool_report_status_pushfailure summary:error.localizedDescription];
        
        
        PTPushReport *report = [[PTPushReport alloc] init];
        report.status = PTPushReportStatusPushFailure;
        report.summary = error.localizedDescription;
        
        if(notification)
        {
            report.payload = [RDPushTool dictionaryFromJson:notification.payload];
            report.deviceToken = notification.token;
        }
        
        if(_pushCompletionBlock)
        {
            _pushCompletionBlock(report);
        }
        
    });
}







@end
