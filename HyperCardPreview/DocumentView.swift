//
//  DocumentView.swift
//  LittleStackReader
//
//  Created by Pierre Lorenzi on 05/03/2017.
//  Copyright © 2017 Pierre Lorenzi. All rights reserved.
//

import Cocoa
import HyperCardCommon

/// The view displaying the HyperCard stack
class DocumentView: NSView, NSMenuDelegate {
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        
        let layer = CALayer()
        layer.isOpaque = true
        self.layer = layer
        self.wantsLayer = true
    }

    override var wantsUpdateLayer: Bool {
        return true
    }
    
    override var isOpaque: Bool {
        return true
    }
    
    override func layout() {
        self.layer!.frame = self.bounds
    }
    
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    override func keyDown(with event: NSEvent) {
        
        /* Arrow keys */
        if event.modifierFlags.rawValue & NSEventModifierFlags.numericPad.rawValue != 0 {
            
            guard let characters = event.charactersIgnoringModifiers else {
                return
            }
            
            /* Reject dead keys */
            guard characters.utf16.count == 1 else {
                return
            }
            
            let character = Int(characters.utf16[String.UTF16View.Index(0)])
            
            switch character {
            case NSRightArrowFunctionKey:
                NSApp.sendAction(#selector(Document.goToNextPage), to: nil, from: nil)
            case NSLeftArrowFunctionKey:
                NSApp.sendAction(#selector(Document.goToPreviousPage), to: nil, from: nil)
            default:
                break;
            }
            
            return
        }
        
        super.keyDown(with: event)
    }
    
    var buttonScriptDisplayed = false
    var partScriptDisplayed = false
    
    override func flagsChanged(with event: NSEvent) {
        
        if event.modifierFlags.contains(NSEventModifierFlags.command) && event.modifierFlags.contains(NSEventModifierFlags.option) {
            
            if event.modifierFlags.contains(NSEventModifierFlags.shift) {
                if !partScriptDisplayed {
                    partScriptDisplayed = true
                    NSApp.sendAction(#selector(Document.displayPartScriptBorders(_:)), to: nil, from: nil)
                }
            }
            else if partScriptDisplayed {
                partScriptDisplayed = false
                buttonScriptDisplayed = true
                NSApp.sendAction(#selector(Document.displayButtonScriptBorders(_:)), to: nil, from: nil)
            }
            else if !buttonScriptDisplayed {
                buttonScriptDisplayed = true
                NSApp.sendAction(#selector(Document.displayButtonScriptBorders(_:)), to: nil, from: nil)
            }
            
        }
        else if partScriptDisplayed || buttonScriptDisplayed {
            partScriptDisplayed = false
            buttonScriptDisplayed = false
            NSApp.sendAction(#selector(Document.hideScriptBorders(_:)), to: nil, from: nil)
        }
        
    }
    
    weak var document: Document!
    
    override func mouseUp(with event: NSEvent) {
        
        let browserPosition = extractPosition(from: event)
        
        document.browser.respondToClick(at: browserPosition)
        
    }
    
    private func extractPosition(from event: NSEvent) -> Point {
        
        let locationInWindow = event.locationInWindow
        let locationInMe = self.convert(locationInWindow, from: nil)
        
        return Point(x: Int(locationInMe.x), y: document.browser.image.height - Int(locationInMe.y))
        
    }
    
    private var partsInMenu: [PartInMenu]? = nil
    
    private struct PartInMenu {
        let part: LayerPart
        let layerType: LayerType
        let number: Int
    }
    
    override func rightMouseUp(with event: NSEvent) {
        
        /* List the parts where the mouse clicks */
        let position = extractPosition(from: event)
        let partsAtClickPosition = listParts(atPoint: position)
        
        /* Save the parts to handle the menu actions */
        self.partsInMenu = partsAtClickPosition
        
        /* Display a menu with the list of the parts */
        let menu = buildContextualMenu(forParts: partsAtClickPosition)
        menu.delegate = self
        NSMenu.popUpContextMenu(menu, with: event, for: self)
        
    }
    
    private func listParts(atPoint point: Point) -> [PartInMenu] {
        
        /* List the parts from the foremost to the outmost */
        var parts: [PartInMenu] = []
        
        /* Look in the card parts */
        if !document.browser.displayOnlyBackground {
            let cardParts = listParts(atPoint: point, inLayer: document.browser.currentCard, layerType: .card)
            parts.append(contentsOf: cardParts)
        }
        
        /* Look in the background parts */
        let backgroundParts = listParts(atPoint: point, inLayer: document.browser.currentBackground, layerType: .background)
        parts.append(contentsOf: backgroundParts)
        
        return parts
    }
    
    private func listParts(atPoint point: Point, inLayer layer: Layer, layerType: LayerType) -> [PartInMenu] {
        
        var parts: [PartInMenu] = []
        
        /* Keep trace of the part numbers */
        var fieldNumber = 0
        var buttonNumber = 0
        
        for part in layer.parts {
            
            var number = 0
            
            /* Update the part numbers */
            switch part {
            case .button(_):
                buttonNumber += 1
                number = buttonNumber
            case .field(_):
                fieldNumber += 1
                number = fieldNumber
            }
            
            /* Check if the part lies at the position */
            if part.part.rectangle.containsPosition(point) {
                let partInMenu = PartInMenu(part: part, layerType: layerType, number: number)
                parts.append(partInMenu)
            }
        }
        
        return parts.reversed()
    }
    
    private func buildContextualMenu(forParts parts: [PartInMenu]) -> NSMenu {
        
        let menu = NSMenu(title: "Parts")
        
        /* Menu item explaining the menu */
        let explanationItem = NSMenuItem(title: "Parts at that point:", action: nil, keyEquivalent: "")
        explanationItem.isEnabled = false
        menu.addItem(explanationItem)
        
        var index = 0
        
        /* Menu item for the parts */
        for part in parts {
            
            /* Create the menu item */
            let title = findTitle(forPart: part)
            let menuItem = NSMenuItem(title: title, action: #selector(DocumentView.displayPartInfo), keyEquivalent: "")
            menuItem.target = self
            menuItem.tag = index
            
            /* Add it to the menu */
            menu.addItem(menuItem)
            
            index += 1
        }
        
        return menu
    }
    
    private func findTitle(forPart part: PartInMenu) -> String {
        
        var type = ""
        switch (part.layerType, part.part) {
        case (.card, .field(_)):
            type = "card field"
        case (.card, .button(_)):
            type = "button"
        case (.background, .field(_)):
            type = "field"
        case (.background, .button(_)):
            type = "background button"
        }
        
        let qualifier = (part.part.part.name != "") ? "\"\(part.part.part.name)\"" : "\(part.number)"
        
        return "\(type) \(qualifier)"
        
    }
    
    func menu(_ menu: NSMenu, willHighlight possibleMenuItem: NSMenuItem?) {
        
        /* Remove the script borders currently displayed  */
        document.removeScriptBorders()
        
        /* Check if a menu item is selected */
        guard let menuItem = possibleMenuItem else {
            return
        }
        
        /* Retrieve the part */
        let tag = menuItem.tag
        let part = self.partsInMenu![tag]
        
        /* Show the script border of the part */
        document.createScriptBorder(forPart: part.part, inLayerType: part.layerType)
    }
    
    func menuDidClose(_ menu: NSMenu) {
        document.removeScriptBorders()
    }
    
    @objc private func displayPartInfo(_ sender: AnyObject) {
        
        /* Retrieve the part */
        let menuItem = sender as! NSMenuItem
        let tag = menuItem.tag
        let part = self.partsInMenu![tag]
        let content = document.retrieveContent(part: part.part, inLayerType: part.layerType)
        
        switch part.part {
        case .field(let field):
            document.displayInfo().displayField(field, withContent: content)
        case .button(let button):
            document.displayInfo().displayButton(button, withContent: content)
        }
        
    }
    
    override func scrollWheel(with event: NSEvent) {
        
        let browserPosition = extractPosition(from: event)
        
        document.browser.respondToScroll(at: browserPosition, delta: Double(event.deltaY))
        
    }
    
    var hasDisplayedCardList = false
    
    override func magnify(with event: NSEvent) {
        
        if event.phase == .began {
            hasDisplayedCardList = false
            return
        }
        
        /* If the user demagnifies the view, show the card list behind */
        if event.magnification < 0.3 && !hasDisplayedCardList {
            document.showCards(self)
            hasDisplayedCardList = true
        }
    }
    
}
