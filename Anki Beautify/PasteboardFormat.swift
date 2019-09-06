//
//  PasteboardFormat.swift
//  Anki Beautify
//
//  Created by gpalya on 8/3/19.
//  Copyright © 2019 gpalya. All rights reserved.
//

import UIKit
import SwiftSoup

class PasteboardFormat {
    
    //let WebkitData = "com.apple.WebKit.custom-pasteboard-data"
    static let PublicHTML = "public.html"
    //let PublicRTF = "public.rtf"
    //let PlainText = "public.utf8-plain-text"
    //let FlatRTFD = "com.apple.flat-rtfd"
    //let AppleRTFD = "com.apple.rtfd"
    //let AttrStr = "com.apple.uikit.attributedstring"
    static let WebArchive = "Apple Web Archive pasteboard type"
    //let RichContent = "iOS rich content paste pasteboard type"
    
    private static var englishLines = ""
    
    static func transform() {
        // girish:
        // All the keys I found in the first item of pasteboard (below)
        // Some are utf8 strings, decodable from Data object (public.html, publi.rtf)
        //   Others are binary archives (OS_dispatch_data). plain-text is
        //   a NSString object that can
        //   be obtained from value() method of paste board.
        //
        // To paste to anki with format you have to have 'apple Web Archive pasteboard
        //   type' data. Others (like public.html and rtf) will just paste unformatted
        //   text.
        //
        // 'Copy' floating menu copies to pasteboard a dictionary into latest item.
        // This dictinonary has following keys (below). But when you set using
        // setData() on paste board it sets a dictionary with one key into latest item.
        //
        // Pwn-Oxford app has rtf. You can see rtf tags in some entries.
        //
        // 'Apple Web Archive pasteboard type' is a binary plist. But plist
        //    can be xml also. Try to create xml plist from public.html data
        //    and insert it into pasteboard, rather than trying to deserialise
        //    binary plist.
        //
        // Using RTF data from public.rtf into the data payload of
        //    'Apple Web Archive pasteboard type' does not work. Nothing pastes.
        //
        // HTML tags pl and gb are polish and english, see <pl...> and <gb style...>
        
        
        // In UIPasteboard, both value() and data() successfully return a value
        //    for all keys.
        //    Difference is that value() returns Any object and data() returns Data.
        
        let pasteBoard = UIPasteboard.general
        
        if let pData = pasteBoard.data(forPasteboardType: PublicHTML) {
            if let decodedString = String(data: pData, encoding: String.Encoding.utf8) {
                //logLongString(str: decodedString)
                reset()
                if let formatted = formatForAnki(input: decodedString) {
                    //NSLog(formatted)
                    if let webArch = getPListXMLArchive(content: formatted) {
                        pasteBoard.setValue(webArch, forPasteboardType: WebArchive)
                    }
                }
            }
        }
        //printPasteboard()
    }
    
    static func filterEnglishLines() {
        let pasteBoard = UIPasteboard.general
        //NSLog(englishLines)
        if englishLines != "" {
            if let webArch = getPListXMLArchive(content: englishLines) {
                pasteBoard.setValue(webArch, forPasteboardType: WebArchive)
            }
        }
    }
    
    static func reset() {
        englishLines = ""
    }
    
    // girish
    private static func formatForAnki(input: String) -> String? {
        do {
            let doc: Document = try SwiftSoup.parse(input)
            let visitor = MyNodeVisitor()
            try doc.traverse(visitor)
            return visitor.formatted
        } catch Exception.Error(_, let message) {
            print(message)
        } catch {
            print("girish: error")
        }
        return nil
    }
    
    
    // girish
    private static func getPListXMLArchive(content: String) -> String? {
        let top = """
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0">
             <dict>
              <key>WebMainResource</key>
              <dict>
               <key>WebResourceData</key>
               <data>
        """
        let bottom = """
               </data>
               <key>WebResourceFrameName</key>
               <string></string>
               <key>WebResourceMIMEType</key>
               <string>text/html</string>
               <key>WebResourceTextEncodingName</key>
               <string>UTF-8</string>
               <key>WebResourceURL</key>
               <string>about:blank</string>
              </dict>
             </dict>
            </plist>
        """
        let utf8data = content.data(using: .utf8)
        if let utf8str = utf8data?.base64EncodedString() {
            return top + utf8str + bottom
        } else { return nil }
    }
    
    
    // girish
    static func printPasteboard() {
        
        let pasteBoard = UIPasteboard.general
        NSLog("Printing pasteboard contents:")
        for item in pasteBoard.types {
            NSLog(item)
            if let pValue = pasteBoard.value(forPasteboardType: item) {
                let t = type(of: pValue as Any)
                NSLog("Value of '\(item)' is of type: '\(t)'")
            }
            
            if let pData = pasteBoard.data(forPasteboardType: item) {
                //NSLog(pData.debugDescription)
                if let decodedString = String(data: pData, encoding: String.Encoding.utf8) {
                    NSLog(decodedString)
                    NSLog("length of decoded string: " + String(decodedString.count))
                    //NSLog("description: " + pData.description)
                } else {
                    NSLog("girish decoding failed for '\(item)'")
                }
            }
        }
        NSLog("item count: %d\n", pasteBoard.types.count)
    }
    
    
    // girish: log long string
    private static func logLongString(str:String) {
        var newStr = String()
        for char in str {
            newStr += String(char)
            if newStr.count == 700 {
                NSLog(newStr)
                newStr = ""
            }
        }
        NSLog(newStr)
    }
    
