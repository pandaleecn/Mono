//
//  MiniPlayerView.swift
//  Mono
//
//  Created by 李大鹏 on 2025/12/20.
//

import UIKit

final class MiniPlayerView: UIView {
    
    var onTap: (() -> Void)?
    
    // MARK: - UI
    private let containerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .secondarySystemBackground
        return view
    }()
    
    private let progressView: UIProgressView = {
        let progress = UIProgressView(progressViewStyle: .default)
        progress.translatesAutoresizingMaskIntoConstraints = false
        progress.progressTintColor = .systemOrange
        progress.trackTintColor = .systemGray5
        progress.progress = 0
        return progress
    }()
    
    private let trackIcon: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.image = UIImage(systemName: "music.note")
        imageView.tintColor = .systemOrange
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .systemGray5
        imageView.layer.cornerRadius = 6
        imageView.clipsToBounds = true
        return imageView
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textColor = .label
        label.text = "未在播放"
        return label
    }()
    
    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabel
        label.text = ""
        return label
    }()
    
    private lazy var playPauseButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: "play.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 22)), for: .normal)
        button.tintColor = .label
        button.addTarget(self, action: #selector(playPauseTapped), for: .touchUpInside)
        return button
    }()
    
    // MARK: - Init
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupObservers()
        updateUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Setup
    private func setupUI() {
        addSubview(containerView)
        containerView.addSubview(progressView)
        containerView.addSubview(trackIcon)
        containerView.addSubview(titleLabel)
        containerView.addSubview(subtitleLabel)
        containerView.addSubview(playPauseButton)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            progressView.topAnchor.constraint(equalTo: containerView.topAnchor),
            progressView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            progressView.heightAnchor.constraint(equalToConstant: 2),
            
            trackIcon.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            trackIcon.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            trackIcon.widthAnchor.constraint(equalToConstant: 44),
            trackIcon.heightAnchor.constraint(equalToConstant: 44),
            
            titleLabel.leadingAnchor.constraint(equalTo: trackIcon.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: playPauseButton.leadingAnchor, constant: -12),
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 14),
            
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            
            playPauseButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            playPauseButton.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            playPauseButton.widthAnchor.constraint(equalToConstant: 44),
            playPauseButton.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        // 点击手势
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(viewTapped))
        containerView.addGestureRecognizer(tapGesture)
        
        // 添加顶部分割线
        let topBorder = UIView()
        topBorder.translatesAutoresizingMaskIntoConstraints = false
        topBorder.backgroundColor = .separator
        containerView.addSubview(topBorder)
        
        NSLayoutConstraint.activate([
            topBorder.topAnchor.constraint(equalTo: containerView.topAnchor),
            topBorder.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            topBorder.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            topBorder.heightAnchor.constraint(equalToConstant: 0.5)
        ])
    }
    
    private func setupObservers() {
        // 监听播放器状态变化
        AudioPlayerManager.shared.delegate = self
    }
    
    // MARK: - Actions
    @objc private func playPauseTapped() {
        AudioPlayerManager.shared.togglePlayPause()
    }
    
    @objc private func viewTapped() {
        onTap?()
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
    }
    
    private func updatePlayPauseButton(isPlaying: Bool) {
        let imageName = isPlaying ? "pause.fill" : "play.fill"
        playPauseButton.setImage(UIImage(systemName: imageName, withConfiguration: UIImage.SymbolConfiguration(pointSize: 22)), for: .normal)
    }
    
    private func updateProgress(current: TimeInterval, duration: TimeInterval) {
        guard duration > 0 else {
            progressView.progress = 0
            return
        }
        progressView.progress = Float(current / duration)
    }
}

// MARK: - AudioPlayerDelegate
extension MiniPlayerView: AudioPlayerDelegate {
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
        // 处理播放结束
    }
}



