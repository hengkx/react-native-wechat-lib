//  Created by little-snow-fox on 2019-10-9.
#import "WXApiObject.h"
#import "WechatLib.h"
#import <React/RCTBridge.h>
#import <React/RCTEventDispatcher.h>
#import <React/RCTImageLoader.h>
#import <React/RCTLog.h>
#import "WechatAuthSDK.h"


@interface WechatLib () <WechatAuthAPIDelegate>
@property (nonatomic, strong) WechatAuthSDK *authSDK;
@property (nonatomic, strong) RCTResponseSenderBlock scanCallback;
@end

@implementation WechatLib

// Define error messages
#define NOT_REGISTERED (@"registerApp required.")
#define INVOKE_FAILED (@"WeChat API invoke returns false.")

@synthesize bridge = _bridge;

RCT_EXPORT_MODULE()

- (instancetype)init {
    self = [super init];
    if (self) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleOpenURL:) name:@"RCTOpenURLNotification" object:nil];
        self.authSDK = [[WechatAuthSDK alloc] init];
        self.authSDK.delegate = self;
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (BOOL)handleOpenURL:(NSNotification *)aNotification {
    NSString *aURLString = [aNotification userInfo][@"url"];
    NSURL *aURL = [NSURL URLWithString:aURLString];

    if ([WXApi handleOpenURL:aURL delegate:self]) {
        return YES;
    } else {
        return NO;
    }
}

- (dispatch_queue_t)methodQueue {
    return dispatch_get_main_queue();
}

+ (BOOL)requiresMainQueueSetup {
    return YES;
}

// 获取网络图片的公共方法
- (UIImage *)getImageFromURL:(NSString *)fileURL {
    UIImage *result;
    NSData *data = [NSData dataWithContentsOfURL:[NSURL URLWithString:fileURL]];
    result = [UIImage imageWithData:data];
    return result;
}

// 压缩图片
- (NSData *)compressImage:(UIImage *)image toByte:(NSUInteger)maxLength {
    // Compress by quality
    CGFloat compression = 1;
    NSData *data = UIImageJPEGRepresentation(image, compression);
    if (data.length < maxLength) return data;

    CGFloat max = 1;
    CGFloat min = 0;
    for (int i = 0; i < 6; ++i) {
        compression = (max + min) / 2;
        data = UIImageJPEGRepresentation(image, compression);
        if (data.length < maxLength * 0.9) {
            min = compression;
        } else if (data.length > maxLength) {
            max = compression;
        } else {
            break;
        }
    }
    UIImage *resultImage = [UIImage imageWithData:data];
    if (data.length < maxLength) return data;

    // Compress by size
    NSUInteger lastDataLength = 0;
    while (data.length > maxLength && data.length != lastDataLength) {
        lastDataLength = data.length;
        CGFloat ratio = (CGFloat)maxLength / data.length;
        CGSize size = CGSizeMake((NSUInteger)(resultImage.size.width * sqrtf(ratio)),
            (NSUInteger)(resultImage.size.height * sqrtf(ratio)));  // Use NSUInteger to prevent white blank
        UIGraphicsBeginImageContext(size);
        [resultImage drawInRect:CGRectMake(0, 0, size.width, size.height)];
        resultImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        data = UIImageJPEGRepresentation(resultImage, compression);
    }

    if (data.length > maxLength) {
        return [self compressImage:resultImage toByte:maxLength];
    }

    return data;
}

RCT_EXPORT_METHOD(registerApp
                  :(NSString *)appid
                  :(NSString *)universalLink
                  :(RCTResponseSenderBlock)callback) {
    self.appId = appid;
    callback(@[[WXApi registerApp:appid universalLink:universalLink] ? [NSNull null] : INVOKE_FAILED]);
}

// RCT_EXPORT_METHOD(registerAppWithDescription:(NSString *)appid
//                   :(NSString *)appdesc
//                   :(RCTResponseSenderBlock)callback)
// {
//     callback(@[[WXApi registerApp:appid withDescription:appdesc] ? [NSNull null] : INVOKE_FAILED]);
// }

RCT_EXPORT_METHOD(isWXAppInstalled:(RCTResponseSenderBlock)callback) {
    callback(@[[NSNull null], @([WXApi isWXAppInstalled])]);
}

