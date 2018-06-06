//
//  DataTests.swift
//  HyperCardCommon
//
//  Created by Pierre Lorenzi on 30/08/2017.
//  Copyright © 2017 Pierre Lorenzi. All rights reserved.
//

import XCTest
import HyperCardCommon


/// Tests on binary data of stacks
class DataTests: XCTestCase {
    
    
    /// Test on some strange flags that appeared in some stacks, in the form of high bits activated in
    /// some values without apparent reason. If they are read, they crash the app.
    /// <p>
    /// The test uses the stack "Stack Templates", which has two of them: one high bit in Master Block length,
    /// and one high bit in window rectangle
    func testStrangeFlags() {
        
        /* Open stack */
        let path = Bundle(for: HyperCardCommonTests.self).path(forResource: "TestStrangeFlags", ofType: "stack")!
        let file = ClassicFile(path: path)
        let dataRange = DataRange(sharedData: file.dataFork!, offset: 0, length: file.dataFork!.count)
        let fileReader = StackReader(data: dataRange)
        
        /* Check window rectangle */
        let stackBlock = fileReader.extractStackBlock()
        let stackReader = try! StackBlockReader(data: stackBlock)
        XCTAssert(stackReader.readWindowRectangle() == Rectangle(top: 0, left: 0, bottom: 0x156, right: 0x200))
        
        /* Check Master Block by loading the list */
        _ = fileReader.extractListBlock(withIdentifier: 0x114B)
        
    }
    
    
}
