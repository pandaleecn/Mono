//
//  PlayerViewController.swift
//  Mono
//
//  Created by 李大鹏 on 2025/12/20.
//

import UIKit

final class PlayerViewController: UIViewController {
    
    // MARK: - UI
    private let trackIconView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .systemGray5
        view.layer.cornerRadius = 16
        return view
    }()
    
    private let trackIconImage: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.image = UIImage(systemName: "music.note")
        imageView.tintColor = .systemOrange
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 20, weight: .semibold)
        label.textColor = .label
        label.textAlignment = .center
        label.numberOfLines = 2
        return label
    }()
    
    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 15)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        return label
    }()
    
    private let progressSlider: UISlider = {
        let slider = UISlider()
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.minimumTrackTintColor = .systemOrange
        slider.maximumTrackTintColor = .systemGray4
        slider.setThumbImage(makeThumbImage(size: 14), for: .normal)
        return slider
    }()
    
    private let currentTimeLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        label.textColor = .secondaryLabel
        label.text = "00:00"
        return label
    }()
    
    private let remainingTimeLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        label.textColor = .secondaryLabel
        label.text = "-00:00"
        label.textAlignment = .right
        return label
    }()
    
    private lazy var skipBackwardButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: "gobackward.15", withConfiguration: UIImage.SymbolConfiguration(pointSize: 32)), for: .normal)
        button.tintColor = .label
        button.addTarget(self, action: #selector(skipBackwardTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var playPauseButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: "play.circle.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 64)), for: .normal)
        button.tintColor = .systemOrange
        button.addTarget(self, action: #selector(playPauseTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var skipForwardButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: "goforward.15", withConfiguration: UIImage.SymbolConfiguration(pointSize: 32)), for: .normal)
        button.tintColor = .label
        button.addTarget(self, action: #selector(skipForwardTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var previousButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: "backward.end.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 24)), for: .normal)
        button.tintColor = .label
        button.addTarget(self, action: #selector(previousTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var nextButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: "forward.end.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 24)), for: .normal)
        button.tintColor = .label
        button.addTarget(self, action: #selector(nextTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var rateButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.titleLabel?.font = .systemFont(ofSize: 15, weight: .medium)
        button.setTitleColor(.label, for: .normal)
        button.backgroundColor = .systemGray5
        button.layer.cornerRadius = 16
        button.addTarget(self, action: #selector(rateTapped), for: .touchUpInside)
        return button
    }()
    
    private var isSeeking = false
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupSliderActions()
        
        AudioPlayerManager.shared.delegate = self
        updateUI()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // 恢复上一个页面的 delegate
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // 添加子视图
        view.addSubview(trackIconView)
        trackIconView.addSubview(trackIconImage)
        view.addSubview(titleLabel)
        view.addSubview(subtitleLabel)
        view.addSubview(progressSlider)
        view.addSubview(currentTimeLabel)
        view.addSubview(remainingTimeLabel)
        view.addSubview(previousButton)
        view.addSubview(skipBackwardButton)
        view.addSubview(playPauseButton)
        view.addSubview(skipForwardButton)
        view.addSubview(nextButton)
        view.addSubview(rateButton)
        
        NSLayoutConstraint.activate([
            // 音乐图标
            trackIconView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),
            trackIconView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            trackIconView.widthAnchor.constraint(equalToConstant: 200),
            trackIconView.heightAnchor.constraint(equalToConstant: 200),
            
            trackIconImage.centerXAnchor.constraint(equalTo: trackIconView.centerXAnchor),
            trackIconImage.centerYAnchor.constraint(equalTo: trackIconView.centerYAnchor),
            trackIconImage.widthAnchor.constraint(equalToConstant: 80),
            trackIconImage.heightAnchor.constraint(equalToConstant: 80),
            
            // 标题
            titleLabel.topAnchor.constraint(equalTo: trackIconView.bottomAnchor, constant: 32),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            
            // 副标题
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            subtitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            
            // 进度条
            progressSlider.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 32),
            progressSlider.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            progressSlider.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            
            // 时间标签
            currentTimeLabel.topAnchor.constraint(equalTo: progressSlider.bottomAnchor, constant: 8),
            currentTimeLabel.leadingAnchor.constraint(equalTo: progressSlider.leadingAnchor),
            
            remainingTimeLabel.topAnchor.constraint(equalTo: progressSlider.bottomAnchor, constant: 8),
            remainingTimeLabel.trailingAnchor.constraint(equalTo: progressSlider.trailingAnchor),
            
            // 播放控制
            playPauseButton.topAnchor.constraint(equalTo: currentTimeLabel.bottomAnchor, constant: 32),
            playPauseButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            playPauseButton.widthAnchor.constraint(equalToConstant: 80),
            playPauseButton.heightAnchor.constraint(equalToConstant: 80),
            
            skipBackwardButton.centerYAnchor.constraint(equalTo: playPauseButton.centerYAnchor),
            skipBackwardButton.trailingAnchor.constraint(equalTo: playPauseButton.leadingAnchor, constant: -24),
            
            skipForwardButton.centerYAnchor.constraint(equalTo: playPauseButton.centerYAnchor),
            skipForwardButton.leadingAnchor.constraint(equalTo: playPauseButton.trailingAnchor, constant: 24),
            
            previousButton.centerYAnchor.constraint(equalTo: playPauseButton.centerYAnchor),
            previousButton.trailingAnchor.constraint(equalTo: skipBackwardButton.leadingAnchor, constant: -16),
            
            nextButton.centerYAnchor.constraint(equalTo: playPauseButton.centerYAnchor),
            nextButton.leadingAnchor.constraint(equalTo: skipForwardButton.trailingAnchor, constant: 16),
            
            // 倍速按钮
            rateButton.topAnchor.constraint(equalTo: playPauseButton.bottomAnchor, constant: 40),
            rateButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            rateButton.widthAnchor.constraint(equalToConstant: 80),
            rateButton.heightAnchor.constraint(equalToConstant: 32)
        ])
    }
    
    private func setupSliderActions() {
        progressSlider.addTarget(self, action: #selector(sliderTouchBegan), for: .touchDown)
        progressSlider.addTarget(self, action: #selector(sliderValueChanged), for: .valueChanged)
        progressSlider.addTarget(self, action: #selector(sliderTouchEnded), for: [.touchUpInside, .touchUpOutside, .touchCancel])
    }
    
    // MARK: - Actions
    @objc private func playPauseTapped() {
        AudioPlayerManager.shared.togglePlayPause()
    }
    
    @objc private func skipBackwardTapped() {
        AudioPlayerManager.shared.skipBackward(15)
    }
    
    @objc private func skipForwardTapped() {
        AudioPlayerManager.shared.skipForward(15)
    }
    
    @objc private func previousTapped() {
        AudioPlayerManager.shared.playPrevious()
    }
    
    @objc private func nextTapped() {
        AudioPlayerManager.shared.playNext()
    }
    
    @objc private func rateTapped() {
        showRatePicker()
    }
    
    @objc private func sliderTouchBegan() {
        isSeeking = true
    }
    
    @objc private func sliderValueChanged() {
        let duration = AudioPlayerManager.shared.duration
        let newTime = TimeInterval(progressSlider.value) * duration
        currentTimeLabel.text = newTime.formattedTime
        remainingTimeLabel.text = "-\((duration - newTime).formattedTime)"
    }
    
    @objc private func sliderTouchEnded() {
        let duration = AudioPlayerManager.shared.duration
        let newTime = TimeInterval(progressSlider.value) * duration
        AudioPlayerManager.shared.seek(to: newTime)
        isSeeking = false
    }
    
    // MARK: - Rate Picker
    private func showRatePicker() {
        let alert = UIAlertController(title: "播放速度", message: nil, preferredStyle: .actionSheet)
        
        let currentRate = AudioPlayerManager.shared.playbackRate
        
        for rate in AudioPlayerManager.availableRates {
            let title = rate == 1.0 ? "正常" : "\(rate)x"
            let action = UIAlertAction(title: title, style: .default) { [weak self] _ in
                AudioPlayerManager.shared.playbackRate = rate
                self?.updateRateButton()
            }
            
            if abs(rate - currentRate) < 0.01 {
                action.setValue(true, forKey: "checked")
            }
            
            alert.addAction(action)
        }
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        
        if let popover = alert.popoverPresentationController {
            popover.sourceView = rateButton
            popover.sourceRect = rateButton.bounds
        }
        
        present(alert, animated: true)
    }
    
    // MARK: - Update UI
    private func updateUI() {
        let player = AudioPlayerManager.shared
        
        if let track = player.currentTrack {
            titleLabel.text = track.displayName
            subtitleLabel.text = track.folderName
        } else {
            titleLabel.text = "未在播放"
            subtitleLabel.text = ""
        }
        
        updatePlayPauseButton(isPlaying: player.isPlaying)
        updateRateButton()
        updateProgress(current: player.currentTime, duration: player.duration)
    }
    
    private func updatePlayPauseButton(isPlaying: Bool) {
        let imageName = isPlaying ? "pause.circle.fill" : "play.circle.fill"
        playPauseButton.setImage(UIImage(systemName: imageName, withConfiguration: UIImage.SymbolConfiguration(pointSize: 64)), for: .normal)
    }
    
    private func updateRateButton() {
        let rate = AudioPlayerManager.shared.playbackRate
        let title = rate == 1.0 ? "1x" : "\(rate)x"
        rateButton.setTitle(title, for: .normal)
    }
    
    private func updateProgress(current: TimeInterval, duration: TimeInterval) {
        guard !isSeeking else { return }
        guard duration > 0 && duration.isFinite else {
            progressSlider.value = 0
            currentTimeLabel.text = "00:00"
            remainingTimeLabel.text = "-00:00"
            return
        }
        
        progressSlider.value = Float(current / duration)
        currentTimeLabel.text = current.formattedTime
        remainingTimeLabel.text = "-\((duration - current).formattedTime)"
    }
    
    // MARK: - Helper
    private static func makeThumbImage(size: CGFloat) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: CGSize(width: size, height: size))
            UIColor.white.setFill()
            context.cgContext.fillEllipse(in: rect)
            UIColor.systemGray3.setStroke()
            context.cgContext.setLineWidth(0.5)
            context.cgContext.strokeEllipse(in: rect.insetBy(dx: 0.25, dy: 0.25))
        }
    }
}

// MARK: - AudioPlayerDelegate
extension PlayerViewController: AudioPlayerDelegate {
    func playerDidUpdateTime(_ currentTime: TimeInterval, duration: TimeInterval) {
        updateProgress(current: currentTime, duration: duration)
    }
    
    func playerDidChangePlayingState(_ isPlaying: Bool) {
        updatePlayPauseButton(isPlaying: isPlaying)
    }
    
    func playerDidChangeTrack(_ track: AudioTrack?) {
        updateUI()
    }
    
    func playerDidFinishTrack() {
        // 播放结束
    }
}



