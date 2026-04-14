import UIKit
import MapKit
import CoreLocation

/// Callback: (latitude, longitude, placemark)
typealias MapLocationPickerCompletion = (_ latitude: Double, _ longitude: Double, _ placemark: CLPlacemark?) -> Void

/// Full-screen map picker with **search autocomplete**.
/// User can search for a place (autocomplete via MKLocalSearchCompleter),
/// select a result to fly there, then fine-tune by dragging the map.
/// The crosshair pin stays centred; the map pans beneath it.
final class MapLocationPickerViewController: UIViewController {

    // MARK: - Public API
    var onLocationPicked: MapLocationPickerCompletion?
    /// Optional starting coordinate (defaults to last known GPS or India centre)
    var initialCoordinate: CLLocationCoordinate2D?

    // MARK: - Brand colour
    private let brandTeal = UIColor(red: 0x70/255.0, green: 0xA7/255.0, blue: 0xB4/255.0, alpha: 1.0)

    // MARK: - UI — Map
    private let mapView = MKMapView()
    private let pinImageView = UIImageView()
    private let pinShadowView = UIView()
    private let pulseRing = UIView()

    // MARK: - UI — Search
    private let searchBar = UISearchBar()
    private let searchResultsTable = UITableView(frame: .zero, style: .plain)
    private var searchCompleter = MKLocalSearchCompleter()
    private var searchResults: [MKLocalSearchCompletion] = []

    // MARK: - UI — Bottom card
    private let bottomCard = UIView()
    private let addressTitleLabel = UILabel()
    private let addressSubLabel = UILabel()
    private let confirmButton = UIButton(type: .system)
    private let locateMeButton = UIButton(type: .system)
    private let activityIndicator = UIActivityIndicatorView(style: .medium)

    // Bottom card height
    private let cardHeight: CGFloat = 170
    private var bottomCardBottomConstraint: NSLayoutConstraint?
    private var searchTableTopConstraint: NSLayoutConstraint?

    // MARK: - State
    private let geocoder = CLGeocoder()
    private var lastReversedCoord: CLLocationCoordinate2D?
    private var geocodeWorkItem: DispatchWorkItem?
    private var isSearchActive = false

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Pick Location"
        view.backgroundColor = .systemBackground

        setupMap()
        setupPin()
        setupBottomCard()
        setupLocateMeButton()
        setupSearchBar()
        setupSearchResultsTable()
        centerOnInitialCoordinate()

