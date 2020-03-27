//
//  QRScanerView.swift
//  StandardQRScanner
//
//  Created by NishiokaKohei on 25/03/2020.
//  Copyright © 2020 Takumi. All rights reserved.
//

import UIKit
import AVFoundation

public protocol QRScanerViewDelegate: class {
    // Required
    func qrScannerView(_ qrScannerView: QRScannerView, didFailure error: ScannerError)
    func qrScannerView(_ qrScannerView: QRScannerView, didSuccess code: String)
    // Optional
    func qrScannerView(_ qrScannerView: QRScannerView, didChangeTorchActive isOn: Bool)
}

public extension QRScanerViewDelegate where Self: AnyObject {
    func qrScannerView(_ qrScannerView: QRScannerView, didChangeTorchActive isOn: Bool) {}
}

public typealias CompletionHandler = ((_ isComplated: Bool, _ code: String?, _ error: ScannerError?) -> Void)

// MARK: - QRScanerView
@IBDesignable
public class QRScannerView: UIView {

    // MARK: - Configuration
    public struct Configuration {
        let objectTypes: [ObjectType]
        let focusImage: UIImage?
        let focusImagePadding: CGFloat?
        let animationDuration: Double?
        let isBlurEffectEnabled: Bool?
        /// フォーカス内のみ検出可能か
        let isDetectableInFocusImage: Bool?

        public static var `default`: Configuration {
            return .init(objectTypes: ObjectType.allCases, focusImage: nil, focusImagePadding: nil, animationDuration: nil, isBlurEffectEnabled: nil)
        }

        public init(objectTypes: [ObjectType] = [.qr],
                    focusImage: UIImage? = nil,
                    focusImagePadding: CGFloat? = nil,
                    animationDuration: Double? = nil,
                    isBlurEffectEnabled: Bool? = nil,
                    isDetectableInFocusImage: Bool? = nil) {
            self.objectTypes = objectTypes
            self.focusImage = focusImage
            self.focusImagePadding = focusImagePadding
            self.animationDuration = animationDuration
            self.isBlurEffectEnabled = isBlurEffectEnabled
            self.isDetectableInFocusImage = isDetectableInFocusImage
        }
    }

    public enum ObjectType: CaseIterable {
        case qr, barcode, pdf417

        var avMetadataObjectType: [AVMetadataObject.ObjectType] {
            switch self {
            case .qr:
                return [.qr]
            case .barcode:
                return [.code39, .code93, .code128, .itf14, .ean8, .ean13]
            case .pdf417:
                return [.pdf417]
            }
        }
    }

    // MARK: - Public Properties

    @IBInspectable
    public var focusImage: UIImage?

    @IBInspectable
    public var focusImagePadding: CGFloat = 8.0

    @IBInspectable
    public var animationDuration: Double = 0.5

    // MARK: - Public methods

    public func configure(
        _ delegate: QRScanerViewDelegate? = nil,
        _ configuration: Configuration = .default,
        _ completion: CompletionHandler? = nil
    ) {
        self.delegate = delegate
        if !configuration.objectTypes.isEmpty {
            self.objectTypes = configuration.objectTypes
        }
        if let focusImage = configuration.focusImage {
            self.focusImage = focusImage
        }
        if let focusImagePadding = configuration.focusImagePadding {
            self.focusImagePadding = focusImagePadding
        }
        if let completion = completion {
            self.completionHandler = completion
        }
        if let animationDuration = configuration.animationDuration {
            self.animationDuration = animationDuration
        }
        if let isDetectableInFocusImage = configuration.isDetectableInFocusImage {
            self.isDetectableInFocusImage = isDetectableInFocusImage
        }

        do {
            try setupSession()
        } catch {
            failure(error as! ScannerError)
        }
        addPreviewLayer()
        setupImageViews()
    }

    public func startRunning() {
        guard isAuthorized else { return }
        guard !session.isRunning else { return }
        metadataOutputEnable = true
        metadataQueue.async { [weak self] in
            self?.session.startRunning()
        }
    }

    public func stopRunning() {
        guard session.isRunning else { return }
        metadataQueue.async { [weak self] in
            self?.session.stopRunning()
        }
        metadataOutputEnable = false
    }

    deinit {
        focusImageView.removeFromSuperview()
        qrCodeImageView.removeFromSuperview()
        session.inputs.forEach({ session.removeInput($0) })
        session.outputs.forEach({ session.removeOutput($0) })
        removePreviewLayer()
        if session.isRunning {
            DispatchQueue.main.async { [weak self] in
                self?.stopRunning()
            }
        }
    }

    // MARK: - Private Properties

    private let metadataQueue = DispatchQueue(label: "metadata.session.qrreader.queue")
    private let videoDataQueue = DispatchQueue(label: "videoData.session.qrreader.queue")
    private let session = AVCaptureSession()

    private weak var delegate: QRScanerViewDelegate?
    private var completionHandler: CompletionHandler? = nil
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var focusImageView = UIImageView()
    private var qrCodeImageView = UIImageView()
    private var metadataOutput = AVCaptureMetadataOutput()
    private var metadataOutputEnable = false
    private var isDetectableInFocusImage = true
    private var qrCodeImage: UIImage?
    private var objectTypes: [ObjectType] = []
}

// MARK: - Private methods
private extension QRScannerView {

    enum AuthorizationStatus {
        case authorized, notDetermined, restricted, denied
    }

    var isAuthorized: Bool { authorizationStatus() == .authorized }
    var isNotDetermined: Bool { authorizationStatus() == .notDetermined }

