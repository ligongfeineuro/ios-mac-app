//
//  LogSelectionViewModelTests.swift
//  ProtonVPNTests
//
//  Created by Jaroslav on 2021-06-04.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import XCTest
import vpncore

class LogSelectionViewModelTests: XCTestCase {

    var viewModel: LogSelectionViewModel!
    let fileManager = FileManager()
    
    override func setUpWithError() throws {
        viewModel = LogSelectionViewModel()
    }

    override func tearDownWithError() throws {
    }
    
    func testViewModelCreatesCells() throws {
        XCTAssert(viewModel.tableViewData.count > 0)
    }
    
    func testHandlerOpensCorrectLog() throws {
        var openedTitle = ""

        viewModel.pushHandler = { logsViewModel in
            openedTitle = logsViewModel.title
        }
        
        let cell = viewModel.tableViewData.first?.cells.first
        switch cell {
        case .pushStandard(let title, let handler):
            XCTAssertEqual(title, LogSource.app.title)
            handler()
            XCTAssertEqual(openedTitle, LogSource.app.title)
            
        default:
            XCTAssert(false, "Wrong cell type returned")
        }
        
    }

}
