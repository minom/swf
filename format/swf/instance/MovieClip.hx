package format.swf.instance;


import Math;
import Math;
import format.swf.tags.TagPlaceObject3;
import haxe.CallStack;
import haxe.Timer;
import flash.display.Bitmap;
import flash.display.BitmapData;
import flash.display.DisplayObject;
import flash.display.FrameLabel;
import flash.display.Graphics;
import flash.display.Sprite;
import flash.geom.Matrix;
import flash.events.Event;
import flash.geom.Point;
import flash.geom.Rectangle;
import flash.Lib;
import format.swf.instance.MovieClip.ChildObject;
import format.swf.tags.TagDefineBits;
import format.swf.tags.TagDefineBitsLossless;
import format.swf.tags.TagDefineButton2;
import format.swf.tags.TagDefineEditText;
import format.swf.tags.TagDefineFont;
import format.swf.tags.TagDefineMorphShape;
import format.swf.tags.TagDefineMorphShape2;
import format.swf.tags.TagDefineShape;
import format.swf.tags.TagDefineSprite;
import format.swf.tags.TagDefineText;
import format.swf.tags.TagPlaceObject;
import format.swf.timeline.Frame;
import format.swf.timeline.FrameObject;


typedef ChildObject = {
	var object:DisplayObject;
	var frameObject:FrameObject;
}


class MovieClip extends flash.display.MovieClip {
	
	private static inline var FLATTEN_MARGIN:Float = 3;
	private static var clips:Array <MovieClip>;
	private static var initialized:Bool;
	
	private var data:TagDefineSprite;
	private var lastUpdate:Int;
	private var playing:Bool;
	
	private var objectPool:Map<Int, List<ChildObject>>;
	private var activeObjects:Array<ChildObject>;
	
	#if flash
	private var __currentFrame:Int;
	private var __currentFrameLabel:String;
	private var __totalFrames:Int;
	private var __currentLabel:String;
	//private var __currentLabels:Array<FrameLabel>;
	#end
	
	private var _scale9Grid:Rectangle;
	private var _flattened:BitmapData;
	private var _scale9ScaleX:Float = 1;
	private var _scale9ScaleY:Float = 1;

	public function new (data:TagDefineSprite) {

		super ();
		
		this.data = data;
		
		if (!initialized) {
			
			clips = new Array <MovieClip> ();
			initialized = true;
			
		}
		
		__currentFrame = 1;
		__totalFrames = data.frames.length;

		/*#if flash
		for (frame in data.frameLabels.keys ()) {

			__currentLabels.push (new FrameLabel (data.frameLabels.get (frame), frame + 1));

		}
		#end*/

		objectPool = new Map<Int, List<ChildObject>>();
		activeObjects = [];

		//set up scale9
		var grid = data.getScalingGrid(data.characterId);
		if(grid != null) {

			setScale9Grid(grid.splitter.rect.clone());

		}

		//draw the frames
		update();

		// TODO: Set ABCData here if needed
		if (__totalFrames > 1) play ();

	}

	
	
	public function flatten ():BitmapData {

		var bitmapData = data.swf.getCachedBitmapData(data.characterId);

		//load from the cache first
		if(bitmapData != null) {

			return bitmapData;

		}

		update();

		var margin = FLATTEN_MARGIN;
		var bounds = getBounds(this);
		var offset = getOffset();
		var width = Math.floor(bounds.width + margin*2);
		var height = Math.floor(bounds.height + margin*2);
		var left = offset.x - margin;
		var top = offset.y - margin;

		//draw it
		if (bounds != null && bounds.width > 0 && bounds.height > 0) {

			bitmapData = new BitmapData (width, height, true, 0x00000000);
			var matrix = new Matrix ();
			matrix.translate (-left, -top);
			bitmapData.draw (this, matrix, true);

		}


		return bitmapData;

	}


	
	
