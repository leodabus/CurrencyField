# CurrencyField

Tiny SPM that provides a battle-tested currency input field for **UIKit** and a clean wrapper for **SwiftUI**.
- Handles suffix-currency locales like `fr_FR` correctly (backspace removes digits even when the symbol sits at the end with a narrow NBSP).
- "Type from right to left" UX backed by `UITextField.deleteBackward` interception.
- SwiftUI wrapper exposes `@Binding<Decimal>` and supports any `Locale`.

# CurrencyField
![GitHub release (latest by date)](https://img.shields.io/github/v/release/leodabus/CurrencyField?style=flat&color=blue)
![GitHub all releases](https://img.shields.io/github/downloads/leodabus/CurrencyField/total?color=blue&label=downloads&style=flat)
![GitHub Repo stars](https://img.shields.io/github/stars/leodabus/CurrencyField?style=flat&color=yellow)
![GitHub License](https://img.shields.io/github/license/leodabus/CurrencyField?style=flat&color=lightgrey)
![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20macOS-lightgrey)
![Swift](https://img.shields.io/badge/Swift-5.10-orange?logo=swift)
Tiny SPM that provides a battle-tested currency input field for **UIKit** and a clean wrapper for **SwiftUI**.

## Installation

Add the package via Xcode (File > Add Packages...) using your repo URL once you push it.

## Usage

### SwiftUI
```swift
import SwiftUI
import CurrencyField

struct ContentView: View {
    @State private var frAmount: Decimal = 0
    @State private var usAmount: Decimal = 0
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .trailing, spacing: 16) {
            Text("French (fr_FR)")
            CurrencyFieldView(amount: $frAmount, locale: .init(identifier: "fr_FR"))
                .frame(width: 220)

            Text("US (en_US)")
            CurrencyFieldView(amount: $usAmount, locale: .init(identifier: "en_US"))
                .frame(width: 220)
                .focused($isFocused)
                .onAppear {
                    isFocused = true
                }
        }
        .padding()
        .multilineTextAlignment(.trailing)
    }
}
```

### UIKit
```swift
import UIKit
import CurrencyField

final class ViewController: UIViewController {

    let currencyField = CurrencyField()

    override func viewDidLoad() {
        super.viewDidLoad()
        currencyField.locale = .init(identifier: "pt_BR")
        currencyField.maximum = 100_000
        currencyField.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(currencyField)

        NSLayoutConstraint.activate([
            currencyField.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            currencyField.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            currencyField.widthAnchor.constraint(equalToConstant: 220)
        ])

        currencyField.addTarget(self, action: #selector(changed), for: .editingChanged)
    }

    @objc private func changed() {
        print("decimal:", currencyField.decimal)
    }
}
```
