//
//  FSBLEService.h
//
//  Created by forget on 2020/6/30.
//  Copyright © 2020 forget. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

static NSString *const kOpenTranslateKey   = @"openTranslate";
static NSString *const kSourceLanguageKey  = @"sourceLanguage";
static NSString *const kTargetLanguageKey  = @"targetLanguage";
static NSString *const kSourceTextKey      = @"sourceText";
static NSString *const kTranslateTextKey   = @"translateText";

/// 10分种休眠指令
static NSString *const kDormancyTimeCommon   = @"ABAAAAAB";
/// 60分种休眠指令
static NSString *const kDormancyTimeRecord   = @"ACAAAAAC";

@interface FSBLEService : NSObject

@property (strong, nonatomic) NSString *androidId;

+ (instancetype)shared;
- (void)connectDevice;

- (void)sendToBLE:(NSString *)result;
- (void)updateBLEDormancyTime:(NSString *)dormancyTime;

@end

NS_ASSUME_NONNULL_END