    class MyNodeVisitor: NodeVisitor {
        
        var formatted: String = "";
        let approved: Set<String> = ["div", "p", "br", "b", "i", "u"]
        let BoldRE = "font-weight:[ ]+bold"
        let ItalicRE = "font-style:[ ]+italic"
        let TitleTxt = "font-size:[ ]+26.66"
        let FilterThis = "Przykłady użycia"
        var insidePrzyklad = false
        var insideEnglishLine = false
        
        /**
         * Callback for when a node is first visited.
         *
         * @param node the node being visited.
         * @param depth the depth of the node, relative to the root node. E.g., the root node has depth 0, and a child node
         * of that will have depth 1.
         */
        func head(_ node: Node, _ depth: Int) throws {
            
            if let element = (node as? Element) {
                let tag = element.tagName()
                
                if approved.contains(tag) {
                    formatted += "<\(tag)>"
                }
                if isStyle(re: TitleTxt, element: element) { // could be in div or span
                    formatted += "<em>"
                }
                if isStyle(re: BoldRE, element: element) {
                    formatted += "<b>"
                }
                if isStyle(re: ItalicRE, element: element) {
                    formatted += "<i>"
                }
                if tag == "a" { // link
                    formatted += "<u>"
                }
                if tag == "gb" {
                    insideEnglishLine = true
                }
                if tag == "span" && insideEnglishLine {
                    if try element.className() == "tekst-gb" {
                        // this is title text translation, ignore this
                        insideEnglishLine = false
                    }
                }
                if tag == "div" {
                    if try element.className() == "przyk sshow" {
                        insidePrzyklad = true
                    }
                }
                if insidePrzyklad && (tag == "gb") {
                    // english translation, so insert a line
                    formatted += "<br>"
                }
            }
        }
        
        /**
         * Callback for when a node is last visited, after all of its descendants have been visited.
         *
         * @param node the node being visited.
         * @param depth the depth of the node, relative to the root node. E.g., the root node has depth 0, and a child node
         * of that will have depth 1.
         */
        func tail(_ node: Node, _ depth: Int) throws {
            if let textNode = (node as? TextNode) {
                if textNode.text().range(of: FilterThis, options: .regularExpression, range: nil, locale: nil) != nil {
                    formatted += "&mdash;"
                } else {
                    formatted += textNode.text()
                }
                if insideEnglishLine {
                    englishLines += "* "
                    englishLines += textNode.text()
                    englishLines += "<br>"
                }
            } else if let element =  (node as? Element) { // reverse order as head function
                if element.tagName() == "div" {
                    if try element.className() == "przyk sshow" {
                        insidePrzyklad = false
                    }
                }
                let tag = element.tagName()
                
                if tag == "gb" {
                    insideEnglishLine = false
                }
                if tag == "a" { // link
                    formatted += "</u>"
                }
                if isStyle(re: ItalicRE, element: element) {
                    formatted += "</i>"
                }
                if isStyle(re: BoldRE, element: element) {
                    formatted += "</b>"
                }
                if isStyle(re: TitleTxt, element: element) {
                    formatted += "</em>"
                }
                // 'br' has no closing tag
                if approved.contains(tag) && (tag != "br") {
                    formatted += "</\(tag)>"
                }
            }
        }
        
        //
        func isStyle(re: String, element: Element) -> Bool {
            do {
                let attrStr = try element.attr("style")
                return attrStr.range(of: re, options: .regularExpression, range: nil, locale: nil) != nil
            } catch {
                NSLog("girish: error in attr")
            }
            return false
        }
        
    }
    
}


