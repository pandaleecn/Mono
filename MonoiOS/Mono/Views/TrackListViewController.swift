//
//  TrackListViewController.swift
//  Mono
//
//  Created by 李大鹏 on 2025/12/20.
//

import UIKit

final class TrackListViewController: UIViewController {
    
    // MARK: - Properties
    private let folder: AudioFolder
    private var tracks: [AudioTrack] = []
    
    // MARK: - UI
    private lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .plain)
        table.translatesAutoresizingMaskIntoConstraints = false
        table.register(TrackCell.self, forCellReuseIdentifier: TrackCell.identifier)
        table.delegate = self
        table.dataSource = self
        table.rowHeight = 60
        table.separatorInset = UIEdgeInsets(top: 0, left: 56, bottom: 0, right: 0)
        table.backgroundColor = .systemBackground
        return table
    }()
    
    private lazy var miniPlayerView: MiniPlayerView = {
        let view = MiniPlayerView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()
    
    // MARK: - Init
    init(folder: AudioFolder) {
        self.folder = folder
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupMiniPlayer()
        loadTracks()
        
        AudioPlayerManager.shared.delegate = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateMiniPlayerVisibility()
        tableView.reloadData()
        scrollToLastPlayedTrack()
    }
    
    /// 滚动到上次播放的曲目，使其显示在列表中间
    private func scrollToLastPlayedTrack() {
        // 优先滚动到当前正在播放的曲目
        if let currentTrack = AudioPlayerManager.shared.currentTrack,
           currentTrack.folderName == folder.name,
           let index = tracks.firstIndex(of: currentTrack) {
            scrollToIndex(index)
            return
        }
        
        // 否则滚动到该文件夹上次播放的曲目
        if let lastPlayedURL = PlaybackStateManager.shared.getLastPlayedTrack(forFolder: folder.name),
           let index = tracks.firstIndex(where: { $0.url == lastPlayedURL }) {
            scrollToIndex(index)
        }
    }
    
    private func scrollToIndex(_ index: Int) {
        let indexPath = IndexPath(row: index, section: 0)
        
        // 延迟一点执行，确保 tableView 已经完成布局
        DispatchQueue.main.async {
            self.tableView.scrollToRow(at: indexPath, at: .middle, animated: false)
        }
    }
    
    // MARK: - Setup
    private func setupUI() {
        title = folder.name
        view.backgroundColor = .systemBackground
        
        // 文件夹设置按钮
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "ellipsis.circle"),
            style: .plain,
            target: self,
            action: #selector(showFolderSettings)
        )
        
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func setupMiniPlayer() {
        view.addSubview(miniPlayerView)
        
        NSLayoutConstraint.activate([
            miniPlayerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            miniPlayerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            miniPlayerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            miniPlayerView.heightAnchor.constraint(equalToConstant: 64)
        ])
        
        miniPlayerView.onTap = { [weak self] in
            self?.showPlayer()
        }
    }
    
    // MARK: - Data Loading
    private func loadTracks() {
        // 快速加载列表（不含时长）
        tracks = FileService.shared.getTracks(in: folder)
        tableView.reloadData()
        
        // 异步加载时长
        FileService.shared.loadDurations(for: tracks) { [weak self] updatedTracks in
            guard let self = self else { return }
            self.tracks = updatedTracks
            self.tableView.reloadData()
        }
    }
    
    // MARK: - Mini Player
    private func updateMiniPlayerVisibility() {
        let hasTrack = AudioPlayerManager.shared.currentTrack != nil
        miniPlayerView.isHidden = !hasTrack
        
        // 刷新 mini player 内容
        if hasTrack {
            miniPlayerView.refreshUI()
        }
        
        let bottomInset: CGFloat = hasTrack ? 64 : 0
        tableView.contentInset.bottom = bottomInset
        tableView.scrollIndicatorInsets.bottom = bottomInset
    }
    
    private func showPlayer() {
        let playerVC = PlayerViewController()
        playerVC.modalPresentationStyle = .pageSheet
        if let sheet = playerVC.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
        present(playerVC, animated: true)
    }
    
    // MARK: - Folder Settings
    @objc private func showFolderSettings() {
        let settings = PlaybackStateManager.shared
        let skipIntro = settings.getSkipIntroSeconds(forFolder: folder.name)
        let skipOutro = settings.getSkipOutroSeconds(forFolder: folder.name)
        
        let alert = UIAlertController(
            title: "文件夹设置",
            message: "「\(folder.name)」的播放设置",
            preferredStyle: .actionSheet
        )
        
        alert.addAction(UIAlertAction(
            title: "跳过开头：\(formatSeconds(skipIntro))",
            style: .default
        ) { [weak self] _ in
            self?.showSkipIntroPicker()
        })
        
        alert.addAction(UIAlertAction(
            title: "跳过结尾：\(formatSeconds(skipOutro))",
            style: .default
        ) { [weak self] _ in
            self?.showSkipOutroPicker()
        })
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        
        if let popover = alert.popoverPresentationController {
            popover.barButtonItem = navigationItem.rightBarButtonItem
        }
        
        present(alert, animated: true)
    }
    
    private func formatSeconds(_ seconds: Int) -> String {
        if seconds == 0 {
            return "关闭"
        } else if seconds < 60 {
            return "\(seconds) 秒"
        } else {
            let minutes = seconds / 60
            let remainingSeconds = seconds % 60
            if remainingSeconds == 0 {
                return "\(minutes) 分钟"
            } else {
                return "\(minutes) 分 \(remainingSeconds) 秒"
            }
        }
    }
    
    private func showSkipIntroPicker() {
        let options = [0, 5, 10, 15, 30, 60, 90, 120]
        let currentValue = PlaybackStateManager.shared.getSkipIntroSeconds(forFolder: folder.name)
        
        let alert = UIAlertController(
            title: "跳过开头",
            message: "每次播放新曲目时自动跳过开头",
            preferredStyle: .actionSheet
        )
        
        for seconds in options {
            let action = UIAlertAction(title: formatSeconds(seconds), style: .default) { [weak self] _ in
                guard let self = self else { return }
                PlaybackStateManager.shared.setSkipIntroSeconds(seconds, forFolder: self.folder.name)
            }
            if seconds == currentValue {
                action.setValue(true, forKey: "checked")
            }
            alert.addAction(action)
        }
        
        // 自定义输入
        let customTitle = options.contains(currentValue) ? "自定义..." : "自定义 (\(formatSeconds(currentValue)))"
        let customAction = UIAlertAction(title: customTitle, style: .default) { [weak self] _ in
            self?.showCustomSkipIntroInput()
        }
        if !options.contains(currentValue) && currentValue > 0 {
            customAction.setValue(true, forKey: "checked")
        }
        alert.addAction(customAction)
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        
        if let popover = alert.popoverPresentationController {
            popover.barButtonItem = navigationItem.rightBarButtonItem
        }
        
        present(alert, animated: true)
    }
    
    private func showCustomSkipIntroInput() {
        let alert = UIAlertController(
            title: "自定义跳过开头",
            message: "请输入要跳过的秒数",
            preferredStyle: .alert
        )
        
        alert.addTextField { textField in
            textField.placeholder = "秒数"
            textField.keyboardType = .numberPad
            let currentValue = PlaybackStateManager.shared.getSkipIntroSeconds(forFolder: self.folder.name)
            if currentValue > 0 {
                textField.text = "\(currentValue)"
            }
        }
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "确定", style: .default) { [weak self] _ in
            guard let self = self else { return }
            if let text = alert.textFields?.first?.text,
               let seconds = Int(text), seconds >= 0 {
                PlaybackStateManager.shared.setSkipIntroSeconds(seconds, forFolder: self.folder.name)
            }
        })
        
        present(alert, animated: true)
    }
    
    private func showSkipOutroPicker() {
        let options = [0, 5, 10, 15, 30, 60]
        let currentValue = PlaybackStateManager.shared.getSkipOutroSeconds(forFolder: folder.name)
        
        let alert = UIAlertController(
            title: "跳过结尾",
            message: "曲目结尾前自动跳到下一曲",
            preferredStyle: .actionSheet
        )
        
        for seconds in options {
            let action = UIAlertAction(title: formatSeconds(seconds), style: .default) { [weak self] _ in
                guard let self = self else { return }
                PlaybackStateManager.shared.setSkipOutroSeconds(seconds, forFolder: self.folder.name)
            }
            if seconds == currentValue {
                action.setValue(true, forKey: "checked")
            }
            alert.addAction(action)
        }
        
        // 自定义输入
        let customTitle = options.contains(currentValue) ? "自定义..." : "自定义 (\(formatSeconds(currentValue)))"
        let customAction = UIAlertAction(title: customTitle, style: .default) { [weak self] _ in
            self?.showCustomSkipOutroInput()
        }
        if !options.contains(currentValue) && currentValue > 0 {
            customAction.setValue(true, forKey: "checked")
        }
        alert.addAction(customAction)
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        
        if let popover = alert.popoverPresentationController {
            popover.barButtonItem = navigationItem.rightBarButtonItem
        }
        
        present(alert, animated: true)
    }
    
    private func showCustomSkipOutroInput() {
        let alert = UIAlertController(
            title: "自定义跳过结尾",
            message: "请输入曲目结束前要跳过的秒数",
            preferredStyle: .alert
        )
        
        alert.addTextField { textField in
            textField.placeholder = "秒数"
            textField.keyboardType = .numberPad
            let currentValue = PlaybackStateManager.shared.getSkipOutroSeconds(forFolder: self.folder.name)
            if currentValue > 0 {
                textField.text = "\(currentValue)"
            }
        }
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "确定", style: .default) { [weak self] _ in
            guard let self = self else { return }
            if let text = alert.textFields?.first?.text,
               let seconds = Int(text), seconds >= 0 {
                PlaybackStateManager.shared.setSkipOutroSeconds(seconds, forFolder: self.folder.name)
            }
        })
        
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDataSource
extension TrackListViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tracks.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: TrackCell.identifier, for: indexPath) as! TrackCell
        let track = tracks[indexPath.row]
        let isPlaying = AudioPlayerManager.shared.currentTrack == track
        let lastPlayedURL = PlaybackStateManager.shared.getLastPlayedTrack(forFolder: folder.name)
        let isLastPlayed = !isPlaying && track.url == lastPlayedURL
        cell.configure(with: track, index: indexPath.row + 1, isPlaying: isPlaying, isLastPlayed: isLastPlayed)
        return cell
    }
}

