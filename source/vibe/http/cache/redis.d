/**
	Cookie based session support.

	Copyright: © 2012-2013 RejectedSoftware e.K.
	License: Subject to the terms of the MIT license, as written in the included LICENSE.txt file.
	Authors: Jan Krüger, Sönke Ludwig, Ilya Shipunov
*/
module vibe.http.cachestore.redis;

import vibe.http.session;
import vibe.http.cachestore.cache;
import vibe.db.redis.redis;

import std.datetime;

/**
	Session store for storing a session in a redis server.
*/
final class RedisCacheStore : CacheDataStore {

	/// Returns the value for a given Key with associated prefix & suffix
	T get(T,string KEY, string KeyPrefix = "")(T value, string keySuffix = "");
	
	/// Sets value for a given Key with associated prefix & suffix
	bool set(T, string KEY, string KeyPrefix = "")(T value, string keySuffix = "", string defaultVal = null);
	
	/// Determines if a certain key is set.
	bool exists(string KEY, string KeyPrefix = "")(string keySuffix = "");
	
	/// Removes the entry from storage. Wildcard * can be used in any parameter
	bool destroy(string KEY = "*", string KeyPrefix = "")(string keySuffix = "");

}
