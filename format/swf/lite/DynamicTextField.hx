package format.swf.lite;


import flash.display.Shape;
import flash.display.Sprite;
import flash.geom.Point;
import flash.text.Font;
import flash.text.TextField;
import flash.text.TextFormat;
import flash.text.TextFormatAlign;
import format.swf.lite.symbols.DynamicTextSymbol;
import format.swf.lite.symbols.FontSymbol;
import format.swf.lite.SWFLite;

import htmlparser.HtmlDocument;

class DynamicTextField extends TextField {


	public var symbol:DynamicTextSymbol;

	private var glyphs:Array<Shape>;
	private var swf:SWFLite;
	private var _text:String;

	/** Returns the localization identifier from the HTML in a SWF TextField. */
	public static function getLocalizationIdentifier (html:String) : String
	{
		var text:String = "";
        for (node in new HtmlDocument(html).nodes) {	// convert HTML to text
        	if (text == "") text  = node.toText();
        	else 			text += "\\n" + node.toText();
        }
        text = StringTools.replace(text, "\"", "\\\"");	// escape double-quotes
        text = ~/[\r\n]/g.replace(text, "\\n");			// escape newline characters
        return text;
	}

	public function new (swf:SWFLite, symbol:DynamicTextSymbol) {

		super ();

		this.swf = swf;
		this.symbol = symbol;

		width = symbol.width;
		height = symbol.height;

		multiline = symbol.multiline;
		wordWrap = symbol.wordWrap;
		displayAsPassword = symbol.password;
		border = symbol.border;
		selectable = symbol.selectable;

		var format = new TextFormat ();
		if (symbol.color != null) format.color = (symbol.color & 0x00FFFFFF);
		format.size = Std.int (symbol.fontHeight / 20);

		var font:FontSymbol = cast swf.symbols.get (symbol.fontID);

		format.font = symbol.fontName;

		var found = false;

		switch (format.font) {

			case "_sans", "_serif", "_typewriter", "", null:

				found = true;

			default:

				for (font in Font.enumerateFonts ()) {

					if (font.fontName == format.font) {

						found = true;
						break;

					}

				}

		}

		if (found) {

			embedFonts = true;

		} else {

			trace ("Warning: Could not find required font \"" + format.font + "\", it has not been embedded");

		}

		if (symbol.align != null) {

			if (symbol.align == "center") format.align = TextFormatAlign.CENTER;
			else if (symbol.align == "right") format.align = TextFormatAlign.RIGHT;
			else if (symbol.align == "justify") format.align = TextFormatAlign.JUSTIFY;

			format.leftMargin = Std.int (symbol.leftMargin / 20);
			format.rightMargin = Std.int (symbol.rightMargin / 20);
			format.indent = Std.int (symbol.indent / 20);

			format.leading = Std.int(symbol.leading / 30);
			#if flash
			if (embedFonts) format.leading = Std.int (symbol.leading / 20) + 6; // TODO: Is this an issue of Flash fonts are embedded?
			#end

		}

		defaultTextFormat = format;

		#if !flash

		text = getLocalizationIdentifier(symbol.text);

		#else

		if (symbol.html) {

			htmlText = symbol.text;

		} else {

			text = symbol.text;

		}

		#end

		//autoSize = (tag.autoSize) ? TextFieldAutoSize.LEFT : TextFieldAutoSize.NONE;

	}


}
