//
//  AppPermissionsViewController.swift
//  RentiWise
//
//  Created by admin99 on 04/02/26.
//

import UIKit
import CoreLocation
import AVFoundation
import Photos

class AppPermissionsViewController: UITableViewController {
    
    private var locationEnabled = false
    private var cameraEnabled = false
    private var photosEnabled = false
    private let locationManager = CLLocationManager()
    
    private let brandTeal = UIColor(red: 0x70/255.0, green: 0xA7/255.0, blue: 0xB4/255.0, alpha: 1.0)
    
    init() {
        super.init(style: .insetGrouped)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "App Permissions"
        
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.backgroundColor = .systemGroupedBackground
        
        refreshStatuses()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tabBarController?.tabBar.isHidden = true
        refreshStatuses()
    }
    
    // MARK: - Status refresh
    
    private func refreshStatuses() {
        // Location
        let locStatus = CLLocationManager.authorizationStatus()
        locationEnabled = (locStatus == .authorizedAlways || locStatus == .authorizedWhenInUse)
        
        // Camera
        let camStatus = AVCaptureDevice.authorizationStatus(for: .video)
        cameraEnabled = (camStatus == .authorized)
        
        // Photos
        let phStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        photosEnabled = (phStatus == .authorized || phStatus == .limited)
        
        tableView.reloadData()
    }
    
    // MARK: - TableView DataSource
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 3 // Location, Camera, Photos
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "App Permissions"
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.selectionStyle = .none
        
        let toggle = UISwitch()
        toggle.onTintColor = brandTeal
        toggle.tag = indexPath.row
        toggle.addTarget(self, action: #selector(toggleChanged(_:)), for: .valueChanged)
        cell.accessoryView = toggle
        
        switch indexPath.row {
        case 0:
            cell.textLabel?.text = "Location"
            toggle.isOn = locationEnabled
        case 1:
            cell.textLabel?.text = "Camera"
            toggle.isOn = cameraEnabled
        case 2:
            cell.textLabel?.text = "Photos"
            toggle.isOn = photosEnabled
        default:
            break
        }
        
        return cell
    }
    
    @objc private func toggleChanged(_ sender: UISwitch) {
        let newValue = sender.isOn
        
        switch sender.tag {
        case 0:
            handleLocationToggle(newValue)
        case 1:
            handleCameraToggle(newValue)
        case 2:
            handlePhotosToggle(newValue)
        default:
            break
        }
    }
    
    // MARK: - Permission Handlers
    
    private func handleLocationToggle(_ newValue: Bool) {
        let status = CLLocationManager.authorizationStatus()
        if newValue {
            switch status {
            case .notDetermined:
                locationManager.requestWhenInUseAuthorization()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    self?.refreshStatuses()
                }
            case .denied, .restricted:
                showSettingsAlert(message: "Location access is disabled. You can enable it in Settings.")
                locationEnabled = false
                tableView.reloadData()
            default:
                refreshStatuses()
            }
        } else {
            showSettingsAlert(message: "To turn off Location access, please use the Settings app.")
            refreshStatuses()
        }
    }
    
    private func handleCameraToggle(_ newValue: Bool) {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if newValue {
            switch status {
            case .notDetermined:
                Task { @MainActor in
                    let granted = await AVCaptureDevice.requestAccess(for: .video)
                    cameraEnabled = granted
                    tableView.reloadData()
                }
            case .denied, .restricted:
                showSettingsAlert(message: "Camera access is disabled. You can enable it in Settings.")
                cameraEnabled = false
                tableView.reloadData()
            case .authorized:
                cameraEnabled = true
                tableView.reloadData()
            @unknown default:
                cameraEnabled = false
                tableView.reloadData()
            }
        } else {
            showSettingsAlert(message: "To turn off Camera access, please use the Settings app.")
            refreshStatuses()
        }
    }
    
    private func handlePhotosToggle(_ newValue: Bool) {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if newValue {
            switch status {
            case .notDetermined:
                Task { @MainActor in
                    let newStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
                    photosEnabled = (newStatus == .authorized || newStatus == .limited)
                    tableView.reloadData()
                }
            case .denied, .restricted:
                showSettingsAlert(message: "Photos access is disabled. You can enable it in Settings.")
                photosEnabled = false
                tableView.reloadData()
            case .limited, .authorized:
                photosEnabled = true
                tableView.reloadData()
            @unknown default:
                photosEnabled = false
                tableView.reloadData()
            }
        } else {
            showSettingsAlert(message: "To turn off Photos access, please use the Settings app.")
            refreshStatuses()
        }
    }
    
    // MARK: - Helpers
    
    private func showSettingsAlert(message: String) {
        let alert = UIAlertController(title: "Change Permissions", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
            self.openAppSettings()
        })
        present(alert, animated: true)
    }
    
    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString), UIApplication.shared.canOpenURL(url) else { return }
        UIApplication.shared.open(url)
    }
}