        // Dismiss keyboard on tap outside search
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissSearch))
        tap.cancelsTouchesInView = false
        mapView.addGestureRecognizer(tap)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        bottomCard.layer.cornerRadius = 20
        bottomCard.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        confirmButton.layer.cornerRadius = confirmButton.bounds.height / 2
    }

    // MARK: - Map

    private func setupMap() {
        mapView.translatesAutoresizingMaskIntoConstraints = false
        mapView.delegate = self
        mapView.showsUserLocation = true
        mapView.showsCompass = false
        view.addSubview(mapView)
        NSLayoutConstraint.activate([
            mapView.topAnchor.constraint(equalTo: view.topAnchor),
            mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mapView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    // MARK: - Pin

    private func setupPin() {
        let pinCenterY = -(cardHeight / 2 + 20)

        // Subtle pulse dot — small ring that breathes under the pin tip
        pulseRing.translatesAutoresizingMaskIntoConstraints = false
        pulseRing.backgroundColor = brandTeal.withAlphaComponent(0.18)
        pulseRing.layer.cornerRadius = 6
        view.addSubview(pulseRing)
        NSLayoutConstraint.activate([
            pulseRing.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            pulseRing.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: pinCenterY + 2),
            pulseRing.widthAnchor.constraint(equalToConstant: 12),
            pulseRing.heightAnchor.constraint(equalToConstant: 12)
        ])

        // Shadow ellipse beneath pin tip
        pinShadowView.translatesAutoresizingMaskIntoConstraints = false
        pinShadowView.backgroundColor = UIColor.black.withAlphaComponent(0.12)
        pinShadowView.layer.cornerRadius = 3.5
        view.addSubview(pinShadowView)
        NSLayoutConstraint.activate([
            pinShadowView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            pinShadowView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: pinCenterY + 2),
            pinShadowView.widthAnchor.constraint(equalToConstant: 10),
            pinShadowView.heightAnchor.constraint(equalToConstant: 4)
        ])

        // Clean bare mappin — premium Apple Maps style (no circle)
        let pinConfig = UIImage.SymbolConfiguration(pointSize: 38, weight: .bold)
        pinImageView.image = UIImage(systemName: "mappin", withConfiguration: pinConfig)
        pinImageView.tintColor = brandTeal
        pinImageView.contentMode = .scaleAspectFit
        pinImageView.translatesAutoresizingMaskIntoConstraints = false
        // Subtle pin drop-shadow for depth
        pinImageView.layer.shadowColor = UIColor.black.cgColor
        pinImageView.layer.shadowOpacity = 0.22
        pinImageView.layer.shadowRadius = 4
        pinImageView.layer.shadowOffset = CGSize(width: 0, height: 3)
        view.addSubview(pinImageView)
        NSLayoutConstraint.activate([
            pinImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            // Pin tip (bottom of the symbol) sits at the map centre point
            pinImageView.bottomAnchor.constraint(equalTo: view.centerYAnchor, constant: pinCenterY + 2),
            pinImageView.widthAnchor.constraint(equalToConstant: 44),
            pinImageView.heightAnchor.constraint(equalToConstant: 44)
        ])

        startPulseAnimation()
    }

    // MARK: - Search Bar

    private func setupSearchBar() {
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        searchBar.delegate = self
        searchBar.placeholder = "Search for area, street, landmark…"
        searchBar.applyRentiWiseStyle()

        view.addSubview(searchBar)

        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 4),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -4),
        ])

        // Search completer
        searchCompleter.delegate = self
        searchCompleter.resultTypes = [.address, .pointOfInterest, .query]
    }

    // MARK: - Search Results Table

    private func setupSearchResultsTable() {
        searchResultsTable.translatesAutoresizingMaskIntoConstraints = false
        searchResultsTable.isHidden = true
        searchResultsTable.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.96)
        searchResultsTable.layer.cornerRadius = 14
        searchResultsTable.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        searchResultsTable.layer.shadowColor = UIColor.black.cgColor
        searchResultsTable.layer.shadowOpacity = 0.10
        searchResultsTable.layer.shadowRadius = 8
        searchResultsTable.layer.shadowOffset = CGSize(width: 0, height: 4)
        searchResultsTable.layer.masksToBounds = true
        searchResultsTable.separatorInset = UIEdgeInsets(top: 0, left: 44, bottom: 0, right: 16)
        searchResultsTable.rowHeight = 56
        searchResultsTable.dataSource = self
        searchResultsTable.delegate = self
        searchResultsTable.register(SearchSuggestionCell.self, forCellReuseIdentifier: SearchSuggestionCell.reuseID)
        searchResultsTable.keyboardDismissMode = .onDrag

        view.addSubview(searchResultsTable)

        let topConstraint = searchResultsTable.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 60)
        searchTableTopConstraint = topConstraint
        NSLayoutConstraint.activate([
            topConstraint,
            searchResultsTable.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            searchResultsTable.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            searchResultsTable.heightAnchor.constraint(lessThanOrEqualToConstant: 280)
        ])
    }

    // MARK: - Bottom Card

    private func setupBottomCard() {
        bottomCard.backgroundColor = .systemBackground
        bottomCard.layer.shadowColor = UIColor.black.cgColor
        bottomCard.layer.shadowOpacity = 0.12
        bottomCard.layer.shadowRadius = 16
        bottomCard.layer.shadowOffset = CGSize(width: 0, height: -4)
        bottomCard.layer.masksToBounds = false
        bottomCard.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bottomCard)

        let bottomConstraint = bottomCard.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        bottomCardBottomConstraint = bottomConstraint
        NSLayoutConstraint.activate([
            bottomCard.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomCard.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomConstraint,
            bottomCard.heightAnchor.constraint(equalToConstant: cardHeight)
        ])

        // Drag handle
        let handle = UIView()
        handle.translatesAutoresizingMaskIntoConstraints = false
        handle.backgroundColor = UIColor.systemGray4
        handle.layer.cornerRadius = 2.5
        bottomCard.addSubview(handle)
        NSLayoutConstraint.activate([
            handle.centerXAnchor.constraint(equalTo: bottomCard.centerXAnchor),
            handle.topAnchor.constraint(equalTo: bottomCard.topAnchor, constant: 8),
            handle.widthAnchor.constraint(equalToConstant: 36),
            handle.heightAnchor.constraint(equalToConstant: 5)
        ])

        // Location pin icon
        let pinIcon = UIImageView(image: UIImage(systemName: "mappin.and.ellipse"))
        pinIcon.tintColor = brandTeal
        pinIcon.contentMode = .scaleAspectFit
        pinIcon.translatesAutoresizingMaskIntoConstraints = false

        // Address labels
        addressTitleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        addressTitleLabel.textColor = .label
        addressTitleLabel.numberOfLines = 2
        addressTitleLabel.text = "Move the map to set location"
        addressTitleLabel.translatesAutoresizingMaskIntoConstraints = false

        addressSubLabel.font = .systemFont(ofSize: 12, weight: .regular)
        addressSubLabel.textColor = .secondaryLabel
        addressSubLabel.numberOfLines = 1
        addressSubLabel.text = "Or search above to find your area"
        addressSubLabel.translatesAutoresizingMaskIntoConstraints = false

        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.hidesWhenStopped = true
        activityIndicator.color = brandTeal

        bottomCard.addSubview(pinIcon)
        bottomCard.addSubview(addressTitleLabel)
        bottomCard.addSubview(addressSubLabel)
        bottomCard.addSubview(activityIndicator)

        NSLayoutConstraint.activate([
            pinIcon.leadingAnchor.constraint(equalTo: bottomCard.leadingAnchor, constant: 16),
            pinIcon.topAnchor.constraint(equalTo: handle.bottomAnchor, constant: 14),
            pinIcon.widthAnchor.constraint(equalToConstant: 24),
            pinIcon.heightAnchor.constraint(equalToConstant: 24),

            addressTitleLabel.leadingAnchor.constraint(equalTo: pinIcon.trailingAnchor, constant: 10),
            addressTitleLabel.trailingAnchor.constraint(equalTo: activityIndicator.leadingAnchor, constant: -8),
            addressTitleLabel.topAnchor.constraint(equalTo: pinIcon.topAnchor, constant: -2),

            addressSubLabel.leadingAnchor.constraint(equalTo: addressTitleLabel.leadingAnchor),
            addressSubLabel.trailingAnchor.constraint(equalTo: addressTitleLabel.trailingAnchor),
            addressSubLabel.topAnchor.constraint(equalTo: addressTitleLabel.bottomAnchor, constant: 3),

            activityIndicator.trailingAnchor.constraint(equalTo: bottomCard.trailingAnchor, constant: -16),
            activityIndicator.centerYAnchor.constraint(equalTo: addressTitleLabel.centerYAnchor)
        ])

        // Confirm button
        confirmButton.translatesAutoresizingMaskIntoConstraints = false
        var config = UIButton.Configuration.filled()
        config.baseBackgroundColor = brandTeal
        config.baseForegroundColor = .white
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 24, bottom: 12, trailing: 24)
        var titleAttr = AttributeContainer()
        titleAttr.font = .systemFont(ofSize: 15, weight: .semibold)
        config.attributedTitle = AttributedString("Confirm Location", attributes: titleAttr)
        confirmButton.configuration = config
        confirmButton.addTarget(self, action: #selector(confirmTapped), for: .touchUpInside)
        confirmButton.layer.shadowColor = brandTeal.cgColor
        confirmButton.layer.shadowOpacity = 0.25
        confirmButton.layer.shadowRadius = 8
        confirmButton.layer.shadowOffset = CGSize(width: 0, height: 3)
        bottomCard.addSubview(confirmButton)

        NSLayoutConstraint.activate([
            confirmButton.leadingAnchor.constraint(equalTo: bottomCard.leadingAnchor, constant: 16),
            confirmButton.trailingAnchor.constraint(equalTo: bottomCard.trailingAnchor, constant: -16),
            confirmButton.bottomAnchor.constraint(equalTo: bottomCard.safeAreaLayoutGuide.bottomAnchor, constant: -10),
            confirmButton.heightAnchor.constraint(equalToConstant: 46)
        ])
    }

    // MARK: - Locate Me

    private func setupLocateMeButton() {
        locateMeButton.translatesAutoresizingMaskIntoConstraints = false
        let imgConfig = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        locateMeButton.setImage(UIImage(systemName: "location.fill", withConfiguration: imgConfig), for: .normal)
        locateMeButton.tintColor = brandTeal
        locateMeButton.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.92)
        locateMeButton.layer.cornerRadius = 20
        locateMeButton.layer.shadowColor = UIColor.black.cgColor
        locateMeButton.layer.shadowOpacity = 0.12
        locateMeButton.layer.shadowRadius = 6
        locateMeButton.layer.shadowOffset = CGSize(width: 0, height: 3)
        locateMeButton.addTarget(self, action: #selector(locateMeTapped), for: .touchUpInside)
        view.addSubview(locateMeButton)
        NSLayoutConstraint.activate([
            locateMeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            locateMeButton.bottomAnchor.constraint(equalTo: bottomCard.topAnchor, constant: -12),
            locateMeButton.widthAnchor.constraint(equalToConstant: 40),
            locateMeButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }

    // MARK: - Initial position

    private func centerOnInitialCoordinate() {
        if let coord = initialCoordinate {
            let region = MKCoordinateRegion(center: coord, latitudinalMeters: 800, longitudinalMeters: 800)
            mapView.setRegion(region, animated: false)
            reverseGeocode(coord)
        } else {
            Task {
                if let coord = await AppLocationManager.shared.currentCoordinates() {
                    await MainActor.run {
                        let region = MKCoordinateRegion(center: coord, latitudinalMeters: 800, longitudinalMeters: 800)
                        self.mapView.setRegion(region, animated: true)
                        self.reverseGeocode(coord)
                    }
                } else {
                    let india = CLLocationCoordinate2D(latitude: 20.5937, longitude: 78.9629)
                    let region = MKCoordinateRegion(center: india, latitudinalMeters: 3_000_000, longitudinalMeters: 3_000_000)
                    mapView.setRegion(region, animated: false)
                }
            }
        }
    }

    // MARK: - Pulse animation

    private func startPulseAnimation() {
        pulseRing.transform = .identity
        pulseRing.alpha = 0.7
        UIView.animate(withDuration: 1.4, delay: 0, options: [.repeat, .autoreverse, .curveEaseInOut]) {
            self.pulseRing.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
            self.pulseRing.alpha = 0
        }
    }

    private func pausePulse() {
        pulseRing.layer.removeAllAnimations()
        UIView.animate(withDuration: 0.12) { self.pulseRing.alpha = 0 }
    }

    private func resumePulse() { startPulseAnimation() }

    // MARK: - Pin lift/drop

    private func liftPin() {
        UIView.animate(withDuration: 0.12, delay: 0, options: .curveEaseOut) {
            self.pinImageView.transform = CGAffineTransform(translationX: 0, y: -10)
            self.pinShadowView.transform = CGAffineTransform(scaleX: 1.4, y: 1)
            self.pinShadowView.alpha = 0.5
        }
    }

    private func dropPin() {
        UIView.animate(withDuration: 0.18, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 6, options: []) {
            self.pinImageView.transform = .identity
            self.pinShadowView.transform = .identity
            self.pinShadowView.alpha = 1.0
        }
    }

    // MARK: - Reverse geocoding

    private func reverseGeocode(_ coord: CLLocationCoordinate2D) {
        geocodeWorkItem?.cancel()
        activityIndicator.startAnimating()

        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            let location = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
            self.geocoder.cancelGeocode()
            self.geocoder.reverseGeocodeLocation(location) { placemarks, error in
                DispatchQueue.main.async {
                    self.activityIndicator.stopAnimating()
                    guard let pm = placemarks?.first, error == nil else {
                        self.addressTitleLabel.text = "Location selected"
                        self.addressSubLabel.text = String(format: "%.5f, %.5f", coord.latitude, coord.longitude)
                        self.lastReversedCoord = coord
                        return
                    }
                    self.lastReversedCoord = coord
                    let parts = [pm.subLocality, pm.locality]
                        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }
                    self.addressTitleLabel.text = parts.isEmpty ? (pm.name ?? "Selected Location") : parts.joined(separator: ", ")
                    let sub = [pm.administrativeArea, pm.country]
                        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }
                        .joined(separator: ", ")
                    self.addressSubLabel.text = sub.isEmpty ? "Tap confirm to use this location" : sub
                }
            }
        }
        geocodeWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    // MARK: - Search helpers

    private func showSearchResults() {
        searchResultsTable.isHidden = searchResults.isEmpty
        searchResultsTable.reloadData()
        isSearchActive = !searchResults.isEmpty
    }

    private func hideSearchResults() {
        searchResultsTable.isHidden = true
        searchResults = []
        isSearchActive = false
    }

    @objc private func dismissSearch() {
        searchBar.resignFirstResponder()
        hideSearchResults()
    }

    private func flyTo(_ completion: MKLocalSearchCompletion) {
        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)
        search.start { [weak self] response, _ in
            guard let self, let item = response?.mapItems.first else { return }
            let coord = item.placemark.coordinate
            let region = MKCoordinateRegion(center: coord, latitudinalMeters: 600, longitudinalMeters: 600)
            self.mapView.setRegion(region, animated: true)
            self.lastReversedCoord = coord
            self.reverseGeocode(coord)
        }
    }

    // MARK: - Actions

    @objc private func confirmTapped() {
        guard let coord = lastReversedCoord ?? initialCoordinate else {
            confirmWithCoord(mapView.region.center)
            return
        }
        confirmWithCoord(coord)
    }

    private func confirmWithCoord(_ coord: CLLocationCoordinate2D) {
        geocodeWorkItem?.cancel()
        activityIndicator.startAnimating()
        confirmButton.isEnabled = false

        let location = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        geocoder.cancelGeocode()
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            guard let self else { return }
            DispatchQueue.main.async {
                self.activityIndicator.stopAnimating()
                self.confirmButton.isEnabled = true
                self.onLocationPicked?(coord.latitude, coord.longitude, placemarks?.first)
                self.navigationController?.popViewController(animated: true)
            }
        }
    }

    @objc private func locateMeTapped() {
        Task {
            if let coord = await AppLocationManager.shared.currentCoordinates() {
                await MainActor.run {
                    let region = MKCoordinateRegion(center: coord, latitudinalMeters: 500, longitudinalMeters: 500)
                    self.mapView.setRegion(region, animated: true)
                }
            } else {
                do {
                    let loc = try await AppLocationManager.shared.currentLocation()
                    await MainActor.run {
                        let region = MKCoordinateRegion(center: loc.coordinate, latitudinalMeters: 500, longitudinalMeters: 500)
                        self.mapView.setRegion(region, animated: true)
                    }
                } catch {
                    await MainActor.run {
                        let ac = UIAlertController(title: "Location Unavailable",
                                                   message: error.localizedDescription,
                                                   preferredStyle: .alert)
                        ac.addAction(UIAlertAction(title: "OK", style: .default))
                        self.present(ac, animated: true)
                    }
                }
            }
        }
    }
}

