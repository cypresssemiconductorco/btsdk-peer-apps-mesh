//
//  PublicationConfigureViewController.swift
//  MeshApp
//
//  Created by Dudley Du on 2019/6/13.
//  Copyright © 2019 Cypress Semiconductor. All rights reserved.
//

import UIKit
import MeshFramework

class PublicationConfigureViewController: UIViewController {
    static let shared = PublicationConfigureViewController()
    @IBOutlet weak var topNavigationBar: UINavigationBar!
    @IBOutlet weak var topNavigationItem: UINavigationItem!
    @IBOutlet weak var topRightBarButtonItem: UIBarButtonItem!
    @IBOutlet weak var rootView: UIView!
    @IBOutlet weak var rootScrollView: UIScrollView!

    @IBOutlet weak var onTopLeftBarButtonItem: UIBarButtonItem!
    @IBOutlet weak var deviceNameLabel: UILabel!
    @IBOutlet weak var publishStatusCustomDropDownButton: CustomDropDownButton!
    @IBOutlet weak var publishToCustomDropDownButton: CustomDropDownButton!
    @IBOutlet weak var publishPeriodTextField: UITextField!

    @IBOutlet weak var scribeActivityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var dataTextView: UITextView!

    private var vcOpenedTime = Date(timeIntervalSinceNow: 0)

