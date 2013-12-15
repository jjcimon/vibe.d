/**
	Cookie based session support.

	Copyright: © 2012-2013 RejectedSoftware e.K.
	License: Subject to the terms of the MIT license, as written in the included LICENSE.txt file.
	Authors: Jan Krüger, Sönke Ludwig, Ilya Shipunov
*/
module vibe.http.session;

import vibe.core.log;

import std.base64;
import std.array;
import core.time;
import std.digest.md;
import std.datetime;
import vibe.crypto.cryptorand;
import std.variant;
import vibe.http.cache;

public import vibe.http.cachestore.memory;

//random number generator
//TODO: Use Whirlpool or SHA-512 here
private SHA1HashMixerRNG g_rng;

static this()
{
	g_rng = new SHA1HashMixerRNG();
}

//The "URL and Filename safe" Base64 without padding
alias Base64Impl!('-', '_', Base64.NoPadding) Base64URLNoPadding;

/// Session settings object passed to the SessionManager during its creation
struct SessionManagerSettings {

	ubyte szSessionID = 64;

	uint maxSessions = 1_000_000;

}

/**
	Represents a single HTTP session.

	Indexing the session object with string keys allows to store arbitrary key/value pairs.
*/
final class Session {
	private {
		SessionManager m_manager;
		string m_id;
	}
	private this(SessionManager man, string id = null)
	{

		m_manager = man;
		if (id) {
			m_id = id;
		} else {
			ubyte[64] rand;
			g_rng.read(rand);
			m_id = (cast(immutable)Base64URLNoPadding.encode(rand))[0..m_manager.settings.szSessionID-1];
		}
	}

	/// Returns the unique session id of this session.
	@property string id() const { return m_id; }

	/// Queries the session for the existence of a particular key.
	bool isKeySet(string key) { return m_manager.isKeySet(key, m_id); }

	/**
	 	Type-safe iteration is made available through Variant

		Examples:
		---
		// sends all session entries to the requesting browser
		void handleRequest(HTTPServerRequest req, HTTPServerResponse res)
		{
			res.contentType = "text/plain";
			foreach(key, Variant value; req.session)
				res.bodyWriter.write(key ~ ": " ~ value.get!string ~ "\n");
		}
		---
	*/
	int opApply(int delegate(ref string key, ref Variant value) del)
	{
		foreach( key, ref value; m_manager.iterateSession(m_id) )
			if( auto ret = del(key, value) != 0 )
				return ret;
		return 0;
	}

	/**
		Gets/sets a key/value pair stored within the session.

		Returns null if the specified key is not set.

		Examples:
		---
		void handleRequest(HTTPServerRequest req, HTTPServerResponse res)
		{
			res.contentType = "text/plain";
			res.bodyWriter.write("Username: " ~ req.session["userName"]);
			res.bodyWriter.write("Request count: " ~ req.session["requestCount"]);
			req.session["requestCount"] = to!string(req.session["requestCount"].to!int + 1);
		}
		---
	*/
	auto opIndex(string name) { return m_manager.get(m_id, name); }
	/// ditto
	void opIndexAssign(T = string)(T value, string name) { m_manager.set(m_id, name, value); }

	package void destroy() { m_manager.destroy(m_id); }
}

/**
	Interface for a session manager

	A session manager is responsible for storing the id and interfacing with a
	cache store for saving and retrieving session data
*/
final class SessionManager {

	private CacheDataStore m_cds;

	/// Creates a new session.
	Session create() {}

	/// Checks if a session exists.
	bool exists(string id) {}
	
	/// Opens an existing session.
	Session open(string id) {}
	
	/// Sets a name/value pair for a given session.
	void set(T)(T value, string name, string id) {}
	
	/// Returns the value for a given session key.
	auto get(string id, string name, string defaultVal = null) {}

	/// Determines if a certain session key is set.
	bool isKeySet(string key, string id) {}
	
	/// Terminates the given sessiom.
	void destroy(string id) {}

	/// Retrieves the active settings
	@property SessionManagerSettings settings() {}

	/// Retrieves the settings for the cache storage.
	@property CacheDataStoreSettings dsSettings() {}

	/// Iterates all key/value pairs stored in the given session.
	int delegate(int delegate(ref string key, ref Variant value)) iterateSession(string id);
	
	/// Creates a new Session object which sources its contents from this store.
	protected final Session createSessionInstance(string id = null)
	{
		return new Session(this, id);
	}

}

deprecated alias SessionManager SessionStore;
