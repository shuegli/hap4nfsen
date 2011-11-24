if [ `basename $PWD` != "src" ]; then
	echo "Change to /src/ please";
	exit;
fi

diff -up nfsen-1.3.5-vanilla/html/details.php nfsen-1.3.5-patched/html/details.php > patches/details.php.patch
diff -up nfsen-1.3.5-vanilla/etc/nfsen-dist.conf nfsen-1.3.5-patched/etc/nfsen-dist.conf > patches/nfsen-dist.conf.patch
diff -up nfsen-1.3.5-vanilla/html/nfsen.php nfsen-1.3.5-patched/html/nfsen.php > patches/nfsen.php.patch
diff -up nfsen-1.3.5-vanilla/html/pic.php nfsen-1.3.5-patched/html/pic.php > patches/pic.php.patch
#( cd HAPviewer_V122-patched/ && for n in *;do diff -upbwN ../HAPviewer_V122-vanilla/$n $n > ../patches/HAPviewer_V122/$n.patch;done )
#( cd patches/HAPviewer_V122/ && find . -type f -name "*.patch" -size 0 -exec rm  "{}" \; )
