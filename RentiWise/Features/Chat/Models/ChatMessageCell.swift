// swift-extract-localization: off
// Disables per-file Swift localized strings extraction to avoid duplicate .stringsdata

//

//  MessageCell.swift
//  RentiWise
//
import UIKit

final class ChatMessageCell: UICollectionViewCell {
  
   static let reuseIdentifier = "ChatMessageCell"
  
   private let bubbleView: UIView = {
       let view = UIView()
       view.translatesAutoresizingMaskIntoConstraints = false
       view.layer.cornerRadius = 16
       view.layer.masksToBounds = true
       return view
   }()
  
   private let messageLabel: UILabel = {
       let label = UILabel()
       label.translatesAutoresizingMaskIntoConstraints = false
       label.numberOfLines = 0
       label.font = .systemFont(ofSize: 16)
       return label
   }()
  
   private let timestampLabel: UILabel = {
       let label = UILabel()
       label.translatesAutoresizingMaskIntoConstraints = false
       label.font = .systemFont(ofSize: 11)
       label.textColor = .secondaryLabel
       return label
   }()
  
   private var bubbleLeadingConstraint: NSLayoutConstraint!
   private var bubbleTrailingConstraint: NSLayoutConstraint!
  
   private let sentBubbleColor = UIColor(red: 0x70/255.0, green: 0xA7/255.0, blue: 0xB4/255.0, alpha: 1.0)
   private let receivedBubbleColor = UIColor.white
  
   override init(frame: CGRect) {
       super.init(frame: frame)
       setupViews()
   }
  
   required init?(coder: NSCoder) {
       super.init(coder: coder)
       setupViews()
   }
  
   private func setupViews() {
       contentView.addSubview(bubbleView)
       bubbleView.addSubview(messageLabel)
       contentView.addSubview(timestampLabel)
      
       bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4).isActive = true
       bubbleView.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: 0.75).isActive = true
      
       bubbleLeadingConstraint = bubbleView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16)
       bubbleTrailingConstraint = bubbleView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
      
       NSLayoutConstraint.activate([
           messageLabel.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 10),
           messageLabel.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -10),
           messageLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 14),
           messageLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -14),
          
           timestampLabel.topAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: 2),
           timestampLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4)
       ])
   }
  
   func configure(with message: ChatMessage, isCurrentUser: Bool) {
       messageLabel.text = message.text
       timestampLabel.text = message.formattedTime
      
       bubbleLeadingConstraint.isActive = false
       bubbleTrailingConstraint.isActive = false
      
       if isCurrentUser {
           bubbleTrailingConstraint.isActive = true
           bubbleView.backgroundColor = sentBubbleColor
           messageLabel.textColor = .white
           timestampLabel.textAlignment = .right
       } else {
           bubbleLeadingConstraint.isActive = true
           bubbleView.backgroundColor = receivedBubbleColor
           messageLabel.textColor = .label
           timestampLabel.textAlignment = .left
       }
   }
  
   override func prepareForReuse() {
       super.prepareForReuse()
       messageLabel.text = nil
       timestampLabel.text = nil
   }
}

