/**
	Cookie based session support.

	Copyright: © 2012-2013 RejectedSoftware e.K.
	License: Subject to the terms of the MIT license, as written in the included LICENSE.txt file.
	Authors: Jan Krüger, Sönke Ludwig, Ilya Shipunov
*/
module vibe.http.sessionstore.redis;

import vibe.http.session;
import vibe.http.sessionstore.cache;
import vibe.db.redis.redis;

import std.datetime;

/**
	Session store for storing a session in a redis server.
*/
final class RedisSessionStore : SessionStore {
	private {
		SessionCacheStore m_cacheStore = void;
		RedisClient m_redisClient = void;
		SessionStoreSettings m_settings = void;
	}

	this(string host = "127.0.0.1", ushort port = 6379, SessionStoreSettings settings = SessionStoreSettings())
	{
		m_redisClient = new RedisClient(host, port);
		m_settings = settings;
		if (m_settings.keepAliveTimeout > 0.seconds){
			auto memory_settings = SessionStoreSettings(0.seconds, settings.cleanupInterval.init, settings.keepAliveTimeout, 64, settings.maxSessions);
			m_cacheStore = new SessionCacheStore(memory_settings);
		}
	}

	bool exists(string id){
		return m_redisClient.exists(id);
	}

	Session create()
	{
		auto s = createSessionInstance();
		return s;
	}
	
	Session open(string id)
	{
		//// If keepalive was enabled this should be quick. 
		//// Check memoryStore first then Redis DB
		return (m_cacheStore.exists(id) || m_redisClient.exists(id) ? createSessionInstance(id) : null);	
	}
	
	void set(string id, string name, string value)
	{
		m_cacheStore.set(id, name, value);
		m_redisClient.hset(id, name, value);
	}
	
	string get(string id, string name, string defaultVal=null)
	{
		
		assert(m_cacheStore.exists(id) || exists(id), "session not in store");

		//// Prolong the redis index lifetime, it's still useful
		m_redisClient.expire(id, cast(uint)m_settings.expiresAfter.total!"seconds");

		if (m_cacheStore.exists(id))
			return m_cacheStore.get(id, name, defaultVal);

		auto val = m_redisClient.hget!string(id, name);
		
		if ( val != "" ) {
			//// Cache this value, it expired.
			m_cacheStore.set(id, name, val);
		} else {
			val = defaultVal;
		}

		return val;
	}
	
	bool isKeySet(string id, string key)
	{
		return m_cacheStore.isKeySet(id, key) || (m_redisClient.hexists(id, key));
	}
	
	void destroy(string id)
	{
		if (m_cacheStore.exists(id))
			m_cacheStore.destroy(id);
		m_redisClient.del(id);
	}
	
	int delegate(int delegate(ref string key, ref string value)) iterateSession(string id)
	{
		assert(m_cacheStore.exists(id) || exists(id), "session not in store");
		int iterator(int delegate(ref string key, ref string value) del)
		{
			RedisReply reply = m_redisClient.hgetAll(id);
			string[string] kv;
			while(reply.hasNext()){
				kv[reply.next!string()] = reply.next!string();
			}
			
			foreach( key, ref value; kv )
				if( auto ret = del(key, value) != 0 )
					return ret;
			return 0;
		}
		return &iterator;
	}

	@property SessionStoreSettings settings(){
		return m_settings;
	}
}
