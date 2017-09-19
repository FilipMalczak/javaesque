import std.stdio;
import std.conv;
import std.concurrency;

void main(string[] args){
    writeln(thisTid);
    writeln(ownerTid);
    spawn((){writeln("--");writeln(thisTid);writeln(ownerTid);});
}
