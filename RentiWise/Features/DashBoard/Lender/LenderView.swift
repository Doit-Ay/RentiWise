import UIKit

protocol LenderViewDelegate: AnyObject {
    // Called when the inner segmented control changes
    func lenderView(_ lenderView: LenderView, didSelectInnerIndex index: Int)
    // Called when the Add button is tapped
    func lenderViewDidTapAddButton(_ lenderView: LenderView)
}

class LenderView: UIView {

    // Connect this to the top-level view in LenderView.xib (File’s Owner -> view)
    @IBOutlet private(set) var view: UIView!
    @IBOutlet private weak var innerSegmented: UISegmentedControl!
    @IBOutlet private weak var earningLabel: UILabel!
    @IBOutlet weak var innerSegmentChangesApplied: UIView!

    weak var delegate: LenderViewDelegate?

    // Keep a reference to the currently embedded child view
    private weak var currentEmbeddedView: UIView?

    // MARK: - Init
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        // Prevent double-adding if somehow called twice
        if view != nil, view.isDescendant(of: self) {
            return
        }

        // Load the nib with File’s Owner pattern
        Bundle.main.loadNibNamed("LenderView", owner: self, options: nil)

        // Ensure the 'view' outlet is connected to the top-level view in the XIB
        guard let content = view else {
            assertionFailure("LenderView.xib not loaded or 'view' outlet not connected to top-level view. Check: File's Owner = LenderView, top view = UIView, and connect File's Owner 'view' -> top view.")
            return
        }

        content.frame = bounds
        content.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(content)

        // Optional: initial state for segmented control
        if innerSegmented.numberOfSegments > 0 {
            if innerSegmented.selectedSegmentIndex == UISegmentedControl.noSegment {
                innerSegmented.selectedSegmentIndex = 0 // Default to first segment
            }
        }

        // Optional: Accessibility polish
        innerSegmented?.accessibilityLabel = "Lender Sections"
        earningLabel?.accessibilityLabel = "Earnings"

        // Show initial section
        applyInnerSegment(index: innerSegmented.selectedSegmentIndex)

        // Notify delegate once on load so it can sync UI if needed
        delegate?.lenderView(self, didSelectInnerIndex: innerSegmented.selectedSegmentIndex)
    }

    // MARK: - Actions wired in the XIB
    // If you rename this to lowerCamelCase, reconnect in Interface Builder
    @IBAction func Additem(_ sender: UIButton) {
        // Optional haptic feedback
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        delegate?.lenderViewDidTapAddButton(self)
    }

    @IBAction func innerSegmentChanged(_ sender: UISegmentedControl) {
        // Optional haptic feedback
        UISelectionFeedbackGenerator().selectionChanged()
        applyInnerSegment(index: sender.selectedSegmentIndex)
        delegate?.lenderView(self, didSelectInnerIndex: sender.selectedSegmentIndex)
    }

    // MARK: - Embedding logic
    // Segment order assumed: 0 = Listing, 1 = Request, 2 = History
    private func applyInnerSegment(index: Int) {
        // Remove previous
        if let current = currentEmbeddedView {
            current.removeFromSuperview()
        }
        currentEmbeddedView = nil

        // Create the new view for the selected segment
        let newView: UIView?
        switch index {
        case 0:
            newView = LenderListingView()
        case 1:
            newView = LenderRequestView()
        case 2:
            newView = LenderHistoryView()
        default:
            newView = nil
        }

        guard let container = innerSegmentChangesApplied, let child = newView else { return }

        // Embed and pin to edges
        child.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(child)
        NSLayoutConstraint.activate([
            child.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            child.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            child.topAnchor.constraint(equalTo: container.topAnchor),
            child.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        currentEmbeddedView = child
    }

}
