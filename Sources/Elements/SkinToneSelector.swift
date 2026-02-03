//
//  SkinToneSelector.swift
//  Demo
//
//  Created by Grant Oganyan on 3/13/23.
//

import Foundation
import UIKit

class SkinToneSelector: UIView {
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    let padding = 8.0

    let blur = UIVisualEffectView()

    init(_ standardEmoji: Emoji, _ emojiPicker: ElegantEmojiPicker, fontSize: CGFloat) {
        super.init(frame: .zero)

        self.popupShadow()

        blur.clipsToBounds = true
        blur.alpha = 0
        blur.effect = UIBlurEffect(style: .systemUltraThinMaterial)

#if !os(visionOS)
        if #available(iOS 26.0, *) {
            blur.effect = UIGlassEffect()
        }
#endif

        self.addSubview(blur, anchors: LayoutAnchor.fullFrame)

        let yellow = SkinToneButton(standardEmoji: standardEmoji, skinTone: nil, emojiPicker: emojiPicker, fontSize: fontSize)
        self.addSubview(yellow, anchors: [.leading(padding), .top(padding), .bottom(padding)])

        var previousButton: UIView = yellow
        for tone in EmojiSkinTone.allCases {
            let button = SkinToneButton(standardEmoji: standardEmoji, skinTone: tone, emojiPicker: emojiPicker, fontSize: fontSize)
            self.addSubview(button, anchors: [.leadingToTrailing(previousButton, padding), .top(padding), .bottom(padding)])
            previousButton = button
        }

        previousButton.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -padding).isActive = true

        DispatchQueue.main.async {
            self.appear()
        }
    }

    func appear() {
#if !os(visionOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
#endif

        UIView.animate(withDuration: 0.25) {
            self.blur.alpha = 1
        }
        for index in 1..<self.subviews.count {
            self.subviews[index].transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
            animate(index, duration: 0.5) {
                self.subviews[index].alpha = 1
                self.subviews[index].transform = CGAffineTransform(scaleX: 1, y: 1)
            }
        }
    }

    func disappear(_ completion: (() -> Void)? = nil) {
        UIView.animate(withDuration: 0.25) {
            self.blur.alpha = 0
        }
        for index in 1..<self.subviews.count {
            animate(index, duration: 0.2) {
                self.subviews[index].alpha = 0
                self.subviews[index].transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(self.subviews.count-1)*0.05 + 0.2) {
            completion?()
        }
    }

    func animate(_ index: Int, duration: CGFloat, animation: @escaping () -> Void) {
        UIView.animate(
            withDuration: duration,
            delay: Double(index-1)*0.05,
            usingSpringWithDamping: 0.5,
            initialSpringVelocity: 0
        ) {
            animation()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        blur.layer.cornerRadius = blur.frame.height * 0.5
    }

    class SkinToneButton: UILabel {
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented")}
        
        let skinTone: EmojiSkinTone?
        let standardEmoji: Emoji
        let skinTonedEmoji: Emoji
        weak var emojiPicker: ElegantEmojiPicker?

        init(standardEmoji: Emoji, skinTone: EmojiSkinTone?, emojiPicker: ElegantEmojiPicker, fontSize: CGFloat) {
            self.skinTone = skinTone
            self.standardEmoji = standardEmoji
            self.skinTonedEmoji = standardEmoji.duplicate(skinTone)
            self.emojiPicker = emojiPicker

            super.init(frame: .zero)

            self.text = skinTonedEmoji.emoji
            self.font = .systemFont(ofSize: fontSize)
            self.isUserInteractionEnabled = true
            self.setContentCompressionResistancePriority(.required, for: .horizontal)
            self.alpha = 0
            self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapTone)))
        }

        @objc func tapTone(_ sender: UITapGestureRecognizer) {
            guard let emojiPicker else { return }

            emojiPicker.didSelectEmoji(skinTonedEmoji)

            emojiPicker.persistSkinTone(originalEmoji: standardEmoji, skinTone: skinTone)
        }
    }
}
