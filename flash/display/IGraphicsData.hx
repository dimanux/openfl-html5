package flash.display;


interface IGraphicsData {
	
	var __graphicsDataType (default, null):GraphicsDataType;
	
}


@:fakeEnum(Int) enum GraphicsDataType {
	
	STROKE;
	SOLID;
	GRADIENT;
	PATH;
	
}