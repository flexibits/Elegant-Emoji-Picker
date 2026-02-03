//
//  ElegantEmojiPicker.swift
//  Demo
//
//  Created by Grant Oganyan on 3/10/23.
//

import Foundation
import UIKit

/// Present this view controller when you want to offer users emoji selection.
/// Conform to its delegate ElegantEmojiPickerDelegate and pass it to the view controller to interact with it and receive user's selection.
open class ElegantEmojiPicker: UIViewController {
    required public init?(coder: NSCoder) { nil }

    public weak var delegate: ElegantEmojiPickerDelegate?
    public let config: ElegantConfiguration
    public let localization: ElegantLocalization

    let padding = 16.0
    let topElementHeight = 40.0

    var searchFieldBackground: UIVisualEffectView?
    var searchField: UITextField?
    var clearButton: UIButton?
    var randomButton: UIButton?
    var resetButton: UIButton?
    var closeButton: UIButton?

    let fadeContainer = UIView()
    let collectionLayout: UICollectionViewFlowLayout = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 10
        layout.minimumInteritemSpacing = 10
        layout.sectionInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        layout.itemSize = CGSize(width: 40.0, height: 40.0)
        return layout
    }()
    var collectionView: UICollectionView?

    var toolbar: SectionsToolbar?
    var toolbarBottomConstraint: NSLayoutConstraint?

    var skinToneSelector: SkinToneSelector?
    var emojiPreview: EmojiPreview?
    public var previewingEmoji: Emoji?

    var emojiSections = [EmojiSection]()
    var searchResults: [Emoji]?

    private var prevFocusedSection: Int = 0
    var focusedSection: Int = 0

    var isSearching: Bool = false
    var overridingFocusedSection: Bool = false

    // swiftlint:disable function_body_length line_length cyclomatic_complexity
    /// Initialize and present this view controller to offer emoji selection to users.
    /// - Parameters:
    ///   - delegate: provide a delegate to interact with the picker
    ///   - configuration: provide a configuration to change UI and behavior
    ///   - localization: provide a localization to change texts on all labels
    ///   - sourceView: provide a source view for a popover presentation style.
    ///   - sourceNavigationBarButton: provide a source navigation bar button for a popover presentation style.
    public init(delegate: ElegantEmojiPickerDelegate? = nil, configuration: ElegantConfiguration = ElegantConfiguration(), localization: ElegantLocalization = ElegantLocalization(), sourceView: UIView? = nil, sourceNavigationBarButton: UIBarButtonItem? = nil) {
        self.delegate = delegate
        self.config = configuration
        self.localization = localization
        super.init(nibName: nil, bundle: nil)

        self.emojiSections = self.delegate?.emojiPicker(self, loadEmojiSections: config, localization) ?? ElegantEmojiPicker.getDefaultEmojiSections(config: config, localization: localization)

        if let sourceView, !AppConfiguration.isIPhone, AppConfiguration.windowFrame.width > 500 {
            self.modalPresentationStyle = .popover
            self.popoverPresentationController?.sourceView = sourceView
        } else if let sourceNavigationBarButton, !AppConfiguration.isIPhone, AppConfiguration.windowFrame.width > 500 {
            self.modalPresentationStyle = .popover
            self.popoverPresentationController?.barButtonItem = sourceNavigationBarButton
        } else {
            self.modalPresentationStyle = .formSheet

#if !os(visionOS)
            if #available(iOS 15.0, *) {
                self.sheetPresentationController?.prefersGrabberVisible = true
                self.sheetPresentationController?.detents = [.medium(), .large()]
            }
#endif
        }

        self.presentationController?.delegate = self

        if #unavailable(iOS 26.0) { // in iOS 26 they forced opaque white background (in large detent) and liquid glass (in medium detent), so we only need the blur for OS below it
            self.view.addSubview(UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial)), anchors: LayoutAnchor.fullFrame)
        }

        if config.showSearch {
            let searchFieldBg = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
            searchFieldBackground = searchFieldBg
            searchFieldBg.backgroundColor = .systemBackground.withAlphaComponent(0.5)
            searchFieldBg.layer.cornerRadius = 8
            searchFieldBg.clipsToBounds = true
            searchFieldBg.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tappedSearchBackground)))
            self.view.addSubview(searchFieldBg, anchors: [.safeAreaLeading(padding), .safeAreaTop(padding*1.5), .height(topElementHeight)])

            let spacing = 10.0

            let clrBtn = UIButton()
            clearButton = clrBtn
            clrBtn.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
            clrBtn.tintColor = .systemGray
            clrBtn.alpha = 0
            clrBtn.contentMode = .scaleAspectFit
            clrBtn.setContentHuggingPriority(.required, for: .horizontal)
            clrBtn.setContentCompressionResistancePriority(.required, for: .horizontal)
            clrBtn.addTarget(self, action: #selector(clearButtonTap), for: .touchUpInside)
            searchFieldBg.contentView.addSubview(clrBtn, anchors: [.trailing(spacing), .top(spacing), .bottom(spacing)])

            let srchField = UITextField()
            searchField = srchField
            srchField.placeholder = localization.searchFieldPlaceholder
            srchField.delegate = self
            srchField.addTarget(self, action: #selector(searchFieldChanged), for: .editingChanged)
            searchFieldBg.contentView.addSubview(srchField, anchors: [.leading(spacing), .top(spacing), .bottom(spacing), .trailingToLeading(clrBtn, spacing)])
        }

        if config.showRandom {
            let rndBtn = UIButton()
            randomButton = rndBtn
            rndBtn.setTitle(localization.randomButtonTitle, for: .normal)
            rndBtn.setTitleColor(.label, for: .normal)
            rndBtn.setTitleColor(.systemGray, for: .highlighted)
            rndBtn.addTarget(self, action: #selector(tappedRandom), for: .touchUpInside)
            rndBtn.contentHorizontalAlignment = .trailing
            rndBtn.setContentHuggingPriority(.required, for: .horizontal)
            rndBtn.setContentCompressionResistancePriority(.required, for: .horizontal)
            self.view.addSubview(rndBtn, anchors: [.safeAreaTop(padding*1.5), .height(topElementHeight)])
            rndBtn.leadingAnchor.constraint(equalTo: searchFieldBackground?.trailingAnchor ?? self.view.safeAreaLayoutGuide.leadingAnchor, constant: padding).isActive = true
        }

        if config.showReset {
            let rstBtn = UIButton()
            resetButton = rstBtn
            rstBtn.setTitle(localization.resetButtonTitle, for: .normal)
            rstBtn.setTitleColor(.systemRed, for: .normal)
            rstBtn.addTarget(self, action: #selector(tappedReset), for: .touchUpInside)
            rstBtn.contentHorizontalAlignment = .trailing
            rstBtn.setContentHuggingPriority(.required, for: .horizontal)
            rstBtn.setContentCompressionResistancePriority(.required, for: .horizontal)
            self.view.addSubview(rstBtn, anchors: [.safeAreaTop(padding*1.5), .height(topElementHeight)])
            rstBtn.leadingAnchor.constraint(equalTo: randomButton?.trailingAnchor ?? searchFieldBackground?.trailingAnchor ?? self.view.safeAreaLayoutGuide.leadingAnchor, constant: padding).isActive = true
        }

        if config.showClose {
            let clsBtn = UIButton()
            closeButton = clsBtn
            clsBtn.setImage(UIImage(systemName: "chevron.down"), for: .normal)
            clsBtn.addTarget(self, action: #selector(tappedClose), for: .touchUpInside)
            clsBtn.setContentHuggingPriority(.required, for: .horizontal)
            clsBtn.contentHorizontalAlignment = .trailing
            clsBtn.setContentCompressionResistancePriority(.required, for: .horizontal)
            self.view.addSubview(clsBtn, anchors: [.safeAreaTop(padding*1.5), .height(topElementHeight)])
            clsBtn.leadingAnchor.constraint(equalTo: resetButton?.trailingAnchor ?? randomButton?.trailingAnchor ?? searchFieldBackground?.trailingAnchor ?? self.view.safeAreaLayoutGuide.leadingAnchor, constant: padding).isActive = true
        }

        if let rightMostItem = closeButton ?? resetButton ?? randomButton ?? searchFieldBackground {
            rightMostItem.trailingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.trailingAnchor, constant: -padding).isActive = true
        }

        let gradient = CAGradientLayer()
        gradient.colors = [UIColor.clear.cgColor, UIColor.black.cgColor]
        gradient.startPoint = CGPoint(x: 0.5, y: 0)
        gradient.endPoint = CGPoint(x: 0.5, y: 0.05)
        fadeContainer.layer.mask = gradient
        self.view.addSubview(fadeContainer, anchors: [.safeAreaLeading(0), .safeAreaTrailing(0), .bottom(0)])
        fadeContainer.topAnchor.constraint(equalTo: closeButton?.bottomAnchor ?? resetButton?.bottomAnchor ?? randomButton?.bottomAnchor ?? searchFieldBackground?.bottomAnchor ?? self.view.safeAreaLayoutGuide.topAnchor).isActive = true

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: collectionLayout)
        collectionView?.backgroundColor = .clear
        collectionView?.delegate = self
        collectionView?.dataSource = self
        collectionView?.contentInset.bottom = 50 + padding // Compensating for the toolbar
        collectionView?.translatesAutoresizingMaskIntoConstraints = false
        collectionView?.register(EmojiCell.self, forCellWithReuseIdentifier: "EmojiCell")
        collectionView?.register(CollectionViewSectionHeader.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "SectionHeader")
        if let collectionView {
            fadeContainer.addSubview(collectionView, anchors: LayoutAnchor.fullFrame)
        }

        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(longPress))
        longPress.minimumPressDuration = 0.3
        longPress.delegate = self
        collectionView?.addGestureRecognizer(longPress)

        if config.showToolbar && emojiSections.count > 1 { addToolbar() }
    }
    // swiftlint:enable function_body_length line_length cyclomatic_complexity

    func addToolbar() {
        let sectionsToolbar = SectionsToolbar(sections: emojiSections, emojiPicker: self)
        toolbar = sectionsToolbar
        self.view.addSubview(sectionsToolbar, anchors: [.centerX(0)])

        sectionsToolbar.leadingAnchor.constraint(greaterThanOrEqualTo: self.view.safeAreaLayoutGuide.leadingAnchor, constant: padding).isActive = true
        sectionsToolbar.trailingAnchor.constraint(lessThanOrEqualTo: self.view.safeAreaLayoutGuide.trailingAnchor, constant: -padding).isActive = true

        toolbarBottomConstraint = sectionsToolbar.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor, constant: -padding)
        toolbarBottomConstraint?.isActive = true
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        collectionLayout.headerReferenceSize = CGSize(width: collectionView?.frame.width ?? 0, height: 50)
        fadeContainer.layer.mask?.frame = fadeContainer.bounds
    }

    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        self.view.backgroundColor = self.traitCollection.userInterfaceStyle == .light ? .black.withAlphaComponent(0.1) : .clear
    }

    @objc func tappedClose() {
        self.dismiss(animated: true)
    }

    @objc func tappedRandom() {
        let randomEmoji = emojiSections.randomElement()?.emojis.randomElement()
        didSelectEmoji(randomEmoji)
    }

    @objc func tappedReset() {
        didSelectEmoji(nil)
    }

    func didSelectEmoji(_ emoji: Emoji?) {
        delegate?.emojiPicker(self, didSelectEmoji: emoji)
        if delegate?.emojiPickerShouldDismissAfterSelection(self) ?? true { self.dismiss(animated: true) }
    }
}

