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

//random number generator
//TODO: Use Whirlpool or SHA-512 here
private SHA1HashMixerRNG g_rng;

static this()
{
	g_rng = new SHA1HashMixerRNG();
}

//The "URL and Filename safe" Base64 without padding
alias Base64Impl!('-', '_', Base64.NoPadding) Base64URLNoPadding;

/**
	Represents a single HTTP session.

	Indexing the session object with string keys allows to store arbitrary key/value pairs.
*/
final class Session {
	private {
		SessionStore m_store;
		string m_id;
	}

	private this(SessionStore store, string id = null)
	{

		m_store = store;
		if (id) {
			m_id = id;
		} else {
			ubyte[64] rand;
			g_rng.read(rand);
			m_id = (cast(immutable)Base64URLNoPadding.encode(rand))[0..store.settings.szId-1];
		}
	}

	/// Returns the unique session id of this session.
	@property string id() const { return m_id; }

	/// Queries the session for the existence of a particular key.
	bool isKeySet(string key) { return m_store.isKeySet(m_id, key); }

	/**
		Enables foreach-iteration over all key/value pairs of the session.

		Examples:
		---
		// sends all session entries to the requesting browser
		void handleRequest(HTTPServerRequest req, HTTPServerResponse res)
		{
			res.contentType = "text/plain";
			foreach(key, value; req.session)
				res.bodyWriter.write(key ~ ": " ~ value ~ "\n");
		}
		---
	*/
	int opApply(int delegate(ref string key, ref string value) del)
	{
		foreach( key, ref value; m_store.iterateSession(m_id) )
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
	string opIndex(string name) { return m_store.get(m_id, name); }
	/// ditto
	void opIndexAssign(string value, string name) { m_store.set(m_id, name, value); }

	package void destroy() { m_store.destroy(m_id); }
}


/**
	Interface for a basic session store.

	A sesseion store is responsible for storing the id and the associated key/value pairs of a
	session.
*/
interface SessionStore {
	/// Creates a new session.
	Session create();

	/// Checks if a session exists.
	bool exists(string id);

	/// Opens an existing session.
	Session open(string id);

	/// Sets a name/value pair for a given session.
	void set(string id, string name, string value);

	/// Returns the value for a given session key.
	string get(string id, string name, string defaultVal = null);

	/// Determines if a certain session key is set.
	bool isKeySet(string id, string key);

	/// Terminates the given sessiom.
	void destroy(string id);

	@property SessionStoreSettings settings();

	/// Iterates all key/value pairs stored in the given session. 
	int delegate(int delegate(ref string key, ref string value)) iterateSession(string id);

	/// Creates a new Session object which sources its contents from this store.
	protected final Session createSessionInstance(string id = null)
	{
		return new Session(this, id);
	}
}

/**
 * Session store settings used in comparisons.
 */
struct SessionStoreSettings
{
	/*
	 * For RedisSessionStore, this is transferred to
	 * the expiresAfter setting of MemorySessionStore
	 * and should be set to the server's KeepAlive Timeout
	 */
	Duration keepAliveTimeout = 10.seconds;

	Duration cleanupInterval = 5.seconds;

	/* 
	 * If MemorySessionStore is called from RedisSessionStore, 
	 * this is the KeepAliveTimeout to avoid using outdated data 
	 * if another thread or server handles a session write.
	 */
	Duration expiresAfter = 360.seconds;

	/// Max bytes in Session ID string
	ubyte szId = 64;

	uint maxSessions = 1_000_000;
}