// MARK: - MKMapViewDelegate

extension MapLocationPickerViewController: MKMapViewDelegate {

    func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
        liftPin()
        pausePulse()
        geocodeWorkItem?.cancel()
        geocoder.cancelGeocode()
        activityIndicator.stopAnimating()
        addressTitleLabel.text = "Move the map to set location"
        addressSubLabel.text = "Release to confirm position"
    }

    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        dropPin()
        resumePulse()
        let centre = mapView.region.center
        lastReversedCoord = centre
        reverseGeocode(centre)
    }
}

// MARK: - UISearchBarDelegate

extension MapLocationPickerViewController: UISearchBarDelegate {

    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        searchBar.setShowsCancelButton(true, animated: true)
    }

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            hideSearchResults()
            searchCompleter.cancel()
        } else {
            searchCompleter.queryFragment = trimmed
        }
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        // If there's a top result, fly to it
        if let first = searchResults.first {
            flyTo(first)
            hideSearchResults()
            searchBar.text = first.title
            searchBar.setShowsCancelButton(false, animated: true)
        }
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.text = nil
        searchBar.resignFirstResponder()
        searchBar.setShowsCancelButton(false, animated: true)
        hideSearchResults()
    }

    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        searchBar.setShowsCancelButton(false, animated: true)
    }
}