// MARK: Built-in toolbar

extension ElegantEmojiPicker {
    func didSelectSection(_ index: Int) {
        collectionView?.scrollToItem(at: IndexPath(row: 0, section: index), at: .centeredVertically, animated: true)

        overridingFocusedSection = true
        self.focusedSection = index
        self.toolbar?.updateCorrectSelection(animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.overridingFocusedSection = false
        }
    }

    func hideBuiltInToolbar() {
        toolbarBottomConstraint?.constant = 50
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.4) {
            self.toolbar?.alpha = 0
            self.view.layoutIfNeeded()
        }
    }

    func showBuiltInToolbar() {
        toolbarBottomConstraint?.constant = -padding
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.4) {
            self.toolbar?.alpha = 1
            self.view.layoutIfNeeded()
        }
    }
}

// MARK: Search

extension ElegantEmojiPicker: UITextFieldDelegate {
    public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    @objc func searchFieldChanged(_ textField: UITextField) {
        guard let text = textField.text else { return }
        let count = text.count
        let searchTerm = text
        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            guard let self else { return }

            if count == 0 {
                self.searchResults = nil
            } else {
                // swiftlint:disable:next line_length
                self.searchResults = self.delegate?.emojiPicker(self, searchResultFor: searchTerm, fromAvailable: self.emojiSections) ?? ElegantEmojiPicker.getSearchResults(searchTerm, fromAvailable: self.emojiSections)
            }

            DispatchQueue.main.async {
                self.collectionView?.reloadData()
                self.collectionView?.setContentOffset(.zero, animated: false)
            }
        }

