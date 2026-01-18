//
//  SettingsViewController.swift
//  Mono
//
//  Created by AI Assistant on 2025/01/18.
//

import UIKit

final class SettingsViewController: UIViewController {
    
    // MARK: - UI
    private lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .insetGrouped)
        table.translatesAutoresizingMaskIntoConstraints = false
        table.delegate = self
        table.dataSource = self
        table.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        table.register(SettingSwitchCell.self, forCellReuseIdentifier: SettingSwitchCell.identifier)
        table.register(SettingValueCell.self, forCellReuseIdentifier: SettingValueCell.identifier)
        return table
    }()
    
    // MARK: - Data
    private enum Section: Int, CaseIterable {
        case playback       // 播放设置
        case skipSettings   // 跳过设置
        case about          // 关于
        
        var title: String {
            switch self {
            case .playback: return "播放设置"
            case .skipSettings: return "跳过设置"
            case .about: return "关于"
            }
        }
    }
    
    private let skipIntroOptions = [0, 5, 10, 15, 30, 60, 90, 120]
    private let skipOutroOptions = [0, 5, 10, 15, 30, 60]
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    // MARK: - Setup
    private func setupUI() {
        title = "设置"
        view.backgroundColor = .systemGroupedBackground
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "完成",
            style: .done,
            target: self,
            action: #selector(doneTapped)
        )
        
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    // MARK: - Actions
    @objc private func doneTapped() {
        dismiss(animated: true)
    }
    
    // MARK: - Helpers
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
        let alert = UIAlertController(title: "默认跳过开头", message: "新文件夹的默认跳过开头秒数", preferredStyle: .actionSheet)
        
        let currentValue = PlaybackStateManager.shared.defaultSkipIntroSeconds
        
        for seconds in skipIntroOptions {
            let action = UIAlertAction(title: formatSeconds(seconds), style: .default) { [weak self] _ in
                PlaybackStateManager.shared.defaultSkipIntroSeconds = seconds
                self?.tableView.reloadData()
            }
            if seconds == currentValue {
                action.setValue(true, forKey: "checked")
            }
            alert.addAction(action)
        }
        
        // 自定义输入选项
        let customTitle = skipIntroOptions.contains(currentValue) ? "自定义..." : "自定义 (\(formatSeconds(currentValue)))"
        let customAction = UIAlertAction(title: customTitle, style: .default) { [weak self] _ in
            self?.showCustomSkipIntroInput()
        }
        if !skipIntroOptions.contains(currentValue) && currentValue > 0 {
            customAction.setValue(true, forKey: "checked")
        }
        alert.addAction(customAction)
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        
        if let popover = alert.popoverPresentationController {
            popover.sourceView = tableView
            popover.sourceRect = tableView.rectForRow(at: IndexPath(row: 0, section: Section.skipSettings.rawValue))
        }
        
        present(alert, animated: true)
    }
    
    private func showCustomSkipIntroInput() {
        let alert = UIAlertController(title: "自定义跳过开头", message: "请输入要跳过的秒数", preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.placeholder = "秒数"
            textField.keyboardType = .numberPad
            let currentValue = PlaybackStateManager.shared.defaultSkipIntroSeconds
            if currentValue > 0 {
                textField.text = "\(currentValue)"
            }
        }
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "确定", style: .default) { [weak self] _ in
            if let text = alert.textFields?.first?.text,
               let seconds = Int(text), seconds >= 0 {
                PlaybackStateManager.shared.defaultSkipIntroSeconds = seconds
                self?.tableView.reloadData()
            }
        })
        
        present(alert, animated: true)
    }
    
    private func showSkipOutroPicker() {
        let alert = UIAlertController(title: "默认跳过结尾", message: "新文件夹的默认跳过结尾秒数", preferredStyle: .actionSheet)
        
        let currentValue = PlaybackStateManager.shared.defaultSkipOutroSeconds
        
        for seconds in skipOutroOptions {
            let action = UIAlertAction(title: formatSeconds(seconds), style: .default) { [weak self] _ in
                PlaybackStateManager.shared.defaultSkipOutroSeconds = seconds
                self?.tableView.reloadData()
            }
            if seconds == currentValue {
                action.setValue(true, forKey: "checked")
            }
            alert.addAction(action)
        }
        
        // 自定义输入选项
        let customTitle = skipOutroOptions.contains(currentValue) ? "自定义..." : "自定义 (\(formatSeconds(currentValue)))"
        let customAction = UIAlertAction(title: customTitle, style: .default) { [weak self] _ in
            self?.showCustomSkipOutroInput()
        }
        if !skipOutroOptions.contains(currentValue) && currentValue > 0 {
            customAction.setValue(true, forKey: "checked")
        }
        alert.addAction(customAction)
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        
        if let popover = alert.popoverPresentationController {
            popover.sourceView = tableView
            popover.sourceRect = tableView.rectForRow(at: IndexPath(row: 1, section: Section.skipSettings.rawValue))
        }
        
        present(alert, animated: true)
    }
    
    private func showCustomSkipOutroInput() {
        let alert = UIAlertController(title: "自定义跳过结尾", message: "请输入曲目结束前要跳过的秒数", preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.placeholder = "秒数"
            textField.keyboardType = .numberPad
            let currentValue = PlaybackStateManager.shared.defaultSkipOutroSeconds
            if currentValue > 0 {
                textField.text = "\(currentValue)"
            }
        }
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "确定", style: .default) { [weak self] _ in
            if let text = alert.textFields?.first?.text,
               let seconds = Int(text), seconds >= 0 {
                PlaybackStateManager.shared.defaultSkipOutroSeconds = seconds
                self?.tableView.reloadData()
            }
        })
        
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDataSource
extension SettingsViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section) {
        case .playback:
            return 2  // 自动播放、记住位置
        case .skipSettings:
            return 2  // 跳过开头、跳过结尾
        case .about:
            return 1  // 版本号
        default:
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return Section(rawValue: section)?.title
    }
    
    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch Section(rawValue: section) {
        case .skipSettings:
            return "这里设置的是新文件夹的默认值。每个文件夹可以在其曲目列表页面单独设置（点击右上角 ••• 按钮）"
        default:
            return nil
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let settings = PlaybackStateManager.shared
        
        switch Section(rawValue: indexPath.section) {
        case .playback:
            let cell = tableView.dequeueReusableCell(withIdentifier: SettingSwitchCell.identifier, for: indexPath) as! SettingSwitchCell
            
            switch indexPath.row {
            case 0:
                cell.configure(
                    title: "启动时自动播放",
                    isOn: settings.autoPlayOnLaunch
                ) { isOn in
                    settings.autoPlayOnLaunch = isOn
                }
            case 1:
                cell.configure(
                    title: "记住每曲播放位置",
                    isOn: settings.rememberPositionPerTrack
                ) { isOn in
                    settings.rememberPositionPerTrack = isOn
                }
            default:
                break
            }
            return cell
            
        case .skipSettings:
            let cell = tableView.dequeueReusableCell(withIdentifier: SettingValueCell.identifier, for: indexPath) as! SettingValueCell
            
            switch indexPath.row {
            case 0:
                cell.configure(
                    title: "默认跳过开头",
                    value: formatSeconds(settings.defaultSkipIntroSeconds)
                )
            case 1:
                cell.configure(
                    title: "默认跳过结尾",
                    value: formatSeconds(settings.defaultSkipOutroSeconds)
                )
            default:
                break
            }
            return cell
            
        case .about:
            let cell = tableView.dequeueReusableCell(withIdentifier: SettingValueCell.identifier, for: indexPath) as! SettingValueCell
            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
            let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
            cell.configure(title: "版本", value: "\(version) (\(build))")
            cell.selectionStyle = .none
            return cell
            
        default:
            return UITableViewCell()
        }
    }
}

