package tests;

import s.Log;

class Tests {
	static function main() {
		#if eval
		Log.info("Testing in Eval");
		#elseif python
		Log.info("Testing in Python");
		#elseif js
		Log.info("Testing in JS");
		#elseif cpp
		Log.info("Testing in C++");
		#end

		Log.debug("debug");
		Log.warning("warning");
		Log.error("error");
		Log.fatal("fatal");
	}
}