        if !isSearching && count > 0 {
            isSearching = true
            clearButton?.alpha = 0.5 // Doing this to keep translucency
            delegate?.emojiPickerDidStartSearching(self)
            hideBuiltInToolbar()
        } else if isSearching && count == 0 {
            isSearching = false
            clearButton?.alpha = 0
            delegate?.emojiPickerDidEndSearching(self)
            showBuiltInToolbar()
        }
    }

    @objc func clearButtonTap() {
        if let searchField {
            searchField.text = ""
            searchFieldChanged(searchField)
        }
    }

    @objc func tappedSearchBackground() {
        searchField?.becomeFirstResponder()
    }
}

// MARK: Collection view

extension ElegantEmojiPicker: UICollectionViewDelegate, UICollectionViewDataSource {

    public func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        guard let sectionHeader = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "SectionHeader", for: indexPath) as? CollectionViewSectionHeader else {
            return UICollectionReusableView()
        }

        let categoryTitle = emojiSections[indexPath.section].title
        if let results = searchResults {
            sectionHeader.label.text = results.isEmpty ? localization.searchResultsEmptyTitle : localization.searchResultsTitle
        } else {
            sectionHeader.label.text = categoryTitle
        }
        return sectionHeader
    }

    public func numberOfSections(in collectionView: UICollectionView) -> Int {
        searchResults == nil ? emojiSections.count : 1
    }

    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        searchResults?.count ?? emojiSections[section].emojis.count
    }

    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "EmojiCell", for: indexPath) as? EmojiCell else {
            return UICollectionViewCell()
        }

        var emoji: Emoji?
        if let results = searchResults, results.indices.contains(indexPath.row) {
            emoji = results[indexPath.row]
        } else if emojiSections.indices.contains(indexPath.section) {
            if emojiSections[indexPath.section].emojis.indices.contains(indexPath.row) {
                emoji = emojiSections[indexPath.section].emojis[indexPath.row]
            }
        }
        if let emoji {
            cell.setup(emoji: emoji, self)
        }

        return cell
    }

    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if let searchResults, indexPath.row < searchResults.count {
            didSelectEmoji(searchResults[indexPath.row])
        } else if indexPath.section < emojiSections.count && indexPath.row < emojiSections[indexPath.section].emojis.count {
            didSelectEmoji(emojiSections[indexPath.section].emojis[indexPath.row])
        }
    }

    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView.contentOffset.y > 10 { searchField?.resignFirstResponder() }

        detectCurrentSection()
        hideSkinToneSelector()
    }
}

