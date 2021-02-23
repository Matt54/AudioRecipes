// Cross-platform helpers

import Foundation
import SwiftUI

#if os(iOS)
    import UIKit
    public typealias CPImage = UIImage
    public typealias CPFont = UIFont
    public typealias CPDisplayLink = CADisplayLink
#elseif os(OSX)
    import AppKit
    public typealias CPImage = NSImage
    public typealias CPFont = NSFont
    public typealias CPDisplayLink = CVDisplayLink
#endif

extension Image {
    
    init(cpImage: CPImage) {
        #if os(iOS)
        self.init(uiImage: cpImage)
        #elseif os(OSX)
        self.init(nsImage: cpImage)
        #endif
    }
}

extension String {
    func widthOfString(usingFont font: CPFont) -> CGFloat {
        let fontAttributes = [NSAttributedString.Key.font: font]
        let size = self.size(withAttributes: fontAttributes)
        return size.width
    }

    func heightOfString(usingFont font: CPFont) -> CGFloat {
        let fontAttributes = [NSAttributedString.Key.font: font]
        let size = self.size(withAttributes: fontAttributes)
        return size.height
    }

    func sizeOfString(usingFont font: CPFont) -> CGSize {
        let fontAttributes = [NSAttributedString.Key.font: font]
        return self.size(withAttributes: fontAttributes)
    }
}

