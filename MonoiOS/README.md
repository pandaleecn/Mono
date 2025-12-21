# Mono - 听书播放器

一个简洁的 iOS 有声书/音乐播放器，专为听书场景设计。

## 功能特性

- **文件传输**：通过 Finder/iTunes 将音频文件夹拖入 App
- **二级目录**：文件夹 → 音频文件，按文件名排序
- **倍速播放**：0.5x ~ 3.0x，自动记住选择
- **断点续播**：退出后自动保存进度，启动时恢复
- **后台播放**：锁屏控制、控制中心播放
- **滑动删除**：左滑删除文件夹或音频文件

## 技术栈

- **语言**：Swift 5
- **UI**：UIKit（纯代码，无 Storyboard）
- **音频**：AVFoundation / AVPlayer
- **存储**：UserDefaults（状态持久化）
- **最低版本**：iOS 15.0

---

## 项目结构

```
Mono/
├── AppDelegate.swift              # 应用入口，配置音频会话
├── SceneDelegate.swift            # 场景管理，窗口初始化，恢复播放状态
├── Info.plist                     # 配置：文件共享、后台音频
│
├── Models/
│   └── AudioTrack.swift           # 数据模型：AudioTrack, AudioFolder
│
├── Services/
│   ├── AudioPlayerManager.swift   # 播放器核心（单例）
│   ├── FileService.swift          # 文件扫描与删除
│   └── PlaybackStateManager.swift # 播放状态持久化
│
├── Views/
│   ├── FolderListViewController.swift  # 首页：文件夹列表
│   ├── TrackListViewController.swift   # 音频列表
│   ├── MiniPlayerView.swift            # 底部迷你播放栏
│   └── PlayerViewController.swift      # 播放详情页（倍速选择）
│
├── Extensions/
│   └── TimeInterval+Format.swift  # 时间格式化
│
└── Assets.xcassets/               # 图片资源
```

---

## 核心类说明

### AudioPlayerManager（单例）

播放控制核心，负责：
- 播放/暂停/上一曲/下一曲
- 倍速控制（通过 `AVPlayer.rate`）
- 进度跳转（seek）
- 锁屏远程控制（MPRemoteCommandCenter）
- 播放状态通知（通过 delegate）

```swift
// 使用示例
AudioPlayerManager.shared.play(track: track, in: playlist)
AudioPlayerManager.shared.togglePlayPause()
AudioPlayerManager.shared.playbackRate = 1.5
AudioPlayerManager.shared.seek(to: 60.0)
```

### FileService（单例）

文件系统操作：
- `getFolders()` - 获取 Documents 下所有包含音频的文件夹
- `getTracks(in:)` - 获取文件夹内的音频文件列表
- `deleteFolder(_:)` - 删除文件夹
- `deleteTrack(_:)` - 删除音频文件

### PlaybackStateManager（单例）

UserDefaults 封装，保存：
- `currentTrackURL` - 当前播放文件路径
- `currentTime` - 播放进度（秒）
- `playbackRate` - 播放倍速

### AudioPlayerDelegate

播放器状态回调协议：
```swift
protocol AudioPlayerDelegate: AnyObject {
    func playerDidUpdateTime(_ currentTime: TimeInterval, duration: TimeInterval)
    func playerDidChangePlayingState(_ isPlaying: Bool)
    func playerDidChangeTrack(_ track: AudioTrack?)
    func playerDidFinishTrack()
}
```

---

## 数据模型

### AudioFolder
```swift
struct AudioFolder: Equatable {
    let name: String        // 文件夹名
    let url: URL            // 文件夹路径
    var trackCount: Int     // 音频文件数量
}
```

### AudioTrack
```swift
struct AudioTrack: Equatable {
    let fileName: String    // 文件名（含扩展名）
    let url: URL            // 文件路径
    let folderName: String  // 所属文件夹名
    var duration: TimeInterval  // 时长（秒）
    
    var displayName: String // 不含扩展名的显示名
}
```

---

## 关键配置

### Info.plist

```xml
<!-- 启用 iTunes/Finder 文件共享 -->
<key>UIFileSharingEnabled</key>
<true/>
<key>LSSupportsOpeningDocumentsInPlace</key>
<true/>

<!-- 后台音频 -->
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
</array>
```

### 支持的音频格式

`mp3, m4a, m4b, wav, aac, flac, caf`

（定义在 `FileService.supportedExtensions`）

---

## AI 开发指南

### 添加新功能的步骤

1. **理解现有架构**：先阅读上述项目结构和核心类说明
2. **确定修改范围**：
   - UI 相关 → `Views/` 目录
   - 播放逻辑 → `AudioPlayerManager.swift`
   - 文件操作 → `FileService.swift`
   - 持久化 → `PlaybackStateManager.swift`
3. **遵循现有模式**：
   - 使用纯代码 UIKit（无 Storyboard）
   - 单例模式用于全局服务
   - Delegate 模式用于状态回调

### 常见功能扩展示例

#### 添加新的播放控制
修改 `AudioPlayerManager.swift`，添加方法后在 UI 层调用。

#### 添加新的持久化字段
在 `PlaybackStateManager.swift` 中添加新的 key 和属性。

#### 添加新的列表页面
1. 在 `Views/` 创建新的 ViewController
2. 参考 `FolderListViewController` 或 `TrackListViewController` 的模式
3. 实现 `UITableViewDataSource` 和 `UITableViewDelegate`

#### 添加新的音频格式支持
在 `FileService.supportedExtensions` 数组中添加扩展名。

### 代码风格

- 使用 `// MARK: -` 分隔代码区块
- 私有属性使用 `private` 修饰
- 单例使用 `static let shared`
- UI 组件使用 lazy 初始化
- 约束使用 `NSLayoutConstraint.activate([])`

---

## 使用说明

1. 用数据线连接 iPhone 和 Mac
2. 打开 Finder，选择设备 → 文件 → Mono
3. 将音频**文件夹**拖入（需要二级结构：文件夹 → 音频文件）
4. 打开 App，下拉刷新即可看到


