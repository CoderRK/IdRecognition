//
//  RKIDRecogntionController.m
//
//  Created by RK on 2017/11/17.
//  Copyright © 2017年 RK. All rights reserved.
//

#import "RKIDRecogntionController.h"
#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import "excards.h"
#import "RKCaptureView.h"
#import "RKIDInfoTool.h"

@interface RKIDRecogntionController () <AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureMetadataOutputObjectsDelegate>

@property (nonatomic,strong) AVCaptureDevice *captureDevice;
@property (nonatomic,strong) AVCaptureSession *captureSession;
@property (nonatomic,strong) NSNumber *outPutSetting;
@property (nonatomic,strong) AVCaptureVideoDataOutput *videoDataOutput;
@property (nonatomic,strong) AVCaptureMetadataOutput *metadataOutput;
@property (nonatomic,strong) AVCaptureVideoPreviewLayer *previewLayer;
@property (nonatomic,assign) CGRect faceDetectionFrame;
@property (nonatomic,strong) dispatch_queue_t queue;

//设备闪光灯
@property (nonatomic,assign,getter = isTorchOn) BOOL torchOn;
@end

@implementation RKIDRecogntionController
#pragma mark - life cycle
- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor cyanColor];
    
    const char *thePath = [[[NSBundle mainBundle] resourcePath] UTF8String];
    int ret = EXCARDS_Init(thePath);
    if (ret != 0)
    {
        NSLog(@"初始化失败：ret=%d", ret);
    }
    
    [self reconigtionFromImage];
    // 添加预览图层
    [self.view.layer addSublayer:self.previewLayer];

    RKCaptureView *caputureView = [[RKCaptureView alloc] initWithFrame:self.view.frame];
    self.faceDetectionFrame = caputureView.facePathRect;
    [self.view addSubview:caputureView];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:YES];
    [self detectTheCameraAvailable];
}

