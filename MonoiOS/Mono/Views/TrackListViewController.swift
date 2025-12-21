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
    }
    
    // MARK: - Setup
    private func setupUI() {
        title = folder.name
        view.backgroundColor = .systemBackground
        
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
        cell.configure(with: track, index: indexPath.row + 1, isPlaying: isPlaying)
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
            
            nameLabel.leadingAnchor.constraint(equalTo: indexLabel.trailingAnchor, constant: 12),
            nameLabel.trailingAnchor.constraint(equalTo: durationLabel.leadingAnchor, constant: -12),
            nameLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            
            durationLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            durationLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            durationLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 50)
        ])
    }
    
    func configure(with track: AudioTrack, index: Int, isPlaying: Bool) {
        nameLabel.text = track.displayName
        durationLabel.text = track.duration.formattedTime
        indexLabel.text = "\(index)"
        
        indexLabel.isHidden = isPlaying
        playingIndicator.isHidden = !isPlaying
        
        nameLabel.textColor = isPlaying ? .systemOrange : .label
    }
}


