//
//  ViewController.m
//  ImageBlur-Accelerate
//
//  Created by Matthew S. Hill on 3/26/17.
//  Copyright © 2017 Matthew S. Hill. All rights reserved.
//

#import "ViewController.h"
#import <Accelerate/Accelerate.h>

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UIImageView *imgView;
-(IBAction)sliderChanged:(id)sender;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    UIImage *pic = [UIImage imageNamed:@"nas.jpg"];
    
    UIImage *image = [self blurImage:pic boxSize:5];
    [self.imgView setImage:image];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

void releasePixels(void *info, const void *data, size_t size) {
    free((void*)data);
}

-(UIImage *)blurImage:(UIImage *)image boxSize:(int)boxSize {
    //Get CGImage from UIImage
    CGImageRef img = image.CGImage;
    
    vImage_Buffer inBuffer, outBuffer;
    vImage_Error error;
    void *pixelBuffer;
    
    //create vImage_buffer w data from CGImageRef
    
    CGDataProviderRef inProvider = CGImageGetDataProvider(img);
    CFDataRef inBitmapData = CGDataProviderCopyData(inProvider);
    
    inBuffer.width = CGImageGetWidth(img);
    inBuffer.height = CGImageGetHeight(img);
    inBuffer.rowBytes = CGImageGetBytesPerRow(img);
    
    inBuffer.data = (void *)CFDataGetBytePtr(inBitmapData);
    
    //create vImage_Bugger for output
    pixelBuffer = malloc(CGImageGetBytesPerRow(img) * CGImageGetHeight(img));
    
    if(pixelBuffer == NULL) NSLog(@"No pixelbuffer");
    
    outBuffer.data = pixelBuffer;
    outBuffer.width = CGImageGetWidth(img);
    outBuffer.height = CGImageGetHeight(img);
    outBuffer.rowBytes = CGImageGetBytesPerRow(img);
    
    error = vImageBoxConvolve_ARGB8888(&inBuffer, &outBuffer, NULL, 0, 0, boxSize, boxSize, NULL, kvImageEdgeExtend);
    
    if(error) {
        NSLog(@"error from convolution %ld", error);
    }
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(outBuffer.data, outBuffer.width, outBuffer.height, 8, outBuffer.rowBytes, colorSpace, kCGImageAlphaNoneSkipLast);

    CGImageRef imageRef = CGBitmapContextCreateImage(ctx);
    UIImage *returnImage = [UIImage imageWithCGImage:imageRef];
    
    //cleanup
    CGContextRelease(ctx);
    CGColorSpaceRelease(colorSpace);
    
    free(pixelBuffer);
    CFRelease(inBitmapData);
    
    CGColorSpaceRelease(colorSpace);
    CGImageRelease(imageRef);
    
    return returnImage;
}

-(CGImageRef)thirtyBlurImage:(CGImageRef)img boxSize:(int)boxSize {
    
    vImage_Buffer inBuffer, outBuffer;
    
    vImage_Error error;
    
    void *pixelBuffer;
    
    
    //create vImage_Buffer with data from CGImageRef
    
    CGDataProviderRef inProvider = CGImageGetDataProvider(img);
    CFDataRef inBitmapData = CGDataProviderCopyData(inProvider);
    
    inBuffer.width = CGImageGetWidth(img);
    inBuffer.height = CGImageGetHeight(img);
    inBuffer.rowBytes = CGImageGetBytesPerRow(img);
    
    inBuffer.data = (void*)CFDataGetBytePtr(inBitmapData);
    
    //create vImage_Buffer for output
    
    pixelBuffer = malloc(CGImageGetBytesPerRow(img) * CGImageGetHeight(img));
    
    if(pixelBuffer == NULL)
        NSLog(@"No pixelbuffer");
    
    outBuffer.data = pixelBuffer;
    outBuffer.width = CGImageGetWidth(img);
    outBuffer.height = CGImageGetHeight(img);
    outBuffer.rowBytes = CGImageGetBytesPerRow(img);
    
    CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
    //perform convolution
    for (int i = 0; i < 30; i++) {
        if (i % 2 == 0) {
            error = vImageBoxConvolve_ARGB8888(&inBuffer, &outBuffer, NULL, 0, 0, boxSize, boxSize, NULL, kvImageEdgeExtend);
            
            if (error) {
                NSLog(@"error from convolution %ld", error);
            }
        } else {
            error = vImageBoxConvolve_ARGB8888(&outBuffer, &inBuffer, NULL, 0, 0, boxSize, boxSize, NULL, kvImageEdgeExtend);
            
            if (error) {
                NSLog(@"error from convolution %ld", error);
            }
        }
    }
    
    NSLog(@"finished in %f seconds, %ld pixels, %f seconds per 1,000 pixels", CFAbsoluteTimeGetCurrent() - start, outBuffer.width * outBuffer.height, (CFAbsoluteTimeGetCurrent() - start)/ ((float)(outBuffer.width * outBuffer.height) / 1000.0) / 30.0);
    
    //create CGImageRef from vImage_Buffer output
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    CGContextRef ctx = CGBitmapContextCreate(outBuffer.data,
                                             outBuffer.width,
                                             outBuffer.height,
                                             8,
                                             outBuffer.rowBytes,
                                             colorSpace,
                                             kCGImageAlphaNoneSkipLast);
    CGImageRef imageRef = CGBitmapContextCreateImage (ctx);
    
    CGContextRelease(ctx);
    CGColorSpaceRelease(colorSpace);
    free(pixelBuffer);
    CFRelease(inBitmapData);
    
    
    return imageRef;
    
}

