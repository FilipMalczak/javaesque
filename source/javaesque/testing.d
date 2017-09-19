module javaesque.testing;

version(unittest){
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
    
    void testSuite(string moduleName=__MODULE__, size_t suiteLine=__LINE__, T...)(T cases) if (areCallable!T) {
        import std.stdio;
        import std.conv;
        Exception e = null;
        writeln("Running suite from module "~moduleName~" and line "~to!string(suiteLine));
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