	public override function gotoAndPlay (frame:#if flash flash.utils.Object #else Dynamic #end, scene:String = null):Void {
		
		__currentFrame = getFrame (frame);
		update ();
		play ();
		
	}
	
	
	public override function gotoAndStop (frame:#if flash flash.utils.Object #else Dynamic #end, scene:String = null):Void {
		
		__currentFrame = getFrame (frame);
		update ();
		stop ();
		
	}
	
	
	public override function nextFrame ():Void {
		
		var next = __currentFrame + 1;
		
		if (next > __totalFrames) {
			
			next = __totalFrames;
			
		}
		
		gotoAndStop (next);
		
	}
	
	
	public override function play ():Void {
		
		if (!playing && __totalFrames > 1) {
			
			playing = true;
			clips.push (this);
			
			Lib.current.stage.removeEventListener (Event.ENTER_FRAME, stage_onEnterFrame);
			Lib.current.stage.addEventListener (Event.ENTER_FRAME, stage_onEnterFrame);
			
		}
		
	}


	public override function stop ():Void {

		if (playing) {

			playing = false;
			clips.remove (this);

			if (clips.length == 0) Lib.current.stage.removeEventListener (Event.ENTER_FRAME, stage_onEnterFrame);

		}

	}
	
	
	public override function prevFrame ():Void {
		
		var previous = __currentFrame - 1;
		
		if (previous < 1) {
			
			previous = 1;
			
		}
		
		gotoAndStop (previous);
		
	}

	
	private inline function renderFrame (index:Int):Void {

		var frame:Frame = data.frames[index];
		var sameCharIdList:List<ChildObject>;
		
		if (frame != null) {
			
			var frameObject:FrameObject = null;
			
			var newActiveObjects:Array<ChildObject> = [];
			
			// Check previously active objects (Maintain or remove)
			
			for (activeObject in activeObjects) {
				
				frameObject = frame.objects.get(activeObject.frameObject.depth);
				
				if (frameObject == null || frameObject.characterId != activeObject.frameObject.characterId) {
					// The The frameObject isn't the same as the active
					// Return object to pool
					
					sameCharIdList = objectPool.get(activeObject.frameObject.characterId);
					if (sameCharIdList == null) {
						sameCharIdList = new List<ChildObject>();
						objectPool.set(activeObject.frameObject.characterId, sameCharIdList);
					}
					sameCharIdList.push (activeObject);
					
					// Remove the object from the display list
					// todo - disconnect event handlers ?
					removeChild(activeObject.object);
				} else {
					newActiveObjects.push(activeObject);
				}
			}
			
			activeObjects = newActiveObjects;
			
			// Check possible new objects
			// For each FrameObject inside the frame, check if it already exists in the activeObjects array, then check in the Pool, and if it's not there, create the DisplayObject
			var displayObject:DisplayObject;
			var child:ChildObject;
			var mask:ChildObject = null;
			
			var activeIdx:Int;
			
			for (object in frame.getObjectsSortedByDepth ()) {
				child = null;
				activeIdx = activeObjects.length - 1;
				
				// Check if it's in the active objects
				if (activeIdx > -1) {
					
					while (activeIdx > -1 && (activeObjects[activeIdx].frameObject.characterId != object.characterId || ( activeObjects[activeIdx].frameObject.characterId == object.characterId && activeObjects[activeIdx].frameObject.depth != object.depth))) { 
						activeIdx--;
					}
					
				}
				
				if (activeIdx > -1) {
					
					// Object in the activeObjects Array, no need to create, just set the frameObject
					child = activeObjects[activeIdx];
					child.frameObject = object;
					displayObject = child.object;
					
				} else {
					
					// Not in the active objects, search in the Pool (For each char ID there's a list of ChildObjects, because the same symbol may be instantiated more than once)
					
					sameCharIdList = objectPool.get(object.characterId);
					if (sameCharIdList != null && !sameCharIdList.isEmpty()) {
						
						// Object already created and in the pool
						
						child = sameCharIdList.pop();
						child.frameObject = object;
						activeObjects.push(child);
						
						//if (sameCharIdList.isEmpty()) objectPool.remove(object.characterId); // No need to remove the list, just leave it empty
						
						displayObject = child.object;
						
					} else {
						
						// We have to create it
						displayObject = getDisplayObject(object.characterId);
						
						if (displayObject != null) {
							activeObjects.push( child = { object:displayObject, frameObject:object } );
						}
						
					}
				}
				
				if (displayObject != null) {
					
					placeObject (displayObject, object);
					
					if (mask != null) {
	
						if (mask.frameObject.clipDepth < object.depth) {
	
							mask = null;
	
						} else {
	
							displayObject.mask = mask.object;
						
						}
					} else {
	
						displayObject.mask = null;
	
					}
					
					if (object.clipDepth != 0 #if neko && object.clipDepth != null #end) {
	
						mask = child;
						displayObject.visible = false;
	
					}
					
					addChild(displayObject);
				}
			}
		}
	}