RCT_EXPORT_METHOD(isWXAppSupportApi:(RCTResponseSenderBlock)callback) {
    callback(@[[NSNull null], @([WXApi isWXAppSupportApi])]);
}

RCT_EXPORT_METHOD(getWXAppInstallUrl:(RCTResponseSenderBlock)callback) {
    callback(@[[NSNull null], [WXApi getWXAppInstallUrl]]);
}

RCT_EXPORT_METHOD(getApiVersion:(RCTResponseSenderBlock)callback) {
    callback(@[[NSNull null], [WXApi getApiVersion]]);
}

RCT_EXPORT_METHOD(openWXApp:(RCTResponseSenderBlock)callback) {
    callback(@[([WXApi openWXApp] ? [NSNull null] : INVOKE_FAILED)]);
}

RCT_EXPORT_METHOD(sendRequest
                  :(NSString *)openid
                  :(RCTResponseSenderBlock)callback) {
    BaseReq *req = [[BaseReq alloc] init];
    req.openID = openid;
    // callback(@[[WXApi sendReq:req] ? [NSNull null] : INVOKE_FAILED]);
    void (^completion)(BOOL);
    completion = ^(BOOL success) {
        callback(@[success ? [NSNull null] : INVOKE_FAILED]);
        return;
    };
    [WXApi sendReq:req completion:completion];
}

RCT_EXPORT_METHOD(sendAuthRequest
                  :(NSString *)scope
                  :(NSString *)state
                  :(RCTResponseSenderBlock)callback) {
    SendAuthReq *req = [[SendAuthReq alloc] init];
    req.scope = scope;
    req.state = state;
    void (^completion)(BOOL);
    completion = ^(BOOL success) {
        callback(@[success ? [NSNull null] : INVOKE_FAILED]);
        return;
    };
    UIViewController *rootViewController = [UIApplication sharedApplication].keyWindow.rootViewController;
    [WXApi sendAuthReq:req viewController:rootViewController delegate:self completion:completion];
}

RCT_EXPORT_METHOD(sendSuccessResponse
                  :(RCTResponseSenderBlock)callback) {
    BaseResp *resp = [[BaseResp alloc] init];
    resp.errCode = WXSuccess;
    void (^completion)(BOOL);
    completion = ^(BOOL success) {
        callback(@[success ? [NSNull null] : INVOKE_FAILED]);
        return;
    };
    [WXApi sendResp:resp completion:completion];
    // callback(@[[WXApi sendResp:resp] ? [NSNull null] : INVOKE_FAILED]);
}

RCT_EXPORT_METHOD(sendErrorCommonResponse
                  :(NSString *)message
                  :(RCTResponseSenderBlock)callback) {
    BaseResp *resp = [[BaseResp alloc] init];
    resp.errCode = WXErrCodeCommon;
    resp.errStr = message;
    void (^completion)(BOOL);
    completion = ^(BOOL success) {
        callback(@[success ? [NSNull null] : INVOKE_FAILED]);
        return;
    };
    [WXApi sendResp:resp completion:completion];
    // callback(@[[WXApi sendResp:resp] ? [NSNull null] : INVOKE_FAILED]);
}

RCT_EXPORT_METHOD(sendErrorUserCancelResponse
                  :(NSString *)message
                  :(RCTResponseSenderBlock)callback) {
    BaseResp *resp = [[BaseResp alloc] init];
    resp.errCode = WXErrCodeUserCancel;
    resp.errStr = message;
    void (^completion)(BOOL);
    completion = ^(BOOL success) {
        callback(@[success ? [NSNull null] : INVOKE_FAILED]);
        return;
    };
    [WXApi sendResp:resp completion:completion];
    // callback(@[[WXApi sendResp:resp] ? [NSNull null] : INVOKE_FAILED]);
}

// 分享文本
RCT_EXPORT_METHOD(shareText
                  :(NSDictionary *)data
                  :(RCTResponseSenderBlock)callback) {
    SendMessageToWXReq *req = [[SendMessageToWXReq alloc] init];
    req.bText = YES;
    req.text = data[@"text"];
    req.scene = [data[@"scene"] intValue];
    void (^completion)(BOOL);
    completion = ^(BOOL success) {
        callback(@[success ? [NSNull null] : INVOKE_FAILED]);
        return;
    };
    [WXApi sendReq:req completion:completion];
}

