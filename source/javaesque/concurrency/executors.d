module javaesque.concurrency.executors;

import core.sync.mutex;
import core.sync.condition;
import std.typecons;

import javaesque.concurrency.atomicref;
import javaesque.concurrency.queue;

version(unittest){
    import javaesque.testing;
}

enum FutureState {
    PENDING,
    STARTED,
    FINISHED,
    FAILED
}

interface Future(V) {
    V get();
    @property FutureState state();
}

class FutureThrewException: Exception {
    const Exception reason;
    
    this(string msg, Exception e){
        super(msg);
        reason = e;
    }
}

//todo: lazy as flag
//todo: make it work with Runnable (not Callable)
class CachedFuture(V): Future!V {
    private shared AtomicReference!FutureState state_;
    private Condition done;
    private Mutex doneMutex;
    private V result;
    private Exception thrown;
    
    protected void initCachedFuture(bool lazy_){
        state_ = atomicReference(FutureState.PENDING);
        doneMutex = new Mutex();
        done = new Condition(doneMutex);
        if (!lazy_)
            calculate();
    }
    
    protected abstract V getResult();
    
    protected auto calculate(){
        state_.set(FutureState.STARTED);
        scope(success) state_.set(FutureState.FINISHED);
        scope(failure) state_.set(FutureState.FAILED);
        scope(exit) synchronized(doneMutex) { done.notifyAll(); done=null; }
        try {
            result = getResult();
        } catch (Exception e) {
            thrown = e;
            
        }
    }
    
    V get(){
        return state_.
            if_((s) => s == FutureState.FINISHED || s == FutureState.FAILED).
            then((s) {
                if (s == FutureState.FINISHED)
                    return result;
                throw new FutureThrewException("Exception was thrown while calculating futures result", thrown);
            }).
            else_((s){
                if (s == FutureState.STARTED)
                    synchronized(doneMutex) { done.wait(); }
                else
                    calculate();
                return get();
            }).go();
    }
    
    @property FutureState state(){
        return state_.get();
    }
}

interface Executor {
    Future!V submit(V, A...)(V delegate(A) callable, A args);
}

struct Calculation(V, A...){
    V delegate(A) callable;
    Tuple!A args;
    
    this(V delegate(A) callable, A args){
        this(callable, tuple(args));
    }
    
    this(V delegate(A) callable, Tuple!A args){
        this.callable = callable;
        this.args = args;
    }
    
    V opCall(){
        return callable(args.expand);
    }
}

class LocalThreadExecutor: Executor {
    bool lazyFutures;
    
    this(bool lazyFutures){
        this.lazyFutures = lazyFutures;
    }
    
    this(){
        this(true);  //todo: is false a better default?
    }

    private class LocalFuture(V, A...): CachedFuture!V {
        private Calculation!(V, A) calculation;
        
        this(bool lazy_, Calculation!(V, A) calculation){
            this.calculation = calculation;
            initCachedFuture(lazy_);
        }
        
        this(bool lazy_, V delegate(A) foo, A args){
            this(lazy_, Calculation!(V, A)(foo, args));
        }
        
        override protected V getResult(){
            return calculation();
        }
    } 
    
    auto submit(V, A...)(V delegate(A) callable, A args){
        return new LocalFuture!(V, A)(lazyFutures, callable, args);
    }
}

version (unittest) {
    import javaesque.debugging;

    void testLazyLocalThreadExecutor(){
        auto executor = new LocalThreadExecutor(true);
        int[] results = [];
        Future!string future = executor.submit((){ results ~= 1; return "X"; });
        assert(results.length == 0);
        string result = future.get();
        assert(result == "X");
        assert(results == [1]);
    }
    
    void testNonlazyLocalThreadExecutor(){
        auto executor = new LocalThreadExecutor(false);
        int[] results = [];
        Future!string future = executor.submit((){ results ~= 1; return "X"; });
        assert(results == [1]);
        string result = future.get();
        assert(result == "X");
    }
}

unittest {
    testSuite(
        testCase("lazy local thread executor", &testLazyLocalThreadExecutor),
        testCase("non-lazy local thread executor", &testNonlazyLocalThreadExecutor),
    );
}
