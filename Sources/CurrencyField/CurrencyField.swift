#if canImport(UIKit)
import UIKit

/// A locale-aware currency input `UITextField`.
///
/// Features:
/// - Right-to-left digit entry: typing appends minor units; backspace removes one digit.
/// - Locale-aware formatting (prefix/suffix symbols, grouping, fraction digits).
/// - Caret locked to the end (users can’t move it into the middle).
/// - Self-sized vertically for SwiftUI/Auto Layout.
/// - Minimal edit menu: Copy/Paste only; AutoFill disabled.
///
/// Notes:
/// - Recommended keyboard on iPhone: `.numberPad` (no Return key).
/// - On iPad or with hardware keyboards, Return is handled via `textFieldShouldReturn`.
public final class CurrencyField: UITextField, UITextFieldDelegate {

    // MARK: Appearance (public)

    /// Border color applied to the field’s layer.
    public var borderColor: UIColor = .label {
        didSet { applyBorder(color: borderColor) }
    }

    /// Corner radius applied to the field’s layer.
    public var borderRadius: CGFloat = 8 {
        didSet { applyBorder(radius: borderRadius) }
    }

    /// Border width applied to the field’s layer.
    public var borderWidth: CGFloat = 1 {
        didSet { applyBorder(width: borderWidth) }
    }

    // MARK: Formatting / Value

    /// Per-instance currency formatter (avoids shared-formatter races across locales).
    private let formatter: NumberFormatter = {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .currency
        return numberFormatter
    }()

    /// The current value in **major units** (e.g. “R$ 0,12” → `0.12`).
    public var decimal: Decimal {
        string.decimal / Decimal.pow10(formatter.maximumFractionDigits)
    }

    // MARK: Sizing

    /// Preferred fixed height used for intrinsic size and a self height constraint.
    public var preferredHeight: CGFloat = 36 {
        didSet {
            heightLayoutConstraint?.constant = preferredHeight
            invalidateIntrinsicContentSize()
        }
    }

    /// Internal height constraint installed on `heightAnchor`.
    private var heightLayoutConstraint: NSLayoutConstraint?
    
    /// Intrinsic content size honoring `preferredHeight`.
    public override var intrinsicContentSize: CGSize {
        .init(
            width: super.intrinsicContentSize.width,
            height: preferredHeight
        )
    }

    /// Insets applied to text, placeholder, and editing rects.
    public var edgeInsets = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10)

    // MARK: Edit menu

    /// Restrict system edit menu to Copy/Paste (disables AutoFill, Select All, etc.).
    public override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        #selector(UIResponderStandardEditActions.paste) == action ||
        #selector(UIResponderStandardEditActions.copy) == action
    }

    // MARK: Caret / Selection (keep at end; IME-safe)

    /// Keep selection at the end unless composing with an IME.
    public override func selectionRects(for range: UITextRange) -> [UITextSelectionRect] {
        if markedTextRange != nil { return super.selectionRects(for: range) }
        guard let range = textRange(from: endOfDocument, to: endOfDocument) else { return [] }
        return super.selectionRects(for: range)
    }

    /// Keep caret at the end unless composing with an IME.
    public override func caretRect(for position: UITextPosition) -> CGRect {
        if markedTextRange != nil { return super.caretRect(for: position) }
        return super.caretRect(for: endOfDocument)
    }

    /// Force selection to the end unless composing with an IME.
    public override var selectedTextRange: UITextRange? {
        get { super.selectedTextRange }
        set {
            if markedTextRange != nil { super.selectedTextRange = newValue; return }
            super.selectedTextRange = textRange(from: endOfDocument, to: endOfDocument)
        }
    }

    // MARK: Text rects (apply insets)

    public override func textRect(forBounds bounds: CGRect) -> CGRect {
        bounds.inset(by: edgeInsets)
    }

    public override func placeholderRect(forBounds bounds: CGRect) -> CGRect {
        bounds.inset(by: edgeInsets)
    }

    public override func editingRect(forBounds bounds: CGRect) -> CGRect {
        bounds.inset(by: edgeInsets)
    }

    // MARK: Limits / Locale

    /// Max allowed **major-units** value.
    public var maximum: Decimal = 999_999_999.99

    /// Convenience for current text formatted with the field’s formatter.
    private var currencyFormatted: String {
        formatter.string(for: decimal) ?? ""
    }

    /// Locale used by the internal currency formatter. Changing this **reformats silently**.
    public var locale: Locale = .current {
        didSet {
            formatter.locale = locale
            text = currencyFormatted
            lastValue = text
        }
    }

    /// Last accepted formatted string (used to revert when exceeding `maximum`).
    private var lastValue: String?

    // MARK: Init
    public override init(frame: CGRect = .zero) {
        super.init(frame: frame)
        configure()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }
    
    /// One-time setup. Avoids broadcasting `.editingChanged` during configuration.
    private func configure() {
        print("3")

        applyBorder(width: 1)
        applyBorder(radius: 8)
        applyBorder(color: .label)

        // Make the view self-size vertically
        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .vertical)

        // Install a self height constraint
        if self.heightLayoutConstraint == nil {
            let heightLayoutConstraint = heightAnchor.constraint(equalToConstant: preferredHeight)
            heightLayoutConstraint.priority = .defaultHigh
            heightLayoutConstraint.isActive = true
            self.heightLayoutConstraint = heightLayoutConstraint
        }

        formatter.locale = locale
        addTarget(self, action: #selector(editingChanged), for: .editingChanged)

        // Input & look
        borderStyle = .roundedRect
        autocorrectionType = .no
        keyboardType = .asciiCapableNumberPad
        textAlignment = .right
        textContentType = .none
        contentVerticalAlignment = .center
        text = currencyFormatted
        returnKeyType = .done
        delegate = self
        lastValue = text
        if showsDoneAccessory && UIDevice.current.userInterfaceIdiom == .phone {
              installAccessoryIfNeeded()
        }
    }

    // MARK: Editing (RTL digit entry)

    /// Backspace removes a single **digit** (minor unit) even for suffix-symbol locales.
    public override func deleteBackward() {
        text = string.digits.dropLast().string
        sendActions(for: .editingChanged)
    }

    /// Reformat after each change; if over `maximum`, revert to `lastValue`.
    @objc private func editingChanged() {
        guard decimal <= maximum else {
            text = lastValue
            return
        }
        text = currencyFormatted
        lastValue = text
    }

    // MARK: Dynamic Type support

    private var minimumHeight: CGFloat = 36

    public override var font: UIFont? {
        didSet { updatePreferredHeight() }
    }

    private func updatePreferredHeight() {
        let base = (font ?? .systemFont(ofSize: 17)).lineHeight
        preferredHeight = max(minimumHeight, ceil(base) + 14)
    }

    public override func traitCollectionDidChange(_ previous: UITraitCollection?) {
        super.traitCollectionDidChange(previous)
        if traitCollection.preferredContentSizeCategory != previous?.preferredContentSizeCategory {
            updatePreferredHeight()
        }
    }

    // MARK: Return key (iPad / hardware keyboards)

    /// Allow Return to dismiss the keyboard on iPad / hardware keyboards.
    public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        print(#function)
        resignFirstResponder()
        return true
    }

    /// Shows a safe-area aware toolbar with a **Done** button above the keyboard.
    public var showsDoneAccessory: Bool = true {
        didSet {
            if showsDoneAccessory {
                installAccessoryIfNeeded()
            } else {
                inputAccessoryView = nil
                reloadInputViews()
            }
        }
    }

    /// Keep a reference so we don’t recreate the accessory each time.
    private var accessoryViewRef: ToolbarView?

    /// Attach a safe-area aware toolbar with a **Done** button.
    private func installAccessoryIfNeeded() {
        if accessoryViewRef == nil {
            let accessory = ToolbarView()
            accessory.toolbar.items = [
                UIBarButtonItem(systemItem: .flexibleSpace),
                UIBarButtonItem(
                    title: "Done",
                    style: .done,
                    target: self,
                    action: #selector(doneTapped)
                )
            ]
            accessory.toolbar.sizeToFit()
            accessoryViewRef = accessory
            print("Accessory created")
        }
        inputAccessoryView = accessoryViewRef
        reloadInputViews()
    }

    /// Dismiss the keyboard deterministically.
    @objc private func doneTapped() {
        resignFirstResponder()
    }

}