// 选择发票
RCT_EXPORT_METHOD(chooseInvoice
                  :(NSDictionary *)data
                  :(RCTResponseSenderBlock)callback) {
    WXChooseInvoiceReq *req = [[WXChooseInvoiceReq alloc] init];
    req.appID = self.appId;
    req.timeStamp = [data[@"timeStamp"] intValue];
    req.nonceStr = data[@"nonceStr"];
    req.cardSign = data[@"cardSign"];
    req.signType = data[@"signType"];

    void (^completion)(BOOL);
    completion = ^(BOOL success) {
        callback(@[success ? [NSNull null] : INVOKE_FAILED]);
        return;
    };
    [WXApi sendReq:req completion:completion];
}

// 分享文件
RCT_EXPORT_METHOD(shareFile
                  :(NSDictionary *)data
                  :(RCTResponseSenderBlock)callback) {
    NSString *url = data[@"url"];
    WXFileObject *file = [[WXFileObject alloc] init];
    file.fileExtension = data[@"ext"];

    NSData *fileData;
    if ([url hasPrefix:@"http"]) {
        fileData = [NSData dataWithContentsOfURL:[NSURL URLWithString:url]];
    } else {
        fileData = [NSData dataWithContentsOfFile:url];
    }
    file.fileData = fileData;

    WXMediaMessage *message = [WXMediaMessage message];
    message.title = data[@"title"];
    message.mediaObject = file;

    SendMessageToWXReq *req = [[SendMessageToWXReq alloc] init];
    req.bText = NO;
    req.message = message;
    req.scene = [data[@"scene"] intValue];
    void (^completion)(BOOL);
    completion = ^(BOOL success) {
        callback(@[success ? [NSNull null] : INVOKE_FAILED]);
        return;
    };
    [WXApi sendReq:req completion:completion];
}

// 分享图片
RCT_EXPORT_METHOD(shareImage
                  :(NSDictionary *)data
                  :(RCTResponseSenderBlock)callback) {
    NSString *imageUrl = data[@"imageUrl"];
    if (imageUrl == NULL || [imageUrl isEqual:@""]) {
        callback([NSArray arrayWithObject:@"shareImage: The value of ImageUrl cannot be empty."]);
        return;
    }
    NSRange range = [imageUrl rangeOfString:@"."];
    if (range.length == 0) {
        callback([NSArray arrayWithObject:@"shareImage: ImageUrl value, Could not find file suffix."]);
        return;
    }

    // 根据路径下载图片
    UIImage *image = [self getImageFromURL:imageUrl];
    // 从 UIImage 获取图片数据
    NSData *imageData = UIImageJPEGRepresentation(image, 1);
    // 用图片数据构建 WXImageObject 对象
    WXImageObject *imageObject = [WXImageObject object];
    imageObject.imageData = imageData;

    WXMediaMessage *message = [WXMediaMessage message];
    // 利用原图压缩出缩略图，确保缩略图大小不大于 32KB
    message.thumbData = [self compressImage:image toByte:32678];
    message.mediaObject = imageObject;
    message.title = data[@"title"];
    message.description = data[@"description"];

    SendMessageToWXReq *req = [[SendMessageToWXReq alloc] init];
    req.bText = NO;
    req.message = message;
    req.scene = [data[@"scene"] intValue];
    //    [WXApi sendReq:req];
    void (^completion)(BOOL);
    completion = ^(BOOL success) {
        callback(@[success ? [NSNull null] : INVOKE_FAILED]);
        return;
    };
    [WXApi sendReq:req completion:completion];
}