// MARK: Long press preview

extension ElegantEmojiPicker: UIGestureRecognizerDelegate {

    @objc func longPress(_ sender: UILongPressGestureRecognizer) {
        if !config.supportsPreview { return }

        if sender.state == .ended {
            hideEmojiPreview()
            return
        }

        guard let collectionView else { return }
        let location = sender.location(in: collectionView)
        guard let indexPath = collectionView.indexPathForItem(at: location),
              let cell = collectionView.cellForItem(at: indexPath) as? EmojiCell,
              let emoji = cell.emoji,
              !(sender.state == .began && emoji.supportsSkinTones && config.supportsSkinTones) else { return }

        if sender.state == .began {
            showEmojiPreview(emoji: emoji)
        } else if sender.state == .changed {
            updateEmojiPreview(newEmoji: emoji)
        }
    }

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }

    func showEmojiPreview(emoji: Emoji) {
        previewingEmoji = emoji
        let preview = EmojiPreview(emoji: emoji)
        emojiPreview = preview
        self.present(preview, animated: false)

        self.delegate?.emojiPicker(self, didStartPreview: emoji)
    }

    func updateEmojiPreview(newEmoji: Emoji) {
        guard let previewingEmoji else { return }
        if previewingEmoji == newEmoji { return }

        self.delegate?.emojiPicker(self, didChangePreview: newEmoji, from: previewingEmoji)

        emojiPreview?.update(newEmoji: newEmoji)
        self.previewingEmoji = newEmoji
    }

    func hideEmojiPreview() {
        guard let previewingEmoji else { return }

        self.delegate?.emojiPicker(self, didEndPreview: previewingEmoji)

        emojiPreview?.dismiss()
        emojiPreview = nil
        self.previewingEmoji = nil
    }
}