// MARK: - UITableViewDelegate
extension SettingsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        switch Section(rawValue: indexPath.section) {
        case .skipSettings:
            switch indexPath.row {
            case 0:
                showSkipIntroPicker()
            case 1:
                showSkipOutroPicker()
            default:
                break
            }
        default:
            break
        }
    }
}

// MARK: - SettingSwitchCell
final class SettingSwitchCell: UITableViewCell {
    static let identifier = "SettingSwitchCell"
    
    private var onValueChanged: ((Bool) -> Void)?
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 17)
        label.textColor = .label
        return label
    }()
    
    private lazy var switchControl: UISwitch = {
        let s = UISwitch()
        s.translatesAutoresizingMaskIntoConstraints = false
        s.onTintColor = .systemOrange
        s.addTarget(self, action: #selector(switchValueChanged), for: .valueChanged)
        return s
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        selectionStyle = .none
        
        contentView.addSubview(titleLabel)
        contentView.addSubview(switchControl)
        
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: switchControl.leadingAnchor, constant: -12),
            
            switchControl.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            switchControl.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }
    
    func configure(title: String, isOn: Bool, onValueChanged: @escaping (Bool) -> Void) {
        titleLabel.text = title
        switchControl.isOn = isOn
        self.onValueChanged = onValueChanged
    }
    
    @objc private func switchValueChanged() {
        onValueChanged?(switchControl.isOn)
    }
}

// MARK: - SettingValueCell
final class SettingValueCell: UITableViewCell {
    static let identifier = "SettingValueCell"
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 17)
        label.textColor = .label
        return label
    }()
    
    private let valueLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 17)
        label.textColor = .secondaryLabel
        label.textAlignment = .right
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
        
        contentView.addSubview(titleLabel)
        contentView.addSubview(valueLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            
            valueLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
            valueLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            valueLabel.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: 12)
        ])
    }
    
    func configure(title: String, value: String) {
        titleLabel.text = title
        valueLabel.text = value
    }
}
