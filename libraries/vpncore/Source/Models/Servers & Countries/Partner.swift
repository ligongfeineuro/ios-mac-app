//
//  Created on 10/11/2022.
//
//  Copyright (c) 2022 Proton AG
//
//  ProtonVPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonVPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonVPN.  If not, see <https://www.gnu.org/licenses/>.

import Foundation

public struct Partner: Codable {
    public let name: String
    public let description: String
    public let iconURL: URL
    public let logicalIDs: [String]

    public init(dictionary: JSONDictionary) throws {
        name = try dictionary.stringOrThrow(key: "Name")
        description = try dictionary.stringOrThrow(key: "Description")
        iconURL = try dictionary.urlOrThrow(key: "IconURL")
        logicalIDs = try dictionary.stringArrayOrThrow(key: "LogicalIDs")
    }

    public init(name: String, description: String, iconURL: URL, logicalIDs: [String]) {
        self.name = name
        self.description = description
        self.iconURL = iconURL
        self.logicalIDs = logicalIDs
    }
}
