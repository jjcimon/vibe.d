module vibe.http.cache;

import std.datetime;

class CacheDataStoreSettings 
{
	/// Sometimes it's worth it to expire some cache items frequently based on accesses,
	/// especially when it's unlikely it'll reach the maxLifeTime because it's always being used
	uint maxAccesses = 0; // forces to keep each item until cold expiry
	
	/// Never cache for longer than
	Duration maxLifeTime = 1.day; // If cold expiry is never triggered
	Duration coldExpiry = 5.minutes; // Triggered based on the last access time
	Duration hotExpiry = 10.seconds; // Removes the item from the HotCacheStore (local process)
	Duration cleanupInterval = 5.seconds; // Checks for expiry of each item
	uint maxItems = 0; // unlimited     
	uint maxSpaceUsageMB = 1024;
	float criticalUsage = 0.2; // 20% under max items or max space usage ; runs critical cleanup
	CacheAlgo criticalCleanup = CacheAlgo.LeastRecentlyUsed; // Cache suppression algorithm
	
	/// Helps select cache suppression strategies when
	/// cache usage reaches critical levels.
	enum CacheAlgo : ubyte {
		MostRecentlyUsed = 0,
		LeastRecentlyUsed,
		PseudoLRU,
		RandomReplacement,
		SegmentedLRU,
		DirectMappedCache,
		LeastFrequentlyUsed,
		LowInterRefRecencySet,
		AdaptiveReplacementCache,
		ClockWithAdaptiveReplacement
	}
	
	
}

/**
	Communicates with a specific data store for global caching

*/
final class GlobalCacheManager 
{

	CacheDataStore m_dataStore;

	/// Retrieve an accessor object
	Cache get();

	/// Sets a name/value pair
	void set(T, string KEY)(T value);
	
	/// Returns the value
	T get(T, string KEY)(string defaultVal = null);

	/// Determines if a certain global key is set.
	bool isKeySet(string KEY)();
	
	/// Removes the given key.
	void destroy(string KEY)();

	/// Retrieves the settings for the cache storage.
	@property CacheDataStoreSettings dsSettings();

	/// Iterates all key/value pairs. Legacy string[string] version. 
	deprecated int delegate(int delegate(ref string key, ref string value)) iterateCache();
	
	/// Iterates all key/value pairs.
	int delegate(int delegate(ref string key, ref Variant value)) iterateCache();
	/// 

	/// The following methods are made available for runtime capabilities

	/// Sets a name/value pair. 
	void set(string name, string value) {}
	
	/// Returns the value. 
	string get(string name, string defaultVal = null) {}

	/// Determines if a certain global key is set.
	bool isKeySet(string name);
	
	/// Removes the given key.
	void destroy(string name);

}

/**
	Allows full-featured access to the global cache
*/
final class Cache 
{

	private GlobalCacheManager m_manager;

	private this(GlobalCacheManager man)
	{
		m_manager = man;
	}

	
	static bool exists(string KEY)() { 
		static if (m_manager.exists(KEY)) 
			return true;
		else
			return false;
	}

	bool isKeySet(string key)() { return m_manager.isKeySet!key; }


	/*
	 * Iterates through all cache objects with Variant
	 * 
	*/
	int opApply(int delegate(ref string key, ref Variant value) del)
	{
		foreach( key, ref value; m_manager.iterateSession(m_id) )
			if( auto ret = del(key, value) != 0 )
				return ret;
		return 0;
	}

	string opIndex(string name) { return m_manager.get(m_id, name); }

	void opIndexAssign(string value, string name) { m_manager.set(m_id, name, value); }
	
	package void destroy() { m_manager.destroy(m_id); }
}

/**
	Interface for a cache data store

	The cache data storage acts like a device responsible for retrieving
	specific values and types from the implemented storage.

	CacheDataStore is inherited in storage adaptors of vibe.http.cachestore.*
*/

interface CacheDataStore 
{
		
	/// Returns the value for a given Key with associated prefix & suffix
	T get(T,string KEY, string KeyPrefix = "")(T value, string keySuffix = "");

	/// Sets value for a given Key with associated prefix & suffix
	bool set(T, string KEY, string KeyPrefix = "")(T value, string keySuffix = "", string defaultVal = null);

	/// Determines if a certain key is set.
	bool exists(string KEY, string KeyPrefix = "")(string keySuffix = "");
	
	/// Removes the entry from storage. Wildcard * can be used in any parameter
	bool destroy(string KEY = "*", string KeyPrefix = "")(string keySuffix = "");

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

