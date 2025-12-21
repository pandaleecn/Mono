//
//  AudioPlayerManager.swift
//  Mono
//
//  Created by 李大鹏 on 2025/12/20.
//

import Foundation
import AVFoundation
import MediaPlayer

protocol AudioPlayerDelegate: AnyObject {
    func playerDidUpdateTime(_ currentTime: TimeInterval, duration: TimeInterval)
    func playerDidChangePlayingState(_ isPlaying: Bool)
    func playerDidChangeTrack(_ track: AudioTrack?)
    func playerDidFinishTrack()
}

final class AudioPlayerManager: NSObject {
    static let shared = AudioPlayerManager()
    
    weak var delegate: AudioPlayerDelegate?
    
    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var timeObserver: Any?
    
    // MARK: - 当前状态
    private(set) var currentTrack: AudioTrack?
    var currentPlaylist: [AudioTrack] = []
    var currentIndex: Int = 0
    
    var isPlaying: Bool {
        return player?.rate ?? 0 > 0
    }
    
    var currentTime: TimeInterval {
        return player?.currentTime().seconds ?? 0
    }
    
    var duration: TimeInterval {
        return playerItem?.duration.seconds ?? 0
    }
    
    // MARK: - 倍速选项
    static let availableRates: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0]
    
    var playbackRate: Float {
        get { PlaybackStateManager.shared.playbackRate }
        set {
            PlaybackStateManager.shared.playbackRate = newValue
            if isPlaying {
                player?.rate = newValue
            }
        }
    }
    
    // MARK: - 初始化
    private override init() {
        super.init()
        setupAudioSession()
        setupRemoteCommandCenter()
    }
    
    deinit {
        removeTimeObserver()
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - 音频会话配置
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [])
            try session.setActive(true)
        } catch {
            print("音频会话配置失败: \(error)")
        }
    }
    
    // MARK: - 远程控制中心
    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.play()
            return .success
        }
        
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }
        
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.playNext()
            return .success
        }
        
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.playPrevious()
            return .success
        }
        
        commandCenter.skipForwardCommand.preferredIntervals = [15]
        commandCenter.skipForwardCommand.addTarget { [weak self] _ in
            self?.skipForward(15)
            return .success
        }
        
        commandCenter.skipBackwardCommand.preferredIntervals = [15]
        commandCenter.skipBackwardCommand.addTarget { [weak self] _ in
            self?.skipBackward(15)
            return .success
        }
        
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            self?.seek(to: event.positionTime)
            return .success
        }
    }
    
    // MARK: - 播放控制
    func play(track: AudioTrack, in playlist: [AudioTrack]) {
        currentPlaylist = playlist
        if let index = playlist.firstIndex(of: track) {
            currentIndex = index
        }
        playTrack(track)
    }
    
    func play(at index: Int) {
        guard index >= 0 && index < currentPlaylist.count else { return }
        currentIndex = index
        playTrack(currentPlaylist[index])
    }
    
    private func playTrack(_ track: AudioTrack) {
        removeTimeObserver()
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: playerItem)
        
        currentTrack = track
        playerItem = AVPlayerItem(url: track.url)
        player = AVPlayer(playerItem: playerItem)
        
        // 监听播放结束
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidFinishPlaying),
            name: .AVPlayerItemDidPlayToEndTime,
            object: playerItem
        )
        
        addTimeObserver()
        player?.rate = playbackRate
        
        delegate?.playerDidChangeTrack(track)
        delegate?.playerDidChangePlayingState(true)
        
        updateNowPlayingInfo()
        saveState()
    }
    
    func play() {
        player?.rate = playbackRate
        delegate?.playerDidChangePlayingState(true)
        updateNowPlayingInfo()
    }
    
    func pause() {
        player?.pause()
        delegate?.playerDidChangePlayingState(false)
        updateNowPlayingInfo()
        saveState()
    }
    
    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }
    
    func playNext() {
        guard currentIndex < currentPlaylist.count - 1 else { return }
        play(at: currentIndex + 1)
    }
    
    func playPrevious() {
        // 如果播放超过3秒，回到开头；否则上一曲
        if currentTime > 3 {
            seek(to: 0)
        } else if currentIndex > 0 {
            play(at: currentIndex - 1)
        } else {
            seek(to: 0)
        }
    }
    
    // MARK: - 进度控制
    func seek(to time: TimeInterval) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player?.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
        updateNowPlayingInfo()
        saveState()
    }
    
    func skipForward(_ seconds: TimeInterval) {
        let newTime = min(currentTime + seconds, duration)
        seek(to: newTime)
    }
    
    func skipBackward(_ seconds: TimeInterval) {
        let newTime = max(currentTime - seconds, 0)
        seek(to: newTime)
    }
    
    // MARK: - 时间观察
    private func addTimeObserver() {
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            let current = self.currentTime
            let total = self.duration
            if total.isFinite && !total.isNaN {
                self.delegate?.playerDidUpdateTime(current, duration: total)
            }
        }
    }
    
    private func removeTimeObserver() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
    }
    
    // MARK: - 播放结束
    @objc private func playerDidFinishPlaying() {
        delegate?.playerDidFinishTrack()
        
        // 自动播放下一曲
        if currentIndex < currentPlaylist.count - 1 {
            playNext()
        } else {
            // 播放列表结束
            delegate?.playerDidChangePlayingState(false)
        }
    }
    
    // MARK: - 锁屏信息
    private func updateNowPlayingInfo() {
        guard let track = currentTrack else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: track.displayName,
            MPMediaItemPropertyArtist: track.folderName,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? playbackRate : 0
        ]
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
    
    // MARK: - 状态保存
    private func saveState() {
        PlaybackStateManager.shared.saveState(
            trackURL: currentTrack?.url,
            time: currentTime
        )
    }
    
    // MARK: - 恢复播放
    func restorePlayback() {
        guard let savedURL = PlaybackStateManager.shared.currentTrackURL,
              FileManager.default.fileExists(atPath: savedURL.path) else {
            return
        }
        
        // 找到对应的文件夹和曲目
        guard let folder = FileService.shared.findFolder(for: savedURL) else {
            return
        }
        
        let tracks = FileService.shared.getTracks(in: folder)
        guard let track = tracks.first(where: { $0.url == savedURL }) else {
            return
        }
        
        // 恢复播放列表和曲目
        currentPlaylist = tracks
        if let index = tracks.firstIndex(of: track) {
            currentIndex = index
        }
        
        // 加载但不播放
        currentTrack = track
        playerItem = AVPlayerItem(url: track.url)
        player = AVPlayer(playerItem: playerItem)
        
        // 恢复进度
        let savedTime = PlaybackStateManager.shared.currentTime
        if savedTime > 0 {
            let cmTime = CMTime(seconds: savedTime, preferredTimescale: 600)
            player?.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
        }
        
        // 监听播放结束
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidFinishPlaying),
            name: .AVPlayerItemDidPlayToEndTime,
            object: playerItem
        )
        
        addTimeObserver()
        delegate?.playerDidChangeTrack(track)
    }
}


