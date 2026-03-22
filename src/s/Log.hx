package s;

using StringTools;

@:forward()
private abstract PosInfo(haxe.PosInfos) from haxe.PosInfos {
	public function toString() {
		return '${this.fileName}:${this.lineNumber}';
	}
}

class Log {
	#if (nodejs || sys)
	#if log
	static var loggers:Array<Logger> = [];
	#end

	public static function close() {
		#if log
		root.close();
		for (logger in loggers)
			logger.close();
		#end
	}
	#end

	public static var root(default, null) = new Logger("ROOT");

	public static inline function error(message:String) {
		root.error(message);
	}

	public static inline function debug(message:String) {
		root.debug(message);
	}

	public static inline function warning(message:String) {
		root.warning(message);
	}

	public static inline function info(message:String) {
		root.info(message);
	}

	public static inline function fatal(message:String) {
		root.fatal(message);
	}

	public static inline function trace(message:String, level:LogLevel = DEBUG, ?pos:PosInfo) {
		root.trace(message, level, pos);
	}

	public static inline function log(message:String, level:LogLevel = DEBUG) {
		root.log(message, level);
	}
}

@:access(s.Log)
class Logger {
	static inline function logFormatted(value:String, ?values:{}) {
		for (f in Reflect.fields(values))
			value = value.replace('{$f}', Std.string(Reflect.field(values, f)));

		var original = value;
		var regex = new EReg("%([RGBOYW]+)\\(([^\\)]*)\\)", "g");

		#if (nodejs || sys)
		var ansiMap = [
			"R" => "\x1b[31m",
			"G" => "\x1b[32m",
			"Y" => "\x1b[38;5;226m",
			"O" => "\x1b[38;5;208m",
			"B" => "\x1b[34m",
			"W" => "\x1b[1m"
		];

		inline function wrapStyle(flags:String, text:String):String {
			var codes = [
				for (i in 0...flags.length)
					if (ansiMap.exists(flags.charAt(i))) ansiMap.get(flags.charAt(i))
			];
			return '${codes.join("")}$text\x1b[0m';
		}
		var formatted = regex.map(original, re -> {
			return wrapStyle(re.matched(1), re.matched(2));
		});

		var clear = regex.map(original, re -> re.matched(2));

		return {
			clear: clear,
			formatted: formatted
		}
		#elseif js
		var styleMap = [
			"R" => "color: red;",
			"G" => "color: green;",
			"Y" => "color: goldenrod;",
			"O" => "color: orange;",
			"B" => "color: blue;",
			"W" => "font-weight: bold;"
		];

		inline function cssFromFlags(flags:String):String
			return [
				for (i in 0...flags.length)
					if (styleMap.exists(flags.charAt(i))) styleMap[flags.charAt(i)]
			].join("");

		var styles:Array<String> = [];
		var msg = regex.map(original, re -> {
			final css = cssFromFlags(re.matched(1));
			styles.push(css);
			styles.push("");
			return '%c${re.matched(2)}%c';
		});

		return {
			msg: msg,
			styles: styles
		};
		#end
	}

	public var name:String;

	public var level:LogLevel = DEBUG;
	public var format:String = "%B({datetime}) :{name}: {message}";

	#if (nodejs || sys)
	#if log
	var file:sys.io.FileOutput;
	var isClosed(get, never):Bool;
	#end

	public function new(name:String, ?file:String) {
		#if log
		this.name = name;
		if (file != null)
			open(file);
		Log.loggers?.push(this);
		#end
	}

	public inline function open(file:String) {
		#if log
		close();
		this.file = sys.io.File.write(file);
		#end
	}

	public inline function close() {
		#if log
		if (!isClosed) {
			file.close();
			file = null;
		}
		#end
	}

	inline function get_isClosed() {
		return file == null;
	}
	#else
	public function new(name:String) {
		this.name = name;
	}
	#end

	public inline function debug(message:String) {
		log('%G($message)', DEBUG);
	}

	public inline function info(message:String) {
		log('%B($message)', INFO);
	}

	public inline function warning(message:String) {
		log('%Y($message)', WARNING);
	}

	public inline function error(message:String) {
		log('%R($message)', ERROR);
	}

	public inline function fatal(message:String) {
		log('%RW($message)', FATAL);
	}

	public inline function trace(message:String, level:LogLevel = DEBUG, ?pos:PosInfo) {
		log('$pos $message', level);
	}

	public inline function log(message:String, level:LogLevel = DEBUG) {
		#if log
		if (this.level <= level) {
			var output = logFormatted(format, {
				datetime: DateTools.format(Date.now(), "%H:%M:%S"),
				level: level.toString(),
				name: name,
				message: message
			});
			#if (nodejs || sys)
			Sys.println(output.formatted);
			#elseif js
			var out = logFormatted(format, {
				datetime: DateTools.format(Date.now(), "%H:%M:%S"),
				level: level.toString(),
				name: name,
				message: message
			});
			js.Syntax.code("console.log").apply(null, [out.msg].concat(out.styles));
			#end
		}
		#end
	}
}

enum abstract LogLevel(Int) to Int {
	var DEBUG;
	var INFO;
	var WARNING;
	var ERROR;
	var FATAL;

	@:op(a == b)
	inline function eq(b:LogLevel) {
		return this == (b : Int);
	}

	@:op(a != b)
	inline function neq(b:LogLevel) {
		return this != (b : Int);
	}

	@:op(a < b)
	inline function lower(b:LogLevel) {
		return this < (b : Int);
	}

	@:op(a <= b)
	inline function lowerEq(b:LogLevel) {
		return this <= (b : Int);
	}

	@:op(a > b)
	inline function greater(b:LogLevel) {
		return this > (b : Int);
	}

	@:op(a >= b)
	inline function greaterEq(b:LogLevel) {
		return this >= (b : Int);
	}

	public inline function toString() {
		return switch this {
			case DEBUG: "DEBUG";
			case INFO: "INFO";
			case WARNING: "WARNING";
			case ERROR: "ERROR";
			case FATAL: "FATAL";
			default: Std.string(this);
		}
	}
}