// MARK: - UITableViewDelegate
extension TrackListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let track = tracks[indexPath.row]
        AudioPlayerManager.shared.play(track: track, in: tracks)
        
        updateMiniPlayerVisibility()
        tableView.reloadData()
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let deleteAction = UIContextualAction(style: .destructive, title: "删除") { [weak self] _, _, completionHandler in
            self?.confirmDeleteTrack(at: indexPath)
            completionHandler(true)
        }
        deleteAction.image = UIImage(systemName: "trash")
        
        return UISwipeActionsConfiguration(actions: [deleteAction])
    }
    
    private func confirmDeleteTrack(at indexPath: IndexPath) {
        let track = tracks[indexPath.row]
        
        let alert = UIAlertController(
            title: "删除音频",
            message: "确定要删除「\(track.displayName)」吗？此操作不可恢复。",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "删除", style: .destructive) { [weak self] _ in
            self?.deleteTrack(at: indexPath)
        })
        
        present(alert, animated: true)
    }
    
    private func deleteTrack(at indexPath: IndexPath) {
        let track = tracks[indexPath.row]
        
        // 如果正在播放该音频，停止播放
        if AudioPlayerManager.shared.currentTrack == track {
            AudioPlayerManager.shared.pause()
            PlaybackStateManager.shared.clearState()
        }
        
        if FileService.shared.deleteTrack(track) {
            tracks.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .automatic)
            
            // 更新播放列表
            AudioPlayerManager.shared.currentPlaylist = tracks
            
            // 如果删除后没有音频了，返回上一页
            if tracks.isEmpty {
                navigationController?.popViewController(animated: true)
            }
        }
    }
}

