#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import UIKit

/// SwiftUI wrapper for `CurrencyField`.
///
/// Responsibilities:
/// - Owns a `CurrencyField` (UIKit) and exposes it as a SwiftUI view.
/// - Keeps a `@Binding<Decimal>` (`amount`) in sync with the field’s `decimal`.
/// - Pushes `locale` and `maximum` down to UIKit, and re-renders when they change.
/// - Optionally shows a **Done** accessory toolbar (for iPhone number pad).
///
/// Notes:
/// - On iPhone, `.numberPad` has no Return key → the toolbar provides a way to dismiss.
/// - On iPad/hardware keyboard, Return is supported via `textFieldShouldReturn`.
public struct CurrencyFieldView: UIViewRepresentable {

    // MARK: - API surface (SwiftUI-facing)

    /// The bound value in **major units** (e.g., "R$ 0,12" ↔︎ 0.12).
    @Binding public var amount: Decimal

    /// Locale used by the underlying formatter (`CurrencyField.locale`).
    public var locale: Locale

    /// Maximum allowed value (major units) forwarded to `CurrencyField.maximum`.
    public var maximum: Decimal

    /// When `true`, attaches an accessory toolbar with a **Done** button.
    public var showsDoneAccessory: Bool
    
    /// Pass-through appearance knobs (forward to `CurrencyField` if desired).
    public var borderColor: UIColor = .label
    public var borderRadius: CGFloat = 8
    public var borderWidth: CGFloat = 1

    // MARK: - Init

    /// Creates a SwiftUI wrapper around `CurrencyField`.
    /// - Parameters:
    ///   - amount: Binding to the major-units value.
    ///   - locale: Locale used for currency formatting (default `.current`).
    ///   - maximum: Upper bound for the value (default ~1B).
    ///   - showsDoneAccessory: Adds a **Done** toolbar (useful on iPhone).
    public init(
        amount: Binding<Decimal>,
        locale: Locale = .current,
        maximum: Decimal = 999_999_999.99,
        showsDoneAccessory: Bool = true
    ) {
        self._amount = amount
        self.locale = locale
        self.maximum = maximum
        self.showsDoneAccessory = showsDoneAccessory
    }

    // MARK: - UIViewRepresentable

    /// Creates and configures the UIKit text field.
    public func makeUIView(context: Context) -> CurrencyField {
        let currencyField = CurrencyField()
        currencyField.translatesAutoresizingMaskIntoConstraints = false
        currencyField.locale = locale
        currencyField.maximum = maximum
        currencyField.delegate = context.coordinator

        // UIKit → SwiftUI value pipeline
        currencyField.addTarget(
            context.coordinator,
            action: #selector(Coordinator.editingChanged),
            for: .editingChanged
        )

        // Seed text from the bound value, then run the field’s formatting pipeline once.
        currencyField.text = amount.currencyString(locale: locale)
        currencyField.sendActions(for: .editingChanged)

        // Keep a weak ref in the coordinator for reliable `resignFirstResponder()`.
        context.coordinator.textField = currencyField
        return currencyField
    }

    /// Keeps UIKit and SwiftUI in sync on every update.
    public func updateUIView(_ tf: CurrencyField, context: Context) {
        if tf.locale.identifier != locale.identifier { tf.locale = locale }
        if tf.maximum != maximum { tf.maximum = maximum }

        // Only push text when not actively editing, or when the value truly drifted.
        if !tf.isFirstResponder || tf.decimal != amount {
            tf.text = amount.currencyString(locale: locale)
            tf.sendActions(for: .editingChanged)
        }
    }

    /// Coordinator mediates events (editing changes, Return, Done).
    public func makeCoordinator() -> Coordinator { Coordinator(self) }

    // MARK: - Coordinator

    public final class Coordinator: NSObject, UITextFieldDelegate {

        /// Back-reference to the SwiftUI wrapper.
        var parent: CurrencyFieldView

        /// Weak ref to the concrete text field so we can call `resignFirstResponder()`.
        weak var textField: UITextField?

        init(_ parent: CurrencyFieldView) {
            self.parent = parent
        }

        /// UIKit → SwiftUI bridge: update the binding when the field value changes.
        @objc func editingChanged(_ sender: CurrencyField) {
            let value = sender.decimal
            DispatchQueue.main.async { [weak self] in
                self?.parent.amount = value
            }
        }

        /// Supports Return key on iPad / hardware keyboards.
        public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            textField.resignFirstResponder()
            return true
        }

        /// "Done" button action (accessory toolbar) to dismiss keyboard deterministically.
        @objc func doneTapped() {
            textField?.resignFirstResponder()
        }
    }
}

// MARK: - Helpers

private extension Decimal {
    /// Format a `Decimal` as currency in a given locale.
    func currencyString(locale: Locale) -> String {
        let numberFormatter = NumberFormatter()
        numberFormatter.locale = locale
        numberFormatter.numberStyle = .currency
        return numberFormatter.string(for: self) ?? ""
    }
}

#endif
