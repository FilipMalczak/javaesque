module javaesque.concurrency.atomicref;

import core.sync.mutex;

auto atomicReference(V)(V v){
    return new shared AtomicReference!V(v);
}

shared class AtomicReference(V) {
    protected Mutex mutex;
    protected V value;
    
    this(V v){
        mutex = cast(shared) new Mutex();
        value = cast(shared) v;
    }
    
    final void set(V newVal){
        synchronized(mutex){
            value = cast(shared) newVal;
        }
    }
    
    final V get(){
        synchronized(mutex){
            return cast() value;
        }
    }
    
    final auto when() {
        return if_((v) => v ? true : false);
    }
    
    final auto whenNot() {
        return if_((v) => v ? false :true);
    }
    
    final auto if_(shared(bool delegate(V)) condition){
        auto AtomicReferenceInstance = this;
    
        shared struct IfClosure {
            auto then(T)(shared(T delegate()) thenCallback){
                return then((ignored) => thenCallback());
            }
        
            auto then(T)(shared(T delegate(V)) thenCallback){
                shared struct ThenClosure {
                    auto else_(shared(T delegate()) elseCallback){
                        return else_((ignored) => elseCallback());
                    }
                
                    auto else_(shared(T delegate(V)) elseCallback){
                        shared struct ElseClosure {
                            auto go(){
                                synchronized(AtomicReferenceInstance.mutex){
                                    V val = AtomicReferenceInstance.get();
                                    if (condition(val))
                                        return (cast(shared)thenCallback)(val);
                                    else
                                        return (cast(shared)elseCallback)(val);
                                }
                            }
                        }
                        return ElseClosure();
                    }
                    
                    auto go(){
                        return else_((ignored){
                            static if (is(T: void))
                                return;
                            else
                                return T.init;
                        });
                    }
                }
                return ThenClosure();
            }
        }
        return IfClosure();
    }
}

version(unittest) {
    import javaesque.concurrency.queue;
    import javaesque.concurrency.thread;
    import javaesque.debugging;
    
    void booleanFixture(void delegate(int number, shared Queue!int trueQueue, shared Queue!int falseQueue, shared AtomicReference!bool boolean) runnable){
        auto q1 = new shared Queue!int();
        auto q2 = new shared Queue!int();
        auto b = new shared AtomicReference!bool(true);
        
        auto t1 = Thread.spawn("t1", runnable, 1, q1, q2, b);
        auto t2 = Thread.spawn("t2", runnable, 2, q1, q2, b);
        
        t1.join();
        t2.join();
        
        auto trueArr = q1.drain();
        auto falseArr = q2.drain();
        
        assert(!b.get());
        assert((trueArr == [2] && falseArr == [1])||(trueArr == [1] && falseArr == [2]));
    }
    
    void simpleBooleanCase() {
        void runnable(int number, shared Queue!int trueQueue, shared Queue!int falseQueue, shared AtomicReference!bool boolean){
            boolean.
                if_((v) => v).
                then((v){
                    assert(v);
                    trueQueue.push(number);
                    boolean.set(false);
                }).
                else_((v){
                    assert(!v);
                    falseQueue.push(number);
                }).go();
        }
        booleanFixture(&runnable);
    }
    
    void simpleBooleanCaseNoThenArgs() {
        void runnable(int number, shared Queue!int trueQueue, shared Queue!int falseQueue, shared AtomicReference!bool boolean){
            boolean.
                if_((v) => v).
                then((){
                    trueQueue.push(number);
                    boolean.set(false);
                }).
                else_((v){
                    falseQueue.push(number);
                }).go();
        }
        booleanFixture(&runnable);
    }
    
    void simpleBooleanCaseNoElseArgs() {
        void runnable(int number, shared Queue!int trueQueue, shared Queue!int falseQueue, shared AtomicReference!bool boolean){
            boolean.
                if_((v) => v).
                then((v){
                    trueQueue.push(number);
                    boolean.set(false);
                }).
                else_((){
                    falseQueue.push(number);
                }).go();
        }
        booleanFixture(&runnable);
    }
    
    void whenBooleanCase() {
        void runnable(int number, shared Queue!int trueQueue, shared Queue!int falseQueue, shared AtomicReference!bool boolean){
            boolean.
                when().
                then((v){
                    trueQueue.push(number);
                    boolean.set(false);
                }).
                else_((v){
                    falseQueue.push(number);
                }).go();
        }
        booleanFixture(&runnable);
    }
    
    void whenNotBooleanCase() {
        void runnable(int number, shared Queue!int trueQueue, shared Queue!int falseQueue, shared AtomicReference!bool boolean){
            boolean.
                whenNot().
                then((v){
                    falseQueue.push(number);
                }).
                else_((v){
                    trueQueue.push(number);
                    boolean.set(false);
                }).go();
        }
        booleanFixture(&runnable);
    }
    
    void integerFixture(void delegate(int number, shared AtomicReference!int integer) runnable){
        auto i = new shared AtomicReference!int(0);
        auto t1 = Thread.spawn("t1", runnable, 1, i);
        auto t2 = Thread.spawn("t2", runnable, 2, i);
        
        t1.join();
        t2.join();
        
        int val = i.get();
        assert(val == 12 || val == 21);
    }
    
    void simpleIntegerCase(){
        void runnable(int number, shared AtomicReference!int integer){
            integer.
                if_((x) => x == 0).
                then((x){
                    integer.set(x + number);
                }).
                else_((x){
                    integer.set(10*x + number);
                }).go();
        }
        integerFixture(&runnable);
    }
    
    void whenIntegerCase(){
        void runnable(int number, shared AtomicReference!int integer){
            integer.
                when().
                then((x){
                    integer.set(10*x + number);
                }).
                else_((x){
                    integer.set(x + number);
                }).go();
        }
        integerFixture(&runnable);
    }
    
    void whenNotIntegerCase(){
        void runnable(int number, shared AtomicReference!int integer){
            integer.
                whenNot().
                then((x){
                    integer.set(x + number);
                }).
                else_((x){
                    integer.set(10*x + number);
                }).go();
        }
        integerFixture(&runnable);
    }
    
    void calculationFixture(int val, string expected){
        auto x = new shared AtomicReference!int(val);
        auto result = x.
            if_((v) => v % 2 == 0).
            then((v) => "EVEN").
            else_((v) => "ODD").
            go();
        assert(result == expected);
    }
    
    void calculations(){
        calculationFixture(5, "ODD");
        calculationFixture(6, "EVEN");
    }
}

unittest {
    import javaesque.testing;
    
    testSuite(
        testCase("simple boolean case", &simpleBooleanCase),
        testCase("simple boolean case without 'then' argument", &simpleBooleanCaseNoThenArgs),
        testCase("simple boolean case without 'else' argument", &simpleBooleanCaseNoElseArgs),
        testCase("'when' boolean case", &whenBooleanCase),
        testCase("'when not' boolean case", &whenNotBooleanCase),
        testCase("simple integer case", &simpleIntegerCase),
        testCase("'when' integer case", &whenIntegerCase),
        testCase("'when not' integer case", &whenNotIntegerCase),
        testCase("calculations", &calculations)
    );
}

