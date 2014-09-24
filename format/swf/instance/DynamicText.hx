package format.swf.instance;


import flash.display.BitmapData;
import flash.geom.Matrix;
import flash.geom.Rectangle;
import flash.text.Font;
import flash.text.TextField;
import flash.text.TextFieldAutoSize;
import flash.text.TextFormat;
import flash.text.TextFormatAlign;
import format.swf.exporters.ShapeCommandExporter;
import format.swf.tags.TagDefineEditText;
import format.swf.tags.TagDefineFont;
import format.swf.tags.TagDefineFont2;
import format.swf.SWFTimelineContainer;

import openfl.Assets;

#if (cpp || neko)
import openfl.text.AbstractFont;
#end


class DynamicText extends TextField {
	
	
	private static var registeredFonts = new Map <Int, Bool> ();
	
	public var offset:Matrix;
	
	private var data:SWFTimelineContainer;
	private var tag:TagDefineEditText;
	
	
	public function new (data:SWFTimelineContainer, tag:TagDefineEditText) {
		
		super ();
		
		var rect = tag.bounds.rect;
		
		offset = new Matrix (1, 0, 0, 1, rect.x, rect.y+1);
		//trace('offset = ' + offset.x + ',' + offset.y + ' - ' + rect.x + 'x' + rect.y);

		width = rect.width;
		height = rect.height;
		
		multiline = tag.multiline;
		wordWrap = tag.wordWrap;
		displayAsPassword = tag.password;
		border = tag.border;
		selectable = !tag.noSelect;
		
		var format = new TextFormat ();
		if (tag.hasTextColor) format.color = (tag.textColor & 0x00FFFFFF);
		format.size = (tag.fontHeight / 20);

		// commenting out font stuff had no effect
		if (tag.hasFont) {

			var font = data.getCharacter (tag.fontId);

			if (Std.is (font, TagDefineFont2)) {

				#if (cpp || neko)

				var fontName =  cast (font, TagDefineFont2).fontName;

				if (fontName.charCodeAt (fontName.length - 1) == 0) {

					fontName = fontName.substr (0, fontName.length - 1).split (" ").join ("");

				}

				var fonts = Font.enumerateFonts (false);
				var foundFont = false;

				for (font in fonts) {

					//trace('trying to find: ' + font.fontName + ' = ' + fontName);

					if (font.fontName == fontName) {

						foundFont = true;
						format.font = fontName;
						break;

					}

				}

				if (!foundFont) {
					trace('>>>>>FAILED >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>  enumerating FONT = ' + fontName);

					format.font = getFont (cast font, format.color);

				}

				#else

				format.font = cast (font, TagDefineFont2).fontName;

				#end

				embedFonts = true;

			}

		}
		// to here
		
		format.leftMargin = tag.leftMargin / 20;
		format.rightMargin = tag.rightMargin / 20;
		format.indent = tag.indent / 20;
		format.leading = (tag.leading / 20)-4;
		
		switch (tag.align) {
			
			case 0: format.align = TextFormatAlign.LEFT;
			case 1: format.align = TextFormatAlign.RIGHT;
			case 2: format.align = TextFormatAlign.CENTER;
			case 3: format.align = TextFormatAlign.JUSTIFY;
			
		}
		
		defaultTextFormat = format;
		
		if (tag.hasText) {
			
			#if (cpp || neko)
			
			var plain = new EReg ("</p>", "g").replace (tag.initialText, "\n");
			plain = new EReg ("<br>", "g").replace (tag.initialText, "\n");
			text = new EReg ("<.*?>", "g").replace (plain, "");
			
			#else
			
			if (tag.html) {
				
				htmlText = tag.initialText;
				
			} else {
				
				text = tag.initialText;
				
			}
			
			#end
			
		}
		
		autoSize = (tag.autoSize) ? TextFieldAutoSize.LEFT : TextFieldAutoSize.NONE;
		
	}
	
	
	#if (cpp || neko)
	
	private function getFont (font:TagDefineFont2, color:Int):String {
		
		if (!registeredFonts.exists (font.characterId)) {
			
			AbstractFont.registerFont (font.fontName, function (definition) { return new SWFFont (font, definition, color); });
			registeredFonts.set (font.characterId, true);
			
		}
		
		return font.fontName;
		
	}
	
