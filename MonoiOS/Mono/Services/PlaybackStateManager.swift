//
//  PlaybackStateManager.swift
//  Mono
//
//  Created by 李大鹏 on 2025/12/20.
//

import Foundation

final class PlaybackStateManager {
    static let shared = PlaybackStateManager()
    
    private let defaults = UserDefaults.standard
    
    // MARK: - Keys
    private enum Keys {
        static let currentTrackURL = "mono_current_track_url"
        static let currentTime = "mono_current_time"
        static let playbackRate = "mono_playback_rate"
        // 设置项
        static let skipIntroSeconds = "mono_skip_intro_seconds"
        static let skipOutroSeconds = "mono_skip_outro_seconds"
        static let autoPlayOnLaunch = "mono_auto_play_on_launch"
        static let rememberPositionPerTrack = "mono_remember_position_per_track"
        static let sleepTimerMinutes = "mono_sleep_timer_minutes"
    }
    
    private init() {}
    
    // MARK: - 播放倍速
    var playbackRate: Float {
        get {
            let rate = defaults.float(forKey: Keys.playbackRate)
            return rate > 0 ? rate : 1.0
        }
        set {
            defaults.set(newValue, forKey: Keys.playbackRate)
        }
    }
    
    // MARK: - 当前播放的音频URL
    var currentTrackURL: URL? {
        get {
            guard let urlString = defaults.string(forKey: Keys.currentTrackURL) else {
                return nil
            }
            return URL(fileURLWithPath: urlString)
        }
        set {
            defaults.set(newValue?.path, forKey: Keys.currentTrackURL)
        }
    }
    
    // MARK: - 当前播放时间
    var currentTime: TimeInterval {
        get {
            return defaults.double(forKey: Keys.currentTime)
        }
        set {
            defaults.set(newValue, forKey: Keys.currentTime)
        }
    }
    
    // MARK: - 保存播放状态
    func saveState(trackURL: URL?, time: TimeInterval) {
        currentTrackURL = trackURL
        currentTime = time
    }
    
    // MARK: - 清除状态
    func clearState() {
        defaults.removeObject(forKey: Keys.currentTrackURL)
        defaults.removeObject(forKey: Keys.currentTime)
    }
    
    // MARK: - 设置项
    
    /// 全局跳过开头秒数（作为新文件夹的默认值）
    var defaultSkipIntroSeconds: Int {
        get { defaults.integer(forKey: Keys.skipIntroSeconds) }
        set { defaults.set(newValue, forKey: Keys.skipIntroSeconds) }
    }
    
    /// 全局跳过结尾秒数（作为新文件夹的默认值）
    var defaultSkipOutroSeconds: Int {
        get { defaults.integer(forKey: Keys.skipOutroSeconds) }
        set { defaults.set(newValue, forKey: Keys.skipOutroSeconds) }
    }
    
    // MARK: - 文件夹级别的跳过设置
    
    /// 获取文件夹的跳过开头秒数
    func getSkipIntroSeconds(forFolder folderName: String) -> Int {
        let key = "mono_folder_skip_intro_\(folderName.hashValue)"
        if defaults.object(forKey: key) == nil {
            // 如果没有设置过，返回全局默认值
            return defaultSkipIntroSeconds
        }
        return defaults.integer(forKey: key)
    }
    
    /// 设置文件夹的跳过开头秒数
    func setSkipIntroSeconds(_ seconds: Int, forFolder folderName: String) {
        let key = "mono_folder_skip_intro_\(folderName.hashValue)"
        defaults.set(seconds, forKey: key)
    }
    
    /// 获取文件夹的跳过结尾秒数
    func getSkipOutroSeconds(forFolder folderName: String) -> Int {
        let key = "mono_folder_skip_outro_\(folderName.hashValue)"
        if defaults.object(forKey: key) == nil {
            return defaultSkipOutroSeconds
        }
        return defaults.integer(forKey: key)
    }
    
    /// 设置文件夹的跳过结尾秒数
    func setSkipOutroSeconds(_ seconds: Int, forFolder folderName: String) {
        let key = "mono_folder_skip_outro_\(folderName.hashValue)"
        defaults.set(seconds, forKey: key)
    }
    
    /// 兼容旧接口：获取当前播放曲目所在文件夹的跳过开头秒数
    var skipIntroSeconds: Int {
        get {
            if let url = currentTrackURL {
                let folderName = url.deletingLastPathComponent().lastPathComponent
                return getSkipIntroSeconds(forFolder: folderName)
            }
            return defaultSkipIntroSeconds
        }
    }
    
    /// 兼容旧接口：获取当前播放曲目所在文件夹的跳过结尾秒数
    var skipOutroSeconds: Int {
        get {
            if let url = currentTrackURL {
                let folderName = url.deletingLastPathComponent().lastPathComponent
                return getSkipOutroSeconds(forFolder: folderName)
            }
            return defaultSkipOutroSeconds
        }
    }
    
    /// 启动时自动播放
    var autoPlayOnLaunch: Bool {
        get { defaults.bool(forKey: Keys.autoPlayOnLaunch) }
        set { defaults.set(newValue, forKey: Keys.autoPlayOnLaunch) }
    }
    
    /// 记住每个曲目的播放位置
    var rememberPositionPerTrack: Bool {
        get {
            // 默认为 true
            if defaults.object(forKey: Keys.rememberPositionPerTrack) == nil {
                return true
            }
            return defaults.bool(forKey: Keys.rememberPositionPerTrack)
        }
        set { defaults.set(newValue, forKey: Keys.rememberPositionPerTrack) }
    }
    
    // MARK: - 每个曲目的播放位置
    
    /// 保存曲目的播放位置
    func saveTrackPosition(url: URL, time: TimeInterval) {
        guard rememberPositionPerTrack else { return }
        let key = "mono_track_position_\(url.path.hashValue)"
        defaults.set(time, forKey: key)
    }
    
    /// 获取曲目的播放位置
    func getTrackPosition(url: URL) -> TimeInterval {
        guard rememberPositionPerTrack else { return 0 }
        let key = "mono_track_position_\(url.path.hashValue)"
        return defaults.double(forKey: key)
    }
    
    /// 清除曲目的播放位置
    func clearTrackPosition(url: URL) {
        let key = "mono_track_position_\(url.path.hashValue)"
        defaults.removeObject(forKey: key)
    }
    
    // MARK: - 每个文件夹的上次播放曲目
    
    /// 保存文件夹上次播放的曲目URL
    func saveLastPlayedTrack(url: URL, forFolder folderName: String) {
        let key = "mono_folder_last_track_\(folderName.hashValue)"
        defaults.set(url.path, forKey: key)
    }
    
    /// 获取文件夹上次播放的曲目URL
    func getLastPlayedTrack(forFolder folderName: String) -> URL? {
        let key = "mono_folder_last_track_\(folderName.hashValue)"
        guard let path = defaults.string(forKey: key) else { return nil }
        return URL(fileURLWithPath: path)
    }
}



