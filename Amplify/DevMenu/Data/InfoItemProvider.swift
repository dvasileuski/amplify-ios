//
// Copyright 2018-2020 Amazon.com,
// Inc. or its affiliates. All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation

/// Implement this protocol to display information for each row in Device / Environment Information screen
protocol InfoItemProvider {
    var displayName: String { get }
    var information: String { get }
}
