//
//  SceneDelegate.swift
//  Mono
//
//  Created by 李大鹏 on 2025/12/20.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        // 创建窗口
        window = UIWindow(windowScene: windowScene)
        
        // 设置根视图控制器
        let folderListVC = FolderListViewController()
        let navigationController = UINavigationController(rootViewController: folderListVC)
        
        // 配置导航栏外观
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        navigationController.navigationBar.standardAppearance = appearance
        navigationController.navigationBar.scrollEdgeAppearance = appearance
        
        window?.rootViewController = navigationController
        window?.makeKeyAndVisible()
        
        // 恢复上次播放状态
        AudioPlayerManager.shared.restorePlayback()
        
        // 如果设置了启动时自动播放，则开始播放
        if PlaybackStateManager.shared.autoPlayOnLaunch,
           AudioPlayerManager.shared.currentTrack != nil {
            // 延迟一点执行，确保 UI 和播放器都准备好
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                AudioPlayerManager.shared.play()
            }
        }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // 保存播放状态
        if let track = AudioPlayerManager.shared.currentTrack {
            PlaybackStateManager.shared.saveState(
                trackURL: track.url,
                time: AudioPlayerManager.shared.currentTime
            )
        }
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // 保存播放状态
        if let track = AudioPlayerManager.shared.currentTrack {
            PlaybackStateManager.shared.saveState(
                trackURL: track.url,
                time: AudioPlayerManager.shared.currentTime
            )
        }
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // 保存播放状态
        if let track = AudioPlayerManager.shared.currentTrack {
            PlaybackStateManager.shared.saveState(
                trackURL: track.url,
                time: AudioPlayerManager.shared.currentTime
            )
        }
    }
}
