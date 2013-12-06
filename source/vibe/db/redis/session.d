module vibe.db.redis.session;

import vibe.db.redis.redis;
import vibe.http.session;

/**
	Session store for storing a session in a redis server.
*/
final class RedisSessionStore : MemorySessionStore {
	private {
		RedisClient m_redisclient = void;
		SessionStoreSettings m_settings = void;
	}
	
	this(string host = "127.0.0.1", ushort port = 6379, SessionStoreSettings settings = SessionStoreSettings())
	{
		m_redisclient = new RedisClient(host, port);
		m_settings = settings;
	}
	
	Session create()
	{
		auto s = createSessionInstance();
		return s;
	}
	
	Session open(string id)
	{
		return m_redisclient.exists(id) ? createSessionInstance(id) : null;	
	}
	
	void set(string id, string name, string value)
	{
		m_redisclient.hset(id, name, value);
	}
	
	string get(string id, string name, string defaultVal=null)
	{
		
		assert(m_redisclient.exists(id), "session not in store");
		
		auto val = m_redisclient.hget!string(id, name);
		
		if ( val != "" ) {
			return val;
		} else {
			return defaultVal;
		}
	}
	
	bool isKeySet(string id, string key)
	{
		return (m_redisclient.hexists(id, key));
	}
	
	void destroy(string id)
	{
		m_redisclient.del(id);
	}
	
	int delegate(int delegate(ref string key, ref string value)) iterateSession(string id)
	{
		assert(m_redisclient.exists(id), "session not in store");
		int iterator(int delegate(ref string key, ref string value) del)
		{
			RedisReply reply = m_redisclient.hgetAll(id);
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