	private inline function placeObject (displayObject:DisplayObject, frameObject:FrameObject):Void {

		var firstTag:TagPlaceObject = cast data.tags [frameObject.placedAtIndex];
		var lastTag:TagPlaceObject = null;

		if (frameObject.lastModifiedAtIndex > 0) {

			lastTag = cast data.tags [frameObject.lastModifiedAtIndex];

		}

		if (lastTag != null && lastTag.hasName) {

			displayObject.name = lastTag.instanceName;

		} else if (firstTag.hasName) {

			displayObject.name = firstTag.instanceName;

		}

		var oldScaleX:Float = displayObject.scaleX;
		var oldScaleY:Float = displayObject.scaleY;

		var sx:Float;
		var sy:Float;

		if (lastTag != null && lastTag.hasMatrix) {

			var matrix = lastTag.matrix.matrix;
			matrix.tx *= 1 / 20;
			matrix.ty *= 1 / 20;

			if (Std.is (displayObject, DynamicText)) {

				var offset = cast (displayObject, DynamicText).offset.clone ();
				offset.concat (matrix);
				matrix = offset;

			}

			displayObject.transform.matrix = matrix;

		} else if (firstTag.hasMatrix) {

			var matrix = firstTag.matrix.matrix;
			matrix.tx *= 1 / 20;
			matrix.ty *= 1 / 20;

			if (Std.is (displayObject, DynamicText)) {

				var offset = cast (displayObject, DynamicText).offset.clone ();
				offset.concat (matrix);
				matrix = offset;

			}


			displayObject.transform.matrix = matrix;

		}


		if (Std.is(displayObject, MovieClip)) {
			var mc:MovieClip = cast displayObject;
			if (mc._scale9Grid != null && (mc.transform.matrix.a != oldScaleX || mc.transform.matrix.d != oldScaleY)) {

				mc._scale9ScaleX = mc.transform.matrix.a;
				mc._scale9ScaleY = mc.transform.matrix.d;

				var mt:Matrix = mc.transform.matrix;

				mt.a = 1;
				mt.d = 1;

				mc.transform.matrix = mt;
				mc.drawScale9Grid();
			}
		}



		if (lastTag != null && lastTag.hasColorTransform) {

			displayObject.transform.colorTransform = lastTag.colorTransform.colorTransform;

		} else if (firstTag.hasColorTransform) {

			displayObject.transform.colorTransform = firstTag.colorTransform.colorTransform;

		}

		if (lastTag != null && lastTag.hasFilterList) {

			var filters = [];

			for (i in 0...lastTag.surfaceFilterList.length) {

				filters[i] = lastTag.surfaceFilterList[i].filter;

			}

			displayObject.filters = filters;

		} else if (firstTag.hasFilterList) {

			var filters = [];

			for (i in 0...firstTag.surfaceFilterList.length) {

				filters[i] = firstTag.surfaceFilterList[i].filter;

			}

			displayObject.filters = filters;

		}


		if (Std.is(displayObject, MorphShape)) {

			if (lastTag != null) cast(displayObject, MorphShape).render(lastTag.ratio);

		}

	}

	
	private inline function getDisplayObject(charId:Int):DisplayObject {
		
		var displayObject:DisplayObject = null;
		var symbol = data.getCharacter (charId);

		if (Std.is (symbol, TagDefineSprite)) {

			displayObject = new MovieClip (cast symbol);

		} else if (Std.is (symbol, TagDefineBitsLossless) || Std.is (symbol, TagDefineBits)) {
			
			displayObject = new Bitmap (cast symbol);

		} else if (Std.is (symbol, TagDefineShape)) {
			
			displayObject = new Shape (data, cast symbol);

		} else if (Std.is (symbol, TagDefineText)) {
			
			displayObject = new StaticText (data, cast symbol);

		} else if (Std.is (symbol, TagDefineEditText)) {
			
			displayObject = new DynamicText (data, cast symbol);

		} else if (Std.is (symbol, TagDefineButton2)) {
			
			displayObject = new SimpleButton(data, cast symbol);

		} else if (Std.is (symbol, TagDefineMorphShape)) {
			
			displayObject = new MorphShape(data, cast symbol);

		} else {
			
			//trace("Warning: No SWF Support for " + Type.getClassName(Type.getClass(symbol)));
			
		}
		
		return displayObject;
	}
	
	
	private function update ():Void {

		if(_scale9Grid != null) return;


		if (__currentFrame != lastUpdate) {
			
			var frameIndex = __currentFrame - 1;
			
			if (frameIndex > -1) {
				
				renderFrame (frameIndex);
				
			}

			var frame = data.frames[frameIndex];
			
			#if flash
			__currentFrameLabel = frame.label;

			if (frameIndex == 0 || frame.label != null) {

				__currentLabel = frame.label;

			}
			#end
			
		}

		
		lastUpdate = __currentFrame;
		
	}



