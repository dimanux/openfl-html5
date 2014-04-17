package flash.display;


import flash.events.Event;
import flash.events.EventPhase;
import flash.events.KeyboardEvent;
import flash.events.MouseEvent;
import flash.events.TouchEvent;
import flash.geom.Matrix;
import flash.geom.Point;
import flash.ui.Keyboard;
import flash.ui.KeyLocation;
import js.html.CanvasElement;
import js.html.CanvasRenderingContext2D;
import js.html.DivElement;
import js.html.Element;
import js.html.HtmlElement;
import js.Browser;


@:access(flash.events.Event)
class Stage extends Sprite {
	
	
	public var align:StageAlign;
	public var color (get, set):Int;
	public var displayState:StageDisplayState;
	public var focus:InteractiveObject;
	public var frameRate:Float;
	public var quality:StageQuality;
	public var stageFocusRect:Bool;
	public var scaleMode:StageScaleMode;
	public var stageHeight (default, null):Int;
	public var stageWidth (default, null):Int;
	
	//private var __canvas:CanvasElement;
	private var __clearBeforeRender:Bool;
	private var __color:Int;
	private var __colorString:String;
	private var __context:CanvasRenderingContext2D;
	private var __cursor:String;
	private var __div:DivElement;
	private var __element:HtmlElement;
	private var __eventQueue:Array<js.html.Event>;
	private var __fullscreen:Bool;
	private var __invalidated:Bool;
	private var __mouseX:Float = 0;
	private var __mouseY:Float = 0;
	private var __originalWidth:Int;
	private var __originalHeight:Int;
	private var __renderSession:RenderSession;
	private var __stack:Array<DisplayObject>;
	#if stats
	private var __stats:Dynamic;
	#end
	private var __transparent:Bool;
	
	
	
	public function new (width:Int, height:Int, element:HtmlElement = null, color:Int = 0xFFFFFF) {
		
		super ();
		
		this.__element = element;
		this.color = color;
		
		__mouseX = 0;
		__mouseY = 0;
		
		#if !dom
		
		__canvas = cast Browser.document.createElement ("canvas");
		__canvas.setAttribute ("moz-opaque", "true");
		
		__context = untyped __js__ ('this.__canvas.getContext ("2d", { alpha: false })');
		//untyped (__context).mozImageSmoothingEnabled = false;
		//untyped (__context).webkitImageSmoothingEnabled = false;
		//__context.imageSmoothingEnabled = false;
		
		var style = __canvas.style;
		style.setProperty ("-webkit-transform", "translateZ(0)", null);
		style.setProperty ("transform", "translateZ(0)", null);
		
		#else
		
		__div = cast Browser.document.createElement ("div");
		
		var style = __div.style;
		style.backgroundColor = __colorString;
		style.setProperty ("-webkit-transform", "translate3D(0,0,0)", null);
		style.setProperty ("transform", "translate3D(0,0,0)", null);
		//style.setProperty ("-webkit-transform-style", "preserve-3d", null);
		//style.setProperty ("transform-style", "preserve-3d", null);
		style.position = "relative";
		style.overflow = "hidden";
		style.setProperty ("-webkit-user-select", "none", null);
		style.setProperty ("-moz-user-select", "none", null);
		style.setProperty ("-ms-user-select", "none", null);
		style.setProperty ("-o-user-select", "none", null);
		
		#end
		
		__originalWidth = width;
		__originalHeight = height;
		
		if (width == 0 && height == 0) {
			
			if (element != null) {
				
				width = element.clientWidth;
				height = element.clientHeight;
				
			} else {
				
				width = Browser.window.innerWidth;
				height = Browser.window.innerHeight;
				
			}
			
			__fullscreen = true;
			
		}
		
		stageWidth = width;
		stageHeight = height;
		
		if (__canvas != null) {
			
			__canvas.width = width;
			__canvas.height = height;
			
		} else {
			
			__div.style.width = width + "px";
			__div.style.height = height + "px";
			
		}
		
		__resize ();
		Browser.window.addEventListener ("resize", window_onResize);
		Browser.window.addEventListener ("focus", window_onFocus);
		Browser.window.addEventListener ("blur", window_onBlur);
		
		if (element != null) {
			
			if (__canvas != null) {
				
				element.appendChild (__canvas);
				
			} else {
				
				element.appendChild (__div);
				
			}
			
		}
		
		this.stage = this;
		this.parent = this;
		
		quality = StageQuality.HIGH;
		__clearBeforeRender = true;
		__eventQueue = [];
		__stack = [];
		
		__renderSession = new RenderSession ();
		__renderSession.context = __context;
		__renderSession.roundPixels = true;
		
		if (__div != null) {
			
			__renderSession.element = __div;
			var prefix = untyped __js__ ("(function () {
			  var styles = window.getComputedStyle(document.documentElement, ''),
			    pre = (Array.prototype.slice
			      .call(styles)
			      .join('') 
			      .match(/-(moz|webkit|ms)-/) || (styles.OLink === '' && ['', 'o'])
			    )[1],
			    dom = ('WebKit|Moz|MS|O').match(new RegExp('(' + pre + ')', 'i'))[1];
			  return {
			    dom: dom,
			    lowercase: pre,
			    css: '-' + pre + '-',
			    js: pre[0].toUpperCase() + pre.substr(1)
			  };
			})")();
			__renderSession.vendorPrefix = prefix.lowercase;
			__renderSession.transformProperty = (prefix.lowercase == "webkit") ? "-webkit-transform" : "transform";
			__renderSession.transformOriginProperty = (prefix.lowercase == "webkit") ? "-webkit-transform-origin" : "transform-origin";
			
		}
		