	#end
	
	
}


#if (cpp || neko)


class SWFFont extends AbstractFont {
	
	
	private var bitmapData:Map <Int, BitmapData>;
	private var color:Int;
	private var font:TagDefineFont2;
	private var glyphInfo:Map <Int, GlyphInfo>;
	
	
	public function new (font:TagDefineFont2, definition:FontDefinition, color:Int) {
		
		this.font = font;
		this.color = color;
		
		// TODO: Allow dynamic change of color
		
		bitmapData = new Map <Int, BitmapData> ();
		glyphInfo = new Map <Int, GlyphInfo> ();
		
		var ascent = Math.round (font.ascent / (font.ascent + font.descent));
		var descent = Math.round (font.descent / (font.ascent + font.descent));
		
		super (definition.height, ascent, descent, false);
		
	}
	
	
	public override function getGlyphInfo (charCode:Int):GlyphInfo {
		
		if (!glyphInfo.exists (charCode)) {
			
			var index = -1;
			
			for (i in 0...font.codeTable.length) {
				
				if (font.codeTable[i] == charCode) {
					
					index = i;
					
				}
				
			}
			
			if (index > -1) {
				
				var scale = (height / 1024);
				var advance = Math.round (scale * font.fontAdvanceTable[index] * 0.05);
				var offsetY = Math.round (font.descent * scale * 0.05);
				
				glyphInfo.set (charCode, { width: height, height: height, advance: advance, offsetX: 0, offsetY: offsetY });
			
			} else {
				
				glyphInfo.set (charCode, { width: 0, height: 0, advance: 0, offsetX: 0, offsetY: 0 });
				
			}
			
		}
		
		return glyphInfo.get (charCode);
		
	}
	
	
	public override function renderGlyph (charCode:Int):BitmapData {

		if (!bitmapData.exists (charCode)) {
			
			var index = -1;
			
			for (i in 0...font.codeTable.length) {
				
				if (font.codeTable[i] == charCode) {
					
					index = i;
					
				}
				
			}
			
			if (index > -1) {
				
				var shape = new flash.display.Shape ();
				var handler = new ShapeCommandExporter (null);
				font.export (handler, index);
				
				shape.graphics.beginFill (color);
				
				var scale = (height / 1024);
				var offsetX = 0;
				var offsetY = (font.ascent - font.descent) * scale * 0.05;
				
				for (command in handler.commands) {
					
					switch (command.type) {
						
						//case BEGIN_FILL: shape.graphics.beginFill (0x0000FF, 1);
						//case END_FILL: shape.graphics.endFill ();
						case LINE_STYLE: 
							
							if (command.params.length > 0) {
								
								shape.graphics.lineStyle (command.params[0], command.params[1], command.params[2], command.params[3], command.params[4], command.params[5], command.params[6], command.params[7]);
								
							} else {
								
								shape.graphics.lineStyle ();
								
							}
							
						case MOVE_TO: shape.graphics.moveTo (command.params[0] * scale + offsetX, command.params[1] * scale + offsetY);
						case LINE_TO: shape.graphics.lineTo (command.params[0] * scale + offsetX, command.params[1] * scale + offsetY);
						case CURVE_TO: 
							
							shape.graphics.curveTo (command.params[0] * scale + offsetX, command.params[1] * scale + offsetY, command.params[2] * scale + offsetX, command.params[3] * scale + offsetY);
						
						default:
						
					}
					
				}
				
				//var bounds = shape.getBounds (shape);
				//var data = new BitmapData (Math.ceil (bounds.width + bounds.x), Math.ceil (bounds.height + bounds.y), true, 0x00000000);
				var data = new BitmapData (height, height, true, 0x00000000);
				data.draw (shape);
				
				var advance = Math.round (scale * font.fontAdvanceTable[index] * 0.05);
				
				bitmapData.set (charCode, data);
				
			} else {
				
				bitmapData.set (charCode, null);
				
			}
			
		}
		
		return bitmapData.get (charCode);
		
	}
	
	
}


#end