// MARK: Skin tones

extension ElegantEmojiPicker {

    func showSkinToneSelector(_ parentCell: EmojiCell) {
        guard let emoji = parentCell.emoji?.duplicate(nil) else { return }

        skinToneSelector?.removeFromSuperview()
        skinToneSelector = SkinToneSelector(emoji, self, fontSize: parentCell.label.font.pointSize)

        if let skinToneSelector {
            collectionView?.addSubview(skinToneSelector, anchors: [.bottomToTop(parentCell, 0)])
        }

        let leading = skinToneSelector?.leadingAnchor.constraint(equalTo: parentCell.leadingAnchor)
        leading?.priority = .defaultHigh
        leading?.isActive = true

        skinToneSelector?.leadingAnchor.constraint(greaterThanOrEqualTo: self.view.safeAreaLayoutGuide.leadingAnchor, constant: padding).isActive = true
        skinToneSelector?.trailingAnchor.constraint(lessThanOrEqualTo: self.view.safeAreaLayoutGuide.trailingAnchor, constant: -padding).isActive = true
    }

    func hideSkinToneSelector() {
        skinToneSelector?.disappear {
            self.skinToneSelector?.removeFromSuperview()
            self.skinToneSelector = nil
        }
    }

    func persistSkinTone(originalEmoji: Emoji, skinTone: EmojiSkinTone?) {
        if !config.persistSkinTones { return }

        ElegantEmojiPicker.persistedSkinTones[originalEmoji.description] = skinTone?.rawValue ?? (config.defaultSkinTone == nil ? nil : "")
    }

    public func cleanPersistedSkinTones() {
        ElegantEmojiPicker.persistedSkinTones = [:]
    }
}

// MARK: Misc

extension ElegantEmojiPicker {

    func detectCurrentSection() {
        if overridingFocusedSection { return }

        let visibleIndexPaths = self.collectionView?.indexPathsForVisibleItems ?? []
        DispatchQueue.global(qos: .userInitiated).async {
            var sectionCounts = [Int: Int]()

            for indexPath in visibleIndexPaths {
                let section = indexPath.section
                sectionCounts[section] = (sectionCounts[section] ?? 0) + 1
            }

            let mostVisibleSection = sectionCounts.max(by: { $0.1 < $1.1 })?.key ?? 0

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }

                self.focusedSection = mostVisibleSection
                if self.prevFocusedSection != self.focusedSection {
                    self.delegate?.emojiPicker(self, focusedSectionChanged: self.focusedSection, fromIndex: self.prevFocusedSection)
                    self.toolbar?.updateCorrectSelection()
                }
                self.prevFocusedSection = self.focusedSection
            }
        }
    }
}

extension ElegantEmojiPicker: UIAdaptivePresentationControllerDelegate {
    public func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        .none // Do not adapt presentation style. We set the presentation style manually in our init(). I know better than Apple.
    }
}

// MARK: Static methods

extension ElegantEmojiPicker {

    /// Persists skin tone for a specified emoji.
    /// - Parameters:
    ///   - originalEmoji: Standard yellow emoji for which to persist a skin tone.
    ///   - skinTone: Skin tone to save. Pass nil to remove saved skin tone.
    static public func persistSkinTone(originalEmoji: Emoji, skinTone: EmojiSkinTone?) {
        ElegantEmojiPicker.persistedSkinTones[originalEmoji.description] = skinTone?.rawValue
    }

    /// Delete all persisted emoji skin tones.
    static public func cleanPersistedSkinTones() {
        ElegantEmojiPicker.persistedSkinTones = [:]
    }