		#if stats
		__stats = untyped __js__("new Stats ()");
		__stats.domElement.style.position = "absolute";
		__stats.domElement.style.top = "0px";
		Browser.document.body.appendChild (__stats.domElement);
		#end
		
		var windowEvents = [ "keydown", "keyup" ];
		var elementEvents = [ "touchstart", "touchmove", "touchend", "mousedown", "mousemove", "mouseup", "click", "dblclick" ];
		
		for (event in windowEvents) {
			
			Browser.window.addEventListener (event, __queueEvent, false);
			
		}
		
		if (__canvas != null) {
			
			for (event in elementEvents) {
				
				__canvas.addEventListener (event, __queueEvent, true);
				
			}
			
		} else {
			
			for (event in elementEvents) {
				
				__div.addEventListener (event, __queueEvent, true);
				
			}
			
		}
		
		Browser.window.requestAnimationFrame (cast __render);
		
	}
	
	
	public override function globalToLocal (pos:Point):Point {
		
		return pos;
		
	}
	
	
	public function invalidate ():Void {
		
		__invalidated = true;
		
	}
	
	
	public override function localToGlobal (pos:Point):Point {
		
		return pos;
		
	}
	
	
	private function __fireEvent (event:Event, stack:Array<DisplayObject>):Void {
		
		var l = stack.length;
		
		if (l > 0) {
			
			// First, the "capture" phase ...
			event.eventPhase = EventPhase.CAPTURING_PHASE;
			stack.reverse ();
			event.target = stack[0];
			
			for (obj in stack) {
				
				event.currentTarget = obj;
				obj.dispatchEvent (event);
				
				if (event.__isCancelled) {
					
					return;
					
				}
				
			}
			
		}
		
		// Next, the "target"
		event.eventPhase = EventPhase.AT_TARGET;
		event.currentTarget = this;
		dispatchEvent (event);
		
		if (event.__isCancelled) {
			
			return;
			
		}
		
		// Last, the "bubbles" phase
		if (event.bubbles) {
			
			event.eventPhase = EventPhase.BUBBLING_PHASE;
			stack.reverse ();
			
			for (obj in stack) {
				
				event.currentTarget = obj;
				obj.dispatchEvent (event);
				
				if (event.__isCancelled) {
					
					return;
					
				}
				
			}
			
		}
		
	}
	
	
	private function __queueEvent (event:js.html.Event):Void {
		
		__eventQueue.push (event);
		
	}
	
	
	private function __render ():Void {
		
		#if stats
		__stats.begin ();
		#end
		
		//__renderable = true;
		//__update ();
		
		for (event in __eventQueue) {
			
			switch (event.type) {
				
				case "keydown", "keyup": window_onKey (cast event);
				case "touchstart", "touchend", "touchmove": element_onTouch (cast event);
				case "mousedown", "mouseup", "mousemove", "click", "dblclick": element_onMouse (cast event);
				default:
				
			}
			
		}
		
		untyped __eventQueue.length = 0;
		
		__broadcast (new Event (Event.ENTER_FRAME));
		
		if (__invalidated) {
			
			__invalidated = false;
			__broadcast (new Event (Event.RENDER));
			
		}
		
		__renderable = true;
		__update ();
		
		if (__canvas != null) {
			
			if (stageWidth != __canvas.width || stageHeight != __canvas.height) {
				
				__canvas.width = stageWidth;
				__canvas.height = stageHeight;
				
			}
			
			__context.setTransform (1, 0, 0, 1, 0, 0);
			__context.globalAlpha = 1;
			
			if (!__transparent && __clearBeforeRender) {
				
				__context.fillStyle = __colorString;
				__context.fillRect (0, 0, stageWidth, stageHeight);
				
			} else if (__transparent && __clearBeforeRender) {
				
				__context.clearRect (0, 0, stageWidth, stageHeight);
				
			}
			
			__renderCanvas (__renderSession);
			
		} else {
			
			__renderSession.z = 1;
			__renderDOM (__renderSession);
			
		}
		
		/*// run interaction!
		if(stage.interactive) {
			
			//need to add some events!
			if(!stage._interactiveEventsAdded) {
				
				stage._interactiveEventsAdded = true;
				stage.interactionManager.setTarget(this);
				
			}
			
		}

		// remove frame updates..
		if(PIXI.Texture.frameUpdates.length > 0) {
			
			PIXI.Texture.frameUpdates.length = 0;
			
		}*/
		
		#if stats
		__stats.end ();
		#end
		
		Browser.window.requestAnimationFrame (cast __render);
		
	}
	
	
	private function __resize ():Void {
		
		if (__element != null && __div == null) {
			
			if (__fullscreen) {
				
				stageWidth = __element.clientWidth;
				stageHeight = __element.clientHeight;
				
				if (__canvas != null) {
					
					__canvas.width = stageWidth;
					__canvas.height = stageHeight;
					
				} else {
					
					__div.style.width = stageWidth + "px";
					__div.style.height = stageHeight + "px";
					
				}
				
			} else {
				
				var scaleX = __element.clientWidth / __originalWidth;
				var scaleY = __element.clientHeight / __originalHeight;
				
				var currentRatio = scaleX / scaleY;
				var targetRatio = Math.min (scaleX, scaleY);
				
				if (__canvas != null) {
					
					__canvas.style.width = __originalWidth * targetRatio + "px";
					__canvas.style.height = __originalHeight * targetRatio + "px";
					__canvas.style.marginLeft = ((__element.clientWidth - (__originalWidth * targetRatio)) / 2) + "px";
					__canvas.style.marginTop = ((__element.clientHeight - (__originalHeight * targetRatio)) / 2) + "px";
					
				} else {
					
					__div.style.width = __originalWidth * targetRatio + "px";
					__div.style.height = __originalHeight * targetRatio + "px";
					__div.style.marginLeft = ((__element.clientWidth - (__originalWidth * targetRatio)) / 2) + "px";
					__div.style.marginTop = ((__element.clientHeight - (__originalHeight * targetRatio)) / 2) + "px";
					
				}
				
			}
			
		}
		
	}
	
	
	private function __setCursor (cursor:String):Void {
		
		if (__cursor != cursor) {
			
			__cursor = cursor;
			
			if (__canvas != null) {
				
				__canvas.style.cursor = cursor;
				
			} else {
				
				__div.style.cursor = cursor;
				
			}
			
		}
		
	}
	
	
	/*public override function __update ():Void {
		
		super.__update ();
		
		for (event in __eventQueue) {
			
			switch (event.type) {
				
				case "keydown", "keyup": window_onKey (cast event);
				case "touchstart", "touchend", "touchmove": canvas_onTouch (cast event);
				case "mousedown", "mouseup", "mousemove", "click", "dblclick": canvas_onMouse (cast event);
				default:
				
			}
			
		}
		
		untyped __eventQueue.length = 0;
		
	}*/
	
	
	
	
	// Get & Set Methods
	
	
	
	
	private override function get_mouseX ():Float {
		
		return __mouseX;
		
	}
	
	
	private override function get_mouseY ():Float {
		
		return __mouseY;
		
	}
	
	
	
	
	// Event Handlers
	
	
	
	
	private function element_onTouch (event:js.html.TouchEvent):Void {
		
		event.preventDefault ();
		
		var rect;
		
		if (__canvas != null) {
			
			rect = __canvas.getBoundingClientRect ();
			
		} else {
			
			rect = __div.getBoundingClientRect ();
			
		}
		
		var touch = event.changedTouches[0];
		var point = new Point (touch.pageX - rect.left, touch.pageY - rect.top);
		
		__mouseX = point.x;
		__mouseY = point.y;
		
		__stack = [];
		
		var type = null;
		var mouseType = null;
		
		switch (event.type) {
			
			case "touchstart":
				
				type = TouchEvent.TOUCH_BEGIN;
				mouseType = MouseEvent.MOUSE_DOWN;
			
			case "touchmove":
				
				type = TouchEvent.TOUCH_MOVE;
				mouseType = MouseEvent.MOUSE_MOVE;
			
			case "touchend":
				
				type = TouchEvent.TOUCH_END;
				mouseType = MouseEvent.MOUSE_UP;
			
			default:
			
		}
		
		if (__hitTest (mouseX, mouseY, false, __stack, true)) {
			
			var target = __stack[__stack.length - 1];
			var localPoint = target.globalToLocal (point);
			
			var touchEvent = TouchEvent.__create (type, event, touch, localPoint, cast target);
			touchEvent.touchPointID = touch.identifier;
			//touchEvent.isPrimaryTouchPoint = isPrimaryTouchPoint;
			touchEvent.isPrimaryTouchPoint = true;
			
			__fireEvent (touchEvent, __stack);
			
			var mouseEvent = MouseEvent.__create (mouseType, cast event, localPoint, cast target);
			if (type != TouchEvent.TOUCH_END)
				mouseEvent.buttonDown = true;
			__fireEvent (mouseEvent, __stack);
			
		} else {
			
			var touchEvent = TouchEvent.__create (type, event, touch, point, this);
			touchEvent.touchPointID = touch.identifier;
			//touchEvent.isPrimaryTouchPoint = isPrimaryTouchPoint;
			touchEvent.isPrimaryTouchPoint = true;
			
			__fireEvent (touchEvent, [ this ]);
			
			var mouseEvent = MouseEvent.__create (mouseType, cast event, point, this);
			if (type != TouchEvent.TOUCH_END)
				mouseEvent.buttonDown = true;
			__fireEvent (mouseEvent, [ this ]);
			
		}
		
		/*case "touchstart":
				
				var evt:js.html.TouchEvent = cast evt;
				evt.preventDefault ();
				var touchInfo = new TouchInfo ();
				__touchInfo[evt.changedTouches[0].identifier] = touchInfo;
				__onTouch (evt, evt.changedTouches[0], TouchEvent.TOUCH_BEGIN, touchInfo, false);
			
			case "touchmove":
				
				var evt:js.html.TouchEvent = cast evt;
				evt.preventDefault ();
				var touchInfo = __touchInfo[evt.changedTouches[0].identifier];
				__onTouch (evt, evt.changedTouches[0], TouchEvent.TOUCH_MOVE, touchInfo, true);
			
			case "touchend":
				
				var evt:js.html.TouchEvent = cast evt;
				evt.preventDefault ();
				var touchInfo = __touchInfo[evt.changedTouches[0].identifier];
				__onTouch (evt, evt.changedTouches[0], TouchEvent.TOUCH_END, touchInfo, true);
				__touchInfo[evt.changedTouches[0].identifier] = null;
				
				
				var rect:Dynamic = untyped Lib.mMe.__scr.getBoundingClientRect ();
		var point : Point = untyped new Point (touch.pageX - rect.left, touch.pageY - rect.top);
		var obj = __getObjectUnderPoint (point);
		
		// used in drag implementation
		_mouseX = point.x;
		_mouseY = point.y;
		
		var stack = new Array<InteractiveObject> ();
		if (obj != null) obj.__getInteractiveObjectStack (stack);
		
		if (stack.length > 0) {
			
			//var obj = stack[0];
			
			stack.reverse ();
			var local = obj.globalToLocal (point);
			var evt = TouchEvent.__create (type, event, touch, local, cast obj);
			
			evt.touchPointID = touch.identifier;
			evt.isPrimaryTouchPoint = isPrimaryTouchPoint;
			
			__checkInOuts (evt, stack, touchInfo);
			obj.__fireEvent (evt);
			
			var mouseType = switch (type) {
				
				case TouchEvent.TOUCH_BEGIN: MouseEvent.MOUSE_DOWN;
				case TouchEvent.TOUCH_END: MouseEvent.MOUSE_UP;
				default: 
					
					if (__dragObject != null) {
						
						__drag (point);
						
					}
					
					MouseEvent.MOUSE_MOVE;
				
			}
			
			obj.__fireEvent (MouseEvent.__create (mouseType, cast evt, local, cast obj));
			
		} else {
			
			var evt = TouchEvent.__create (type, event, touch, point, null);
			evt.touchPointID = touch.identifier;
			evt.isPrimaryTouchPoint = isPrimaryTouchPoint;
			__checkInOuts (evt, stack, touchInfo);
			
		}*/
		
	}
	
	
	private function element_onMouse (event:js.html.MouseEvent):Void {
		
		var rect;
		
		if (__canvas != null) {
			
			rect = __canvas.getBoundingClientRect ();
			__mouseX = (event.clientX - rect.left) * (__canvas.width / rect.width);
			__mouseY = (event.clientY - rect.top) * (__canvas.height / rect.height);
			
		} else {
			
			rect = __div.getBoundingClientRect ();
			//__mouseX = (event.clientX - rect.left) * (__div.style.width / rect.width);
			__mouseX = (event.clientX - rect.left) * (rect.width);
			//__mouseY = (event.clientY - rect.top) * (__div.style.height / rect.height);
			__mouseY = (event.clientY - rect.top) * (rect.height);
			
		}
		
		__stack = [];
		
		var type = switch (event.type) {
			
			case "mousedown": MouseEvent.MOUSE_DOWN;
			case "mouseup": MouseEvent.MOUSE_UP;
			case "mousemove": MouseEvent.MOUSE_MOVE;
			case "click": MouseEvent.CLICK;
			case "dblclick": MouseEvent.DOUBLE_CLICK;
			default: null;
			
		}
		
		if (__hitTest (mouseX, mouseY, false, __stack, true)) {
			
			var target = __stack[__stack.length - 1];
			__setCursor (untyped (target).buttonMode ? "pointer" : "default");
			__fireEvent (MouseEvent.__create (type, event, target.globalToLocal (new Point (mouseX, mouseY)), cast target), __stack);
			
		} else {
			
			__setCursor (buttonMode ? "pointer" : "default");
			__fireEvent (MouseEvent.__create (type, event, new Point (mouseX, mouseY), this), [ this ]);
			
		}
		
		
		/*case "mousemove":
				
				__onMouse (cast evt, MouseEvent.MOUSE_MOVE);
			
			case "mousedown":
				
				__onMouse (cast evt, MouseEvent.MOUSE_DOWN);
			
			case "mouseup":
				
				__onMouse (cast evt, MouseEvent.MOUSE_UP);
				
				
				
				var rect:Dynamic = untyped Lib.mMe.__scr.getBoundingClientRect ();
		var point:Point = untyped new Point (event.clientX - rect.left, event.clientY - rect.top);
		
		if (__dragObject != null) {
			
			__drag (point);
			
		}
		
		var obj = __getObjectUnderPoint (point);
		
		// used in drag implementation
		_mouseX = point.x;
		_mouseY = point.y;
		
		var stack = new Array<InteractiveObject> ();
		if (obj != null) obj.__getInteractiveObjectStack (stack);
		
		if (stack.length > 0) {
			
			//var global = obj.localToGlobal(point);
			//var obj = stack[0];
			
			stack.reverse ();
			var local = obj.globalToLocal (point);
			var evt = MouseEvent.__create (type, event, local, cast obj);
			
			__checkInOuts (evt, stack);
			
			// MOUSE_DOWN brings focus to the clicked object, and takes it
			// away from any currently focused object
			if (type == MouseEvent.MOUSE_DOWN) {
				
				__onFocus (stack[stack.length - 1]);
				
			}
			
			obj.__fireEvent (evt);
			
		} else {
			
			var evt = MouseEvent.__create (type, event, point, null);
			__checkInOuts (evt, stack);
			
		}*/
		
	}
	
	
	private function window_onKey (event:js.html.KeyboardEvent):Void {
		
		var keyCode = (event.keyCode != null ? event.keyCode : event.which);
		keyCode = Keyboard.__convertMozillaCode (keyCode);
		
		var keyLocation = KeyLocation.STANDARD;
		
		if (untyped (event).location != null) {
			
			keyLocation = cast (untyped (event).location, KeyLocation);
			
		} else if (event.keyLocation != null) {
			
			keyLocation = cast (event.keyLocation, KeyLocation);
			
		}
		
		dispatchEvent (new KeyboardEvent (event.type == "keydown" ? KeyboardEvent.KEY_DOWN : KeyboardEvent.KEY_UP, true, false, event.charCode, keyCode, keyLocation, event.ctrlKey, event.altKey, event.shiftKey));
		
	}
	
	
	private function window_onResize (event:js.html.Event):Void {
		
		__resize ();
		
		var event = new Event (Event.RESIZE);
		__broadcast (event);
		
	}
	
	private function window_onFocus (event:js.html.Event):Void {
		
		var event = new Event (Event.ACTIVATE);
		__broadcast (event);
		
	}
	
	private function window_onBlur (event:js.html.Event):Void {
		
		var event = new Event (Event.DEACTIVATE);
		__broadcast (event);
		
	}
	
	
	
	
	// Get & Set Methods
	
	
	
	
	private function get_color ():Int {
		
		return __color;
		
	}
	
	
	private function set_color (value:Int):Int {
		
		//this.backgroundColorSplit = PIXI.hex2rgb(this.backgroundColor);
		//var hex = this.backgroundColor.toString (16);
		//hex = '000000'.substr(0, 6 - hex.length) + hex;
		__colorString = "#" + StringTools.hex (value, 6);
		
		return __color = value;
		
	}
	
	
}


