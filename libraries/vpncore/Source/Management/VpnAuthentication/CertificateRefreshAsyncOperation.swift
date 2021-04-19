//
//  CertificateRefreshAsyncOperation.swift
//  vpncore - Created on 16.04.2021.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of vpncore.
//
//  vpncore is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  vpncore is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with vpncore.  If not, see <https://www.gnu.org/licenses/>.
//

import Foundation

enum CertificateRefreshError: Error {
    case canceled
}

final class CertificateRefreshAsyncOperation: AsyncOperation {
    private let keychain: VpnAuthenticationKeychain
    private let alamofireWrapper: AlamofireWrapper
    private let completion: CertificateRefreshCompletion?
    private let certificateRefreshDeadline: TimeInterval = 60 * 60 * 3 // 3 hours
    private var isRetry = false

    init(keychain: VpnAuthenticationKeychain, alamofireWrapper: AlamofireWrapper) {
        self.keychain = keychain
        self.alamofireWrapper = alamofireWrapper
        self.completion = nil
    }

    init(keychain: VpnAuthenticationKeychain, alamofireWrapper: AlamofireWrapper, completion: CertificateRefreshCompletion?) {
        self.keychain = keychain
        self.alamofireWrapper = alamofireWrapper
        self.completion = completion
    }

    private func finish(_ result: Result<(VpnAuthenticationData), Error>) {
        completion?(result)
        finish()
    }

    private func getCertificate(keys: VpnKeys, completion: @escaping (Result<VpnCertificate, Error>) -> Void) {
        PMLog.D("Asking backend API for new vpn authentication certificate")
        let request = CertificateRequest(publicKey: keys.publicKey)
        alamofireWrapper.request(request) { (dict: JSONDictionary) in
            do {
                let certificate = try VpnCertificate(dict: dict)
                PMLog.D("Got new vpn authentication certificate valid until \(certificate.validUntil)")
                DispatchQueue.main.async {
                    completion(.success(certificate))
                }
            } catch {
                PMLog.ET("Failed to decode vpn authentication certificate from backend: \(error)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        } failure: { error in
            PMLog.ET("Failed to get vpn authentication certificate from backend: \(error)")
            DispatchQueue.main.async {
                completion(.failure(error))
            }
        }
    }

    override func main() {
        guard !isCancelled else {
            finish(.failure(CertificateRefreshError.canceled))
            return
        }

        PMLog.D("Checking if vpn authentication certificate refresh is needed")

        let keys = keychain.getKeys()
        let existingCertificate = keychain.getStoredCertificate()

        let needsRefresh: Bool
        if let certificate = existingCertificate {
            // refresh is needed if the certificate expired before a safe interval
            needsRefresh = certificate.validUntil < Date().addingTimeInterval(certificateRefreshDeadline)
        } else {
            PMLog.D("No stored vpn authentication certificate found")
            // no certificate exists, refresh is definitely needed
            needsRefresh = true
        }

        guard needsRefresh else {
            PMLog.D("Stored vpn authentication certificate does not need refreshing (valid until \(existingCertificate!.validUntil)")
            finish(.success(VpnAuthenticationData(clientKey: keys.privateKey, clientCertificate: existingCertificate!.certificate)))
            return
        }

        guard !isCancelled else {
            finish(.failure(CertificateRefreshError.canceled))
            return
        }

        // fetch new certificate from backend
        getCertificate(keys: keys) { result in
            guard !self.isCancelled else {
                self.finish(.failure(CertificateRefreshError.canceled))
                return
            }

            switch result {
            case let .failure(error):
                let nsError = error as NSError
                switch nsError.code {
                case 2500 where !self.isRetry: // error ClientPublicKey fingerprint conflict, please regenerate a new key
                    PMLog.D("Trying to recover by generating new keys and trying again")
                    self.keychain.deleteKeys()
                    self.keychain.deleteCertificate()
                    self.isRetry = true
                    self.main()
                default:
                    self.finish(.failure(error))
                }
            case let .success(certificate):
                // store it
                self.keychain.store(certificate: certificate)
                self.finish(.success(VpnAuthenticationData(clientKey: keys.privateKey, clientCertificate: certificate.certificate)))
            }
        }
    }
}