// MARK: - AudioPlayerDelegate
extension TrackListViewController: AudioPlayerDelegate {
    func playerDidUpdateTime(_ currentTime: TimeInterval, duration: TimeInterval) {
        // MiniPlayerView 会自己处理
    }
    
    func playerDidChangePlayingState(_ isPlaying: Bool) {
        tableView.reloadData()
    }
    
    func playerDidChangeTrack(_ track: AudioTrack?) {
        updateMiniPlayerVisibility()
        tableView.reloadData()
    }
    
    func playerDidFinishTrack() {
        // 自动播放下一曲在 AudioPlayerManager 中处理
    }
}

// MARK: - TrackCell
final class TrackCell: UITableViewCell {
    static let identifier = "TrackCell"
    
    private let indexLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .monospacedDigitSystemFont(ofSize: 14, weight: .regular)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        return label
    }()
    
    private let playingIndicator: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.image = UIImage(systemName: "speaker.wave.2.fill")
        imageView.tintColor = .systemOrange
        imageView.contentMode = .scaleAspectFit
        imageView.isHidden = true
        return imageView
    }()
    
    private let lastPlayedIndicator: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.image = UIImage(systemName: "bookmark.fill")
        imageView.tintColor = .systemBlue
        imageView.contentMode = .scaleAspectFit
        imageView.isHidden = true
        return imageView
    }()
    
    private let nameLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 16)
        label.textColor = .label
        label.numberOfLines = 2
        return label
    }()
    
    private let durationLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        label.textColor = .tertiaryLabel
        return label
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        contentView.addSubview(indexLabel)
        contentView.addSubview(playingIndicator)
        contentView.addSubview(lastPlayedIndicator)
        contentView.addSubview(nameLabel)
        contentView.addSubview(durationLabel)
        
        NSLayoutConstraint.activate([
            indexLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            indexLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            indexLabel.widthAnchor.constraint(equalToConstant: 28),
            
            playingIndicator.centerXAnchor.constraint(equalTo: indexLabel.centerXAnchor),
            playingIndicator.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            playingIndicator.widthAnchor.constraint(equalToConstant: 20),
            playingIndicator.heightAnchor.constraint(equalToConstant: 20),
            
            lastPlayedIndicator.centerXAnchor.constraint(equalTo: indexLabel.centerXAnchor),
            lastPlayedIndicator.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            lastPlayedIndicator.widthAnchor.constraint(equalToConstant: 16),
            lastPlayedIndicator.heightAnchor.constraint(equalToConstant: 16),
            
            nameLabel.leadingAnchor.constraint(equalTo: indexLabel.trailingAnchor, constant: 12),
            nameLabel.trailingAnchor.constraint(equalTo: durationLabel.leadingAnchor, constant: -12),
            nameLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            
            durationLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            durationLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            durationLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 50)
        ])
    }
    
    func configure(with track: AudioTrack, index: Int, isPlaying: Bool, isLastPlayed: Bool = false) {
        nameLabel.text = track.displayName
        durationLabel.text = track.duration.formattedTime
        indexLabel.text = "\(index)"
        
        // 显示状态：正在播放 > 上次播放 > 普通
        indexLabel.isHidden = isPlaying || isLastPlayed
        playingIndicator.isHidden = !isPlaying
        lastPlayedIndicator.isHidden = !isLastPlayed || isPlaying
        
        if isPlaying {
            nameLabel.textColor = .systemOrange
        } else if isLastPlayed {
            nameLabel.textColor = .systemBlue
        } else {
            nameLabel.textColor = .label
        }
    }
}


