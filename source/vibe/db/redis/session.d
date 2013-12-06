module vibe.db.redis.session;

import vibe.db.redis.redis;
import vibe.http.session;

import std.duration : Clock, SysTime, Duration;
/**
	Session store for storing a session in a redis server.
*/
final class RedisSessionStore : SessionStore {
	private {
		MemorySessionStore m_memoryStore = void;
		RedisClient m_redisClient = void;
		SessionStoreSettings m_settings = void;
	}
	
	this(string host = "127.0.0.1", ushort port = 6379, Duration keepAlive, SessionStoreSettings settings = SessionStoreSettings())
	{
		m_redisClient = new RedisClient(host, port);
		if (keepAlive > 0.seconds){
			auto memsett = settings.dup;
			memsett.expiresAfter = keepAlive;
			m_memoryStore = new MemorySessionStore(memsett);
		}
		m_settings = settings;
	}
	
	Session create()
	{
		auto s = createSessionInstance();
		return s;
	}
	
	Session open(string id)
	{
		auto s = m_memoryStore.open(id);

		//// Check memoryStore first then the redis DB
		return !s ? (m_redisClient.exists(id) ? createSessionInstance(id) : null) : s;	
	}
	
	void set(string id, string name, string value)
	{
		m_redisClient.hset(id, name, value);
	}
	
	string get(string id, string name, string defaultVal=null)
	{
		
		assert(m_redisClient.exists(id), "session not in store");
		
		auto val = m_redisClient.hget!string(id, name);
		
		if ( val != "" ) {
			return val;
		} else {
			return defaultVal;
		}
	}
	
	bool isKeySet(string id, string key)
	{
		return (m_redisClient.hexists(id, key));
	}
	
	void destroy(string id)
	{
		m_redisClient.del(id);
	}
	
	int delegate(int delegate(ref string key, ref string value)) iterateSession(string id)
	{
		assert(m_redisClient.exists(id), "session not in store");
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
