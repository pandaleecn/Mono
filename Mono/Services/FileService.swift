//
//  FileService.swift
//  Mono
//
//  Created by 李大鹏 on 2025/12/20.
//

import Foundation
import AVFoundation

final class FileService {
    static let shared = FileService()
    
    private let supportedExtensions = ["mp3", "m4a", "m4b", "wav", "aac", "flac", "caf"]
    
    private init() {}
    
    /// Documents 目录
    var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    /// 获取所有文件夹（按名称排序）
    func getFolders() -> [AudioFolder] {
        let fileManager = FileManager.default
        
        do {
            let contents = try fileManager.contentsOfDirectory(
                at: documentsURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
            
            var folders: [AudioFolder] = []
            
            for url in contents {
                var isDirectory: ObjCBool = false
                if fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory),
                   isDirectory.boolValue {
                    let trackCount = getTracksCount(in: url)
                    if trackCount > 0 {
                        folders.append(AudioFolder(
                            name: url.lastPathComponent,
                            url: url,
                            trackCount: trackCount
                        ))
                    }
                }
            }
            
            // 按文件夹名排序（数字感知排序）
            return folders.sorted { 
                $0.name.compare($1.name, options: [.numeric, .caseInsensitive, .widthInsensitive]) == .orderedAscending 
            }
        } catch {
            print("获取文件夹失败: \(error)")
            return []
        }
    }
    
    /// 获取文件夹内的音频文件数量
    private func getTracksCount(in folderURL: URL) -> Int {
        let fileManager = FileManager.default
        
        do {
            let contents = try fileManager.contentsOfDirectory(
                at: folderURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            
            return contents.filter { url in
                supportedExtensions.contains(url.pathExtension.lowercased())
            }.count
        } catch {
            return 0
        }
    }
    
    /// 获取文件夹内的音频文件（按文件名排序）
    func getTracks(in folder: AudioFolder) -> [AudioTrack] {
        let fileManager = FileManager.default
        
        do {
            let contents = try fileManager.contentsOfDirectory(
                at: folder.url,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            
            var tracks: [AudioTrack] = []
            
            for url in contents {
                if supportedExtensions.contains(url.pathExtension.lowercased()) {
                    var track = AudioTrack(
                        fileName: url.lastPathComponent,
                        url: url,
                        folderName: folder.name
                    )
                    track.duration = getAudioDuration(url: url)
                    tracks.append(track)
                }
            }
            
            // 按文件名排序（数字感知排序，确保 01 < 02 < 10）
            return tracks.sorted { 
                $0.fileName.compare($1.fileName, options: [.numeric, .caseInsensitive, .widthInsensitive]) == .orderedAscending 
            }
        } catch {
            print("获取音频文件失败: \(error)")
            return []
        }
    }
    
    /// 获取音频时长
    private func getAudioDuration(url: URL) -> TimeInterval {
        let asset = AVAsset(url: url)
        return CMTimeGetSeconds(asset.duration)
    }
    
    /// 根据URL查找对应的文件夹
    func findFolder(for trackURL: URL) -> AudioFolder? {
        let folderURL = trackURL.deletingLastPathComponent()
        let folderName = folderURL.lastPathComponent
        let trackCount = getTracksCount(in: folderURL)
        
        return AudioFolder(name: folderName, url: folderURL, trackCount: trackCount)
    }
    
    // MARK: - 删除操作
    
    /// 删除文件夹
    func deleteFolder(_ folder: AudioFolder) -> Bool {
        do {
            try FileManager.default.removeItem(at: folder.url)
            return true
        } catch {
            print("删除文件夹失败: \(error)")
            return false
        }
    }
    
    /// 删除音频文件
    func deleteTrack(_ track: AudioTrack) -> Bool {
        do {
            try FileManager.default.removeItem(at: track.url)
            return true
        } catch {
            print("删除音频文件失败: \(error)")
            return false
        }
    }
}


