
import UIKit
import BanubaSdk
import BanubaEffectPlayer

class InteractivePreviewController: UIViewController {
    
    var srcImage: UIImage?
    var image: UIImage?
    var sdkManager: BanubaSdkManager?
    
    var rects: Array<BNBPixelRect> = []
    
    @IBOutlet weak var imageView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.imageView.image = self.image
        if (srcImage == nil) {
            srcImage = image
        }
        // Do any additional setup after loading the view.
        
        rects.removeAll()
        
        let tapGesture = UITapGestureRecognizer(target:self, action:#selector(didTap))
        view.addGestureRecognizer(tapGesture)
        
        let tapGesture2 = UILongPressGestureRecognizer(target:self, action:#selector(didTap2))
        view.addGestureRecognizer(tapGesture2)
    }
    
    @IBAction func didTap(gesture:UIGestureRecognizer) {
        if (gesture.state == UIGestureRecognizer.State.ended) {
            let size = Int32((srcImage!.size.width + srcImage!.size.height) / 2 * 0.03);
            
            let point = gesture.location(in: view);
            let imgPoint = imageView.convertPoint(fromViewPoint: point);
            let rect = BNBPixelRect(x: Int32(imgPoint.x) - size / 2, y: Int32(imgPoint.y) - size / 2, w: size, h: size)
            rects.append(rect)
            
            coalesce(timeout: 0.350) { [weak self] in
                self?.sdkManager?.processImageData(self!.srcImage!, params: BNBProcessImageParams(acneProcessing: false, acneUserAreas:self?.rects)) { [weak self] (image) in
                    self?.image = image
                    DispatchQueue.main.async { [weak self] in
                        self?.imageView.image = self?.image
                    }
                };
            }
        }
    }
    
    @IBAction func didTap2(gesture:UIGestureRecognizer) {
        if (gesture.state == UIGestureRecognizer.State.began) {
            DispatchQueue.main.async {
                self.imageView.image = self.srcImage
            }
        }
        if (gesture.state == UIGestureRecognizer.State.ended) {
            DispatchQueue.main.async {
                self.imageView.image = self.image
            }
        }
    }
    
    var coalesceTrack = 0;
    func coalesce(timeout: TimeInterval, block: @escaping ()->())
    {
        coalesceTrack = coalesceTrack + 1
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak self] in
            self?.coalesceTrack = self!.coalesceTrack - 1
            if self?.coalesceTrack == 0 {
                block()
            }
        }
    }
    
    @IBAction func backAction(_ sender: Any) {
        self.dismiss(animated: false, completion: nil)
    }
}

//https://github.com/nubbel/UIImageView-GeometryConversion
extension UIImageView {
    
    func convertPoint(fromImagePoint imagePoint: CGPoint) -> CGPoint {
        guard let imageSize = image?.size else { return CGPoint.zero }
        
        var viewPoint = imagePoint
        let viewSize = bounds.size
        
        let ratioX = viewSize.width / imageSize.width
        let ratioY = viewSize.height / imageSize.height
        
        switch contentMode {
        case .scaleAspectFit: fallthrough
        case .scaleAspectFill:
            var scale : CGFloat = 0
            
            if contentMode == .scaleAspectFit {
                scale = min(ratioX, ratioY)
            }
            else {
                scale = max(ratioX, ratioY)
            }
            
            viewPoint.x *= scale
            viewPoint.y *= scale
            
            viewPoint.x += (viewSize.width  - imageSize.width  * scale) / 2.0
            viewPoint.y += (viewSize.height - imageSize.height * scale) / 2.0
            
        case .scaleToFill: fallthrough
        case .redraw:
            viewPoint.x *= ratioX
            viewPoint.y *= ratioY
        case .center:
            viewPoint.x += viewSize.width / 2.0  - imageSize.width  / 2.0
            viewPoint.y += viewSize.height / 2.0 - imageSize.height / 2.0
        case .top:
            viewPoint.x += viewSize.width / 2.0 - imageSize.width / 2.0
        case .bottom:
            viewPoint.x += viewSize.width / 2.0 - imageSize.width / 2.0
            viewPoint.y += viewSize.height - imageSize.height
        case .left:
            viewPoint.y += viewSize.height / 2.0 - imageSize.height / 2.0
        case .right:
            viewPoint.x += viewSize.width - imageSize.width
            viewPoint.y += viewSize.height / 2.0 - imageSize.height / 2.0
        case .topRight:
            viewPoint.x += viewSize.width - imageSize.width
        case .bottomLeft:
            viewPoint.y += viewSize.height - imageSize.height
        case .bottomRight:
            viewPoint.x += viewSize.width  - imageSize.width
            viewPoint.y += viewSize.height - imageSize.height
        case.topLeft: fallthrough
        default:
            break
        }
        
        return viewPoint
    }
    
