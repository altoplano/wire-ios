//
//  ConversationContentViewController+Forward.swift
//  Wire-iOS
//
//  Created by Mihail Gerasimenko on 11/8/16.
//  Copyright © 2016 Zeta Project Germany GmbH. All rights reserved.
//

import Foundation
import zmessaging
import Cartography

extension UITableViewCell: UITableViewDelegate, UITableViewDataSource {
    public func wrapInTableView() -> UITableView {
        let tableView = UITableView(frame: self.bounds, style: .plain)
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.layoutMargins = self.layoutMargins
        
        let size = self.systemLayoutSizeFitting(CGSize(width: 320.0, height: 0.0) , withHorizontalFittingPriority: UILayoutPriorityRequired, verticalFittingPriority: UILayoutPriorityFittingSizeLevel)
        self.layoutSubviews()
        
        self.bounds = CGRect(x: 0.0, y: 0.0, width: size.width, height: size.height)
        self.contentView.bounds = self.bounds
        
        tableView.reloadData()
        tableView.bounds = self.bounds
        tableView.layoutIfNeeded()
        
        constrain(tableView) { tableView in
            tableView.height == size.height
        }
        
        CASStyler.default().styleItem(self)
        self.layoutSubviews()
        return tableView
    }
    
    public func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return self.bounds.size.height
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return self
    }
}

extension ZMConversation: ShareDestination {
}

func forward(_ message: ZMMessage, to: [AnyObject]) {
    if Message.isTextMessage(message) {
        ZMUserSession.shared().performChanges {
            to.forEach { _ = $0.appendMessage(withText: message.textMessageData!.messageText) }
        }
    }
    else if Message.isImageMessage(message) {
        ZMUserSession.shared().performChanges {
            to.forEach { _ = $0.appendMessage(withImageData: message.imageMessageData!.imageData) }
        }
    }
    else if Message.isVideoMessage(message) || Message.isAudioMessage(message) || Message.isFileTransferMessage(message) {
        ZMUserSession.shared().performChanges {
            FileMetaDataGenerator.metadataForFileAtURL(message.fileMessageData!.fileURL, UTI: message.fileMessageData!.mimeType) { fileMetadata in
                to.forEach { _ = $0.appendMessage(with: fileMetadata) }
            }
        }
    }
    else if Message.isLocationMessage(message) {
//        ZMUserSession.shared().performChanges {
//            to.forEach { _ = $0.appendMessage(with: ZMLocationData(latitude:  message.locationMessageData!.latitude, longitude:  message.locationMessageData!.longitude, name: message.locationMessageData!.name, zoomLevel: message.locationMessageData!.zoomLevel)) }
//        }
    }
    else {
        fatal("Cannot forward \(message)")
    }
}

extension ZMMessage: Shareable {
    
    public func share<ZMConversation>(to: [ZMConversation]) {
        forward(self, to: to as [AnyObject])
    }
    
    public typealias I = ZMConversation
    
    public func previewView() -> UIView {
        let cell: ConversationCell
        if Message.isTextMessage(self) {
            cell = TextMessageCell(style: .default, reuseIdentifier: "")
        }
        else if Message.isImageMessage(self) {
            cell = ImageMessageCell(style: .default, reuseIdentifier: "")
        }
        else if Message.isVideoMessage(self) {
            cell = VideoMessageCell(style: .default, reuseIdentifier: "")
        }
        else if Message.isAudioMessage(self) {
            cell = AudioMessageCell(style: .default, reuseIdentifier: "")
        }
        else if Message.isLocationMessage(self) {
            cell = LocationMessageCell(style: .default, reuseIdentifier: "")
        }
        else if Message.isFileTransferMessage(self) {
            cell = FileTransferCell(style: .default, reuseIdentifier: "")
        }
        else {
            fatal("Cannot create preview for \(self)")
        }
        
        cell.contentView.layoutMargins = UIEdgeInsets(top: 0, left: 24, bottom: 0, right: 0)
        
        let layoutProperties = ConversationCellLayoutProperties()
        layoutProperties.showSender       = false
        layoutProperties.showUnreadMarker = false
        layoutProperties.showBurstTimestamp = false
        layoutProperties.topPadding       = 0
        layoutProperties.alwaysShowDeliveryState = false
        
        if Message.isTextMessage(self) {
            layoutProperties.linkAttachments = Message.linkAttachments(self.textMessageData!)
        }
        
        cell.configure(for: self, layoutProperties: layoutProperties)
        
        return cell.wrapInTableView()
    }
}

extension ConversationContentViewController {
    @objc public func showForwardFor(message: ZMConversationMessage) {
        let conversations = SessionObjectCache.shared().allConversations.map { $0 as! ZMConversation }.filter { $0 != message.conversation }
        
        let shareViewController = ShareViewController(shareable: message as! ZMMessage, destinations: conversations)
        
        if self.parent?.parent?.wr_splitViewController.layoutSize == .compact {
            shareViewController.modalPresentationStyle = .overCurrentContext
        }
        else {
            shareViewController.modalPresentationStyle = .formSheet
        }
       
        shareViewController.onDismiss = { shareController in
            shareController.presentingViewController?.dismiss(animated: true, completion: .none)
        }
        UIApplication.shared.keyWindow?.rootViewController?.present(shareViewController, animated: true, completion: .none)
    }
}