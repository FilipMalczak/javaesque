module javaesque.concurrency.executors;

import core.sync.mutex;
import std.typecons;

version(unittest){
    import javaesque.testing;
}

interface Future(V) {
    V get();
}

//todo: make it work with Runnable (not Callable)
class CachedFuture(V): Future!V {
    private Mutex mutex;
    private bool calculated;
    private V result;
    
    protected void initCachedFuture(bool lazy_){
        mutex = new Mutex();
        calculated = false;
        if (!lazy_)
            get();
    }
    
    protected abstract V getResult();
    
    V get(){
        synchronized(mutex){
            if (!calculated) {
                result = getResult();
                calculated = true;
            }
            return result;
        }
    }
}

//enum Callable(V, A...) = Alias!(V delegate(A));

////todo: needed?
//enum Runnable(A...) = Callable!(void, A);

interface Executor {
    Future!V submit(V, A...)(V delegate(A) callable, A args);
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
        private V delegate(A) callable;
        private Tuple!A args;
        
        this(bool lazy_, V delegate(A) callable, A args){
            this.callable = callable;
            this.args = tuple(args);
            initCachedFuture(lazy_);
        }
        
        override protected V getResult(){
            return callable(args.expand);
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
