module javaesque.concurrency.queue;

import core.sync.rwmutex;
import core.sync.semaphore;
import core.sync.condition;

version(unittest){
    import javaesque.concurrency.thread;
    import javaesque.testing;
    
    enum VERBOSE_TESTS = false;

}

shared class Queue(T) {
    private shared(T)[] buffer;
    private shared ReadWriteMutex rwmutex;
    private shared Semaphore nonEmptySemaphore;

    this(){
        //todo: add policy to constructor
        rwmutex = cast(shared) new ReadWriteMutex();
        nonEmptySemaphore = cast(shared) new Semaphore();
    }
    
    void put(T val){
        synchronized((cast() rwmutex).writer){
            buffer ~= cast(shared) val;
            (cast()nonEmptySemaphore).notify();
        }
    }
    
    alias push = put;
    
    T get(){
        (cast()nonEmptySemaphore).wait();
        synchronized((cast() rwmutex).reader){
            shared T result = buffer[0];
            buffer = buffer[1..$];
            return cast() result;
        }
    }
    
    alias pull = get;
}

version(unittest){
    import std.random;

    void producer(shared Queue!int queue, int minDelay, int maxDelay){
        for (int i=0; i<10; ++i){
            queue.put(i);
            Thread.sleep(dur!("msecs")(uniform!"[]"(minDelay, maxDelay)));
        }
        static if (VERBOSE_TESTS) {
            import std.stdio;
            writeln(Thread.thisThread.name~" finished");
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
            writeln(Thread.thisThread.name~" finished");
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
    
    void testMultipleConsumers(){
        auto q1 = new shared Queue!int;
        auto q2 = new shared Queue!int;
        
        Thread[] threads;
        
        Thread producer = Thread.spawn("producer", (shared Queue!int oq){
            for (int i=0; i<20; ++i){
                oq.push(i);
                Thread.sleep(dur!("msecs")(uniform!"[]"(150, 200)));
            }
            static if (VERBOSE_TESTS) {
                import std.stdio;
                writeln(Thread.thisThread.name~" finished");
            }
        }, q1);
        
        auto consumerFoo = (shared Queue!int iq, shared Queue!int oq){
            for (int i=0; i<10; ++i) {
                oq.push(iq.pull());
                Thread.sleep(dur!("msecs")(uniform!"[]"(150, 200)));
            }
            static if (VERBOSE_TESTS) {
                import std.stdio;
                writeln(Thread.thisThread.name~" finished");
            }
        };
        
        Thread consumer1 = Thread.spawn("consumer1", consumerFoo, q1, q2);
        Thread consumer2 = Thread.spawn("consumer2", consumerFoo, q1, q2);
        
        Thread checker = Thread.spawn("checker", (shared Queue!int oq){
            int[] result;
            int[] expected;
            for (int i=0; i<20; ++i){
                expected ~= i;
                result ~= oq.pull();
            }
            static if (VERBOSE_TESTS) {
                import std.stdio;
                import std.conv;
                writeln(Thread.thisThread.name~" finished");
                writeln("expected: "~to!string(expected)~"; result: "~to!string(result));
            }
            import std.algorithm;
            assert(isPermutation(expected, result));
        }, q2);
        producer.join();
        consumer1.join();
        consumer2.join();
        checker.join();
    }
}

unittest {
    testSuite(
        testCase("single no delay producer", &testSingleNoDelayProducer),
        testCase("single constant delay producer", &testSingleConstantProducer),
        testCase("single varying delay producer", &testSingleVaryingProducer),
        testCase("multiple no delay producers", &testMultipleNoDelayProducer),
        testCase("multiple constant delay producers", &testMultipleConstantProducer),
        testCase("multiple varying delay producers", &testMultipleVaryingProducer),
        testCase("multiple consumers", &testMultipleConsumers)
    );
}
