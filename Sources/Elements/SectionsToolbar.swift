//
//  CategoriesToolbar.swift
//  Demo
//
//  Created by Grant Oganyan on 3/10/23.
//

import Foundation
import UIKit

class SectionsToolbar: UIView {
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    weak var emojiPicker: ElegantEmojiPicker?
    let padding = 8.0

    let backgroundEffect = UIVisualEffectView()
    let selectionBlur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))

    var selectionConstraint: NSLayoutConstraint?

    var categoryButtons = [SectionButton]()

    init(sections: [EmojiSection], emojiPicker: ElegantEmojiPicker) {
        self.emojiPicker = emojiPicker
        super.init(frame: .zero)

        self.heightAnchor.constraint(lessThanOrEqualToConstant: 50).isActive = true

        self.popupShadow()

        backgroundEffect.clipsToBounds = true
        backgroundEffect.effect = UIBlurEffect(style: .systemUltraThinMaterial)

#if !os(visionOS)
        if #available(iOS 26.0, *) {
            backgroundEffect.effect = UIGlassEffect()
        }
#endif

        self.addSubview(backgroundEffect, anchors: LayoutAnchor.fullFrame)

        selectionBlur.clipsToBounds = true
        selectionBlur.backgroundColor = .label.withAlphaComponent(0.3)
        self.addSubview(selectionBlur, anchors: [.centerY(0)])

        selectionConstraint = selectionBlur.leadingAnchor.constraint(equalTo: self.leadingAnchor)
        selectionConstraint?.isActive = true

        for index in 0..<sections.count {
            let button = SectionButton(index, icon: sections[index].icon, emojiPicker: emojiPicker)

            let prevButton: UIView? = categoryButtons.last

            self.addSubview(button, anchors: [.top(padding), .bottom(padding)])
            categoryButtons.append(button)

            button.leadingAnchor.constraint(equalTo: prevButton?.trailingAnchor ?? self.leadingAnchor, constant: prevButton != nil ? 0 : padding).isActive = true
            if let prevButton { button.widthAnchor.constraint(equalTo: prevButton.widthAnchor).isActive = true }
        }

        if let lastButton = self.subviews.last {
            lastButton.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -padding).isActive = true

            selectionBlur.widthAnchor.constraint(equalTo: lastButton.widthAnchor).isActive = true
            selectionBlur.heightAnchor.constraint(equalTo: lastButton.heightAnchor).isActive = true
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        backgroundEffect.layer.cornerRadius = backgroundEffect.frame.height*0.5
        selectionBlur.layer.cornerRadius = selectionBlur.frame.height*0.5

        updateCorrectSelection(animated: false)
    }

    func updateCorrectSelection(animated: Bool = true) {
        guard let emojiPicker else { return }

        if !emojiPicker.isSearching { self.alpha = emojiPicker.config.categories.count <= 1 ? 0 : 1 }

        let posX: CGFloat? = categoryButtons.indices.contains(emojiPicker.focusedSection) ? categoryButtons[emojiPicker.focusedSection].frame.origin.x : nil
        let safePos: CGFloat = posX ?? padding

        if animated {
            selectionConstraint?.constant = safePos
            UIView.animate(withDuration: 0.25) {
                self.layoutIfNeeded()
            }
            return
        }

        selectionConstraint?.constant = safePos
    }

    class SectionButton: UIView {
        required init?(coder: NSCoder) { nil }

        let imageView = UIImageView()

        let section: Int
        weak var emojiPicker: ElegantEmojiPicker?

        init(_ section: Int, icon: UIImage?, emojiPicker: ElegantEmojiPicker) {
            self.section = section
            self.emojiPicker = emojiPicker
            super.init(frame: .zero)

            self.heightAnchor.constraint(equalTo: self.widthAnchor).isActive = true

            imageView.image = icon
            imageView.contentMode = .scaleAspectFit
            imageView.tintColor = .systemGray
            self.addSubview(imageView, anchors: LayoutAnchor.fullFrame(8))

            self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tap)))
        }

        @objc func tap() {
            guard let emojiPicker else { return }
            emojiPicker.didSelectSection(section)
        }
    }
}
