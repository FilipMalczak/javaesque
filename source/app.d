import std.stdio;
import std.conv;
import std.concurrency;
import javaesque.concurrency;

void runnable(Queue!string q){
    try {
        while (true) {
            writeln(to!string(thisTid)~" "~q.pull());
        }
    } catch (OwnerTerminated ot) {
        writeln(to!string(thisTid)~" "~"bye");
    }
}

void main(string[] args){
    Queue!string queue = queue!string();
//    writeln("A");
    spawn(&runnable, queue);
    spawn(&runnable, queue);
//    writeln("B");
    for (int i = 0; i< 20; ++i){
//        writeln("C");
        queue.push(to!string(i));
//        writeln("D");
    }
    writeln("wait");
    readln();
    writeln("wait2");
    readln();
}