    var groupName: String?
    var deviceName: String? {
        didSet {
            if deviceNameLabel != nil, let name = deviceName {
                deviceNameLabel!.text = "\(name)"
                viewInit()
            }
        }
    }
    var componentType: Int = MeshConstants.MESH_COMPONENT_UNKNOWN

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        notificationInit()
        viewInit()
    }

    func viewInit() {
        guard let componentName = self.deviceName else {
            return
        }

        topNavigationItem.rightBarButtonItem = nil
        deviceNameLabel.text = componentName
        publishPeriodTextField.delegate = self
        publishPeriodTextField.text = ""
        scribeActivityIndicator.stopAnimating()
        scribeActivityIndicator.isHidden = true
        dataTextView.layer.borderWidth = 1
        dataTextView.layer.borderColor = UIColor.gray.cgColor
        dataTextView.isEditable = false
        dataTextView.isSelectable = false
        dataTextView.layoutManager.allowsNonContiguousLayout = false

        // init drop donw buttons for publication.
        var statusItems: [String] = []
        statusItems.append(MeshControl.METHOD_ONOFF)
        statusItems.append(MeshControl.METHOD_LEVEL)
        statusItems.append(MeshControl.METHOD_LIGHTNESS)
        statusItems.append(MeshControl.METHOD_POWER)
        statusItems.append(MeshControl.METHOD_HSL)
        statusItems.append(MeshControl.METHOD_CTL)
        statusItems.append(MeshControl.METHOD_XYL)
        statusItems.append(MeshControl.METHOD_SENSOR)
        statusItems.append(MeshControl.METHOD_VENDOR)
        publishStatusCustomDropDownButton.dropDownItems = statusItems
        publishStatusCustomDropDownButton.setSelection(select: MeshControl.METHOD_ONOFF)

        var toItems: [String] = []
        if let groups = MeshFrameworkManager.shared.getAllMeshNetworkGroups() {
            for group in groups {
                toItems.append(group)
            }
        }
        toItems.append(contentsOf: MeshControl.PUBLICATION_TARGETS)
        publishToCustomDropDownButton.dropDownItems = toItems

        if let publishTarget = MeshFrameworkManager.shared.meshClientGetPublicationTarget(componentName: componentName, isClient: false, method: MeshControl.METHOD_ONOFF) {
            publishToCustomDropDownButton.setSelection(select: publishTarget)
        } else {
            if let groups = MeshFrameworkManager.shared.getMeshComponentGroupList(componentName: componentName), !groups.isEmpty {
                publishToCustomDropDownButton.setSelection(select: groups[0])
            } else {
                publishToCustomDropDownButton.setSelection(select: 0)
            }
        }

        let publishPeriod = MeshFrameworkManager.shared.meshClientGetPublicationPeriod(componentName: componentName, isClient: false, method: MeshControl.METHOD_ONOFF)
        if publishPeriod > 0 {
            publishPeriodTextField.text = "\(publishPeriod)"
        }
    }

    func notificationInit() {
        NotificationCenter.default.addObserver(self, selector: #selector(notificationHandler(_:)),
                                               name: UIWindow.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notificationHandler(_:)),
                                               name: UIWindow.keyboardWillHideNotification, object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(notificationHandler(_:)),
                                               name: Notification.Name(rawValue: MeshNotificationConstants.MESH_CLIENT_NODE_CONNECTION_STATUS_CHANGED), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notificationHandler(_:)),
                                               name: Notification.Name(rawValue: MeshNotificationConstants.MESH_CLIENT_NETWORK_LINK_STATUS_CHANGED), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notificationHandler(_:)),
                                               name: Notification.Name(rawValue: MeshNotificationConstants.MESH_NETWORK_DATABASE_CHANGED), object: nil)
    }

    @objc func notificationHandler(_ notification: Notification) {
        guard let userInfo = notification.userInfo else {
            return
        }
        switch notification.name {
        case UIWindow.keyboardWillShowNotification:
            adjustingHeightWithKeyboard(show: true, notification: notification)
        case UIWindow.keyboardWillHideNotification:
            adjustingHeightWithKeyboard(show: false, notification: notification)
        case Notification.Name(rawValue: MeshNotificationConstants.MESH_CLIENT_NODE_CONNECTION_STATUS_CHANGED):
            if let nodeConnectionStatus = MeshNotificationConstants.getNodeConnectionStatus(userInfo: userInfo) {
                self.showToast(message: "Device \"\(nodeConnectionStatus.componentName)\" \((nodeConnectionStatus.status == MeshConstants.MESH_CLIENT_NODE_CONNECTED) ? "has connected." : "is unreachable").")
            }
        case Notification.Name(rawValue: MeshNotificationConstants.MESH_CLIENT_NETWORK_LINK_STATUS_CHANGED):
            if let linkStatus = MeshNotificationConstants.getLinkStatus(userInfo: userInfo) {
                self.showToast(message: "Mesh network has \((linkStatus.isConnected) ? "connected" : "disconnected").")
            }
        case Notification.Name(rawValue: MeshNotificationConstants.MESH_NETWORK_DATABASE_CHANGED):
            if let networkName = MeshNotificationConstants.getNetworkName(userInfo: userInfo) {
                self.showToast(message: "Database of mesh network \(networkName) has changed.")
            }

        case Notification.Name(rawValue: MeshNotificationConstants.MESH_CLIENT_ON_OFF_STATUS):
            guard let notificationStatus = MeshNotificationConstants.getOnOffStatus(userInfo: userInfo) else { return }
            print("Device \"\(notificationStatus.deviceName)\" is \(notificationStatus.isOn ? "ON" : "OFF").")
            self.log("Device \"\(notificationStatus.deviceName)\" is \(notificationStatus.isOn ? "ON" : "OFF").")
            //self.showToast(message: "Device \"\(notificationStatus.deviceName)\" is \(notificationStatus.isOn ? "ON" : "OFF").")
        case Notification.Name(rawValue: MeshNotificationConstants.MESH_CLIENT_LEVEL_STATUS):
            guard let notificationStatus = MeshNotificationConstants.getLevelStatus(userInfo: userInfo) else { return }
            print("Device \"\(notificationStatus.deviceName)\" level status is \(notificationStatus.level).")
            self.log("Device \"\(notificationStatus.deviceName)\" level status is \(notificationStatus.level).")
            //self.showToast(message: "Device \"\(notificationStatus.deviceName)\" level status is \(notificationStatus.level).")
        case Notification.Name(rawValue: MeshNotificationConstants.MESH_CLIENT_LIGHTNESS_STATUS):
            guard let notificationStatus = MeshNotificationConstants.getLightnessStatus(userInfo: userInfo) else { return }
            print("Device \"\(notificationStatus.deviceName)\" lightness status is \(notificationStatus.targetLightness).")
            self.log("Device \"\(notificationStatus.deviceName)\" lightness status is \(notificationStatus.targetLightness).")
            //self.showToast(message: "Device \"\(notificationStatus.deviceName)\" lightness status is \(notificationStatus.targetLightness).")
        case Notification.Name(rawValue: MeshNotificationConstants.MESH_CLIENT_HSL_STATUS):
            guard let notificationStatus = MeshNotificationConstants.getHslStatus(userInfo: userInfo) else { return }
            print("Device \"\(notificationStatus.deviceName)\" HSL status, hue: \(notificationStatus.hue), saturation: \(notificationStatus.saturation), lightness: \(notificationStatus.lightness).")
            self.log("Device \"\(notificationStatus.deviceName)\" HSL status, hue: \(notificationStatus.hue), saturation: \(notificationStatus.saturation), lightness: \(notificationStatus.lightness).")
            //self.showToast(message: "Device \"\(notificationStatus.deviceName)\" HSL status, hue: \(notificationStatus.hue), saturation: \(notificationStatus.saturation), lightness: \(notificationStatus.lightness).")
        case Notification.Name(rawValue: MeshNotificationConstants.MESH_CLIENT_CTL_STATUS):
            guard let notificationStatus = MeshNotificationConstants.getCtlStatus(userInfo: userInfo) else { return }
            print("Device \"\(notificationStatus.deviceName)\" CTL status, temperature: \(notificationStatus.targetTemperature), lightness: \(notificationStatus.targetLightness).")
            self.log("Device \"\(notificationStatus.deviceName)\" CTL status, temperature: \(notificationStatus.targetTemperature), lightness: \(notificationStatus.targetLightness).")
            //self.showToast(message: "Device \"\(notificationStatus.deviceName)\" CTL status, temperature: \(notificationStatus.targetTemperature), lightness: \(notificationStatus.targetLightness).")
        case Notification.Name(rawValue: MeshNotificationConstants.MESH_CLIENT_SENSOR_STATUS):
            guard let notificationStatus = MeshNotificationConstants.getSensorStatus(userInfo: userInfo) else { return }
            print("Device \"\(notificationStatus.deviceName)\" sensor data, Property ID: \(notificationStatus.propertyId), data: \(notificationStatus.data.dumpHexBytes()).")
            self.log("Device \"\(notificationStatus.deviceName)\" sensor data, Property ID: \(notificationStatus.propertyId), data: \(notificationStatus.data.dumpHexBytes()).")
            //self.showToast(message: "Device \"\(notificationStatus.deviceName)\" sensor data, Property ID: \(notificationStatus.propertyId), data: \(notificationStatus.data.dumpHexBytes()).")
        case Notification.Name(rawValue: MeshNotificationConstants.MESH_CLIENT_VENDOR_SPECIFIC_DATA_CHANGED):
            guard let notificationStatus = MeshNotificationConstants.getVendorSpecificData(userInfo: userInfo) else { return }
            print("Device \"\(notificationStatus.deviceName)\" vendor specific data, Company ID: \(notificationStatus.companyId), Model ID: \(notificationStatus.modelId), Opcode: \(notificationStatus.opcode), data: \(notificationStatus.data.dumpHexBytes()).")
            self.log("Device \"\(notificationStatus.deviceName)\" vendor specific data, Company ID: \(notificationStatus.companyId), Model ID: \(notificationStatus.modelId), Opcode: \(notificationStatus.opcode), data: \(notificationStatus.data.dumpHexBytes()).")
            //self.showToast(message: "Device \"\(notificationStatus.deviceName)\" vendor specific data, Company ID: \(notificationStatus.companyId), Model ID: \(notificationStatus.modelId), Opcode: \(notificationStatus.opcode), data: \(notificationStatus.data.dumpHexBytes()).")
        default:
            break
        }
    }

    @IBAction func onTopLeftBarButtonItemClick(_ sender: UIBarButtonItem) {
        self.dismiss(animated: true, completion: nil)
    }

    @IBAction func onTopRightBarButtonItemClick(_ sender: UIBarButtonItem) {
    }

    @IBAction func onPublishStatusCustomDropDownButtonClick(_ sender: CustomDropDownButton) {
        publishStatusCustomDropDownButton.showDropList(width: 300, parent: self) {
            print("PublicationConfigureViewController, onPublishStatusCustomDropDownButtonClick, \(self.publishStatusCustomDropDownButton.selectedIndex), \(self.publishStatusCustomDropDownButton.selectedString)")
        }
    }

    @IBAction func onPublishToCustomDropDownButtonClick(_ sender: CustomDropDownButton) {
        publishToCustomDropDownButton.showDropList(width: 300, parent: self) {
            print("PublicationConfigureViewController, publishToCustomDropDownButton, \(self.publishToCustomDropDownButton.selectedIndex), \(self.publishToCustomDropDownButton.selectedString)")
        }
    }

    @IBAction func onPublishSetButtonClick(_ sender: UIButton) {
        guard let componentName = self.deviceName else {
            print("error: PublicationConfigureViewController, onPublishSetButtonClick, invalid nil mesh component name")
            UtilityManager.showAlertDialogue(parentVC: self, message: "Internal error, invalid mesh component name.")
            return
        }
        guard let seconds = UtilityManager.convertDigitStringToInt(digit: publishPeriodTextField.text) else {
            print("error: PublicationConfigureViewController, onPublishSetButtonClick, period textField is empty or not set")
            UtilityManager.showAlertDialogue(parentVC: self, message: "Please input the publish period time firstly before click the Publsh Set button.")
            return
        }
        let publishTarget = publishToCustomDropDownButton.selectedString
        let publishPeriod = Int(seconds)
        print("PublicationConfigureViewController, onPublishSetButtonClick, componentName=\(componentName), publishTarget:\(publishTarget), publishPeriod:\(publishPeriod)")

        MeshFrameworkManager.shared.runHandlerWithMeshNetworkConnected { (error: Int) in
            guard error == MeshErrorCode.MESH_SUCCESS else {
                print("error: PublicationConfigureViewController, onPublishSetButtonClick, failed to connect to mesh network, error:\(error)")
                UtilityManager.showAlertDialogue(parentVC: self, message: "Unable to connect to the mesh network. Error Code: \(error).")
                return
            }

            var error = MeshFrameworkManager.shared.setMeshPublicationConfiguration()
            guard error == MeshErrorCode.MESH_SUCCESS else {
                print("error: PublicationConfigureViewController, onPublishSetButtonClick, failed to call setMeshPublicationConfiguration API, error:\(error)")
                if error == MeshErrorCode.MESH_ERROR_INVALID_STATE {
                    UtilityManager.showAlertDialogue(parentVC: self, message: "Mesh network is busying, please try again a little later.")
                } else {
                    UtilityManager.showAlertDialogue(parentVC: self, message: "Failed to do mesh publication configuration. Error Code: \(error).")
                }
                return
            }

            error = MeshFrameworkManager.shared.configureMeshPublication(componentName: componentName, isClient: false, method: self.publishStatusCustomDropDownButton.selectedString, targetName: publishTarget, publishPeriod: publishPeriod)
            guard error == MeshErrorCode.MESH_SUCCESS else {
                print("error: PublicationConfigureViewController, onPublishSetButtonClick, failed to call setMeshPublicationConfiguration API, error:\(error)")
                if error == MeshErrorCode.MESH_ERROR_INVALID_STATE {
                    UtilityManager.showAlertDialogue(parentVC: self, message: "Mesh network is busying, please try again a little later.")
                } else {
                    UtilityManager.showAlertDialogue(parentVC: self, message: "Failed to configure mesh publication. Error Code: \(error).")
                }
                return
            }

            switch self.publishStatusCustomDropDownButton.selectedString {
            case MeshControl.METHOD_ONOFF:
                NotificationCenter.default.addObserver(self, selector: #selector(self.notificationHandler(_:)),
                                                       name: Notification.Name(rawValue: MeshNotificationConstants.MESH_CLIENT_ON_OFF_STATUS), object: nil)
            case MeshControl.METHOD_LEVEL:
                NotificationCenter.default.addObserver(self, selector: #selector(self.notificationHandler(_:)),
                                                       name: Notification.Name(rawValue: MeshNotificationConstants.MESH_CLIENT_LEVEL_STATUS), object: nil)
            case MeshControl.METHOD_LIGHTNESS:
                NotificationCenter.default.addObserver(self, selector: #selector(self.notificationHandler(_:)),
                                                       name: Notification.Name(rawValue: MeshNotificationConstants.MESH_CLIENT_LIGHTNESS_STATUS), object: nil)
            case MeshControl.METHOD_HSL:
                NotificationCenter.default.addObserver(self, selector: #selector(self.notificationHandler(_:)),
                                                       name: Notification.Name(rawValue: MeshNotificationConstants.MESH_CLIENT_HSL_STATUS), object: nil)
            case MeshControl.METHOD_CTL:
                NotificationCenter.default.addObserver(self, selector: #selector(self.notificationHandler(_:)),
                                                       name: Notification.Name(rawValue: MeshNotificationConstants.MESH_CLIENT_CTL_STATUS), object: nil)
            case MeshControl.METHOD_SENSOR:
                NotificationCenter.default.addObserver(self, selector: #selector(self.notificationHandler(_:)),
                                                       name: Notification.Name(rawValue: MeshNotificationConstants.MESH_CLIENT_SENSOR_STATUS), object: nil)
            case MeshControl.METHOD_VENDOR:
                NotificationCenter.default.addObserver(self, selector: #selector(self.notificationHandler(_:)),
                                                       name: Notification.Name(rawValue: MeshNotificationConstants.MESH_CLIENT_VENDOR_SPECIFIC_DATA_CHANGED), object: nil)
            default:
                break
            }

            print("PublicationConfigureViewController, onPublishSetButtonClick, configureMeshPublication success, publishTarget:\(publishTarget), publishPeriod:\(publishPeriod)")
            UtilityManager.showAlertDialogue(parentVC: self, message: "Publish Set done successfully.", title: "Success")
        }
    }

    @IBAction func onStartScribeClick(_ sender: UIButton) {
        MeshFrameworkManager.shared.runHandlerWithMeshNetworkConnected { (error: Int) in
            guard error == MeshErrorCode.MESH_SUCCESS else {
                print("error: PublicationConfigureViewController, onPublishSetButtonClick, failed to connect to mesh network, error:\(error)")
                UtilityManager.showAlertDialogue(parentVC: self, message: "Unable to connect to the mesh network. Error Code: \(error).")
                return
            }

            let error = MeshFrameworkManager.shared.meshClientlistenForAppGroupBroadcast(controlMethod: self.publishStatusCustomDropDownButton.selectedString, groupName: self.publishToCustomDropDownButton.selectedString, startListening: true)
            guard error == MeshErrorCode.MESH_SUCCESS else {
                print("error: PublicationConfigureViewController, onStartScribeClick, failed to call meshClientlistenForAppGroupBroadcast API, error:\(error)")
                UtilityManager.showAlertDialogue(parentVC: self, message: "Failed to subscribe for \(self.publishToCustomDropDownButton.selectedString) data. Error Code: \(error).")
                return
            }

            self.scribeActivityIndicator.startAnimating()
            self.scribeActivityIndicator.isHidden = false
        }
    }

    @IBAction func onStopScribeClick(_ sender: UIButton) {
        MeshFrameworkManager.shared.runHandlerWithMeshNetworkConnected { (error: Int) in
            guard error == MeshErrorCode.MESH_SUCCESS else {
                print("error: PublicationConfigureViewController, onStopScribeClick, failed to connect to mesh network, error:\(error)")
                UtilityManager.showAlertDialogue(parentVC: self, message: "Unable to connect to the mesh network. Error Code: \(error).")
                return
            }

            let error = MeshFrameworkManager.shared.meshClientlistenForAppGroupBroadcast(controlMethod: self.publishStatusCustomDropDownButton.selectedString, groupName: self.publishToCustomDropDownButton.selectedString, startListening: false)
            guard error == MeshErrorCode.MESH_SUCCESS else {
                print("error: PublicationConfigureViewController, onStopScribeClick, failed to call meshClientlistenForAppGroupBroadcast API, error:\(error)")
                UtilityManager.showAlertDialogue(parentVC: self, message: "Failed to unsubscribe for \(self.publishToCustomDropDownButton.selectedString) data. Error Code: \(error).")
                return
            }

            self.scribeActivityIndicator.stopAnimating()
            self.scribeActivityIndicator.isHidden = true
        }
    }

    @IBAction func onClearButtonClick(_ sender: UIButton) {
        dataTextView.text = ""
    }

    func log(_ message: String) {
        let seconds = Date().timeIntervalSince(vcOpenedTime)
        let msg = String(format: "[%.3f] \(message)\n", seconds)
        dataTextView.text += msg
        let bottom = NSRange(location: dataTextView.text.count, length: 1)
        dataTextView.scrollRangeToVisible(bottom)
    }
}

extension PublicationConfigureViewController: UITextFieldDelegate {
    // used to make sure the input UITextField view won't be covered by the keyboard.
    func adjustingHeightWithKeyboard(show: Bool, notification: Notification) {
        guard let userInfo = notification.userInfo else { return }
        guard let keyboardFrame = (userInfo[UIWindow.keyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue else { return }
        let changeInHeight = (keyboardFrame.size.height + 5) * (show ? 1 : -1)
        rootScrollView.contentInset.bottom += changeInHeight
        rootScrollView.scrollIndicatorInsets.bottom += changeInHeight
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        // hide the keyboard when click on the screen outside the keyboard.
        self.view.endEditing(true)
    }

    public func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        return true
    }

    public func textFieldDidBeginEditing(_ textField: UITextField) {
    }

    public func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
        return true
    }

    public func textFieldDidEndEditing(_ textField: UITextField) {
        self.view.endEditing(true)
    }

    public func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        return true
    }

    public func textFieldShouldClear(_ textField: UITextField) -> Bool {
        return true
    }

    public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.view.endEditing(true)
        return true
    }
}