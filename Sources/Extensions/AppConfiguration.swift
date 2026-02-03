//
//  File.swift
//
//
//  Created by Grant Oganyan on 3/19/23.
//

import Foundation
import UIKit

class AppConfiguration {
    static var deviceType: UIUserInterfaceIdiom { UIDevice.current.userInterfaceIdiom }

    static var isIPad: Bool { deviceType == .pad }
    static var isIPhone: Bool { deviceType == .phone }
    static var isMacCatalyst: Bool {
#if targetEnvironment(macCatalyst)
        return true
#else
        return false
#endif
    }

    static var windowFrame: CGRect { UIApplication.shared.keyWindow?.frame ?? .zero }
}

extension UIApplication {
    var keyWindow: UIWindow? {
        UIApplication.shared.windows.first(where: { $0.isKeyWindow })
    }
}
