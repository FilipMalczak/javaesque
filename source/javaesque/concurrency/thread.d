module javaesque.concurrency.thread;

import std.concurrency: raw_spawn = spawn, raw_send = send, Tid, register, unregister, locate; 
public import std.concurrency: receive;
public import std.concurrency: OwnerTerminated;
import core.sync.semaphore;

private string threadName = "mainThread";

struct Thread {
    string name;
    Semaphore semaphore;
    
    void join(){
        semaphore.wait();
    }
}

Thread spawn(F, T...)(string name, F fn, T args) {
    auto foo = function(string n, shared Semaphore semaphore, shared F f, T a){
        threadName = n;
        (cast()f)(a);
        unregister(n);
        (cast()semaphore).notify();
    };
    shared Semaphore semaphore = cast(shared) new Semaphore();
    Tid tid = raw_spawn(foo, name, semaphore, cast(shared) fn, args);
    register(name, tid);
    return Thread(name, cast()semaphore);
}

void send(T...)(string name, T vals){
    raw_send(locate(name), vals);
}

@property string thisName(){
    return threadName;
}