// 分享本地图片
RCT_EXPORT_METHOD(shareLocalImage
                  :(NSDictionary *)data
                  :(RCTResponseSenderBlock)callback) {
    NSString *imageUrl = data[@"imageUrl"];
    if (imageUrl == NULL || [imageUrl isEqual:@""]) {
        callback([NSArray arrayWithObject:@"shareLocalImage: The value of ImageUrl cannot be empty."]);
        return;
    }
    NSRange range = [imageUrl rangeOfString:@"."];
    if (range.length == 0) {
        callback([NSArray arrayWithObject:@"shareLocalImage: ImageUrl value, Could not find file suffix."]);
        return;
    }

    // 根据路径下载图片
    UIImage *image = [UIImage imageWithContentsOfFile:imageUrl];
    // 从 UIImage 获取图片数据
    NSData *imageData = UIImageJPEGRepresentation(image, 1);
    // 用图片数据构建 WXImageObject 对象
    WXImageObject *imageObject = [WXImageObject object];
    imageObject.imageData = imageData;

    WXMediaMessage *message = [WXMediaMessage message];
    // 利用原图压缩出缩略图，确保缩略图大小不大于 32KB
    message.thumbData = [self compressImage:image toByte:32678];
    message.mediaObject = imageObject;
    message.title = data[@"title"];
    message.description = data[@"description"];

    SendMessageToWXReq *req = [[SendMessageToWXReq alloc] init];
    req.bText = NO;
    req.message = message;
    req.scene = [data[@"scene"] intValue];
    //    [WXApi sendReq:req];
    void (^completion)(BOOL);
    completion = ^(BOOL success) {
        callback(@[success ? [NSNull null] : INVOKE_FAILED]);
        return;
    };
    [WXApi sendReq:req completion:completion];
}

// 分享音乐
RCT_EXPORT_METHOD(shareMusic
                  :(NSDictionary *)data
                  :(RCTResponseSenderBlock)callback) {
    WXMusicObject *musicObject = [WXMusicObject object];
    musicObject.musicUrl = data[@"musicUrl"];
    musicObject.musicLowBandUrl = data[@"musicLowBandUrl"];
    musicObject.musicDataUrl = data[@"musicDataUrl"];
    musicObject.musicLowBandDataUrl = data[@"musicLowBandDataUrl"];

    WXMediaMessage *message = [WXMediaMessage message];
    message.title = data[@"title"];
    message.description = data[@"description"];
    NSString *thumbImageUrl = data[@"thumbImageUrl"];
    if (thumbImageUrl != NULL && ![thumbImageUrl isEqual:@""]) {
        // 根据路径下载图片
        UIImage *image = [self getImageFromURL:thumbImageUrl];
        message.thumbData = [self compressImage:image toByte:32678];
    }
    message.mediaObject = musicObject;
    SendMessageToWXReq *req = [[SendMessageToWXReq alloc] init];
    req.bText = NO;
    req.message = message;
    req.scene = [data[@"scene"] intValue];
    void (^completion)(BOOL);
    completion = ^(BOOL success) {
        callback(@[success ? [NSNull null] : INVOKE_FAILED]);
        return;
    };
    [WXApi sendReq:req completion:completion];
}

// 分享视频
RCT_EXPORT_METHOD(shareVideo
                  :(NSDictionary *)data
                  :(RCTResponseSenderBlock)callback) {
    WXVideoObject *videoObject = [WXVideoObject object];
    videoObject.videoUrl = data[@"videoUrl"];
    videoObject.videoLowBandUrl = data[@"videoLowBandUrl"];
    WXMediaMessage *message = [WXMediaMessage message];
    message.title = data[@"title"];
    message.description = data[@"description"];
    NSString *thumbImageUrl = data[@"thumbImageUrl"];
    if (thumbImageUrl != NULL && ![thumbImageUrl isEqual:@""]) {
        UIImage *image = [self getImageFromURL:thumbImageUrl];
        message.thumbData = [self compressImage:image toByte:32678];
    }
    message.mediaObject = videoObject;
    SendMessageToWXReq *req = [[SendMessageToWXReq alloc] init];
    req.bText = NO;
    req.message = message;
    req.scene = [data[@"scene"] intValue];
    void (^completion)(BOOL);
    completion = ^(BOOL success) {
        callback(@[success ? [NSNull null] : INVOKE_FAILED]);
        return;
    };
    [WXApi sendReq:req completion:completion];
}
// 分享网页
RCT_EXPORT_METHOD(shareWebpage
                  :(NSDictionary *)data
                  :(RCTResponseSenderBlock)callback) {
    WXWebpageObject *webpageObject = [WXWebpageObject object];
    webpageObject.webpageUrl = data[@"webpageUrl"];
    WXMediaMessage *message = [WXMediaMessage message];
    message.title = data[@"title"];
    message.description = data[@"description"];
    NSString *thumbImageUrl = data[@"thumbImageUrl"];
    if (thumbImageUrl != NULL && ![thumbImageUrl isEqual:@""]) {
        UIImage *image = [self getImageFromURL:thumbImageUrl];
        message.thumbData = [self compressImage:image toByte:32678];
    }
    message.mediaObject = webpageObject;
    SendMessageToWXReq *req = [[SendMessageToWXReq alloc] init];
    req.bText = NO;
    req.message = message;
    req.scene = [data[@"scene"] intValue];
    void (^completion)(BOOL);
    completion = ^(BOOL success) {
        callback(@[success ? [NSNull null] : INVOKE_FAILED]);
        return;
    };
    [WXApi sendReq:req completion:completion];
}

