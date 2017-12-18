//
//  RKCaptureView.m
//  Created by RK on 2017/11/17.
//  Copyright © 2017年 RK. All rights reserved.
//

#import "RKCaptureView.h"

@interface RKCaptureView()
@property(nonatomic, strong) CAShapeLayer *scanningLayer;
@property(nonatomic, strong) NSTimer *timer;
@end

@implementation RKCaptureView
- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame])
    {
        self.backgroundColor = [UIColor clearColor];
        
        [self addCoverScanningMask];
        [self addTimer];
    }
    return self;
}

- (void)addCoverScanningMask
{
    CAShapeLayer *scanningLayer = [CAShapeLayer layer];
    scanningLayer.position = self.layer.position;
    CGFloat width = kMainScreenWidth*270/375.0;
    scanningLayer.bounds = (CGRect){CGPointZero, {width, width * 1.574}};
    scanningLayer.cornerRadius = 15;
    scanningLayer.borderColor = [UIColor whiteColor].CGColor;
    scanningLayer.borderWidth = 1.5;
    [self.layer addSublayer:scanningLayer];
    self.scanningLayer = scanningLayer;
    
    UIBezierPath *transparentRoundedRectPath = [UIBezierPath bezierPathWithRoundedRect:scanningLayer.frame cornerRadius:scanningLayer.cornerRadius];
    
    UIBezierPath *path = [UIBezierPath bezierPathWithRect:self.frame];
    [path appendPath:transparentRoundedRectPath];
    [path setUsesEvenOddFillRule:YES];
    
    CAShapeLayer *fillLayer = [CAShapeLayer layer];
    fillLayer.path = path.CGPath;
    fillLayer.fillRule = kCAFillRuleEvenOdd;
    fillLayer.fillColor = [UIColor blackColor].CGColor;
    fillLayer.opacity = 0.6;
    [self.layer addSublayer:fillLayer];
    
    CGFloat facePathWidth = kMainScreenWidth*150/375.0;
    CGFloat facePathHeight = facePathWidth * 0.812;
    CGRect rect = scanningLayer.frame;
    self.facePathRect = (CGRect){CGRectGetMaxX(rect) - facePathWidth - 35,CGRectGetMaxY(rect) - facePathHeight - 25,facePathWidth,facePathHeight};
    
    // 提示信息
    CGPoint center = self.center;
    center.x = CGRectGetMaxX(scanningLayer.frame) + 20;
    [self addTipLabelWithText:@"将身份证人像面置于此区域内，头像对准，扫描" center:center];

}

-(void)addTipLabelWithText:(NSString *)text center:(CGPoint)center
{
    UILabel *tipLabel = [[UILabel alloc] init];
    tipLabel.text = text;
    tipLabel.textColor = [UIColor whiteColor];
    tipLabel.textAlignment = NSTextAlignmentCenter;
    tipLabel.transform = CGAffineTransformMakeRotation(M_PI * 0.5);
    [tipLabel sizeToFit];
    tipLabel.center = center;
    [self addSubview:tipLabel];
}

- (void)drawRect:(CGRect)rect
{
    rect = self.scanningLayer.frame;
    
    // 身份证头像提示框
    UIBezierPath *facePath = [UIBezierPath bezierPathWithRect:_facePathRect];
    facePath.lineWidth = 1.5;
    [[UIColor whiteColor] set];
    [facePath stroke];
    
    // 水平扫描线
    CGContextRef context = UIGraphicsGetCurrentContext();
    static CGFloat moveX = 0;
    static CGFloat distanceX = 0;
    CGContextBeginPath(context);
    CGContextSetLineWidth(context, 2);
    CGContextSetRGBStrokeColor(context,0.3,0.8,0.3,0.8);
    
    CGPoint p1, p2;
    moveX += distanceX;
    if (moveX >= CGRectGetWidth(rect) - 2)
    {
        distanceX = -2;
    }
    else if (moveX <= 2)
    {
        distanceX = 2;
    }
    
    p1 = CGPointMake(CGRectGetMaxX(rect) - moveX, rect.origin.y);
    p2 = CGPointMake(CGRectGetMaxX(rect) - moveX, rect.origin.y + rect.size.height);
    
    CGContextMoveToPoint(context,p1.x, p1.y);
    CGContextAddLineToPoint(context, p2.x, p2.y);
    
    CGContextStrokePath(context);
}

-(void)addTimer
{
    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:0.02 target:self selector:@selector(timerFire:) userInfo:nil repeats:YES];
    [timer fire];
    self.timer = timer;
}

-(void)timerFire:(id)notice
{
    [self setNeedsDisplay];
}

-(void)dealloc
{
    [self.timer invalidate];
}
@end