    func convertRect(fromImageRect imageRect: CGRect) -> CGRect {
        let imageTopLeft = imageRect.origin
        let imageBottomRight = CGPoint(x: imageRect.maxX, y: imageRect.maxY)
        
        let viewTopLeft = convertPoint(fromImagePoint: imageTopLeft)
        let viewBottomRight = convertPoint(fromImagePoint: imageBottomRight)
        
        var viewRect : CGRect = .zero
        viewRect.origin = viewTopLeft
        viewRect.size = CGSize(width: abs(viewBottomRight.x - viewTopLeft.x), height: abs(viewBottomRight.y - viewTopLeft.y))
        return viewRect
    }
    
    func convertPoint(fromViewPoint viewPoint: CGPoint) -> CGPoint {
        guard let imageSize = image?.size else { return CGPoint.zero }
        
        var imagePoint = viewPoint
        let viewSize = bounds.size
        
        let ratioX = viewSize.width / imageSize.width
        let ratioY = viewSize.height / imageSize.height
        
        switch contentMode {
        case .scaleAspectFit: fallthrough
        case .scaleAspectFill:
            var scale : CGFloat = 0
            
            if contentMode == .scaleAspectFit {
                scale = min(ratioX, ratioY)
            }
            else {
                scale = max(ratioX, ratioY)
            }
            
            // Remove the x or y margin added in FitMode
            imagePoint.x -= (viewSize.width  - imageSize.width  * scale) / 2.0
            imagePoint.y -= (viewSize.height - imageSize.height * scale) / 2.0
            
            imagePoint.x /= scale;
            imagePoint.y /= scale;
            
        case .scaleToFill: fallthrough
        case .redraw:
            imagePoint.x /= ratioX
            imagePoint.y /= ratioY
        case .center:
            imagePoint.x -= (viewSize.width - imageSize.width)  / 2.0
            imagePoint.y -= (viewSize.height - imageSize.height) / 2.0
        case .top:
            imagePoint.x -= (viewSize.width - imageSize.width)  / 2.0
        case .bottom:
            imagePoint.x -= (viewSize.width - imageSize.width)  / 2.0
            imagePoint.y -= (viewSize.height - imageSize.height);
        case .left:
            imagePoint.y -= (viewSize.height - imageSize.height) / 2.0
        case .right:
            imagePoint.x -= (viewSize.width - imageSize.width);
            imagePoint.y -= (viewSize.height - imageSize.height) / 2.0
        case .topRight:
            imagePoint.x -= (viewSize.width - imageSize.width);
        case .bottomLeft:
            imagePoint.y -= (viewSize.height - imageSize.height);
        case .bottomRight:
            imagePoint.x -= (viewSize.width - imageSize.width)
            imagePoint.y -= (viewSize.height - imageSize.height)
        case.topLeft: fallthrough
        default:
            break
        }
        
        return imagePoint
    }
    
    func convertRect(fromViewRect viewRect : CGRect) -> CGRect {
        let viewTopLeft = viewRect.origin
        let viewBottomRight = CGPoint(x: viewRect.maxX, y: viewRect.maxY)
        
        let imageTopLeft = convertPoint(fromImagePoint: viewTopLeft)
        let imageBottomRight = convertPoint(fromImagePoint: viewBottomRight)
        
        var imageRect : CGRect = .zero
        imageRect.origin = imageTopLeft
        imageRect.size = CGSize(width: abs(imageBottomRight.x - imageTopLeft.x), height: abs(imageBottomRight.y - imageTopLeft.y))
        return imageRect
    }
    
}