// MARK: - Public helpers

public extension CurrencyField {
    /// Convenience `Double` accessor for APIs that don’t accept `Decimal`.
    var doubleValue: Double { (decimal as NSDecimalNumber).doubleValue }
}

// MARK: - Utilities (scoped to this target)

fileprivate extension UITextField {
    /// Safe access to current text string.
    var string: String { text ?? "" }
}

fileprivate extension StringProtocol where Self: RangeReplaceableCollection {
    /// Keep only decimal digits from this string.
    var digits: Self { filter(\.isWholeNumber) }
}

fileprivate extension String {
    /// Interpret the string’s digits as a base-10 integer `Decimal`.
    var decimal: Decimal { Decimal(string: digits) ?? 0 }
}

fileprivate extension LosslessStringConvertible {
    /// String representation helper.
    var string: String { .init(self) }
}

fileprivate extension Decimal {
    /// 10^exp as `Decimal`.
    static func pow10(_ exp: Int) -> Decimal {
        guard exp > 0 else { return 1 }
        return (0..<exp).reduce(1 as Decimal) { acc, _ in acc * Decimal(10) }
    }
}

fileprivate extension UIView {
    /// Apply a corner radius and enable clipping.
    func applyBorder(radius: CGFloat) {
        layer.cornerRadius = radius
        clipsToBounds = true
    }
    /// Apply a border width.
    func applyBorder(width: CGFloat) {
        layer.borderWidth = width
    }
    /// Apply a border color.
    func applyBorder(color: UIColor) {
        layer.borderColor = color.cgColor
    }
}

/// Accessory view that pads a UIToolbar for the home-indicator area.
/// Uses intrinsic/sizeThatFits; no Auto Layout constraints.
private final class ToolbarView: UIView {

    let toolbar = UIToolbar()

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(toolbar)
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
        toolbar.autoresizingMask = [.flexibleWidth, .flexibleTopMargin]
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private var windowBottomInset: CGFloat { window?.safeAreaInsets.bottom ?? 0 }

    override var intrinsicContentSize: CGSize {
        .init(
            width: UIView.noIntrinsicMetric,
            height: 44 + windowBottomInset
        )
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        .init(
            width: size.width,
            height: 44 + windowBottomInset
        )
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // pad only for the bottom safe area
        toolbar.frame = bounds.inset(
            by: .init(
                top: 44,
                left: 0,
                bottom: windowBottomInset - 34,
                right: 0
            )
        )
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }
}

#endif
