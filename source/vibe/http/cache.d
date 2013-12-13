module vibe.http.cache;

import std.datetime;

/**
	Interface for a cache data store

	The cache data storage acts like a device responsible for retrieving
	specific values and types from the implemented storage.
*/
interface CacheDataStore {
		
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