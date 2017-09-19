module javaesque.testing;

version(unittest){
    enum VERBOSE_TESTS = false;
    
    import std.traits;
    import std.stdio;
    
    template areCallable(T...){
        static if (T.length > 0) {
            enum areCallable = isCallable!(T[0]);
        } else {
            enum areCallable = isCallable!(T[0]) && areCallable(T[1..$]);
        }
    }
    
    auto testCase(T...)(string name, T foo) if (T.length == 1 && isCallable!(T[0])){
        return () {
            writeln("Test case: \t"~name);
            scope(success) writeln("Test case \""~name~"\" succeeded");
            scope(failure) writeln("Test case \""~name~"\" failed\t\t\t[!!!]");
            foo[0]();
        };
    }
    
    void testSuite(T...)(T cases) if (areCallable!T) {
        import std.stdio;
        Exception e = null;
        foreach (testcase; cases){
            try {
                testcase();
            } catch (Exception ex){
                if (e is null)
                    e = ex;
            }
        }
        if (e !is null) {
            writeln("First caught exception:");
            throw e;
        }
    }
}