    func authorizationStatus() -> AuthorizationStatus {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return .authorized
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        @unknown default:
            return .denied
        }
    }

    func setupSession() throws {
        // check devide
        guard let videoDevice = AVCaptureDevice.default(for: .video) else {
            throw ScannerError.unavailable(.videoUnavailable)
        }
        guard let deviceInput = try? AVCaptureDeviceInput(device: videoDevice),
            session.canAddInput(deviceInput) else {
                throw ScannerError.unavailable(.inputInvalid)
        }
        guard session.canAddOutput(metadataOutput) else {
            throw ScannerError.unavailable(.videoDataOutputFailure)
        }

        // session commit
        session.beginConfiguration()
        session.addInput(deviceInput)
        metadataOutput.setMetadataObjectsDelegate(self, queue: metadataQueue)
        session.addOutput(metadataOutput)
        metadataOutput.metadataObjectTypes = objectTypes.flatMap({ $0.avMetadataObjectType })
        
        session.commitConfiguration()

        if isNotDetermined {
            metadataOutputEnable = true
            metadataQueue.async { [weak self] in
                // start session
                self?.session.startRunning()
            }
        }
    }

    func addPreviewLayer() {
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = self.bounds
        layer.addSublayer(previewLayer)

        self.previewLayer = previewLayer
    }

    func removePreviewLayer() {
        previewLayer?.removeFromSuperlayer()
    }

    func setupImageViews() {
        let width = UIScreen.main.bounds.width * 0.618
        let x = UIScreen.main.bounds.width * 0.191
        let y = UIScreen.main.bounds.height * 0.191
        focusImageView = UIImageView(frame: CGRect(x: x, y: y, width: width, height: width))
        focusImageView.image
            = focusImage ?? UIImage(named: "scan_focus", in: Bundle(for: QRScannerView.self), compatibleWith: nil)
        addSubview(focusImageView)

        qrCodeImageView = UIImageView()
        qrCodeImageView.contentMode = .scaleAspectFill
        addSubview(qrCodeImageView)

        if isDetectableInFocusImage {
            let width = focusImageView.frame.width / self.frame.width
            let height = focusImageView.frame.height / self.frame.height
            let x = focusImageView.frame.origin.x / self.frame.width
            let y = focusImageView.frame.origin.y / self.frame.height
            metadataOutput.rectOfInterest = CGRect(x: y, y: 1 - x - width, width: height, height: width)
        }
    }

    func success(_ code: String) {
        if let completionHandler = completionHandler {
            completionHandler(true, code, nil)
        }
        delegate?.qrScannerView(self, didSuccess: code)
    }

    func failure(_ error: ScannerError) {
        if let completionHandler = completionHandler {
            completionHandler(false, nil, error)
        }
        delegate?.qrScannerView(self, didFailure: error)
    }

    func detectQRCode(_ qrCode: String, corners: [CGPoint]) {
        moveImageViews(qrCode: qrCode, corners: corners)
    }

    private func moveImageViews(qrCode: String, corners: [CGPoint]) {
        assert(Thread.isMainThread)

        let path = UIBezierPath()
        path.move(to: corners[0])
        corners[1..<corners.count].forEach() {
            path.addLine(to: $0)
        }
        path.close()

        let aSide: CGFloat
        let bSide: CGFloat
        if corners[0].x < corners[1].x {
            aSide = corners[0].x - corners[1].x
            bSide = corners[1].y - corners[0].y
        } else {
            aSide = corners[2].y - corners[1].y
            bSide = corners[2].x - corners[1].x
        }
        let degrees = atan(aSide / bSide)

        var maxSide: CGFloat =  hypot(corners[3].x - corners[0].x, corners[3].y - corners[0].y)
        for (i, _) in corners.enumerated() {
            if i == 3 { break }
            let side = hypot(corners[i].x - corners[i+1].x, corners[i].y - corners[i+1].y)
            maxSide = side > maxSide ? side : maxSide
        }
        maxSide += focusImagePadding * 2

        UIView.animate(withDuration: animationDuration, animations: { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.focusImageView.frame = path.bounds
            let center = strongSelf.focusImageView.center
            strongSelf.focusImageView.frame.size = CGSize(width: maxSide, height: maxSide)
            strongSelf.focusImageView.center = center
            strongSelf.focusImageView.transform = CGAffineTransform.identity.rotated(by: degrees)

            strongSelf.qrCodeImageView.frame = path.bounds
            strongSelf.qrCodeImageView.center = center
        }, completion: { [weak self] _ in
                guard let strongSelf = self else { return }
                strongSelf.qrCodeImageView.image = strongSelf.qrCodeImage
                strongSelf.success(qrCode)
        })
    }

}

// MARK* - AVCaptureMetadataOutputObjectsDelegate
extension QRScannerView: AVCaptureMetadataOutputObjectsDelegate {
    public func metadataOutput(_ output: AVCaptureMetadataOutput,
                               didOutput metadataObjects: [AVMetadataObject],
                               from connection: AVCaptureConnection) {
        guard metadataOutputEnable else { return }
        guard !metadataObjects.isEmpty else {
            failure(ScannerError.readFailure)
            return
        }
        guard let metadata = metadataObjects.first else { return }
        switch metadata.type {
        case .qr:
            guard let readableObject = previewLayer?.transformedMetadataObject(for: metadata)
                as? AVMetadataMachineReadableCodeObject else { return }
            guard let qrCode = readableObject.stringValue else { return }
            metadataOutputEnable = false

            DispatchQueue.main.async { [weak self] in
                guard let `self` = self else { return }
                self.detectQRCode(qrCode, corners: readableObject.corners)
                self.stopRunning()
            }
        default:
            break
        }
    }

}
