import CoreText
import Foundation

/// Registers the bundled Spectral + Hanken Grotesk faces with the font manager at launch so they
/// can be resolved by PostScript name through `Font.custom`. Runtime registration avoids any
/// dependency on an `Info.plist` `UIAppFonts` array.
enum AppFonts {
    private static let fontFileNames = [
        "Spectral-Light",
        "Spectral-Regular",
        "Spectral-Medium",
        "Spectral-SemiBold",
        "Spectral-Italic",
        "Spectral-MediumItalic",
        "HankenGrotesk"
    ]

    static func registerAll() {
        for name in fontFileNames {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else { continue }
            var error: Unmanaged<CFError>?
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
        }
    }
}
