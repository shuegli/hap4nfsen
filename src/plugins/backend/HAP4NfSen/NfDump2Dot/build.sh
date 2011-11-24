#!/bin/sh
swig -perl5 nfdump2dot.i &&
g++ -c nfdump2dot.c nfdump2dot_wrap.c `perl -MExtUtils::Embed -e ccopts` -fPIC -I /usr/local/include/hapviz/ -I /usr/include/hapviz/ &&
g++ -shared nfdump2dot.o nfdump2dot_wrap.o -lhapviz -L/usr/local/lib/ -L /usr/lib/ -o `basename *pm .pm`.so &&
rm nfdump2dot_wrap.c nfdump2dot_wrap.o nfdump2dot.o