	private function drawScale9Grid():Void {

		if(_flattened == null) return;

		var bitmap = _flattened;
		var drawWidth = _flattened.width * _scale9ScaleX;
		var drawHeight = _flattened.height* _scale9ScaleY;
		var scale9Rect = _scale9Grid;
		var offset = getOffset();

		//align
		offset.x += FLATTEN_MARGIN;
		offset.y += FLATTEN_MARGIN;

		//precompute some helper variables
		var matrix = new Matrix();
		var cols = [0, scale9Rect.left, scale9Rect.right, bitmap.width];
		var rows = [0, scale9Rect.top, scale9Rect.bottom, bitmap.height];
		var outerWidth = bitmap.width - (cols[2] - cols[1]);
		var outerHeight = bitmap.height - (rows[2] - rows[1]);
		var innerScaleX = (drawWidth - outerWidth) / (bitmap.width - outerWidth);
		var innerScaleY = (drawHeight - outerHeight) / (bitmap.height - outerHeight);
		var scaleX = drawWidth / bitmap.width;
		var scaleY = drawHeight / bitmap.height;
		var dx = offset.x * scaleX;
		var dy = offset.y * scaleY;
		var w = 0.0;
		var h = 0.0;

		//clear previous scale9 drawing
		graphics.clear();

		//loop through and draw each section of the scale9Grid
		for(row in 0...3) {
			for(col in 0...3) {

				var sourceX = cols[col];
				var sourceY = rows[row];
				w = cols[col+1] - cols[col];
				h = rows[row+1] - rows[row];

				//this makes sure the bitmap is drawn in the right spot to be drawn
				matrix.identity();
				matrix.translate(dx-sourceX, dy-sourceY);

				//scale the middle section
				if(row == 1) {

					h *= innerScaleY;
					matrix.translate(0, sourceY - dy); //undo the previous translation
					matrix.scale(1, innerScaleY); //scale it to the right size
					matrix.translate(0, dy - sourceY * innerScaleY); //move it so that the middle section is being drawn

				}

				if(col == 1) {

					w *= innerScaleX;
					matrix.translate(sourceX - dx, 0); //undo the previous translation
					matrix.scale(innerScaleX, 1); //scale it to the right size
					matrix.translate(dx - sourceX * innerScaleX, 0); //move it so that the middle section is being drawn

				}

				//now draw it
				graphics.beginBitmapFill(bitmap, matrix, false, true);
				graphics.drawRect(Math.floor(dx), Math.floor(dy), Math.ceil(w), Math.ceil(h));
				graphics.endFill();
				dx += w;

			}

			dx = offset.x * scaleX;
			dy += h;

		}
	}


