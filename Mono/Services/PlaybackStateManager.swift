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
}