// 分享小程序
RCT_EXPORT_METHOD(shareMiniProgram
                  :(NSDictionary *)data
                  :(RCTResponseSenderBlock)callback) {
    WXMiniProgramObject *object = [WXMiniProgramObject object];
    object.webpageUrl = data[@"webpageUrl"];
    object.userName = data[@"userName"];
    object.path = data[@"path"];
    NSString *hdImageUrl = data[@"hdImageUrl"];
    if (hdImageUrl != NULL && ![hdImageUrl isEqual:@""]) {
        UIImage *image = [self getImageFromURL:hdImageUrl];
        // 压缩图片到小于 128KB
        object.hdImageData = [self compressImage:image toByte:131072];
    }
    object.withShareTicket = data[@"withShareTicket"];
    int miniProgramType = [data[@"miniProgramType"] integerValue];
    object.miniProgramType = [self integerToWXMiniProgramType:miniProgramType];
    WXMediaMessage *message = [WXMediaMessage message];
    message.title = data[@"title"];
    message.description = data[@"description"];
    // 兼容旧版本节点的图片，小于 32KB，新版本优先
    // 使用 WXMiniProgramObject 的 hdImageData 属性
    NSString *thumbImageUrl = data[@"thumbImageUrl"];
    if (thumbImageUrl != NULL && ![thumbImageUrl isEqual:@""]) {
        UIImage *image = [self getImageFromURL:thumbImageUrl];
        message.thumbData = [self compressImage:image toByte:32678];
    }
    message.mediaObject = object;
    SendMessageToWXReq *req = [[SendMessageToWXReq alloc] init];
    req.bText = NO;
    req.message = message;
    req.scene = [data[@"scene"] integerValue];
    void (^completion)(BOOL);
    completion = ^(BOOL success) {
        callback(@[success ? [NSNull null] : INVOKE_FAILED]);
        return;
    };
    [WXApi sendReq:req completion:completion];
}

// 一次性订阅消息
RCT_EXPORT_METHOD(subscribeMessage
                  :(NSDictionary *)data
                  :(RCTResponseSenderBlock)callback) {
    WXSubscribeMsgReq *req = [[WXSubscribeMsgReq alloc] init];
    req.scene = [data[@"scene"] integerValue];
    req.templateId = data[@"templateId"];
    req.reserved = data[@"reserved"];
    void (^completion)(BOOL);
    completion = ^(BOOL success) {
        callback(@[success ? [NSNull null] : INVOKE_FAILED]);
        return;
    };
    [WXApi sendReq:req completion:completion];
}

RCT_EXPORT_METHOD(launchMiniProgram
                  :(NSDictionary *)data
                  :(RCTResponseSenderBlock)callback) {
    WXLaunchMiniProgramReq *launchMiniProgramReq = [WXLaunchMiniProgramReq object];
    // 拉起的小程序的 username
    launchMiniProgramReq.userName = data[@"userName"];
    // 拉起小程序页面的可带参路径，不填默认拉起小程序首页
    launchMiniProgramReq.path = data[@"path"];
    // 拉起小程序的类型
    int miniProgramType = [data[@"miniProgramType"] integerValue];
    launchMiniProgramReq.miniProgramType = [self integerToWXMiniProgramType:miniProgramType];
    // launchMiniProgramReq.miniProgramType = [data[@"miniProgramType"] integerValue];
    void (^completion)(BOOL);
    completion = ^(BOOL success) {
        callback(@[success ? [NSNull null] : INVOKE_FAILED]);
        return;
    };
    [WXApi sendReq:launchMiniProgramReq completion:completion];
    // BOOL success = [WXApi sendReq:launchMiniProgramReq];
    // callback(@[success ? [NSNull null] : INVOKE_FAILED]);
}

