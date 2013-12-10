/**
	Cookie based session support.

	Copyright: © 2012-2013 RejectedSoftware e.K.
	License: Subject to the terms of the MIT license, as written in the included LICENSE.txt file.
	Authors: Jan Krüger, Sönke Ludwig, Ilya Shipunov
*/
module vibe.http.sessionstore.memory;

import vibe.http.session;
import vibe.core.log;
import std.datetime;

/*
	Session store for storing a session in local memory.

	If the server is running as a single instance (no thread or process clustering), this kind of
	session store provies the fastest and simplest way to store sessions. In any other case,
	a persistent session store based on a database is necessary.
*/
final class MemorySessionStore : SessionStore {
	private {
		string[string][string] m_sessions;
		bool[string] m_exists;
		SysTime m_lastCleanup;
		SysTime[string] m_lastAccess;
		SessionStoreSettings m_settings;
	}
	
	this(SessionStoreSettings settings = SessionStoreSettings())
	{
		m_settings = settings;
	}
	
	bool exists(string id)
	{
		return (id in m_exists) !is null;
	}
	
	Session create()
	{
		auto s = createSessionInstance();
		m_exists[s.id] = true;
		m_sessions[s.id] = null;
		m_lastAccess[s.id] = Clock.currTime;
		return s;
	}
	
	Session open(string id)
	{
		auto pv = id in m_sessions;
		return pv ? createSessionInstance(id) : null;	
	}
	
	void set(string id, string name, string value)
	{
		m_sessions[id][name] = value;
		m_lastAccess[id] = Clock.currTime;
		debug foreach(k, v; m_sessions[id]) logTrace("Csession[%s][%s] = %s", id, k, v);
	}
	
	private void cleanup(){
		foreach(id, ref val; m_sessions){
			if (Clock.currTime - m_lastAccess[id] > m_settings.expiresAfter){
				destroy(id);
			}
		}
		m_lastCleanup = Clock.currTime;
	}
	
	string get(string id, string name, string defaultVal=null)
	{
		assert(exists(id), "session not in store");
		
		if (Clock.currTime - m_lastCleanup > m_settings.cleanupInterval)
			cleanup();
		
		m_lastAccess[id] = Clock.currTime;
		
		debug foreach(k, v; m_sessions[id]) logTrace("Dsession[%s][%s] = %s", id, k, v);
		if (auto pv = name in m_sessions[id]) {
			return *pv;			
		} else {
			return defaultVal;
		}
	}
	
	bool isKeySet(string id, string key)
	{
		return (key in m_sessions[id]) !is null;
	}
	
	void destroy(string id)
	{
		m_sessions.remove(id);
		m_lastAccess.remove(id);
		m_exists.remove(id);
	}
	
	int delegate(int delegate(ref string key, ref string value)) iterateSession(string id)
	{
		assert(exists(id), "session not in store");
		int iterator(int delegate(ref string key, ref string value) del)
		{
			
			m_lastAccess[id] = Clock.currTime;
			
			foreach( key, ref value; m_sessions[id] )
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