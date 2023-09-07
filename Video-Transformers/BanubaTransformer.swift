import Foundation
import OpenTok

class BanubaTransformer: NSObject, OTCustomVideoTransformer {
    func resizeImage(_ image: UIImage, to size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        image.draw(in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resizedImage
    }
    
    func transform(_ videoFrame: OTVideoFrame) {
        if let image = UIImage(named: "Vonage_Logo.png") {
            let yPlaneData = videoFrame.getPlaneBinaryData(0)
            let videoWidth = Int(videoFrame.format?.imageWidth ?? 0)
            let videoHeight = Int(videoFrame.format?.imageHeight ?? 0)
            
            // Calculate the desired size of the image
            let desiredWidth = CGFloat(videoWidth) / 8 // Adjust this value as needed
            let desiredHeight = image.size.height * (desiredWidth / image.size.width)
            
            // Resize the image to the desired size
            if let resizedImage = resizeImage(image, to: CGSize(width: desiredWidth, height: desiredHeight)) {
                let yPlane = yPlaneData
                
                // Create a CGContext from the Y plane
                guard let context = CGContext(data: yPlane,
                                              width: videoWidth,
                                              height: videoHeight,
                                              bitsPerComponent: 8,
                                              bytesPerRow: videoWidth,
                                              space: CGColorSpaceCreateDeviceGray(),
                                              bitmapInfo: CGImageAlphaInfo.none.rawValue) else {
                    return
                }
                
                // Location of the image (in this case right bottom corner)
                let x = CGFloat(videoWidth) * 4/5
                let y = CGFloat(videoHeight) * 1/5
                
                // Draw the resized image on top of the Y plane
                let rect = CGRect(x: x, y: y, width: desiredWidth, height: desiredHeight)
                context.draw(resizedImage.cgImage!, in: rect)
            }
        }
    }
}