-(CGImageRef)matchHistogramInImage:(CGImageRef)inImg withImage:(CGImageRef)matchImg {
    CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
    
    vImage_Buffer					buffer,
    inBuffer,
    outBuffer;
    
    vImage_Error					error;
    
    void*							pixelBuffer;
    
    vImagePixelCount				histogramA[256];
    vImagePixelCount				histogramR[256];
    vImagePixelCount				histogramG[256];
    vImagePixelCount				histogramB[256];
    vImagePixelCount*				histograms[4];
    
    CGDataProviderRef inProvider = CGImageGetDataProvider(inImg);
    CFDataRef inBitmapData = CGDataProviderCopyData(inProvider);
    
    buffer.width = CGImageGetWidth(inImg);
    buffer.height = CGImageGetHeight(inImg);
    buffer.rowBytes = CGImageGetBytesPerRow(inImg);
    
    buffer.data = (void*)CFDataGetBytePtr(inBitmapData);
    
    histograms[0] = histogramA;
    histograms[1] = histogramR;
    histograms[2] = histogramG;
    histograms[3] = histogramB;
    
    error = vImageHistogramCalculation_ARGB8888(&buffer, histograms, 0);
    NSLog(@"error from historgram calc, %ld", error);
    
    CGDataProviderRef outProvider = CGImageGetDataProvider(matchImg);
    CFDataRef outBitmapData = CGDataProviderCopyData(outProvider);
    
    inBuffer.width = CGImageGetWidth(matchImg);
    inBuffer.height = CGImageGetHeight(matchImg);
    inBuffer.rowBytes = CGImageGetBytesPerRow(matchImg);
    
    inBuffer.data = (void*)CFDataGetBytePtr(outBitmapData);
    
    pixelBuffer = malloc(CGImageGetBytesPerRow(matchImg) * CGImageGetHeight(matchImg));
    
    if(pixelBuffer == NULL)
        NSLog(@"No pixelbuffer");
    
    outBuffer.data = pixelBuffer;
    outBuffer.width = CGImageGetWidth(matchImg);
    outBuffer.height = CGImageGetHeight(matchImg);
    outBuffer.rowBytes = CGImageGetBytesPerRow(matchImg);
    
    error = vImageHistogramSpecification_ARGB8888(&inBuffer, &outBuffer, (const vImagePixelCount**)histograms, 0);
    NSLog(@"error from specification %ld", error);
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    CGContextRef ctx = CGBitmapContextCreate(outBuffer.data,
                                             outBuffer.width,
                                             outBuffer.height,
                                             8,
                                             outBuffer.rowBytes,
                                             colorSpace,
                                             kCGImageAlphaNoneSkipLast);
    CGImageRef imageRef = CGBitmapContextCreateImage (ctx);
    
    NSLog(@"finished in %f seconds", CFAbsoluteTimeGetCurrent() - start);
    
    CGContextRelease(ctx);
    CGColorSpaceRelease(colorSpace);
    free(pixelBuffer);
    CFRelease(inBitmapData);
    
    return imageRef;
}

- (IBAction)sliderChanged:(id)sender {
    UISlider *slider = (UISlider *)sender;
    
    UIImage *pic = [UIImage imageNamed:@"nas.jpg"];
    
    int boxsize = (int)(slider.value * 50);
    boxsize = boxsize - (boxsize % 2) + 1;
    
    UIImage *image = [self blurImage:pic boxSize:boxsize];
    
    [self.imgView setImage:image];
    
}

@end