class RenderSession {
	
	
	public var context:CanvasRenderingContext2D;
	public var element:Element;
	//public var mask:Bool;
	public var maskManager:MaskManager;
	//public var scaleMode:ScaleMode;
	public var roundPixels:Bool;
	public var transformProperty:String;
	public var transformOriginProperty:String;
	public var vendorPrefix:String;
	public var z:Int;
	//public var smoothProperty:Null<Bool> = null;
	
	
	public function new () {
		
		maskManager = new MaskManager (this);
		
	}
	
	
}


class MaskManager {
	
	
	private var renderSession:RenderSession;
	
	
	public function new (renderSession:RenderSession) {
		
		this.renderSession = renderSession;
		
	}
	
	
	public function pushMask (mask:IBitmapDrawable):Void {
		
		var context = renderSession.context;
		
		context.save ();
		
		//var cacheAlpha = mask.__worldAlpha;
		var transform = mask.__worldTransform;
		if (transform == null) transform = new Matrix ();
		
		context.setTransform (transform.a, transform.c, transform.b, transform.d, transform.tx, transform.ty);
		
		context.beginPath ();
		mask.__renderMask (renderSession);
		
		context.clip ();
		
		//mask.worldAlpha = cacheAlpha;
		
	}
	
	
	public function popMask ():Void {
		
		renderSession.context.restore ();
		
	}
	
	
}