    /// Dictionary containing all emojis with persisted skin tones. [Emoji : Skin tone]
    static public var persistedSkinTones: [String: String] {
        get { UserDefaults.standard.object(forKey: "Finalet_Elegant_Emoji_Picker_Skin_Tones_Key") as? [String: String] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: "Finalet_Elegant_Emoji_Picker_Skin_Tones_Key") }
    }

    /// Returns an array of all available emojis. Use this method to retrieve emojis for your own collection.
    /// - Returns: Array of all emojis.
    static public func getAllEmoji() -> [Emoji] {
        guard let url = Bundle.module.url(forResource: "Emoji Unicode 16.0", withExtension: "json"),
              let emojiData = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([Emoji].self, from: emojiData) else {
            return []
        }
        return decoded
    }

    /// Returns an array of all available emojis categorized by section.
    /// - Parameters:
    ///   - config: Config used to setup the emoji picker.
    ///   - localization: Localization used to setup the emoji picker.
    /// - Returns: Array of default sections [EmojiSection] containing all available emojis.
    static public func getDefaultEmojiSections(config: ElegantConfiguration = ElegantConfiguration(), localization: ElegantLocalization = ElegantLocalization()) -> [EmojiSection] {
        var emojis = getAllEmoji()

        let persistedSkinTones = ElegantEmojiPicker.persistedSkinTones
        emojis = emojis.map({
            if !$0.supportsSkinTones { return $0 }

            if let persistedSkinToneStr = persistedSkinTones[$0.description], let persistedSkinTone = EmojiSkinTone(rawValue: persistedSkinToneStr) {
                return $0.duplicate(persistedSkinTone)
            } else if let defaultSkinTone = config.defaultSkinTone, !(persistedSkinTones[$0.description]?.isEmpty ?? false) {
                return $0.duplicate(defaultSkinTone)
            }

            return $0
        })

        var emojiSections = [EmojiSection]()

        let currentIOSVersion = UIDevice.current.systemVersion

        for emoji in emojis {
            if emoji.iOSVersion.compare(currentIOSVersion, options: .numeric) == .orderedDescending { continue } // Skip unsupported emojis.

            let localizedCategoryTitle = localization.emojiCategoryTitles[emoji.category] ?? emoji.category.rawValue

            if let section = emojiSections.firstIndex(where: { $0.title == localizedCategoryTitle }) {
                emojiSections[section].emojis.append(emoji)
            } else if config.categories.contains(emoji.category) {
                emojiSections.append(
                    EmojiSection(title: localizedCategoryTitle, icon: emoji.category.image, emojis: [emoji])
                )
            }
        }

        return emojiSections
    }

    /// Get emoji search results for a given prompt, using the default search algorithm. First looks for matches in aliases, then in tags, and lastly in description. Sorts search results by relevance.
    /// - Parameters:
    ///   - prompt: Search prompt to use.
    ///   - fromAvailable: Which emojis to search from.
    /// - Returns: Array of [Emoji] that were found.
    static public func getSearchResults(_ prompt: String, fromAvailable: [EmojiSection] ) -> [Emoji] {
        if prompt.isEmpty || prompt == " " { return []}

        var cleanSearchTerm = prompt.lowercased()
        if cleanSearchTerm.last == " " { cleanSearchTerm.removeLast() }

        var results = [Emoji]()

        for section in fromAvailable {
            results.append(contentsOf: section.emojis.filter {
                $0.aliases.contains(where: { $0.localizedCaseInsensitiveContains(cleanSearchTerm) }) ||
                $0.tags.contains(where: { $0.localizedCaseInsensitiveContains(cleanSearchTerm) }) ||
                $0.description.localizedCaseInsensitiveContains(cleanSearchTerm)
            })
        }

        return results.sorted { sortSearchResults($0, $1, prompt: cleanSearchTerm) }
    }

    static func sortSearchResults(_ first: Emoji, _ second: Emoji, prompt: String) -> Bool {
        let regExp = "\\b\(prompt)\\b"

        // swiftlint:disable:next line_length
        // The emoji which contains the exact search prompt in its aliases (first priority), tags (second priority), or description (lowest priority) wins. If both contain it, return the shorted described emoji, since that is usually more accurate.

        if first.aliases.contains(where: { $0.range(of: regExp, options: .regularExpression) != nil }) {
            if second.aliases.contains(where: { $0.range(of: regExp, options: .regularExpression) != nil }) {
                return first.description.count < second.description.count
            }
            return true
        } else if second.aliases.contains(where: { $0.range(of: regExp, options: .regularExpression) != nil }) {
            return false
        }

        if first.tags.contains(where: { $0.range(of: regExp, options: .regularExpression) != nil }) {
            if second.tags.contains(where: { $0.range(of: regExp, options: .regularExpression) != nil }) {
                return first.description.count < second.description.count
            }
            return true
        } else if second.tags.contains(where: { $0.range(of: regExp, options: .regularExpression) != nil }) {
            return false
        }

        if first.description.range(of: regExp, options: .regularExpression) != nil {
            if second.description.range(of: regExp, options: .regularExpression) != nil {
                return first.description.count < second.description.count
            }
            return true
        } else if second.description.range(of: regExp, options: .regularExpression) != nil {
            return false
        }

        return false
    }

}
