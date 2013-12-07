module vibe.db.redis.session;

import vibe.db.redis.redis;
import vibe.http.session;

import std.datetime;
/**
	Session store for storing a session in a redis server.
*/
final class RedisSessionStore : SessionStore {
	private {
		MemorySessionStore m_memoryStore = void;
		RedisClient m_redisClient = void;
		SessionStoreSettings m_settings = void;
	}

	this(string host = "127.0.0.1", ushort port = 6379, SessionStoreSettings settings = SessionStoreSettings())
	{
		m_redisClient = new RedisClient(host, port);
		m_settings = settings;
		if (m_settings.keepAliveTimeout > 0.seconds){
			auto memory_settings = SessionStoreSettings(0.seconds, settings.cleanupInterval.init, settings.keepAliveTimeout, settings.maxSessions);
			m_memoryStore = new MemorySessionStore(memory_settings);
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
		return (m_redisClient.exists(id) ? createSessionInstance(id) : null);	
	}
	
	void set(string id, string name, string value)
	{
		m_memoryStore.set(id, name, value);
		m_redisClient.hset(id, name, value);
	}
	
	string get(string id, string name, string defaultVal=null)
	{
		
		assert(m_memoryStore.exists(id) || exists(id), "session not in store");

		//// Prolong the redis index lifetime, it's still useful
		m_redisClient.expire(id, cast(uint)m_settings.expiresAfter.total!"seconds");

		if (m_memoryStore.exists(id))
			return m_memoryStore.get(id, name, defaultVal);

		auto val = m_redisClient.hget!string(id, name);
		
		if ( val != "" ) {
			//// Cache this value, it expired.
			m_memoryStore.set(id, name, val);
		} else {
			val = defaultVal;
		}

		return val;
	}
	
	bool isKeySet(string id, string key)
	{
		return m_memoryStore.isKeySet(id, key) || (m_redisClient.hexists(id, key));
	}
	
	void destroy(string id)
	{
		if (m_memoryStore.exists(id))
			m_memoryStore.destroy(id);
		m_redisClient.del(id);
	}
	
	int delegate(int delegate(ref string key, ref string value)) iterateSession(string id)
	{
		assert(m_memoryStore.exists(id) || exists(id), "session not in store");
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
}
