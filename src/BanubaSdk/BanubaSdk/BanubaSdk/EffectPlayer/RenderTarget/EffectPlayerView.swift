import BanubaEffectPlayer

public class EffectPlayerView: UIView {
    public var effectPlayer: BNBEffectPlayer?
    
    override public class var layerClass : AnyClass {
        return CAEAGLLayer.self
    }

    override public func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        inputManager?.onTouchesBegan(converTouches(touches))
    }

    override public func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        inputManager?.onTouchesMoved(converTouches(touches))
    }

    override public func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        inputManager?.onTouchesEnded(converTouches(touches))
    }

    override public func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        inputManager?.onTouchesCancelled(converTouches(touches))
    }
    
    fileprivate var inputManager: BNBInputManager? {
        get { return effectPlayer?.getInputManager() }
    }
    
    fileprivate func converTouches(_ touches: Set<UITouch>) -> [NSNumber: BNBTouch] {
        var result: [NSNumber: BNBTouch] = [:]
        for touch in touches {
            result[NSNumber(value: touch.id)] = BNBTouch(touch)
        }
        return result
    }
}