RCT_EXPORT_METHOD(pay
                  :(NSDictionary *)data
                  :(RCTResponseSenderBlock)callback) {
    PayReq *req = [PayReq new];
    req.partnerId = data[@"partnerId"];
    req.prepayId = data[@"prepayId"];
    req.nonceStr = data[@"nonceStr"];
    req.timeStamp = [data[@"timeStamp"] unsignedIntValue];
    req.package = data[@"package"];
    req.sign = data[@"sign"];
    void (^completion)(BOOL);
    completion = ^(BOOL success) {
        callback(@[success ? [NSNull null] : INVOKE_FAILED]);
        return;
    };
    [WXApi sendReq:req completion:completion];
    // BOOL success = [WXApi sendReq:req];
    // callback(@[success ? [NSNull null] : INVOKE_FAILED]);
}

// 跳转微信客服
RCT_EXPORT_METHOD(openCustomerServiceChat
                  :(NSString *)corpId
                  :(NSString *)kfUrl
                  :(RCTResponseSenderBlock)callback) {
    WXOpenCustomerServiceReq *req = [[WXOpenCustomerServiceReq alloc] init];
    req.corpid = corpId;  // 企业 ID
    req.url = kfUrl;  // 客服 URL
    [WXApi sendReq:req completion:nil];
}

#pragma mark - wx callback

- (void)onReq:(BaseReq *)req {
    if ([req isKindOfClass:[LaunchFromWXReq class]]) {
        LaunchFromWXReq *launchReq = req;
        NSString *appParameter = launchReq.message.messageExt;
        NSMutableDictionary *body = @{ @"errCode": @0 }.mutableCopy;
        body[@"type"] = @"LaunchFromWX.Req";
        body[@"lang"] = launchReq.lang;
        body[@"country"] = launchReq.country;
        body[@"extMsg"] = appParameter;
        [self.bridge.eventDispatcher sendDeviceEventWithName:RCTWXEventNameWeChatReq body:body];
    }
}

