module javaesque.debugging;

import std.stdio;
import std.conv;

private void impl(T...)(string mod, string foo, size_t line, T toNote){
    write(mod~"@"~to!string(line)~"\t"~foo);
    static if (T.length > 0)
        write("\t\t"~text(toNote));
    writeln();
}

void prettyNote(string mod=__MODULE__, string foo=__PRETTY_FUNCTION__, size_t line=__LINE__, T...)(T toNote){
    impl(mod, foo, line, toNote);
}

void note(string mod=__MODULE__, string foo=__FUNCTION__, size_t line=__LINE__, T...)(T toNote){
    impl(mod, foo, line, toNote);
}
