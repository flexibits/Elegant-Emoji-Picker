//
//  EmojiPreview.swift
//  Demo
//
//  Created by Grant Oganyan on 3/14/23.
//

import Foundation
import UIKit

class EmojiPreview: UIViewController {
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    let padding = 16.0
    let blackout = UIView()
    let label = UILabel()

    init(emoji: Emoji) {
        super.init(nibName: nil, bundle: nil)
        self.modalPresentationStyle = .overFullScreen

        blackout.alpha = 0
        blackout.backgroundColor = .black.withAlphaComponent(0.5)
        self.view.addSubview(blackout, anchors: LayoutAnchor.fullFrame)

        label.textAlignment = .center

        if let emojiFont = UIFont(name: "AppleColorEmoji", size: 100) {
            label.font = emojiFont
        } else {
            label.font = .systemFont(ofSize: 100)
        }
        
        label.alpha = 0
        label.contentMode = .scaleAspectFit
        label.popupShadow()
        self.view.addSubview(label, anchors: [.safeAreaLeading(padding), .safeAreaTrailing(padding), .centerYMultiplier(0.75)])

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.update(newEmoji: emoji)
        }
    }

    func update(newEmoji: Emoji) {
        label.text = newEmoji.emoji
        label.alpha = 0
        label.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
        emojiAnimation { [self] in
            label.alpha = 1
            label.transform = CGAffineTransform(scaleX: 1, y: 1)
        }
        blackoutAnimation { [self] in
            blackout.alpha = 1
        }

#if !os(visionOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
#endif
    }

    func dismiss() {
        emojiAnimation(duration: 0.25) { [self] in
            label.alpha = 0
            label.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
        }
        blackoutAnimation { [self] in
            blackout.alpha = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            self.dismiss(animated: false)
        }
    }

    func emojiAnimation(duration: CGFloat = 0.5, _ animation: @escaping () -> Void) {
        UIView.animate(withDuration: duration, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0) {
            animation()
        }
    }
    func blackoutAnimation(_ animation: @escaping () -> Void) {
        UIView.animate(withDuration: 0.25) {
            animation()
        }
    }
}
