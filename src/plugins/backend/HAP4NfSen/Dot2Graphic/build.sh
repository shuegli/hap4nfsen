#!/bin/sh
export PERL_DL_NONLAZY=1
swig -perl5 dottographic.i &&
gcc -c dottographic.c dottographic_wrap.c `perl -MExtUtils::Embed -e ccopts` -fPIC `pkg-config libgvc --cflags`
gcc -shared dottographic.o dottographic_wrap.o -L/usr/local/lib/ -L/usr/lib/ `pkg-config --libs gthread-2.0 libgvc` -lpthread -o `basename *pm .pm`.so &&
rm dottographic_wrap.c dottographic_wrap.o dottographic.o
