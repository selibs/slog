package;

using StringTools;

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

	public static var root(default, null) = new Logger("LOG");

	extern public static inline function error(message:Any)
		root.error(message);

	extern public static inline function debug(message:Any)
		root.debug(message);

	extern public static inline function warning(message:Any)
		root.warning(message);

	extern public static inline function info(message:Any)
		root.info(message);

	extern public static inline function fatal(message:Any)
		root.fatal(message);

	extern public static inline function trace(message:Any, level:LogLevel = DEBUG, ?pos:haxe.PosInfos)
		root.trace(message, level, pos);

	extern public static inline function log(message:Any, level:LogLevel = DEBUG)
		root.log(message, level);
}

@:access(Log)
class Logger {
	static function replaceTokens(value:String, ?values:{}):String {
		if (values == null)
			return value;
		for (f in Reflect.fields(values))
			value = StringTools.replace(value, '{$f}', Std.string(Reflect.field(values, f)));
		return value;
	}

	static function mapFormattedSegments(value:String, onSegment:String->String->String):String {
		var out = new StringBuf();
		var i = 0;
		final len = value.length;

		while (i < len) {
			if (value.charAt(i) != "%") {
				out.add(value.charAt(i));
				++i;
				continue;
			}

			var flagsStart = i + 1;
			var flagsEnd = flagsStart;
			while (flagsEnd < len) {
				final ch = value.charAt(flagsEnd);
				if (ch == "R" || ch == "G" || ch == "B" || ch == "O" || ch == "Y" || ch == "W")
					++flagsEnd;
				else
					break;
			}

			if (flagsEnd == flagsStart || flagsEnd >= len || value.charAt(flagsEnd) != "(") {
				out.add("%");
				++i;
				continue;
			}

			var depth = 1;
			var j = flagsEnd + 1;
			while (j < len && depth > 0) {
				final ch = value.charAt(j);
				if (ch == "(")
					++depth;
				else if (ch == ")")
					--depth;
				++j;
			}

			if (depth != 0) {
				out.add(value.substr(i, len - i));
				break;
			}

			final flags = value.substring(flagsStart, flagsEnd);
			final text = value.substring(flagsEnd + 1, j - 1);
			out.add(onSegment(flags, text));
			i = j;
		}

		return out.toString();
	}

	static inline function logFormatted(value:String, ?values:{}) {
		var original = replaceTokens(value, values);

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
		var formatted = mapFormattedSegments(original, wrapStyle);
		var clear = mapFormattedSegments(original, (_, text) -> text);

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
		var msg = mapFormattedSegments(original, (flags, text) -> {
			final css = cssFromFlags(flags);
			styles.push(css);
			styles.push("");
			return '%c${text}%c';
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

	inline function get_isClosed()
		#if log
		return file == null;
		#else
		return true;
		#end
	#else
	public function new(name:String)
		this.name = name;
	#end

	extern public inline function debug(message:Any)
		log('%G($message)', DEBUG);

	extern public inline function info(message:Any)
		log('%B($message)', INFO);

	extern public inline function warning(message:Any)
		log('%Y($message)', WARNING);

	extern public inline function error(message:Any)
		log('%R($message)', ERROR);

	extern public inline function fatal(message:Any)
		log('%RW($message)', FATAL);

	extern public inline function trace(message:Any, level:LogLevel = DEBUG, ?pos:haxe.PosInfos)
		log('${pos.fileName}:${pos.lineNumber} $message', level);

	extern public inline function log(message:Any, level:LogLevel = DEBUG)
		#if log
		if (this.level <= level)
			for (line in Std.string(message).split("\n")) {
				var out = logFormatted(format, {
					datetime: DateTools.format(Date.now(), "%H:%M:%S"),
					level: level.toString(),
					name: name,
					message: line
				});
				#if (nodejs || sys)
				Sys.println(out.formatted);
				#elseif js
				js.Syntax.code("console.log").apply(null, [out.msg].concat(out.styles));
				#end
			}
		#end
}

enum abstract LogLevel(Int) to Int {
	var DEBUG;
	var INFO;
	var WARNING;
	var ERROR;
	var FATAL;

	@:op(a == b)
	inline function eq(b:LogLevel)
		return this == (b : Int);

	@:op(a != b)
	inline function neq(b:LogLevel)
		return this != (b : Int);

	@:op(a < b)
	inline function lower(b:LogLevel)
		return this < (b : Int);

	@:op(a <= b)
	inline function lowerEq(b:LogLevel)
		return this <= (b : Int);

	@:op(a > b)
	inline function greater(b:LogLevel)
		return this > (b : Int);

	@:op(a >= b)
	inline function greaterEq(b:LogLevel)
		return this >= (b : Int);

	public inline function toString()
		return switch this {
			case DEBUG: "DEBUG";
			case INFO: "INFO";
			case WARNING: "WARNING";
			case ERROR: "ERROR";
			case FATAL: "FATAL";
			default: Std.string(this);
		}
}
