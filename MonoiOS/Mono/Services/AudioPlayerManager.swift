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
    private var playerItemStatusObserver: NSKeyValueObservation?
    
    // MARK: - 当前状态
    private(set) var currentTrack: AudioTrack?
    var currentPlaylist: [AudioTrack] = []
    var currentIndex: Int = 0
    
    /// 记录被中断前是否正在播放，用于中断结束后恢复
    private var wasPlayingBeforeInterruption = false
    
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
                // 倍速变化时更新锁屏信息，确保进度条正确
                updateNowPlayingInfo()
            }
        }
    }
    
    // MARK: - 初始化
    private override init() {
        super.init()
        setupAudioSession()
        setupRemoteCommandCenter()
        setupInterruptionObserver()
    }
    
    deinit {
        removeTimeObserver()
        playerItemStatusObserver?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - 中断监听
    private func setupInterruptionObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionInterruption),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )
    }
    
    @objc private func handleAudioSessionInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            // 中断开始（如来电），记录当前播放状态
            wasPlayingBeforeInterruption = isPlaying
            if isPlaying {
                pause()
            }
            
        case .ended:
            // 中断结束，检查是否应该恢复播放
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else {
                return
            }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            
            if options.contains(.shouldResume) && wasPlayingBeforeInterruption {
                // 延迟一小段时间再恢复播放，确保系统准备就绪
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    self?.play()
                }
            }
            wasPlayingBeforeInterruption = false
            
        @unknown default:
            break
        }
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
        
        // 播放/暂停控制
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.play()
            return .success
        }
        
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }
        
        // 上一曲/下一曲控制 - 锁屏显示切换按钮
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.playNext()
            return .success
        }
        
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.playPrevious()
            return .success
        }
        
        // 禁用快进/快退命令，这样锁屏会显示上一首/下一首按钮
        // 如果启用 skipForward/skipBackward，iOS 会优先显示跳过按钮而隐藏切换按钮
        commandCenter.skipForwardCommand.isEnabled = false
        commandCenter.skipBackwardCommand.isEnabled = false
        
        // 进度条拖动控制
        commandCenter.changePlaybackPositionCommand.isEnabled = true
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
        // 保存当前曲目的播放位置（切换前）
        if let oldTrack = currentTrack, oldTrack != track {
            let position = currentTime
            if position > 0 {
                PlaybackStateManager.shared.saveTrackPosition(url: oldTrack.url, time: position)
            }
        }
        
        removeTimeObserver()
        playerItemStatusObserver?.invalidate()
        playerItemStatusObserver = nil
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: playerItem)
        
        currentTrack = track
        playerItem = AVPlayerItem(url: track.url)
        player = AVPlayer(playerItem: playerItem)
        
        // 获取文件夹级别的设置
        let folderName = track.folderName
        let skipIntro = PlaybackStateManager.shared.getSkipIntroSeconds(forFolder: folderName)
        let savedPosition = PlaybackStateManager.shared.getTrackPosition(url: track.url)
        
        // 监听 playerItem 状态，等加载完成后恢复位置或应用跳过开头设置
        playerItemStatusObserver = playerItem?.observe(\.status, options: [.new]) { [weak self] item, _ in
            guard let self = self else { return }
            if item.status == .readyToPlay {
                DispatchQueue.main.async {
                    let skipTime = TimeInterval(skipIntro)
                    
                    // 优先恢复保存的位置，否则使用跳过开头设置
                    if savedPosition > 0 && savedPosition < self.duration - 5 {
                        // 有保存的位置，恢复到该位置
                        self.seek(to: savedPosition)
                    } else if skipIntro > 0 && self.duration > skipTime + 10 {
                        // 没有保存位置，应用跳过开头
                        self.seek(to: skipTime)
                    }
                    
                    self.updateNowPlayingInfo()
                }
            }
        }
        
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
        
        // 先更新基本信息（duration 可能还是 0，等 readyToPlay 后会再次更新）
        updateNowPlayingInfo()
        saveState()
        
        // 保存该文件夹的上次播放曲目
        PlaybackStateManager.shared.saveLastPlayedTrack(url: track.url, forFolder: track.folderName)
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
        
        // 暂停时保存当前曲目的播放位置
        if let track = currentTrack {
            PlaybackStateManager.shared.saveTrackPosition(url: track.url, time: currentTime)
        }
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
        
        // 立即更新锁屏信息（使用目标时间），避免进度条跳动
        updateNowPlayingInfo(elapsedTime: time)
        
        player?.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] finished in
            guard finished else { return }
            self?.saveState()
        }
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
    /// 上次更新锁屏信息的时间，用于定期刷新（蓝牙同步）
    private var lastNowPlayingUpdateTime: TimeInterval = 0
    /// 上次保存播放位置的时间
    private var lastPositionSaveTime: TimeInterval = 0
    
    private func addTimeObserver() {
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            let current = self.currentTime
            let total = self.duration
            
            guard total.isFinite && !total.isNaN else { return }
            
            self.delegate?.playerDidUpdateTime(current, duration: total)
            
            // 定期更新锁屏/蓝牙进度信息
            // 使用倍速播放时更频繁更新（每5秒），正常速度每10秒更新
            let updateInterval: TimeInterval = self.playbackRate != 1.0 ? 5 : 10
            if abs(current - self.lastNowPlayingUpdateTime) >= updateInterval {
                self.lastNowPlayingUpdateTime = current
                self.updateNowPlayingInfo()
            }
            
            // 定期保存播放位置（每30秒），防止意外退出丢失进度
            if abs(current - self.lastPositionSaveTime) >= 30 {
                self.lastPositionSaveTime = current
                if let track = self.currentTrack {
                    PlaybackStateManager.shared.saveTrackPosition(url: track.url, time: current)
                    PlaybackStateManager.shared.saveState(trackURL: track.url, time: current)
                }
            }
            
            // 跳过结尾检测（使用文件夹级别设置）
            let folderName = self.currentTrack?.folderName ?? ""
            let skipOutro = PlaybackStateManager.shared.getSkipOutroSeconds(forFolder: folderName)
            if skipOutro > 0 {
                let skipTime = TimeInterval(skipOutro)
                // 当剩余时间小于设定值时，自动播放下一曲
                if total - current <= skipTime && total - current > skipTime - 1 {
                    // 确保只触发一次（在 1 秒窗口内）
                    if self.currentIndex < self.currentPlaylist.count - 1 {
                        self.playNext()
                    }
                }
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
        // 播放完成，清除该曲目的保存位置（下次从头开始）
        if let track = currentTrack {
            PlaybackStateManager.shared.clearTrackPosition(url: track.url)
        }
        
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
    /// 更新锁屏播放信息
    /// - Parameter elapsedTime: 可选的已播放时间，用于 seek 时立即更新（避免使用尚未更新的 currentTime）
    private func updateNowPlayingInfo(elapsedTime: TimeInterval? = nil) {
        guard let track = currentTrack else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        
        let elapsed = elapsedTime ?? currentTime
        let totalDuration = duration
        
        // 确保 duration 有效，否则某些蓝牙设备会显示异常
        guard totalDuration.isFinite && !totalDuration.isNaN && totalDuration > 0 else {
            return
        }
        
        // 使用实际播放速率，锁屏可以正确显示
        // 对于不支持变速的蓝牙设备，通过频繁更新 elapsedTime 来保持同步
        let rate: Double = isPlaying ? Double(playbackRate) : 0.0
        
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: track.displayName,
            MPMediaItemPropertyArtist: track.folderName,
            MPMediaItemPropertyPlaybackDuration: NSNumber(value: totalDuration),
            MPNowPlayingInfoPropertyElapsedPlaybackTime: NSNumber(value: elapsed),
            MPNowPlayingInfoPropertyPlaybackRate: NSNumber(value: rate),
            MPNowPlayingInfoPropertyDefaultPlaybackRate: NSNumber(value: 1.0)
        ]
        
        // 添加曲目编号信息，方便在锁屏看到进度
        if !currentPlaylist.isEmpty {
            info[MPMediaItemPropertyAlbumTrackNumber] = NSNumber(value: currentIndex + 1)
            info[MPMediaItemPropertyAlbumTrackCount] = NSNumber(value: currentPlaylist.count)
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
    
    // MARK: - 状态保存
    private func saveState() {
        PlaybackStateManager.shared.saveState(
            trackURL: currentTrack?.url,
            time: currentTime
        )
        
        // 同时保存当前曲目的播放位置
        if let track = currentTrack {
            PlaybackStateManager.shared.saveTrackPosition(url: track.url, time: currentTime)
        }
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
        
        // 清理之前的观察者
        playerItemStatusObserver?.invalidate()
        playerItemStatusObserver = nil
        
        // 加载但不播放
        currentTrack = track
        playerItem = AVPlayerItem(url: track.url)
        player = AVPlayer(playerItem: playerItem)
        
        // 监听 playerItem 状态，等加载完成后更新锁屏信息
        let savedTime = PlaybackStateManager.shared.currentTime
        playerItemStatusObserver = playerItem?.observe(\.status, options: [.new]) { [weak self] item, _ in
            guard let self = self else { return }
            if item.status == .readyToPlay {
                DispatchQueue.main.async {
                    // 恢复进度
                    if savedTime > 0 {
                        let cmTime = CMTime(seconds: savedTime, preferredTimescale: 600)
                        self.player?.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
                    }
                    self.updateNowPlayingInfo(elapsedTime: savedTime > 0 ? savedTime : nil)
                }
            }
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