#pragma mark - Loading data
#pragma mark - UITableViewDelegate And UITableViewDataSource
#pragma mark - UIScrollViewDelegate
#pragma mark - CustomDelegate
-(void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection
{
    if (metadataObjects.count)
    {
        AVMetadataMachineReadableCodeObject *metadataObject = metadataObjects.firstObject;
        AVMetadataObject *transformedMetadataObject = [self.previewLayer transformedMetadataObjectForMetadataObject:metadataObject];
        CGRect faceRegion = transformedMetadataObject.bounds;

        if (metadataObject.type == AVMetadataObjectTypeFace)
        {
            NSLog(@"是否包含头像：%d, facePathRect: %@, faceRegion: %@",CGRectContainsRect(self.faceDetectionFrame, faceRegion),NSStringFromCGRect(self.faceDetectionFrame),NSStringFromCGRect(faceRegion));

            if (CGRectContainsRect(self.faceDetectionFrame, faceRegion))
            {// 只有当人脸区域的确在小框内时，才再去做捕获此时的这一帧图像
                // 为videoDataOutput设置代理，程序就会自动调用下面的代理方法，捕获每一帧图像
                if (!self.videoDataOutput.sampleBufferDelegate)
                {
                    [self.videoDataOutput setSampleBufferDelegate:self queue:self.queue];
                }
            }
        }
    }
}

-(void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    if ([self.outPutSetting isEqualToNumber:[NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange]] ||
        [self.outPutSetting isEqualToNumber:[NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]])
    {
        CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        
        if ([captureOutput isEqual:self.videoDataOutput])
        {
            [self toRecongntionWithImageBuffer:imageBuffer];
            
            if (self.videoDataOutput.sampleBufferDelegate)
            {
                [self.videoDataOutput setSampleBufferDelegate:nil queue:self.queue];
            }
        }
    }
    else
    {
        NSLog(@"输出格式不支持");
    }
}
#pragma mark - Event response
#pragma mark - Private methods
- (void)detectTheCameraAvailable
{
    AVAuthorizationStatus authorizationStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    switch (authorizationStatus)
    {
        case AVAuthorizationStatusNotDetermined:
        {
            NSLog(@"--NotDetermined----");
            break;
        }
        case AVAuthorizationStatusAuthorized:
        {
            [self runSession];
            break;
        }
        case AVAuthorizationStatusDenied:
        {
            NSLog(@"--Denied----");
            break;
        }
        case AVAuthorizationStatusRestricted:
        {
            NSLog(@"--Restricted----");
            break;
        }
    }
}

- (void)runSession
{
    if (![self.captureSession isRunning])
    {
        dispatch_async(self.queue, ^{
            [self.captureSession startRunning];
        });
    }
}

- (void)reconigtionFromImage
{
    UIImage *image = [UIImage imageNamed:@"RKid"];
    CVImageBufferRef buf = [self ConvertToCVPixelBufferRefFromImage:image.CGImage withSize:CGSizeMake(1920, 1080)];
    [self toRecongntionWithImageBuffer:buf];
}

-(CVPixelBufferRef) ConvertToCVPixelBufferRefFromImage: (CGImageRef )image withSize:(CGSize) size
{
    NSDictionary *options =[NSDictionary dictionaryWithObjectsAndKeys:
                            [NSNumber numberWithBool:YES],kCVPixelBufferCGImageCompatibilityKey,
                            [NSNumber numberWithBool:YES],kCVPixelBufferCGBitmapContextCompatibilityKey,nil];
    
    CVPixelBufferRef pxbuffer =NULL;
    CVReturn status =CVPixelBufferCreate(kCFAllocatorDefault,size.width,size.height,kCVPixelFormatType_32BGRA,(__bridge CFDictionaryRef) options,&pxbuffer);
    
    NSParameterAssert(status ==kCVReturnSuccess && pxbuffer !=NULL);
    
    CVPixelBufferLockBaseAddress(pxbuffer,0);
    void *pxdata =CVPixelBufferGetBaseAddress(pxbuffer);
    NSParameterAssert(pxdata !=NULL);
    
    CGColorSpaceRef rgbColorSpace=CGColorSpaceCreateDeviceRGB();
    CGContextRef context =CGBitmapContextCreate(pxdata,size.width,size.height,8,4*size.width,rgbColorSpace,kCGImageAlphaNoneSkipFirst | kCGBitmapByteOrder32Little);
    NSParameterAssert(context);
    
    
    CGContextDrawImage(context,CGRectMake(0,0,CGImageGetWidth(image),CGImageGetHeight(image)),image);
    CGColorSpaceRelease(rgbColorSpace);
    CGContextRelease(context);
    
    CVPixelBufferUnlockBaseAddress(pxbuffer,0);
    
    
    return pxbuffer;
}

- (void)toRecongntionWithImageBuffer:(CVImageBufferRef)imageBuffer
{
    CVBufferRetain(imageBuffer);
    
    if (CVPixelBufferLockBaseAddress(imageBuffer, 0) == kCVReturnSuccess)
    {
        size_t width= CVPixelBufferGetWidth(imageBuffer);// 1920
        size_t height = CVPixelBufferGetHeight(imageBuffer);// 1080
        
        CVPlanarPixelBufferInfo_YCbCrBiPlanar *planar = CVPixelBufferGetBaseAddress(imageBuffer);
        size_t offset = NSSwapBigIntToHost(planar->componentInfoY.offset);
        size_t rowBytes = NSSwapBigIntToHost(planar->componentInfoY.rowBytes);
        unsigned char* baseAddress = (unsigned char *)CVPixelBufferGetBaseAddress(imageBuffer);
        unsigned char* pixelAddress = baseAddress + offset;
        
        static unsigned char *buffer = NULL;
        if (buffer == NULL)
        {
            buffer = (unsigned char *)malloc(sizeof(unsigned char) * width * height);
        }
        
        memcpy(buffer, pixelAddress, sizeof(unsigned char) * width * height);
        
        unsigned char pResult[1024];
        int ret = EXCARDS_RecoIDCardData(buffer, (int)width, (int)height, (int)rowBytes, (int)8, (char*)pResult, sizeof(pResult));
        if (ret <= 0)
        {
            NSLog(@"ret=[%d]", ret);
        }
        else
        {
            NSLog(@"ret=[%d]", ret);
            
            // 播放一下“拍照”的声音，模拟拍照
            AudioServicesPlaySystemSound(1108);
            
            if ([self.captureSession isRunning])
            {
                [self.captureSession stopRunning];
            }
            
            char ctype;
            char content[256];
            int xlen;
            int i = 0;
            
            RKIDInfoTool *iDInfo = [[RKIDInfoTool alloc] init];
            
            ctype = pResult[i++];
            while(i < ret)
            {
                ctype = pResult[i++];
                for(xlen = 0; i < ret; ++i)
                {
                    if(pResult[i] == ' ')
                    {
                        ++i;
                        break;
                    }
                    content[xlen++] = pResult[i];
                }
                
                content[xlen] = 0;
                
                if(xlen)
                {
                    NSStringEncoding gbkEncoding = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000);
//                    NSLog(@"=========%@===========",[NSString stringWithCString:(char *)content encoding:gbkEncoding]);
                    if(ctype == 0x21)
                    {
                        iDInfo.idNum = [NSString stringWithCString:(char *)content encoding:gbkEncoding];
                    }
                    else if(ctype == 0x22)
                    {
                        iDInfo.name = [NSString stringWithCString:(char *)content encoding:gbkEncoding];
                    }
                    else if(ctype == 0x23)
                    {
                        iDInfo.gender = [NSString stringWithCString:(char *)content encoding:gbkEncoding];
                    }
                    else if(ctype == 0x24)
                    {
                        iDInfo.nation = [NSString stringWithCString:(char *)content encoding:gbkEncoding];
                    }
                    else if(ctype == 0x25)
                    {
                        iDInfo.address = [NSString stringWithCString:(char *)content encoding:gbkEncoding];
                    }
                    else if(ctype == 0x26)
                    {
                        iDInfo.issue = [NSString stringWithCString:(char *)content encoding:gbkEncoding];
                    }
                    else if(ctype == 0x27)
                    {
                        iDInfo.valid = [NSString stringWithCString:(char *)content encoding:gbkEncoding];
                    }
                }
            }
            
            if (iDInfo)
            {// 读取到身份证信息，实例化出IDInfo对象后，截取身份证的有效区域，获取到图像
                NSLog(@"\n正面\n姓名：%@\n性别：%@\n民族：%@\n住址：%@\n公民身份证号码：%@\n\n反面\n签发机关：%@\n有效期限：%@",iDInfo.name,iDInfo.gender,iDInfo.nation,iDInfo.address,iDInfo.idNum,iDInfo.issue,iDInfo.valid);
                
//                CGRect effectRect = [RectManager getEffectImageRect:CGSizeMake(width, height)];
//                CGRect rect = [RectManager getGuideFrame:effectRect];
//                
//                UIImage *image = [UIImage getImageStream:imageBuffer];
//                UIImage *subImage = [UIImage getSubImage:rect inImage:image];

                 //退出IDInfoVC（展示身份证信息的控制器）
//                IDInfoViewController *IDInfoVC = [[IDInfoViewController alloc] init];
//                
//                IDInfoVC.IDInfo = iDInfo;// 身份证信息
//                IDInfoVC.IDImage = subImage;// 身份证图像
//                
//                dispatch_async(dispatch_get_main_queue(), ^{
//                    [self.navigationController pushViewController:IDInfoVC animated:YES];
//                });
            }
        }
        CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
    }
    CVBufferRelease(imageBuffer);
}
#pragma mark - Setup Controll
#pragma mark - Setter
#pragma mark - Getter
- (AVCaptureSession *)captureSession
{
    if (!_captureSession)
    {
        AVCaptureSession *captureSession = [[AVCaptureSession alloc] init];
        captureSession.sessionPreset = AVCaptureSessionPresetHigh;
        
        NSError *error = nil;
        AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:self.captureDevice error:&error];
        if (error)
        {
            NSLog(@"------%@-------",error);
//            UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil];
//            [self alertControllerWithTitle:@"没有摄像设备" message:error.localizedDescription okAction:okAction cancelAction:nil];
        }
        else
        {
            if ([captureSession canAddInput:input])
            {
                [captureSession addInput:input];
            }
            
            if ([captureSession canAddOutput:self.videoDataOutput])
            {
                [captureSession addOutput:self.videoDataOutput];
            }
            
            if ([captureSession canAddOutput:self.metadataOutput])
            {
                [captureSession addOutput:self.metadataOutput];
                // 输出格式要放在addOutPut之后，否则奔溃
                self.metadataOutput.metadataObjectTypes = @[AVMetadataObjectTypeFace];
            }
        }
         _captureSession = captureSession;
    }
    return _captureSession;
}