	private inline function getOffset():Point
	{
		var offset = new Point();
		offset.x = Math.POSITIVE_INFINITY;
		offset.y = Math.POSITIVE_INFINITY;

		for(frame in data.frames){
			for (object in frame.objects) {

				var s = data.getCharacter (object.characterId);
				if(Std.is(s, TagDefineShape)) {

					var shape:TagDefineShape = cast s;
					var rect = shape.shapeBounds.rect;
					offset.x = Math.min(rect.x, offset.x);
					offset.y = Math.min(rect.y, offset.y);

				}
			}
		}

		return offset;
	}


	private inline function applyTween (start:Float, end:Float, ratio:Float):Float {

		return start + ((end - start) * ratio);

	}


	private function enterFrame ():Void {

		if (lastUpdate == __currentFrame) {

			__currentFrame ++;

			if (__currentFrame > __totalFrames) {

				__currentFrame = 1;

			}

		}

		update ();

	}


	private function removeAllChildren():Void {

		for (i in 0...numChildren) {

			var child = getChildAt (0);

			if (Std.is (child, MovieClip)) {

				untyped child.stop ();

			}

			removeChildAt (0);

		}

		stop();
	}


	private function getFrame (frame:Dynamic):Int {

		var value = 1;

		if (Std.is (frame, Int)) {

			value = cast frame;
			if (value < 1) value = 1;
			if (value > __totalFrames) value = __totalFrames;

		} else if (Std.is (frame, String)) {

			if (data.frameIndexes.exists(cast frame))
				value = data.frameIndexes.get(cast frame);
			else
				value = 1;
		}

		return value;

	}
	
	
	// Get & Set Methods
	#if flash
	@:getter public function get_currentFrame():Int {
		
		return __currentFrame;
		
	}
	
	
	@:getter public function get___totalFrames():Int {
		
		return __totalFrames;
		
	}
	#end
	
	
	// Overriding properties for scale9Grid to work
	@:setter(scaleX)
	#if (!flash) override #end private function set_scaleX(val:Float):#if (!flash) Float #else Void #end
	{
		if (_scale9Grid == null) super.scaleX = val;
		else {
			super.scaleX = 1;
			_scale9ScaleX = val;
			drawScale9Grid();
		}
		#if (!flash) return val; #end
	}


	@:getter(scaleX)
	#if (!flash) override #end private function get_scaleX():Float {
		if (_scale9Grid == null) return super.scaleX;
		else return _scale9ScaleX;
	}


	@:setter(scaleY)
	#if (!flash) override #end private function set_scaleY(val:Float):#if (!flash) Float #else Void #end
	{
		if (_scale9Grid == null) super.scaleY = val;
		else {
			super.scaleY = 1;
			_scale9ScaleY = val;
			drawScale9Grid();
		}
		#if (!flash) return val; #end
	}


	@:getter(scaleY)
	#if (!flash) override #end private function get_scaleY():Float {
		if (_scale9Grid == null) return super.scaleY;
		else return _scale9ScaleY;
	}
	
	
	@:setter(width)
	#if (!flash) override #end private function set_width(val:Float):#if (!flash) Float #else Void #end
	{
		if (_scale9Grid == null) super.width = val;
		else {
			_scale9ScaleX = val / _flattened.width;
			drawScale9Grid();
		}
		#if (!flash) return val; #end
	}


	@:setter(height)
	#if (!flash) override #end private function set_height(val:Float):#if (!flash) Float #else Void #end
	{
		if (_scale9Grid == null) super.height = val;
		else {
			_scale9ScaleY = val / _flattened.height;
			drawScale9Grid();
		}
		#if (!flash) return val; #end
	}


	private function setScale9Grid(value:Rectangle):Void {

		if (value != null) {

			_flattened = flatten();
			_scale9Grid = value;
			removeAllChildren();
			drawScale9Grid();

		} else {

			_scale9Grid = null;
			lastUpdate = -1;
			update ();

		}
	}
	
	
	// Event Handlers

	private static function stage_onEnterFrame (event:Event):Void {
		
		for (clip in clips) {
			
			clip.enterFrame ();
			
		}
		
	}
	
	
}
