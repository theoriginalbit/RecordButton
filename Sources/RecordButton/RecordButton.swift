import UIKit

private let layerPathKeyPath = #keyPath(CAShapeLayer.path)
private let redColor: UIColor = {
    if #available(iOS 13, *) {
        return .systemRed
    } else {
        return .red
    }
}()

public class RecordButton: UIControl {
    public enum Haptics {
        case selection
        case highlight(UIImpactFeedbackGenerator.FeedbackStyle)
    }

    // MARK: - Properties

    private let squareWidthPercent: CGFloat = 0.68
    private let squareCornerRadiusPercent: CGFloat = 0.13
    private let pressedShrinkPercent: CGFloat = 0.05

    private lazy var innerLayer: CAShapeLayer = {
        $0.path = pathForRestingInnerShape() // show the correct shape based on the state
        $0.strokeColor = nil // we don't want a ring around the inner circle
        $0.fillColor = innerColor.cgColor
        return $0
    }(CAShapeLayer())

    private lazy var outerLayer: CAShapeLayer = {
        $0.path = pathForOuterRing()
        $0.lineWidth = ringWidth
        $0.strokeColor = ringColor.cgColor
        $0.fillColor = nil
        return $0
    }(CAShapeLayer())

    private var selectionFeedbackGenerator: UISelectionFeedbackGenerator?
    private var highlightedFeedbackGenerator: UIImpactFeedbackGenerator?

    public var innerColor: UIColor = redColor {
        didSet {
            innerLayer.fillColor = innerColor.cgColor
        }
    }

    public var ringColor: UIColor = .white {
        didSet {
            outerLayer.strokeColor = ringColor.cgColor
        }
    }

    public var ringWidth: CGFloat = 6.0 {
        didSet {
            outerLayer.lineWidth = ringWidth
            outerLayer.path = pathForOuterRing()
            innerLayer.path = pathForRestingInnerShape()
        }
    }

    public var ringSpacing: CGFloat = 2.0 {
        didSet {
            outerLayer.path = pathForOuterRing()
            innerLayer.path = pathForRestingInnerShape()
        }
    }

    public var transitionAnimationDuration: TimeInterval = 0.2
    public var haptics: Haptics? = .selection

    public override var isSelected: Bool {
        didSet {
            animateToggle()
            triggerHaptics()
        }
    }

    public override var bounds: CGRect {
        didSet {
            outerLayer.path = pathForOuterRing()
            innerLayer.path = pathForRestingInnerShape()
        }
    }

    // MARK: - Initialization

    public override init(frame: CGRect) {
        super.init(frame: frame)

        layer.addSublayer(innerLayer)
        layer.addSublayer(outerLayer)
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        layer.addSublayer(innerLayer)
        layer.addSublayer(outerLayer)
    }

    open override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)

        if touches.anyTouch(in: self) {
            let morph = createAnimation(keyPath: layerPathKeyPath)
            morph.toValue = pathForTouchDownInnerShape()
            innerLayer.add(morph, forKey: nil)
            prepareHaptics()
        }
    }

    open override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)

        if touches.anyTouch(in: self) {
            isSelected = !isSelected
            releaseHaptics()
        } else {
            animateToggle() // since isSelected is unchanged this will reset the inner path from 'pressed' to unselected 'resting'
            releaseHaptics()
        }
    }
}

// MARK: - Haptics Helper Methods

private extension RecordButton {
    func prepareHaptics() {
        switch haptics {
        case .none:
            break
        case .selection:
            selectionFeedbackGenerator = UISelectionFeedbackGenerator()
            selectionFeedbackGenerator?.prepare() // get the engine ready to tap
        case let .highlight(style):
            highlightedFeedbackGenerator = UIImpactFeedbackGenerator(style: style)
            highlightedFeedbackGenerator?.impactOccurred()
            highlightedFeedbackGenerator?.prepare() // keep it prepared, we're going to tap again on release
        }
    }

    func triggerHaptics() {
        switch haptics {
        case .none:
            break
        case .selection:
            selectionFeedbackGenerator?.selectionChanged()
        case .highlight:
            highlightedFeedbackGenerator?.impactOccurred()
        }
    }

    func releaseHaptics() {
        selectionFeedbackGenerator = nil
        highlightedFeedbackGenerator = nil
    }
}

// MARK: - Animation Helper Methods

private extension RecordButton {
    func animateToggle() {
        let morph = createAnimation(keyPath: layerPathKeyPath)
        morph.toValue = pathForRestingInnerShape()
        innerLayer.add(morph, forKey: nil)
    }

    func createAnimation(keyPath: String) -> CABasicAnimation {
        let morph = CABasicAnimation(keyPath: keyPath)
        morph.duration = transitionAnimationDuration
        morph.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        // ensure the animation isn't reverted once complete
        morph.fillMode = .forwards
        morph.isRemovedOnCompletion = false

        return morph
    }
}

// MARK: - Path and Rect Helper Methods

private extension RecordButton {
    func pathForOuterRing() -> CGPath {
        let buttonPadding = ringWidth / 2
        let width = bounds.width - ringWidth
        let height = bounds.height - ringWidth
        let outerRingRect = CGRect(x: buttonPadding, y: buttonPadding, width: width, height: height)
        return circlePath(rect: outerRingRect).cgPath
    }

    func pathForRestingInnerShape() -> CGPath {
        let rect = isSelected ? squareRestingRect() : circleRestingRect()
        return (isSelected ? squarePath(rect: rect) : circlePath(rect: rect)).cgPath
    }

    func pathForTouchDownInnerShape() -> CGPath {
        // calculate a depressed rect to use for the path
        let rect = isSelected ? squareRestingRect() : circleRestingRect()
        let inset = rect.width * pressedShrinkPercent
        let pressedRect = rect.insetBy(dx: inset, dy: inset)

        return (isSelected ? squarePath(rect: pressedRect) : circlePath(rect: pressedRect)).cgPath
    }

    func circleRestingRect() -> CGRect {
        let inset = ringWidth + ringSpacing
        let width = bounds.width - (inset * 2)
        let height = bounds.height - (inset * 2)
        return CGRect(x: inset, y: inset, width: width, height: height)
    }

    func squareRestingRect() -> CGRect {
        let circleInset = ringWidth + ringSpacing
        let width = (bounds.width * squareWidthPercent) - (circleInset * 2)
        let height = (bounds.height * squareWidthPercent) - (circleInset * 2)
        let xInset = (bounds.width - width) / 2
        let yInset = (bounds.height - height) / 2
        return CGRect(x: xInset, y: yInset, width: width, height: height)
    }

    func squarePath(rect: CGRect) -> UIBezierPath {
        let cornerRadius = min(rect.width, rect.height) * squareCornerRadiusPercent
        return UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
    }

    func circlePath(rect: CGRect) -> UIBezierPath {
        let cornerRadius = min(rect.width, rect.height) / 2
        return UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
    }
}

// MARK: - Touch Helper Methods

private extension Set where Element == UITouch {
    func anyTouch(in view: UIView) -> Bool {
        return lazy
            .map { $0.location(in: view) }
            .contains { view.bounds.contains($0) }
    }
}
