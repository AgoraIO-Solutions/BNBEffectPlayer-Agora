import BanubaEffectPlayer

extension BNBTouch {
    convenience init(_ touch: UITouch) {
        let viewSize = touch.view?.bounds.size
        var location = touch.location(in: touch.view)
        location.x = location.x / ((viewSize?.width ?? 1) / 2) - 1
        location.y = -(location.y / ((viewSize?.height ?? 1) / 2) - 1)
        self.init(x: Float(location.x), y: Float(location.y), id: touch.id)
    }
}
