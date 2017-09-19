module javaesque.concurrency.thread;

import std.concurrency: raw_spawn = spawn, raw_send = send, 
    Tid, thisTid, ownerTid, TidMissingException, initOnce,
    register, unregister, locate; 
public import std.concurrency: receive;
public import std.concurrency: OwnerTerminated;
import core.sync.semaphore;
import core.sync.mutex;
import core.thread: CoreThread = Thread;

enum MAIN_THREAD_NAME = "mainThread";

private string threadLocalName = MAIN_THREAD_NAME;

void send(T...)(string name, T vals){
    raw_send(locate(name), vals);
}

private alias sendToThread = send;

struct Threading {
    private __gshared bool initialized = false;
    private __gshared Mutex initializationMutex;
    
    static void init(){
        initOnce!initializationMutex(new Mutex());
        synchronized(initializationMutex) {
            if (!initialized)
                try {
                    auto x = ownerTid;
                    assert(false); //first and only time this actually does something must happen in main thread
                } catch (TidMissingException tme){
                    register(MAIN_THREAD_NAME, thisTid);
                    initialized = true;
                }
        }
    }

}

struct Thread {
    private string threadName;
    private Semaphore finished;
    
    this(string tn, Semaphore s){
        Threading.init();
        threadName = tn;
        finished = s;
    }
    
    @property
    string name(){
        return threadName;
    }
    
    void join(){
        assert(threadName != threadLocalName); //todo: contract
        assert(threadName != MAIN_THREAD_NAME); //todo: contract
        finished.wait();
    }
    
    void send(T...)(T vals){
        sendToThread(threadName, vals);
    }
    
    alias sleep = CoreThread.sleep;
    
    static Thread spawn(F, T...)(string name, F fn, T args) {
        auto foo = function(string name, shared Semaphore finished, shared F foo, T args){
            threadLocalName = name;
            (cast()foo)(args);
            unregister(name);
            (cast()finished).notify();
        };
        Semaphore finished = new Semaphore();
        Tid tid = raw_spawn(foo, name, cast(shared) finished, cast(shared) fn, args);
        register(name, tid);
        return Thread(name, finished);
    }
    
    @property
    static Thread thisThread(){
        return Thread(threadLocalName, null);
    }
    
    @property
    static Thread mainThread(){
        return Thread(MAIN_THREAD_NAME, null);
    }
}

alias spawn = Thread.spawn;

unittest {
    import javaesque.testing;
    import std.typecons;
    
    import javaesque.debugging;
    
    void singleSpawnedSendByName(){
        auto spawned = Thread.spawn("customName", (){
            receive((string payload){
                send(MAIN_THREAD_NAME, Thread.thisThread.name, payload);
            });
        });
        send("customName", "customPayload");
        Tuple!(string, string) received;
        receive((Tuple!(string, string) data){
            received = data;
        });
        assert(received[0] == "customName");
        assert(received[1] == "customPayload");
    }
    
    void singleSpawnedSendByStruct(){
        auto spawned = Thread.spawn("customName", (){
            receive((string payload){
                send(MAIN_THREAD_NAME, Thread.thisThread.name, payload);
            });
        });
        spawned.send("customPayload");
        Tuple!(string, string) received;
        receive((Tuple!(string, string) data){
            received = data;
        });
        assert(received[0] == "customName");
        assert(received[1] == "customPayload");
    }
    
    void singleSpawnedRespondingByStruct(){
        auto spawned = Thread.spawn("customName", (){
            receive((string payload){
                Thread.mainThread.send(Thread.thisThread.name, payload);
            });
        });
        send("customName", "customPayload");
        Tuple!(string, string) received;
        receive((Tuple!(string, string) data){
            received = data;
        });
        assert(received[0] == "customName");
        assert(received[1] == "customPayload");
    }
    
    void joining(){
        import javaesque.concurrency.queue;
        auto q = new shared Queue!string();
        auto spawned = Thread.spawn("spawned", (shared Queue!string queue){
            Thread.sleep(dur!"seconds"(3));
            queue.put(Thread.thisThread.name);
        }, q);
        spawned.join();
        auto txt = q.get();
        assert(txt == "spawned");
    }
    
    testSuite(
        testCase("single thread scenario sending by name", &singleSpawnedSendByName),
        testCase("single thread scenario sending by struct", &singleSpawnedSendByStruct),
        testCase("single thread scenario responding by struct", &singleSpawnedSendByStruct),
        testCase("joining", &joining),
    );
}
