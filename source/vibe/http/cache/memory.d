/**
	Cookie based session support.

	Copyright: © 2012-2013 RejectedSoftware e.K.
	License: Subject to the terms of the MIT license, as written in the included LICENSE.txt file.
	Authors: Jan Krüger, Sönke Ludwig, Ilya Shipunov
*/
module vibe.http.cachestore.memory;

import vibe.http.cache;
import vibe.core.log;
import std.datetime;

/*
	Session store for storing a session in local memory.

	If the server is running as a single instance (no thread or process clustering), this kind of
	session store provies the fastest and simplest way to store sessions. In any other case,
	a persistent session store based on a database is necessary.
*/
final class MemoryCacheStore : CacheDataStore {

	/// Returns the value for a given Key with associated prefix & suffix
	T get(T)(string key, string keyPrefix = "", string keySuffix = "");
	
	/// Sets value for a given Key with associated prefix & suffix
	bool set(T)(string key, T value, string keyPrefix = "", string keySuffix = "", string defaultVal = null);
	
	/// Determines if a certain key is set.
	bool exists(string key, string keyPrefix = "", string keySuffix = "");
	
	/// Removes the entry from storage. Wildcard * can be used in any parameter
	bool remove(string key, string keyPrefix = "", string keySuffix = "");
	
	/// Runs periodically to remove expired cache
	void cleanup(); 
	
	/// Runs when cache suppression is necessary. 
	/// Should the strategies be selectable at runtime?
	void criticalCleanup();
	
	/// Retrieve or set the settings
	@property CacheDataStoreSettings settings();
	
	/// Iterates all key/value pairs in storage. 
	/// int delegate(int delegate(ref string key, ref T value)) iterateSession(string KEY, T)(string id);

}