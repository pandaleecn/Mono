# Mono Android - 听书播放器

Android 版听书播放器，使用 Kotlin + Jetpack Compose 开发。

## 功能特性

- **文件导入**：将音频文件夹复制到 `Music/Mono/` 目录
- **二级目录**：文件夹 → 音频文件，按文件名排序
- **倍速播放**：0.5x ~ 3.0x，自动记住选择
- **断点续播**：退出后自动保存进度，启动时恢复
- **后台播放**：通知栏控制、锁屏播放
- **滑动删除**：左滑删除文件夹或音频

## 技术栈

- **语言**：Kotlin
- **UI**：Jetpack Compose + Material 3
- **音频**：Media3 ExoPlayer
- **存储**：SharedPreferences
- **最低版本**：Android 8.0 (API 26)

## 项目结构

```
app/src/main/java/com/mono/
├── MainActivity.kt                 # 入口 Activity
├── MonoApplication.kt              # Application
│
├── data/
│   ├── model/
│   │   ├── AudioFolder.kt          # 文件夹数据类
│   │   └── AudioTrack.kt           # 音频数据类
│   ├── repository/
│   │   └── FileRepository.kt       # 文件扫描
│   └── preferences/
│       └── PreferencesManager.kt   # 状态持久化
│
├── player/
│   ├── AudioPlaybackService.kt     # 前台播放服务
│   └── PlaybackState.kt            # 播放状态
│
└── ui/
    ├── navigation/
    │   └── NavGraph.kt             # 导航
    ├── screens/
    │   ├── FolderListScreen.kt     # 文件夹列表
    │   ├── TrackListScreen.kt      # 音频列表
    │   └── PlayerScreen.kt         # 播放详情
    ├── components/
    │   └── MiniPlayer.kt           # 迷你播放栏
    └── theme/
        └── Theme.kt                # 主题
```

## 使用说明

1. 用 Android Studio 打开 `MonoAndroid` 目录
2. 等待 Gradle 同步完成
3. 连接 Android 设备或启动模拟器
4. 点击 Run 运行应用
5. 将音频文件夹复制到设备的 `Music/Mono/` 目录
6. 在 App 中即可看到导入的内容

## 文件导入方式

### 方法一：通过 USB 连接
1. 用 USB 连接手机和电脑
2. 在手机上选择「文件传输」模式
3. 在电脑上打开手机的 Music 文件夹
4. 创建 Mono 文件夹（如果不存在）
5. 将音频文件夹拖入 Music/Mono/

### 方法二：通过文件管理器
1. 使用手机自带的文件管理器
2. 将音频文件夹复制到 Music/Mono/

## AI 开发指南

### 添加新功能
1. **UI 相关**：修改 `ui/screens/` 或 `ui/components/`
2. **播放功能**：修改 `player/AudioPlaybackService.kt`
3. **文件操作**：修改 `data/repository/FileRepository.kt`
4. **持久化**：修改 `data/preferences/PreferencesManager.kt`

### 代码规范
- 使用 Kotlin 协程处理异步
- UI 使用 Compose 声明式语法
- 单例通过 `MonoApplication.instance` 访问
- 播放服务通过 `AudioPlaybackService.getInstance()` 访问


