module javaesque.concurrency.queue;

import core.thread: CoreThread = Thread;
import core.sync.mutex;
import core.sync.semaphore;
import core.sync.condition;

version(unittest){
    import javaesque.concurrency.thread;
    import javaesque.testing;
}

shared class Queue(T) {
    private shared(T)[] buffer;
    private shared Mutex putLock;
    private shared Mutex getLock;
    private shared Semaphore nonEmptySemaphore;
    private shared Condition emptyCondition;
    private shared bool closed;
    
    this(){
        putLock = cast(shared) new Mutex();
        getLock = cast(shared) new Mutex();
        nonEmptySemaphore = cast(shared) new Semaphore();
        emptyCondition = cast(shared) new Condition(new Mutex());
        closed = false;
    }
    
    void put(T val){
        synchronized(cast() putLock){
            assert(!closed); //todo: exception
            buffer ~= cast(shared) val;
            (cast()nonEmptySemaphore).notify();
        }
    }
    
    T get(){
        synchronized(cast() getLock){
            (cast()nonEmptySemaphore).wait();
            shared T result = buffer[0];
            buffer = buffer[1..$];
            if ((cast()buffer))
                (cast()emptyCondition).notify();
            return cast() result;
        }
    }
}

version(unittest){
    import std.random;

    void producer(shared Queue!int queue, int minDelay, int maxDelay){
        for (int i=0; i<10; ++i){
            queue.put(i);
            CoreThread.sleep(dur!("msecs")(uniform!"[]"(minDelay, maxDelay)));
        }
        static if (VERBOSE_TESTS) {
            import std.stdio;
            writeln(thisName~" finished");
        }
    }
    
    void consumer(int producers)(shared Queue!int queue, void function(int[] expected, int[] result) checker){
        int[] result;
        int[] expected;
        for (int j=0; j<producers; ++j)
            for (int i=0; i<10; ++i){
                result ~= queue.get();
                expected ~= i;
            }
        static if (VERBOSE_TESTS) {
            import std.stdio;
            import std.conv;
            writeln(thisName~" finished");
            writeln("expected: "~to!string(expected)~"; result: "~to!string(result));
        }
        checker(expected, result);
    }

    void singleProducerCheck(int[] expected, int[] result){
        assert(expected == result);
    }
    
    void multipleProducerCheck(int[] expected, int[] result){
        import std.algorithm.comparison: isPermutation;
        assert(isPermutation(expected, result));
    }

    void testSingleNoDelayProducer(){
        shared Queue!int q = new shared Queue!int;
        Thread[] threads;
        threads ~= spawn("singleNoDelayProducer", &producer, q, 0, 0);
        threads ~= spawn("consumer", &consumer!1, q, &singleProducerCheck);
        foreach (thread; threads) thread.join();
    }

    void testSingleConstantProducer(){
        shared Queue!int q = new shared Queue!int;
        Thread[] threads;
        threads ~= spawn("singleConstantDelayProducer", &producer, q, 200, 200);
        threads ~= spawn("consumer", &consumer!1, q, &singleProducerCheck);
        foreach (thread; threads) thread.join();
    }

    void testSingleVaryingProducer(){
        shared Queue!int q = new shared Queue!int;
        Thread[] threads;
        threads ~= spawn("singleVaryingDelayProducer", &producer, q, 0, 500);
        threads ~= spawn("consumer", &consumer!1, q, &singleProducerCheck);
        foreach (thread; threads) thread.join();
    }

    void testMultipleNoDelayProducer(){
        shared Queue!int q = new shared Queue!int;
        Thread[] threads;
        threads ~= spawn("firstNoDelayProducer", &producer, q, 0, 0);
        threads ~= spawn("secondNoDelayProducer", &producer, q, 0, 0);
        threads ~= spawn("thirdNoDelayProducer", &producer, q, 0, 0);
        threads ~= spawn("consumer", &consumer!3, q, &multipleProducerCheck);
        foreach (thread; threads) thread.join();
    }

    void testMultipleConstantProducer(){
        shared Queue!int q = new shared Queue!int;
        Thread[] threads;
        threads ~= spawn("firstConstantDelayProducer", &producer, q, 200, 200);
        threads ~= spawn("secondConstantDelayProducer", &producer, q, 200, 200);
        threads ~= spawn("thirdConstantDelayProducer", &producer, q, 200, 200);
        threads ~= spawn("consumer", &consumer!3, q, &multipleProducerCheck);
        foreach (thread; threads) thread.join();
    }

    void testMultipleVaryingProducer(){
        shared Queue!int q = new shared Queue!int;
        Thread[] threads;
        threads ~= spawn("firstVaryingDelayProducer", &producer, q, 0, 500);
        threads ~= spawn("secondVaryingDelayProducer", &producer, q, 0, 500);
        threads ~= spawn("thirdVaryingDelayProducer", &producer, q, 0, 500);
        threads ~= spawn("consumer", &consumer!3, q, &multipleProducerCheck);
        foreach (thread; threads) thread.join();
    }
}

unittest {
    testSuite(
        testCase("single no delay producer", &testSingleNoDelayProducer),
        testCase("single constant delay producer", &testSingleConstantProducer),
        testCase("single varying delay producer", &testSingleVaryingProducer),
        testCase("multiple no delay producers", &testMultipleNoDelayProducer),
        testCase("multiple constant delay producers", &testMultipleConstantProducer),
        testCase("multiple varying delay producers", &testMultipleVaryingProducer)
    );
}