// MARK: - MKLocalSearchCompleterDelegate

extension MapLocationPickerViewController: MKLocalSearchCompleterDelegate {

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        searchResults = Array(completer.results.prefix(6))
        showSearchResults()
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        // Silently ignore — user can still pan manually
    }
}

// MARK: - UITableViewDataSource / Delegate  (search results)

extension MapLocationPickerViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        searchResults.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: SearchSuggestionCell.reuseID, for: indexPath) as? SearchSuggestionCell else {
            return UITableViewCell()
        }
        let result = searchResults[indexPath.row]
        cell.configure(title: result.title, subtitle: result.subtitle, tintColor: brandTeal)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let result = searchResults[indexPath.row]
        searchBar.text = result.title
        searchBar.resignFirstResponder()
        hideSearchResults()
        flyTo(result)
    }
}

// MARK: - SearchSuggestionCell

private final class SearchSuggestionCell: UITableViewCell {
    static let reuseID = "SearchSuggestionCell"

    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundColor = .clear
        selectionStyle = .default

        let iconConfig = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        iconView.image = UIImage(systemName: "mappin.circle.fill", withConfiguration: iconConfig)
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = .systemFont(ofSize: 14, weight: .medium)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 1
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        subtitleLabel.font = .systemFont(ofSize: 12, weight: .regular)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.numberOfLines = 1
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(iconView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(subtitleLabel)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 14),
            iconView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 22),
            iconView.heightAnchor.constraint(equalToConstant: 22),

            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 10),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -14),
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),

            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            subtitleLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -10)
        ])
    }

    func configure(title: String, subtitle: String, tintColor: UIColor) {
        titleLabel.text = title
        subtitleLabel.text = subtitle
        iconView.tintColor = tintColor
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        titleLabel.text = nil
        subtitleLabel.text = nil
    }
}
