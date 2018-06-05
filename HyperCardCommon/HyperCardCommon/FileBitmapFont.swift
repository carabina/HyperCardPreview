//
//  FileBitmapFont.swift
//  HyperCard
//
//  Created by Pierre Lorenzi on 06/03/2017.
//  Copyright © 2017 Pierre Lorenzi. All rights reserved.
//


/// Subclass of BitmapFont with lazy loading from a file
/// <p>
/// Lazy loading is implemented by hand because an inherited property can't be made
/// lazy in swift.
public extension BitmapFont {
    
    public convenience init(reader: BitmapFontResourceReader) {
        
        self.init()
        
        /* Read now the scalar fields */
        self.maximumWidth = reader.readMaximumWidth()
        self.maximumKerning = reader.readMaximumKerning()
        self.fontRectangleWidth = reader.readFontRectangleWidth()
        self.fontRectangleHeight = reader.readFontRectangleHeight()
        self.maximumAscent = reader.readMaximumAscent()
        self.maximumDescent = reader.readMaximumDescent()
        self.leading = reader.readLeading()
        
        /* Lazy load the glyphs */
        self.glyphsProperty.lazyCompute { () -> [Glyph] in
            return BitmapFont.loadGlyphs(reader: reader)
        }
    }
    
    private static func loadGlyphs(reader: BitmapFontResourceReader) -> [Glyph] {
        
        var glyphs = [Glyph]()
        
        /* Gather some data */
        let lastCharacterCode = reader.readLastCharacterCode()
        let firstCharacterCode = reader.readFirstCharacterCode()
        let maximumAscent = reader.readMaximumAscent()
        let maximumKerning = reader.readMaximumKerning()
        let fontRectangleHeight = reader.readFontRectangleHeight()
        let widthTable = reader.readWidthTable()
        let offsetTable = reader.readOffsetTable()
        let bitmapLocationTable = reader.readBitmapLocationTable()
        let bitImageProperty = Property<Image> { () -> Image in
            return reader.readBitImage()
        }
        let loadBitImage = { () -> Image in return bitImageProperty.value }
        
        /* The special glyph is used outside the character bounds. It is the last in the font */
        let specialGlyphIndex = lastCharacterCode - firstCharacterCode + 1
        let specialGlyph = Glyph(maximumAscent: maximumAscent, maximumKerning: maximumKerning, fontRectangleHeight: fontRectangleHeight, width: widthTable[specialGlyphIndex], offset: offsetTable[specialGlyphIndex], startImageOffset: bitmapLocationTable[specialGlyphIndex], endImageOffset: bitmapLocationTable[specialGlyphIndex+1], loadBitImage: loadBitImage)
        
        for index in 0..<256 {
            
            /* Outside of the bounds, use the special glyph */
            guard index >= firstCharacterCode && index <= lastCharacterCode else {
                glyphs.append(specialGlyph)
                continue
            }
            
            /* Build the glyph */
            let glyph = Glyph(maximumAscent: maximumAscent, maximumKerning: maximumKerning, fontRectangleHeight: fontRectangleHeight, width: widthTable[index], offset: offsetTable[index], startImageOffset: bitmapLocationTable[index], endImageOffset: bitmapLocationTable[index+1], loadBitImage: loadBitImage)
            glyphs.append(glyph)
            
        }
        
        return glyphs
    }
    
}

