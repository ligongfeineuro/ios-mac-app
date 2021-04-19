//
//  VpnKeys.swift
//  vpncore - Created on 15.04.2021.
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

import CommonCrypto
import Foundation
import Sodium

/**
 Ed25519 public key
 */
public struct PublicKey: Codable {
    // 32 byte Ed25519 key
    let rawRepresentation: [UInt8]

    // ASN.1 DER
    var derRepresentation: String {
        let publicKeyData = "30:2A:30:05:06:03:2B:65:70:03:21:00".dataFromHex()! + rawRepresentation
        let publicKeyBase64 = publicKeyData.base64EncodedString()
        return "-----BEGIN PUBLIC KEY-----\n\(publicKeyBase64)\n-----END PUBLIC KEY-----"
    }
}

/**
 Ed25519 private key
 */
public struct SecretKey: Codable {
    // 32 byte Ed25519 key
    let rawRepresentation: [UInt8]

    // ASN.1 DER
    var derRepresentation: String {
        let privateKeyData = "30:2E:02:01:00:30:05:06:03:2B:65:70:04:22:04:20".dataFromHex()! + rawRepresentation
        let privateKeyBase64 = privateKeyData.base64EncodedString()
        return "-----BEGIN PRIVATE KEY-----\n\(privateKeyBase64)\n-----END PRIVATE KEY-----"
    }

    // 32 byte X25519 key
    var rawX25519Representation: [UInt8] {
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA512_DIGEST_LENGTH))
        CC_SHA512(rawRepresentation, CC_LONG(rawRepresentation.count), &digest)
        var tmp = Array(digest.prefix(32)) // First 32 bytes of the SHA512 of the Ed25519 secret key
        tmp[0] &= 0xF8
        tmp[31] &= 0x7F
        tmp[31] |= 0x40
        return tmp
    }
}

/**
 Ed25519 key pair
 */
public struct VpnKeys: Codable {
    let privateKey: SecretKey
    let publicKey: PublicKey

    init() {
        let sodium = Sodium()
        let keyPair = sodium.sign.keyPair()!
        privateKey = SecretKey(rawRepresentation: keyPair.secretKey)
        publicKey = PublicKey(rawRepresentation: keyPair.publicKey)
    }
}    
