package format;


import flash.events.TimerEvent;
import format.swf.tags.TagDefineScalingGrid;
import flash.display.BitmapData;
import openfl.Assets;
import haxe.Timer;
import flash.display.BitmapData;
import flash.events.Event;
import flash.events.EventDispatcher;
import flash.utils.ByteArray;
import format.swf.instance.Bitmap;
import format.swf.instance.MovieClip;
import format.swf.instance.SimpleButton;
import format.swf.SWFRoot;
import format.swf.SWFTimelineContainer;
import format.swf.tags.TagDefineBits;
import format.swf.tags.TagDefineBitsJPEG2;
import format.swf.tags.TagDefineBitsLossless;
import format.swf.tags.TagDefineButton2;
import format.swf.tags.TagDefineSprite;
import format.swf.tags.TagSymbolClass;

#if !haxe3
typedef Map<String, T> = Hash<T>;
#end


class SWF extends EventDispatcher {
	

	public var data:SWFRoot;
	public static var instances = new Map<String, SWF> ();
	public static var parseABC:Bool = false;



	public var backgroundColor (default, null):Int;
	public var frameRate (default, null):Float;
	public var height (default, null):Int;
	public var symbols:Map <String, Int>;
	public var width (default, null):Int;
	public var scalingGrids:Map<Int, TagDefineScalingGrid>;

	private var complete:Bool;
	private var cachePath:String;

	
	public function new (bytes:ByteArray, cachePath:String = null) {
		
		super ();

		this.cachePath = cachePath;
		scalingGrids = new Map();
		//SWFTimelineContainer.AUTOBUILD_LAYERS = true;
		data = new SWFRoot (this, bytes);
		
		backgroundColor = data.backgroundColor;
		frameRate = data.frameRate;
		width = Std.int (data.frameSize.rect.width);
		height = Std.int (data.frameSize.rect.height);
		
		symbols = data.symbols;

		trace('loading xx ');		
		
		#if flash
		
		var allTags = 0;
		var loadedTags = 0;
		
		var handler = function (_) {
			
			loadedTags++;
			
			if (loadedTags >= allTags) {
				
				dispatchCompleteTimer();
				
			}
			
		}
		
		for (tag in data.tags) {
			
			if (Std.is (tag, TagDefineBits)) {
				
				allTags++;
				
				var bits:TagDefineBits = cast tag;
				bits.exportBitmapData (handler);
				
			} /*else if (Std.is (tag, TagDefineBitsLossless)) {
				
				allTags++;
				
				var bits:TagDefineBitsLossless = cast tag;
				bits.exportBitmapData (handler);
				
			}*/
			
		}
		
		if (allTags == 0) {
			dispatchCompleteTimer();
		}
		
		#else
		
		dispatchCompleteTimer();
		
		#end
		
	}

	private var tmr:flash.utils.Timer;
	inline private function dispatchCompleteTimer():Void {
		tmr = new flash.utils.Timer(1, 1);
		tmr.addEventListener(flash.events.TimerEvent.TIMER_COMPLETE, dispatchComplete);
		tmr.start();
	}
	
	private function dispatchComplete(e:flash.events.TimerEvent):Void 
	{
		complete = true;
		trace('removed timer listener');
		tmr.removeEventListener(flash.events.TimerEvent.TIMER_COMPLETE, dispatchComplete);
		tmr.stop();
		tmr = null;
		dispatchEvent (new Event (Event.COMPLETE));
	}
	
	
	public override function addEventListener (type:String, listener:Dynamic, useCapture:Bool = false, priority:Int = 0, useWeakReference:Bool = false):Void {
		
		super.addEventListener (type, listener, useCapture, priority, useWeakReference);
		
		if (complete) {
			
			dispatchEvent (new Event (Event.COMPLETE));
			
		}
		
	}
	
	
	public function createButton (className:String):SimpleButton {
		var symbol:Dynamic = null;
		var charId:Int;
			
		if (symbols.exists (className)) {
			charId = symbols.get (className);
			symbol = data.getCharacter (charId);
		}
		
		if (Std.is (symbol, TagDefineButton2)) {
			
			return new SimpleButton (data, cast symbol);
			
		}
		
		return null;
		
	}
	
	
	public function createMovieClip (className:String = ""):MovieClip {

		var symbol:Dynamic = null;
		var charId:Int;
		if (className == "") {
			
			symbol = data;
			
		} else {
			
			if (symbols.exists (className)) {
				
				charId = symbols.get (className);
				
				if (charId > 0) {
					symbol = data.getCharacter (charId);
				} else {
					symbol = data;
				}
				
			}
			
		}

		
		if (Std.is (symbol, SWFTimelineContainer)) {

			return new MovieClip (cast symbol);
			
		}
		
		return null;
		
	}
	
	
	public function getBitmapData (className:String):BitmapData {

		var symbol:Dynamic = null;
		
		if (className == "") {
			
			symbol = data;
			
		} else {
			
			if (symbols.exists (className)) {
				
				symbol = data.getCharacter (symbols.get (className));
				
			}
			
		}
		
		if (Std.is (symbol, TagDefineBits) || Std.is (symbol, TagDefineBitsLossless)) {
			
			var b = new Bitmap (data, cast symbol).bitmapData;
			return b;
			
		}
		
		return null;
		
	}


	public function getCachedBitmapData(id:Int):BitmapData
	{
		if(cachePath == null) return null;

		//try get it from cache first
		var path = cachePath + id + ".png";

		if(Assets.exists(path)) {

			return Assets.getBitmapData(path, true);

		}

		return null;
	}


	
	
	public function hasSymbol (className:String):Bool {
		
		return symbols.exists (className);
		//return streamPositions.exists (id);
		
	}	
	
	
}
