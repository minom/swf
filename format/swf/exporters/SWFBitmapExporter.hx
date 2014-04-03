package format.swf.exporters;


import Reflect;
import flash.geom.Rectangle;
import format.swf.tags.TagPlaceObject2;
import flash.geom.Point;
import Type;
import format.swf.instance.MovieClip;
import flash.display.BitmapData;
import flash.text.TextFormatAlign;
import format.swf.exporters.core.ShapeCommand;
import format.swf.instance.Bitmap;
import format.swf.lite.SWFLite;
import format.swf.lite.symbols.BitmapSymbol;
import format.swf.lite.symbols.DynamicTextSymbol;
import format.swf.lite.symbols.FontSymbol;
import format.swf.lite.symbols.ShapeSymbol;
import format.swf.lite.symbols.SpriteSymbol;
import format.swf.lite.symbols.StaticTextSymbol;
import format.swf.lite.symbols.SWFSymbol;
import format.swf.lite.timeline.Frame;
import format.swf.lite.timeline.FrameObject;
import format.swf.SWFTimelineContainer;
import format.swf.tags.IDefinitionTag;
import format.swf.tags.TagDefineBits;
import format.swf.tags.TagDefineBitsJPEG2;
import format.swf.tags.TagDefineBitsLossless;
import format.swf.tags.TagDefineButton;
import format.swf.tags.TagDefineEditText;
import format.swf.tags.TagDefineFont;
import format.swf.tags.TagDefineFont2;
import format.swf.tags.TagDefineFont4;
import format.swf.tags.TagDefineShape;
import format.swf.tags.TagDefineSprite;
import format.swf.tags.TagDefineText;
import format.swf.tags.TagPlaceObject;
import format.swf.tags.TagSymbolClass;
import format.swf.SWFRoot;


class SWFBitmapExporter {


	public var bitmaps:Map <Int, BitmapData>;
	private var data:SWFRoot;


	public function new (data:SWFRoot) {

		this.data = data;
		this.bitmaps = new Map <Int, BitmapData> ();

		//process everything that is on the stage
		processSprite (data, true);

		//process all symbols in library that are exported for action script
		for (tag in data.tags) {

			if (Std.is (tag, TagSymbolClass)) {

				for (symbol in cast (tag, TagSymbolClass).symbols) {

					processTag (cast data.getCharacter (symbol.tagId));

				}

			}

		}

	}


	private function processBitmap (tag:IDefinitionTag):Void {

		var bitmapData = new Bitmap (data, tag).bitmapData;

		if (bitmapData != null) {

//			bitmaps.set (tag.characterId, bitmapData);

		}

	}



	private function processShape (tag:TagDefineShape):Void {

		var handler = new ShapeCommandExporter (data);
		tag.export (handler);

		for (command in handler.commands) {

			if (command.type == CommandType.BEGIN_BITMAP_FILL) {

				processTag (cast data.getCharacter (command.params[0]));

			}

		}

	}


	private function processSprite (tag:SWFTimelineContainer, root:Bool = false):Void {

		for(frame in tag.frames) {

			for (object in frame.getObjectsSortedByDepth ()) {

				processTag (cast data.getCharacter (object.characterId));

			}
		}
	}


	private function processScale9 (tag:TagDefineSprite, root:Bool = false):Void {

		var bitmap = new MovieClip(tag);

		if(bitmap != null) {

			var bitmapData = bitmap.flatten();
			if(bitmapData != null) {

				bitmaps.set (tag.characterId, bitmapData);

			}

		}

	}


	private function processTag (tag:IDefinitionTag):Void {

		if (Std.is (tag, TagDefineSprite)) {

			if(data.getScalingGrid(tag.characterId) != null) {

				processScale9(cast tag);

			}

			processSprite (cast tag);

		} else if (Std.is (tag, TagDefineBits) || Std.is (tag, TagDefineBitsJPEG2) || Std.is (tag, TagDefineBitsLossless)) {

			processBitmap (tag);

		} else if (Std.is (tag, TagDefineShape)) {

			processShape (cast tag);

		}

	}


}