- (AVCaptureDevice *)captureDevice
{
    if (!_captureDevice)
    {
        AVCaptureDevice *captureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        
        NSError *error = nil;
        if ([captureDevice lockForConfiguration:&error])
        {
            if ([captureDevice isSmoothAutoFocusSupported])
            {
                captureDevice.smoothAutoFocusEnabled = YES;
            }
            
            if ([captureDevice isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus])
            {
                captureDevice.focusMode = AVCaptureFocusModeContinuousAutoFocus;
            }
            
            if ([captureDevice isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure ])
            {
                captureDevice.exposureMode = AVCaptureExposureModeContinuousAutoExposure;
            }
            
            if ([captureDevice isWhiteBalanceModeSupported:AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance])
            {
                captureDevice.whiteBalanceMode = AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance;
            }
            
            [captureDevice unlockForConfiguration];
        }
        _captureDevice = captureDevice;
    }
    return _captureDevice;
}

- (NSNumber *)outPutSetting
{
    if (!_outPutSetting)
    {
        NSNumber *outPutSetting = @(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange);
        _outPutSetting = outPutSetting;
    }
    return _outPutSetting;
}

- (AVCaptureVideoDataOutput *)videoDataOutput
{
    if (!_videoDataOutput)
    {
        AVCaptureVideoDataOutput *videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
        videoDataOutput.alwaysDiscardsLateVideoFrames = YES;
        videoDataOutput.videoSettings = @{(id)kCVPixelBufferPixelFormatTypeKey:self.outPutSetting};
        [videoDataOutput setSampleBufferDelegate:self queue:self.queue];
        _videoDataOutput = videoDataOutput;
    }
    return _videoDataOutput;
}

- (AVCaptureMetadataOutput *)metadataOutput
{
    if (!_metadataOutput)
    {
        AVCaptureMetadataOutput *metadataOutput = [[AVCaptureMetadataOutput alloc] init];
        [metadataOutput setMetadataObjectsDelegate:self queue:self.queue];
        _metadataOutput = metadataOutput;
    }
    return _metadataOutput;
}

- (AVCaptureVideoPreviewLayer *)previewLayer
{
    if (!_previewLayer)
    {
        AVCaptureVideoPreviewLayer *previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.captureSession];
        previewLayer.frame = self.view.frame;
        previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
        _previewLayer = previewLayer;
    }
    return _previewLayer;
}

- (dispatch_queue_t)queue
{
    if (!_queue)
    {
        dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        _queue = queue;
    }
    return _queue;
}
@end
