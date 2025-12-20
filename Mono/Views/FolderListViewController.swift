//
//  FolderListViewController.swift
//  Mono
//
//  Created by 李大鹏 on 2025/12/20.
//

import UIKit

final class FolderListViewController: UIViewController {
    
    // MARK: - UI
    private lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .plain)
        table.translatesAutoresizingMaskIntoConstraints = false
        table.register(FolderCell.self, forCellReuseIdentifier: FolderCell.identifier)
        table.delegate = self
        table.dataSource = self
        table.rowHeight = 64
        table.separatorInset = UIEdgeInsets(top: 0, left: 72, bottom: 0, right: 0)
        table.backgroundColor = .systemBackground
        return table
    }()
    
    private lazy var emptyLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "暂无音频文件\n\n请通过 Finder 或 iTunes\n将音频文件夹传输到此App"
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 16)
        label.isHidden = true
        return label
    }()
    
    private lazy var miniPlayerView: MiniPlayerView = {
        let view = MiniPlayerView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()
    
    private var miniPlayerBottomConstraint: NSLayoutConstraint!
    
    // MARK: - Data
    private var folders: [AudioFolder] = []
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupMiniPlayer()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadFolders()
        updateMiniPlayerVisibility()
    }
    
    // MARK: - Setup
    private func setupUI() {
        title = "听书"
        view.backgroundColor = .systemBackground
        
        navigationController?.navigationBar.prefersLargeTitles = true
        
        view.addSubview(tableView)
        view.addSubview(emptyLabel)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 40),
            emptyLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -40)
        ])
        
        // 下拉刷新
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refreshFolders), for: .valueChanged)
        tableView.refreshControl = refreshControl
    }
    
    private func setupMiniPlayer() {
        view.addSubview(miniPlayerView)
        
        miniPlayerBottomConstraint = miniPlayerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        
        NSLayoutConstraint.activate([
            miniPlayerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            miniPlayerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            miniPlayerBottomConstraint,
            miniPlayerView.heightAnchor.constraint(equalToConstant: 64)
        ])
        
        miniPlayerView.onTap = { [weak self] in
            self?.showPlayer()
        }
    }
    
    // MARK: - Data Loading
    private func loadFolders() {
        folders = FileService.shared.getFolders()
        tableView.reloadData()
        emptyLabel.isHidden = !folders.isEmpty
    }
    
    @objc private func refreshFolders() {
        loadFolders()
        tableView.refreshControl?.endRefreshing()
    }
    
    // MARK: - Mini Player
    private func updateMiniPlayerVisibility() {
        let hasTrack = AudioPlayerManager.shared.currentTrack != nil
        miniPlayerView.isHidden = !hasTrack
        
        // 调整 tableView 的 contentInset
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
extension FolderListViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return folders.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: FolderCell.identifier, for: indexPath) as! FolderCell
        cell.configure(with: folders[indexPath.row])
        return cell
    }
}

// MARK: - UITableViewDelegate
extension FolderListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let folder = folders[indexPath.row]
        let trackListVC = TrackListViewController(folder: folder)
        navigationController?.pushViewController(trackListVC, animated: true)
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let deleteAction = UIContextualAction(style: .destructive, title: "删除") { [weak self] _, _, completionHandler in
            self?.confirmDeleteFolder(at: indexPath)
            completionHandler(true)
        }
        deleteAction.image = UIImage(systemName: "trash")
        
        return UISwipeActionsConfiguration(actions: [deleteAction])
    }
    
    private func confirmDeleteFolder(at indexPath: IndexPath) {
        let folder = folders[indexPath.row]
        
        let alert = UIAlertController(
            title: "删除文件夹",
            message: "确定要删除「\(folder.name)」及其中的 \(folder.trackCount) 个音频文件吗？此操作不可恢复。",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "删除", style: .destructive) { [weak self] _ in
            self?.deleteFolder(at: indexPath)
        })
        
        present(alert, animated: true)
    }
    
    private func deleteFolder(at indexPath: IndexPath) {
        let folder = folders[indexPath.row]
        
        // 如果正在播放该文件夹中的音频，停止播放
        if let currentTrack = AudioPlayerManager.shared.currentTrack,
           currentTrack.folderName == folder.name {
            AudioPlayerManager.shared.pause()
            PlaybackStateManager.shared.clearState()
        }
        
        if FileService.shared.deleteFolder(folder) {
            folders.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .automatic)
            emptyLabel.isHidden = !folders.isEmpty
            updateMiniPlayerVisibility()
        }
    }
}

// MARK: - FolderCell
final class FolderCell: UITableViewCell {
    static let identifier = "FolderCell"
    
    private let folderIcon: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .systemOrange
        imageView.image = UIImage(systemName: "folder.fill")
        return imageView
    }()
    
    private let nameLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 17, weight: .medium)
        label.textColor = .label
        return label
    }()
    
    private let countLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
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
        accessoryType = .disclosureIndicator
        
        contentView.addSubview(folderIcon)
        contentView.addSubview(nameLabel)
        contentView.addSubview(countLabel)
        
        NSLayoutConstraint.activate([
            folderIcon.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            folderIcon.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            folderIcon.widthAnchor.constraint(equalToConstant: 40),
            folderIcon.heightAnchor.constraint(equalToConstant: 40),
            
            nameLabel.leadingAnchor.constraint(equalTo: folderIcon.trailingAnchor, constant: 16),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            nameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            
            countLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            countLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4)
        ])
    }
    
    func configure(with folder: AudioFolder) {
        nameLabel.text = folder.name
        countLabel.text = "\(folder.trackCount) 个音频"
    }
}