- (void)onResp:(BaseResp *)resp {
    if ([resp isKindOfClass:[SendMessageToWXResp class]]) {
        SendMessageToWXResp *r = (SendMessageToWXResp *)resp;

        NSMutableDictionary *body = @{ @"errCode": @(r.errCode) }.mutableCopy;
        body[@"errStr"] = r.errStr;
        body[@"lang"] = r.lang;
        body[@"country"] = r.country;
        body[@"type"] = @"SendMessageToWX.Resp";
        [self.bridge.eventDispatcher sendDeviceEventWithName:RCTWXEventName body:body];
    } else if ([resp isKindOfClass:[SendAuthResp class]]) {
        SendAuthResp *r = (SendAuthResp *)resp;
        NSMutableDictionary *body = @{ @"errCode": @(r.errCode) }.mutableCopy;
        body[@"errStr"] = r.errStr;
        body[@"state"] = r.state;
        body[@"lang"] = r.lang;
        body[@"country"] = r.country;
        body[@"type"] = @"SendAuth.Resp";

        if (resp.errCode == WXSuccess) {
            if (self.appId && r) {
                // ios 第一次获取不到 appid 会卡死，加个判断 OK
                [body addEntriesFromDictionary:@{ @"appid": self.appId, @"code": r.code }];
                [self.bridge.eventDispatcher sendDeviceEventWithName:RCTWXEventName body:body];
            }
        } else {
            [self.bridge.eventDispatcher sendDeviceEventWithName:RCTWXEventName body:body];
        }
    } else if ([resp isKindOfClass:[PayResp class]]) {
        PayResp *r = (PayResp *)resp;
        NSMutableDictionary *body = @{ @"errCode": @(r.errCode) }.mutableCopy;
        body[@"errStr"] = r.errStr;
        body[@"type"] = @(r.type);
        body[@"returnKey"] = r.returnKey;
        body[@"type"] = @"PayReq.Resp";
        [self.bridge.eventDispatcher sendDeviceEventWithName:RCTWXEventName body:body];
    } else if ([resp isKindOfClass:[WXLaunchMiniProgramResp class]]) {
        WXLaunchMiniProgramResp *r = (WXLaunchMiniProgramResp *)resp;
        NSMutableDictionary *body = @{ @"errCode": @(r.errCode) }.mutableCopy;
        body[@"errStr"] = r.errStr;
        body[@"extMsg"] = r.extMsg;
        body[@"type"] = @"WXLaunchMiniProgramReq.Resp";
        [self.bridge.eventDispatcher sendDeviceEventWithName:RCTWXEventName body:body];
    } else if ([resp isKindOfClass:[WXChooseInvoiceResp class]]) {
        WXChooseInvoiceResp *r = (WXChooseInvoiceResp *)resp;
        NSMutableDictionary *body = @{ @"errCode": @(r.errCode) }.mutableCopy;
        body[@"errStr"] = r.errStr;
        NSMutableArray *arr = [[NSMutableArray alloc] init];
        for (WXCardItem *cardItem in r.cardAry) {
            NSMutableDictionary *item = @{ @"cardId": cardItem.cardId, @"encryptCode": cardItem.encryptCode, @"appId": cardItem.appID }.mutableCopy;
            [arr addObject:item];
        }
        body[@"cards"] = arr;
        body[@"type"] = @"WXChooseInvoiceResp.Resp";
        [self.bridge.eventDispatcher sendDeviceEventWithName:RCTWXEventName body:body];
    }
}

- (WXMiniProgramType)integerToWXMiniProgramType:(int)value {
    WXMiniProgramType type = WXMiniProgramTypeRelease;
    switch (value) {
        case 0:
            type = WXMiniProgramTypeRelease;
            break;
        case 1:
            type = WXMiniProgramTypeTest;
            break;
        case 2:
            type = WXMiniProgramTypePreview;
            break;
    }
    return type;
}

#pragma mark - WechatAuthAPIDelegate

RCT_EXPORT_METHOD(addListener:(NSString *)eventName) {
    
}

RCT_EXPORT_METHOD(removeListeners:(double)count) {
    
}

RCT_EXPORT_METHOD(authByScan:(NSString *)appid
                  nonceStr:(NSString *)nonceStr
                 timeStamp:(NSString *)timeStamp
                     scope:(NSString *)scope
                 signature:(NSString *)signature
                schemeData:(nullable NSString *)schemeData
                  callback:(RCTResponseSenderBlock)callback) {
    self.scanCallback = callback;
    [self.authSDK StopAuth];
    [self.authSDK Auth:appid nonceStr:nonceStr timeStamp:timeStamp scope:scope signature:signature schemeData:schemeData];
}

//得到二维码
- (void)onAuthGotQrcode:(UIImage *)image {
    NSLog(@"onAuthGotQrcode");
    NSData *imageData = UIImagePNGRepresentation(image);
    if (!imageData) {
        imageData = UIImageJPEGRepresentation(image, 1);
    }
    NSString *base64String = [imageData base64EncodedStringWithOptions:0];
    [self.bridge.eventDispatcher sendDeviceEventWithName:@"onAuthGotQrcode" body:@{@"qrcode": base64String}];
}

//二维码被扫描
- (void)onQrcodeScanned {
    NSLog(@"onQrcodeScanned");
}

//成功登录
- (void)onAuthFinish:(int)errCode AuthCode:(nullable NSString *)authCode {
    NSLog(@"onAuthFinish");
    if (self.scanCallback) {
        self.scanCallback(@[[NSNull null], @{@"authCode": authCode?:@"", @"errCode": @(errCode)}]);
        self.scanCallback = nil;
    }
}

- (NSArray<NSString *> *)supportedEvents
{
  return @[@"onAuthGotQrcode", @"onQrcodeScanned", @"onAuthFinish"];
}

@end
