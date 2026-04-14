//
//  CategoryCollectionViewCell.swift
//  RentiWise
//
//  Created by admin99 on 06/11/25.
//

import UIKit

final class CategoryCollectionViewCell: UICollectionViewCell {
    static let reuseIdentifier = "Category"

    let categoryImage = UIImageView()
    let categoryLabel = UILabel()
    let categoryBg = UIImageView()

    private let darkOverlayView = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    private func setupUI() {
        contentView.layer.cornerRadius = 12
        contentView.layer.masksToBounds = true
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        categoryBg.translatesAutoresizingMaskIntoConstraints = false
        categoryBg.contentMode = .scaleAspectFill
        categoryBg.clipsToBounds = true

        darkOverlayView.translatesAutoresizingMaskIntoConstraints = false
        darkOverlayView.backgroundColor = UIColor.black.withAlphaComponent(0.35)
        darkOverlayView.isUserInteractionEnabled = false

        categoryImage.translatesAutoresizingMaskIntoConstraints = false
        categoryImage.contentMode = .scaleAspectFit
        categoryImage.tintColor = .white

        categoryLabel.translatesAutoresizingMaskIntoConstraints = false
        categoryLabel.textAlignment = .center
        categoryLabel.numberOfLines = 1

        contentView.addSubview(categoryBg)
        categoryBg.addSubview(darkOverlayView)
        contentView.addSubview(categoryImage)
        contentView.addSubview(categoryLabel)

        NSLayoutConstraint.activate([
            categoryBg.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            categoryBg.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            categoryBg.topAnchor.constraint(equalTo: contentView.topAnchor),
            categoryBg.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            darkOverlayView.leadingAnchor.constraint(equalTo: categoryBg.leadingAnchor),
            darkOverlayView.trailingAnchor.constraint(equalTo: categoryBg.trailingAnchor),
            darkOverlayView.topAnchor.constraint(equalTo: categoryBg.topAnchor),
            darkOverlayView.bottomAnchor.constraint(equalTo: categoryBg.bottomAnchor),

            categoryImage.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            categoryImage.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            categoryImage.widthAnchor.constraint(equalToConstant: 44),
            categoryImage.heightAnchor.constraint(equalToConstant: 44),

            categoryLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 6),
            categoryLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -6),
            categoryLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
    }
}
