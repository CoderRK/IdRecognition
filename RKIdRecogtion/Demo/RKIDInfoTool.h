//
//  RKIDInfoTool.h
//
//  Created by RK on 2017/11/17.
//  Copyright © 2017年 RK. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger,RKIDInfoToolType)
{
    RKIDInfoToolTypeFrontSide = 0,//身份证正面
    RKIDInfoToolTypeOtherSide
};

@interface RKIDInfoTool : NSObject
@property(nonatomic, assign) RKIDInfoToolType type;
@property (nonatomic,copy) NSString *idNum; //身份证号
@property (nonatomic,copy) NSString *name; //姓名
@property (nonatomic,copy) NSString *gender; //性别
@property (nonatomic,copy) NSString *nation; //民族
@property (nonatomic,copy) NSString *address; //地址
@property (nonatomic,copy) NSString *issue; //签发机关
@property (nonatomic,copy) NSString *valid; //有效期
@end
