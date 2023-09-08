import Foundation
import OpenTok
import BNBSdkCore
import BNBSdkApi

let kClientToken = <#Client Token#>

class BanubaTransformer: NSObject, OTCustomVideoTransformer {
    
    public override init() {
    
        if !BanubaTransformer.intialized {
            BanubaSdkManager.initialize(
                resourcePath: [
                    Bundle.main.bundlePath + "/bnb-resources",
                    Bundle.main.bundlePath + "/effects"
                ],
                clientTokenString: kClientToken
            )
            BanubaTransformer.intialized = true
        }
    }
    
    public func loadEffect(name: String) {
        effectName = name
        if oep != nil {
            oep?.loadEffect(name)
        }
    }
    
    public static func deinitialize() {
        if BanubaTransformer.intialized {
            BanubaSdkManager.deinitialize()
            BanubaTransformer.intialized = false
        }
    }
    
    func transform(_ videoFrame: OTVideoFrame) {
        let width  = Int(videoFrame.format?.imageWidth ?? 0)
        let height = Int(videoFrame.format?.imageHeight ?? 0)
        createOepIfRequiered(width, height)
        var bnbFormat = createBnbFormat(videoFrame)
         
        var planes = [
            videoFrame.planes?.pointer(at: 0),
            videoFrame.planes?.pointer(at: 1),
            videoFrame.planes?.pointer(at: 2)
        ]
        var widths = [width, width / 2, width / 2]
        var heights = [height, height / 2, height / 2]
        var strides = [
            Int(videoFrame.getPlaneStride(0)),
            Int(videoFrame.getPlaneStride(1)),
            Int(videoFrame.getPlaneStride(2))
        ]
        
        var otBuffer: CVPixelBuffer?;
        assert(CVPixelBufferCreateWithPlanarBytes(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_420YpCbCr8Planar,
            nil,
            0,
            3,
            &planes,
            &widths,
            &heights,
            &strides,
            nil,
            nil,
            nil,
            &otBuffer
        ) == kCVReturnSuccess)
        let processResult = oep?.processImage(otBuffer!, with: &bnbFormat)
        
        CVPixelBufferLockBaseAddress(processResult!, .readOnly)
        
        let y = CVPixelBufferGetBaseAddressOfPlane(processResult!, 0)!.assumingMemoryBound(to: UInt8.self)
        let u = CVPixelBufferGetBaseAddressOfPlane(processResult!, 1)!.assumingMemoryBound(to: UInt8.self)
        let v = CVPixelBufferGetBaseAddressOfPlane(processResult!, 2)!.assumingMemoryBound(to: UInt8.self)
        let strideY = CVPixelBufferGetBytesPerRowOfPlane(processResult!, 0)
        let strideU = CVPixelBufferGetBytesPerRowOfPlane(processResult!, 1)
        let strideV = CVPixelBufferGetBytesPerRowOfPlane(processResult!, 2)
        
        for h in 0 ..< height {
            memcpy(videoFrame.getPlaneBinaryData(0) + h * strides[0], y + strideY * (height - h - 1), width)
        }
        for h in 0 ..< height / 2 {
            memcpy(videoFrame.getPlaneBinaryData(1) + h * strides[1], u + strideU * (height / 2 - h - 1), width / 2)
            memcpy(videoFrame.getPlaneBinaryData(2) + h * strides[2], v + strideV * (height / 2 - h - 1), width / 2)
        }
        
        CVPixelBufferUnlockBaseAddress(processResult!, .readOnly)
    }
    
    private func createOepIfRequiered(_ width:Int, _ height:Int) {
        if oep == nil {
            oep = BNBOffscreenEffectPlayer(
                effectWidth: UInt(width),
                andHeight: UInt(height),
                manualAudio: true
            )
            playerWidth = width
            playerHeight = height
            oep?.loadEffect(effectName)
        } else {
            if playerWidth != width || playerHeight != height {
                oep?.surfaceChanged(UInt(width), withHeight: UInt(height))
                playerWidth = width
                playerHeight = height
            }
        }
    }
    
    private func createBnbFormat(_ otFrame:OTVideoFrame) -> EpImageFormat {
        let bnbOrientation = {(otOrientation:OTVideoOrientation)->EPOrientation in
            switch otOrientation {
                case .up: return .angles0
                case .left: return .angles90
                case .right: return .angles270
                case .down: return .angles180
                @unknown default: return .angles0
            }
        }(otFrame.orientation)
    
        return EpImageFormat(
            imageSize: CGSize(width: CGFloat(otFrame.format?.imageWidth ?? 0), height: CGFloat(otFrame.format?.imageHeight ?? 0)),
            orientation: bnbOrientation,
            resultedImageOrientation: bnbOrientation,
            isMirrored: true,
            needAlphaInOutput: false,
            overrideOutputToBGRA: false,
            outputTexture: false
        )
    }
    
    private var oep: BNBOffscreenEffectPlayer?
    private var effectName: String = ""
    private static var intialized = false
    private var playerWidth = 0
    private var playerHeight = 0
}
